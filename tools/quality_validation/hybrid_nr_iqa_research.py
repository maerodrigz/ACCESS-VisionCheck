#!/usr/bin/env python3
"""Research-only hybrid No-Reference IQA for ACCESS VisionCheck Phase 1.

Architecture (frozen before pilot comparison):
  - Overall perceptual quality (OPQ): official Google MUSIQ PaQ-2-PiQ via TF Hub
    (scale ~0-100). Kept separate from criterion heads.
  - Criterion heads: OpenCV/NumPy classical signals + production color heuristics
    (Color Balance / Color Saturation), mapped to continuous q in [0,1] and
    equal-bin 1-5 badges using a priori scales from Phase 9 TECHNICAL_SCORING
    (not fitted on the 30-image human pilot).

Does not import or call production media_evaluator, EfficientNet, PROBE, WaveRep,
Gemini, XP, Flutter, React, or PostgreSQL. Does not write production trees.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"

# ---------------------------------------------------------------------------
# A priori scales (Phase 9 TECHNICAL_SCORING_CANDIDATES / scoring_candidates.py).
# Declared before any pilot Spearman/MAE. Not percentile-fitted on pilot_hvsm
# or SPAQ-200. SPAQ-200 was previously used for exploratory Tenengrad readiness
# reporting only; these LAP/blocking scales predate that and come from production
# OpenCV / trainer knobs.
# ---------------------------------------------------------------------------
LAP_SCALE = 420.0
BLOCK_RATIO_REF = 1.0
RESIZE_CAP = 1024  # longest side; INTER_AREA; no upscale (Phase 13 prototype)

# License notes for the OPQ path (copied into reports; do not claim production OK).
MUSIQ_LICENSE_NOTES = {
    "preferred_engine": "TensorFlow Hub google/musiq TensorFlow2/paq2piq/1",
    "tfhub_license_label": "Apache License 2.0 (as listed on TF Hub / Kaggle model card)",
    "google_research_source": (
        "google-research/google-research musiq/*.py headers: Apache License 2.0"
    ),
    "gcs_npz_limitation": (
        "gs://gresearch/musiq/*.npz weights have no LICENSE/NOTICE in the bucket. "
        "Apache labeling of repo code does not automatically cover those npz files. "
        "Production use of GCS npz is not established."
    ),
    "pyiqa_limitation": (
        "IQA-PyTorch (pyiqa) is PolyForm Noncommercial License 1.0.0. Research-only OK; "
        "commercial / production redistribution is not permitted under that license. "
        "Phase 1 prefers the official TF Hub SavedModel, not pyiqa."
    ),
    "training_data_note": (
        "MUSIQ PaQ-2-PiQ was trained on public IQA corpora (PaQ-2-PiQ/FLIVE and related). "
        "Those dataset licenses are separate from the model card Apache label."
    ),
    "intended_use_this_phase": (
        "Research comparison only inside tools/quality_validation. Not enabled in "
        "production API, Flutter, XP, or rule-based feedback."
    ),
}


def clip01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))


def equal_bin_1_5(q: float) -> int:
    """Monotone bins that can emit 1 and 5. q in [0,1], higher=better.

    Frozen a priori map from Phase 9. Not fitted on the human pilot.
    """
    x = clip01(q)
    if x >= 1.0:
        return 5
    return 1 + int(x * 5.0)


def linear_continuous_1_5(q: float) -> float:
    return 1.0 + 4.0 * clip01(q)


def production_brightness_q(mean_luma: float) -> float:
    """Triangle around 0.48 (production brightness remap; a priori)."""
    return clip01(1.0 - abs(float(mean_luma) - 0.48) * 2.2)


def _resize_cap_bgr(bgr: np.ndarray, cap: int = RESIZE_CAP) -> np.ndarray:
    if cv2 is None:
        raise RuntimeError("OpenCV is required for hybrid classical criteria")
    h, w = bgr.shape[:2]
    longest = max(h, w)
    if longest <= cap:
        return bgr
    scale = cap / float(longest)
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    return cv2.resize(bgr, (nw, nh), interpolation=cv2.INTER_AREA)


def _decode_bgr(path: Path) -> np.ndarray:
    if cv2 is None:
        raise RuntimeError("OpenCV is required")
    data = np.fromfile(str(path), dtype=np.uint8)
    bgr = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if bgr is None:
        raise RuntimeError(f"could not decode image: {path}")
    return bgr


def _import_color_heuristics():
    """Reuse production color heuristics without modifying them."""
    backend = str(_BACKEND)
    if backend not in sys.path:
        sys.path.insert(0, backend)
    from app.services.color_quality_criteria import (  # type: ignore
        analyze_color_balance_criterion_bgr,
        analyze_color_saturation_criterion_bgr,
    )

    return analyze_color_balance_criterion_bgr, analyze_color_saturation_criterion_bgr


def classical_quality_q(bgr: np.ndarray) -> dict[str, Any]:
    """Higher-is-better continuous q for technical criteria + raw signals."""
    from classical_quality_metrics import analyze_bgr

    raw = analyze_bgr(bgr)
    lap = float(raw["sharpness_laplacian_var"])
    sharpness_q = clip01(lap / LAP_SCALE)
    # Blur uses the same Laplacian quality axis (Phase 9 duplication note).
    # Reported separately so the pilot can measure correlation with human Blur.
    blur_q = sharpness_q
    luma = float(raw["brightness_mean"])
    clipf = clip01(float(raw["exposure_clip_frac"]))
    brightness_q = clip01(production_brightness_q(luma) * (1.0 - clipf))
    rms_q = clip01(float(raw["contrast_rms"]))
    contrast_q = clip01(rms_q * (1.0 - clipf))
    bound = float(raw["blocking_boundary_ratio"])
    blocking_q = clip01(1.0 / (1.0 + max(0.0, bound - BLOCK_RATIO_REF)))
    return {
        "raw": raw,
        "q": {
            "sharpness": sharpness_q,
            "blur": blur_q,
            "brightness": brightness_q,
            "contrast": contrast_q,
            "blocking_artifacts": blocking_q,
        },
        "badge_equal_bin": {
            "sharpness": equal_bin_1_5(sharpness_q),
            "blur": equal_bin_1_5(blur_q),
            "brightness": equal_bin_1_5(brightness_q),
            "contrast": equal_bin_1_5(contrast_q),
            "blocking_artifacts": equal_bin_1_5(blocking_q),
        },
        "linear_continuous": {
            "sharpness": linear_continuous_1_5(sharpness_q),
            "blur": linear_continuous_1_5(blur_q),
            "brightness": linear_continuous_1_5(brightness_q),
            "contrast": linear_continuous_1_5(contrast_q),
            "blocking_artifacts": linear_continuous_1_5(blocking_q),
        },
        "notes": {
            "sharpness_blur_duplication": (
                "Sharpness and Blur share the Laplacian / LAP_SCALE quality axis "
                "(Phase 9). They are not independent detectors."
            ),
            "mapping": "equal_bin_1_5 on a priori q; not fitted on human pilot",
            "resize_cap": RESIZE_CAP,
        },
    }


def color_criteria(bgr: np.ndarray) -> dict[str, Any]:
    bal_fn, sat_fn = _import_color_heuristics()
    bal = bal_fn(bgr)
    sat = sat_fn(bgr)
    out: dict[str, Any] = {
        "color_balance": {
            "available": bool(bal.get("available", False)),
            "badge": int(bal["score"]) if bal.get("available") else None,
            "label": bal.get("label"),
            "estimate_kind": bal.get("estimate_kind"),
            "source": "access_backend.app.services.color_quality_criteria (read-only reuse)",
        },
        "color_saturation": {
            "available": bool(sat.get("available", False)),
            "badge": int(sat["score"]) if sat.get("available") else None,
            "label": sat.get("label"),
            "estimate_kind": sat.get("estimate_kind"),
            "source": "access_backend.app.services.color_quality_criteria (read-only reuse)",
        },
    }
    return out


@dataclass
class HybridResult:
    media_id: str
    path: str
    criteria: dict[str, Any] = field(default_factory=dict)
    color: dict[str, Any] = field(default_factory=dict)
    musiq_opq: float | None = None
    musiq_engine: str | None = None
    musiq_error: str | None = None
    errors: list[str] = field(default_factory=list)

    def to_flat_row(self) -> dict[str, Any]:
        q = self.criteria.get("q", {})
        badge = self.criteria.get("badge_equal_bin", {})
        lin = self.criteria.get("linear_continuous", {})
        raw = self.criteria.get("raw", {})
        bal = self.color.get("color_balance", {})
        sat = self.color.get("color_saturation", {})
        return {
            "media_id": self.media_id,
            "path": self.path,
            "musiq_opq_raw": self.musiq_opq,
            "musiq_engine": self.musiq_engine,
            "musiq_error": self.musiq_error,
            "q_sharpness": q.get("sharpness"),
            "q_blur": q.get("blur"),
            "q_brightness": q.get("brightness"),
            "q_contrast": q.get("contrast"),
            "q_blocking_artifacts": q.get("blocking_artifacts"),
            "badge_sharpness": badge.get("sharpness"),
            "badge_blur": badge.get("blur"),
            "badge_brightness": badge.get("brightness"),
            "badge_contrast": badge.get("contrast"),
            "badge_blocking_artifacts": badge.get("blocking_artifacts"),
            "lin_sharpness": lin.get("sharpness"),
            "lin_blur": lin.get("blur"),
            "lin_brightness": lin.get("brightness"),
            "lin_contrast": lin.get("contrast"),
            "lin_blocking_artifacts": lin.get("blocking_artifacts"),
            "raw_laplacian_var": raw.get("sharpness_laplacian_var"),
            "raw_tenengrad": raw.get("sharpness_tenengrad"),
            "raw_brightness_mean": raw.get("brightness_mean"),
            "raw_contrast_rms": raw.get("contrast_rms"),
            "raw_blocking_boundary_ratio": raw.get("blocking_boundary_ratio"),
            "badge_color_balance": bal.get("badge"),
            "color_balance_available": bal.get("available"),
            "badge_color_saturation": sat.get("badge"),
            "color_saturation_available": sat.get("available"),
            "errors": "; ".join(self.errors) if self.errors else "",
        }


def score_image_classical(path: Path, media_id: str) -> HybridResult:
    result = HybridResult(media_id=media_id, path=str(path))
    try:
        bgr = _resize_cap_bgr(_decode_bgr(path))
        result.criteria = classical_quality_q(bgr)
        result.color = color_criteria(bgr)
    except Exception as exc:  # noqa: BLE001
        result.errors.append(f"classical/color: {exc}")
    return result


def load_official_musiq_predict_fn(
    *,
    tfhub_cache_dir: Path | None = None,
) -> tuple[Any, str]:
    """Load official TF Hub MUSIQ PaQ-2-PiQ SavedModel (research venv)."""
    import os

    os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")
    if tfhub_cache_dir is not None:
        tfhub_cache_dir.mkdir(parents=True, exist_ok=True)
        os.environ["TFHUB_CACHE_DIR"] = str(tfhub_cache_dir)

    import tensorflow as tf
    import tensorflow_hub as hub

    tf.config.set_visible_devices([], "GPU")
    handles = (
        "https://tfhub.dev/google/musiq/paq2piq/1",
        "https://www.kaggle.com/models/google/musiq/TensorFlow2/paq2piq/1",
    )
    last_err: Exception | None = None
    for handle in handles:
        try:
            model = hub.load(handle)
            return model.signatures["serving_default"], handle
        except Exception as exc:  # noqa: BLE001
            last_err = exc
    raise RuntimeError(f"Could not load official MUSIQ PaQ-2-PiQ: {last_err}")


def _scalar_from_hub(prediction: Any) -> float:
    if isinstance(prediction, dict):
        if "output_0" in prediction:
            tensor = prediction["output_0"]
        elif len(prediction) == 1:
            tensor = next(iter(prediction.values()))
        else:
            for key in ("mos", "predictions", "output", "outputs"):
                if key in prediction:
                    tensor = prediction[key]
                    break
            else:
                tensor = prediction[sorted(prediction.keys())[0]]
    else:
        tensor = prediction
    numpy = tensor.numpy() if hasattr(tensor, "numpy") else tensor
    arr = np.asarray(numpy, dtype=float).reshape(-1)
    if arr.size == 0:
        raise RuntimeError("empty MUSIQ prediction")
    return float(arr[0])


def score_jpeg_musiq(predict_fn: Any, image_path: Path) -> float:
    import tensorflow as tf

    raw = image_path.read_bytes()
    if not raw:
        raise RuntimeError(f"empty file: {image_path}")
    return _scalar_from_hub(predict_fn(tf.constant(raw)))


def attach_musiq(
    result: HybridResult,
    predict_fn: Any | None,
    engine: str | None,
    image_path: Path,
) -> HybridResult:
    if predict_fn is None:
        result.musiq_opq = None
        result.musiq_engine = None
        result.musiq_error = "MUSIQ engine not loaded"
        return result
    try:
        result.musiq_opq = score_jpeg_musiq(predict_fn, image_path)
        result.musiq_engine = engine
        result.musiq_error = None
    except Exception as exc:  # noqa: BLE001
        result.musiq_opq = None
        result.musiq_engine = engine
        result.musiq_error = str(exc)
        result.errors.append(f"musiq: {exc}")
    return result
