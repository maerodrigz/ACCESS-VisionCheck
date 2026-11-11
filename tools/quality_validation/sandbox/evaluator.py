"""Research-only photo quality evaluator for the sandbox.

Returns BOTH engines' results in a single call so the frontend can render a
side-by-side comparison without making two requests.

Engine A — EfficientNet-B0 (production baseline)
    Uses the *same* model weights, the *same* preprocessing (224×224 ImageNet-
    normalised), and the *same* _photo_criteria / _soft_score / _brightness_metric
    badge conversion that production media_evaluator.py uses.  All imported
    read-only; nothing in app/ is modified.  If the model or its weights are
    unavailable the result carries engine_available=False and all badges are None.

Engine B — Experimental Classical Combined v1 (research candidate)
    Sharpness → v2, Blur → v2, Noise → v2 (UNVALIDATED), Brightness → v2,
    Contrast → v2, Blocking → v3 (lightweight-pass only), Ringing → v2 (UNVALIDATED).
    Noise v3/v4 and Ringing v3/v4 alternates can be requested but are never
    auto-selected and are never labelled validated.

STRICT CONTRACT
  - decode once (shared BGR array fed to both engines — no double I/O)
  - no DB writes, no production API calls, no files saved to disk
  - does NOT compute an arithmetic mean of seven badges as a skill grade
  - all experimental scales a priori; none fitted on SPAQ-200 or ACCESS pilot
"""

from __future__ import annotations

import sys
import time
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[3]
BACKEND = REPO / "access_backend"
TOOLKIT = Path(__file__).resolve().parents[1]
for _p in (str(REPO), str(BACKEND), str(TOOLKIT)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import numpy as np  # noqa: E402

try:
    import cv2  # noqa: E402
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

# ── constants ─────────────────────────────────────────────────────────────────

CRITERIA_NAMES = (
    "Sharpness",
    "Blur",
    "Noise",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Ringing Artifacts",
)

_BADGE_LABELS = {1: "Poor", 2: "Needs Improvement", 3: "Fair", 4: "Good", 5: "Excellent"}

# ── public API ────────────────────────────────────────────────────────────────


def evaluate(
    image_bytes: bytes,
    *,
    include_noise_alternates: bool = False,
    include_ringing_alternates: bool = False,
    include_diagnostics: bool = True,
) -> dict[str, Any]:
    """Run both engines and return a structured comparison dict.

    Top-level keys:
        ok, error, image_size, thumbnail_datauri
        engine_a / engine_b   dual-engine blocks (scores unchanged)
        criteria_names, overall_note, research_notes, alternates
        diagnostics           supplementary measurements (optional)
        explanations          per-criterion Why-this-score blocks (optional)
        diagnostics_elapsed_ms
    """
    if cv2 is None:
        return _error_result("OpenCV not available. Use venv312.")
    if not image_bytes:
        return _error_result("Empty image data.")

    # ── single decode ─────────────────────────────────────────────────────────
    try:
        bgr = _decode(image_bytes)
    except Exception as exc:  # noqa: BLE001
        return _error_result(f"Image decode failed: {exc}")

    h, w = bgr.shape[:2]

    # ── Engine A: EfficientNet-B0 ─────────────────────────────────────────────
    engine_a = _run_efficientnet(image_bytes)

    # ── Engine B: Experimental combined v1 ───────────────────────────────────
    engine_b = _run_combined_v1(bgr)
    combined_source = engine_b.pop("_combined_source", None)

    # ── optional alternates ───────────────────────────────────────────────────
    alternates: dict[str, Any] = {}
    if include_noise_alternates:
        alternates["noise"] = _noise_alternates(bgr)
    if include_ringing_alternates:
        alternates["ringing"] = _ringing_alternates(bgr)

    diagnostics: dict[str, Any] | None = None
    explanations: list[dict[str, Any]] | None = None
    diagnostics_elapsed_ms = 0.0
    if include_diagnostics:
        from tools.quality_validation.sandbox.diagnostics import (
            build_criterion_explanations,
            compute_supplementary_diagnostics,
        )

        t_diag = time.perf_counter()
        diagnostics = compute_supplementary_diagnostics(bgr)
        explanations = build_criterion_explanations(
            engine_a=engine_a,
            engine_b=engine_b,
            diagnostics=diagnostics,
            combined_source=combined_source,
        )
        diagnostics_elapsed_ms = round((time.perf_counter() - t_diag) * 1000.0, 1)
        # Attach compact pointers on each classical criterion (scores untouched).
        by_name = {e["name"]: e for e in explanations}
        for c in engine_b.get("criteria") or []:
            exp = by_name.get(c["name"])
            if exp:
                c["explanation"] = {
                    "measures": exp["measures"],
                    "interpretation": exp["classical"].get("interpretation"),
                    "limitation": exp["classical"].get("limitation"),
                    "measurements": exp["classical"].get("measurements"),
                    "disagreement_note": exp.get("disagreement_note"),
                }
        for c in engine_a.get("criteria") or []:
            exp = by_name.get(c["name"])
            if exp:
                c["explanation"] = {
                    "measures": exp["measures"],
                    "interpretation": exp["efficientnet"].get("explanation"),
                    "limitation": exp["efficientnet"].get("limitation"),
                    "measurements": exp["efficientnet"].get("measurements"),
                    "disagreement_note": exp.get("disagreement_note"),
                }

    return {
        "ok": True,
        "error": None,
        "image_size": {"width": int(w), "height": int(h)},
        "thumbnail_datauri": None,   # filled by server
        "engine_a": engine_a,
        "engine_b": engine_b,
        "criteria_names": list(CRITERIA_NAMES),
        "overall_note": (
            "No overall member skill grade is shown. "
            "The arithmetic mean of seven criterion badges is NOT a validated "
            "measure of photographer skill."
        ),
        "research_notes": [
            "Engine A (EfficientNet-B0) is the production baseline scored with "
            "production _soft_score / _brightness_metric badge conversion — read-only, "
            "weights unchanged.",
            "Engine B (Experimental v1) uses research estimators, none of which are "
            "validated for production without further approval.",
            "Noise (classical v2) and Ringing (combined uses v3 estimator) remain "
            "UNVALIDATED for ACCESS production decisions.",
            "Blocking v3 (Engine B) passed lightweight synthetic gates only; human "
            "pilot validation is still pending.",
            "Blur v2 (Engine B) is the strongest research result: pilot rho=0.82.",
            "Diagnostic measurements are explanatory only and do not change badges.",
            "Do not use any result here to retrain models, change thresholds, or "
            "alter member XP.",
        ],
        "alternates": alternates,
        "diagnostics": diagnostics,
        "explanations": explanations,
        "diagnostics_elapsed_ms": diagnostics_elapsed_ms,
        "include_diagnostics": include_diagnostics,
    }


def enet_status() -> dict[str, Any]:
    """Return availability info for EfficientNet without loading the model."""
    try:
        from app.services.efficientnet_b0_scorer import (
            efficientnet_available,
            weights_path,
        )
        avail = efficientnet_available()
        wp = weights_path()
        return {
            "engine_available": avail,
            "weights_path": str(wp),
            "weights_exist": wp.is_file(),
        }
    except Exception as exc:  # noqa: BLE001
        return {"engine_available": False, "error": str(exc)}


# ── engine runners ────────────────────────────────────────────────────────────


_ENET_CRITERIA_META = {
    "Sharpness": ("sharpness", "higher = sharper", "v1-production"),
    "Blur": ("blur", "higher badge = less blur", "v1-production"),
    "Noise": ("noise", "higher badge = cleaner", "v1-production"),
    "Brightness": ("brightness", "higher badge = better exposure", "v1-production"),
    "Contrast": ("contrast", "higher badge = better contrast", "v1-production"),
    "Blocking Artifacts": ("blocking_artifacts", "higher badge = cleaner", "v1-production"),
    "Ringing Artifacts": ("ringing_artifacts", "higher badge = cleaner", "v1-production"),
}

_ENET_LIMITATION = (
    "Sandbox reads production EfficientNet-B0 only. "
    "OpenCV fallback is never substituted here. "
    "Badges use production _soft_score (compressed; badge 1 unreachable for metric in [0,1])."
)


def _enet_placeholder_criteria(*, reason: str) -> list[dict[str, Any]]:
    """Always return seven criterion rows when ENET cannot score (no silent substitute)."""
    rows: list[dict[str, Any]] = []
    for cname in CRITERIA_NAMES:
        raw_key, direction, ver = _ENET_CRITERIA_META[cname]
        rows.append({
            "name": cname,
            "badge": None,
            "badge_label": None,
            "raw_value": None,
            "raw_key": raw_key,
            "version": ver,
            "direction": direction,
            "status": "unavailable",
            "limitation": reason,
            "warning": reason,
        })
    return rows


def _run_efficientnet(image_bytes: bytes) -> dict[str, Any]:
    """Run EfficientNet-B0 using the EXACT same path as production.

    Never calls OpenCV or media_evaluator.resolve_quality_engine_for_bytes.
    If the model/weights are unavailable, returns engine_available=False with
    seven null-badge criteria and an explicit unavailable_reason.
    """
    base: dict[str, Any] = {
        "engine_id": "efficientnet-b0",
        "engine_available": False,
        "elapsed_ms": 0.0,
        "criteria": [],
        "raw_metrics": None,
        "unavailable_reason": None,
        "limitations": [_ENET_LIMITATION],
        "opencv_fallback_used": False,
    }

    # -- check availability without loading weights yet --
    try:
        from app.services.efficientnet_b0_scorer import (
            analyze_image_bytes as enet_analyze,
            efficientnet_available,
            ensure_weights,
            weights_path,
            MODEL_ID,
            MODEL_VERSION,
        )
    except Exception as exc:  # noqa: BLE001
        reason = f"Import error: {exc}"
        base["unavailable_reason"] = reason
        base["criteria"] = _enet_placeholder_criteria(reason=reason)
        return base

    if not efficientnet_available():
        reason = "PyTorch or PIL not available in this environment."
        base["unavailable_reason"] = reason
        base["criteria"] = _enet_placeholder_criteria(reason=reason)
        return base

    wp = weights_path()
    if not wp.is_file():
        reason = (
            f"EfficientNet-B0 weights missing at {wp}. "
            "Scores not computed. OpenCV fallback was NOT used."
        )
        base["unavailable_reason"] = reason
        base["criteria"] = _enet_placeholder_criteria(reason=reason)
        base["weights_path"] = str(wp)
        base["weights_exist"] = False
        return base

    if not ensure_weights():
        reason = (
            f"EfficientNet-B0 weights exist at {wp} but failed to load. "
            "Scores not computed. OpenCV fallback was NOT used."
        )
        base["unavailable_reason"] = reason
        base["criteria"] = _enet_placeholder_criteria(reason=reason)
        base["weights_path"] = str(wp)
        base["weights_exist"] = True
        return base

    # -- infer (EfficientNet only; no OpenCV) --
    t0 = time.perf_counter()
    try:
        raw = enet_analyze(image_bytes)
    except Exception as exc:  # noqa: BLE001
        reason = f"Inference error: {exc}"
        base["unavailable_reason"] = reason
        base["elapsed_ms"] = round((time.perf_counter() - t0) * 1000.0, 1)
        base["criteria"] = _enet_placeholder_criteria(reason=reason)
        return base

    elapsed_ms = round((time.perf_counter() - t0) * 1000.0, 1)

    if raw is None:
        reason = (
            "EfficientNet-B0 analyze_image_bytes returned None. "
            "Scores not computed. OpenCV fallback was NOT used."
        )
        base["unavailable_reason"] = reason
        base["elapsed_ms"] = elapsed_ms
        base["criteria"] = _enet_placeholder_criteria(reason=reason)
        return base

    # -- badge conversion: EXACT same as production _photo_criteria ----------
    try:
        from app.services.media_evaluator import (
            _brightness_metric,
            _soft_score,
        )
    except Exception as exc:  # noqa: BLE001
        reason = f"Badge-conversion import error: {exc}"
        base["unavailable_reason"] = reason
        base["elapsed_ms"] = elapsed_ms
        base["criteria"] = _enet_placeholder_criteria(reason=reason)
        return base

    def _enet_badge(key: str) -> int | None:
        v = raw.get(key)
        if v is None:
            return None
        if key == "brightness":
            return _soft_score(_brightness_metric(float(v)))
        if key in ("blur", "noise", "blocking_artifacts", "ringing_artifacts"):
            # production inverts defect heads
            if key == "noise":
                return _soft_score(1.0 - min(float(v), 0.85))
            return _soft_score(1.0 - float(v))
        return _soft_score(float(v))

    criteria: list[dict[str, Any]] = []
    for cname in CRITERIA_NAMES:
        raw_key, direction, ver = _ENET_CRITERIA_META[cname]
        badge = _enet_badge(raw_key)
        raw_val = raw.get(raw_key)
        status = "production_baseline"
        warning = None
        if cname in ("Noise", "Ringing Artifacts"):
            status = "production_estimate_unvalidated_on_ACCESS_pilot"
            warning = (
                f"{cname} from EfficientNet-B0 is a model estimate, not an ACCESS-validated "
                "human-rubric measurement."
            )
        criteria.append({
            "name": cname,
            "badge": badge,
            "badge_label": _BADGE_LABELS.get(badge, "?") if badge else None,
            "raw_value": round(float(raw_val), 4) if raw_val is not None else None,
            "raw_key": raw_key,
            "version": ver,
            "direction": direction,
            "status": status,
            "limitation": _ENET_LIMITATION,
            "warning": warning,
        })

    return {
        "engine_id": f"efficientnet-b0 v{MODEL_VERSION}",
        "engine_available": True,
        "elapsed_ms": elapsed_ms,
        "criteria": criteria,
        "raw_metrics": {k: round(float(v), 4) for k, v in raw.items()
                       if k not in ("width", "height")},
        "unavailable_reason": None,
        "opencv_fallback_used": False,
        "weights_path": str(wp),
        "weights_exist": True,
        "model_id": MODEL_ID,
        "limitations": [_ENET_LIMITATION],
        "note": (
            "Production baseline. Weights: ml/efficientnet_b0_heads.pt. "
            "Badges use production _soft_score / _brightness_metric. "
            "Weights NOT modified. OpenCV fallback NOT used."
        ),
    }


def _run_combined_v1(bgr: np.ndarray) -> dict[str, Any]:
    """Run experimental combined v1 engine on a pre-decoded BGR array."""
    base: dict[str, Any] = {
        "engine_id": "experimental_classical_combined_v1",
        "engine_available": False,
        "elapsed_ms": 0.0,
        "criteria": [],
        "raw_metrics": None,
        "unavailable_reason": None,
    }

    t0 = time.perf_counter()
    try:
        from tools.quality_validation.experimental_quality_engine_combined_v1 import (
            analyze_bgr as combined_analyze_bgr,
        )
        result = combined_analyze_bgr(bgr)
    except Exception as exc:  # noqa: BLE001
        base["unavailable_reason"] = f"Engine error: {exc}"
        base["elapsed_ms"] = round((time.perf_counter() - t0) * 1000.0, 1)
        return base

    elapsed_ms = round((time.perf_counter() - t0) * 1000.0, 1)

    crit_scores = result["criterion_scores"]
    quality_01 = result.get("quality_0_1", {})
    raw = result.get("raw", {})

    _QUALITY_KEY = {
        "Sharpness": "sharpness", "Blur": "blur", "Noise": "noise",
        "Brightness": "brightness", "Contrast": "contrast",
        "Blocking Artifacts": "blocking_artifacts",
        "Ringing Artifacts": "ringing_artifacts",
    }
    _RAW_KEY = {
        "Sharpness": "tenengrad", "Blur": "laplacian_var",
        "Noise": "homogeneous_residual_std", "Brightness": "brightness_mean",
        "Contrast": "contrast_rms_over_72",
        "Blocking Artifacts": "blocking_amount_v3",
        "Ringing Artifacts": "ringing_amount_v3",
    }
    # Combined-v1 composition: Sharpness..Contrast = classical v2; Blocking = v3;
    # Ringing estimator = ringing v3 (scores unchanged; label corrected for honesty).
    _VERSIONS = {
        "Sharpness": "v2", "Blur": "v2", "Noise": "v2",
        "Brightness": "v2", "Contrast": "v2",
        "Blocking Artifacts": "v3", "Ringing Artifacts": "v3",
    }
    _STATUSES = {
        "Sharpness": "adopted_research", "Blur": "adopted_research",
        "Noise": "UNVALIDATED_on_pilot",
        "Brightness": "adopted_research", "Contrast": "adopted_research",
        "Blocking Artifacts": "lightweight_pass_only",
        "Ringing Artifacts": "UNVALIDATED_on_pilot",
    }
    _WARNINGS: dict[str, str | None] = {
        "Sharpness": None, "Blur": None,
        "Noise": "Noise v2 wrong-signed vs pilot (rho=-0.25). Treat with caution.",
        "Brightness": None, "Contrast": None,
        "Blocking Artifacts": "Blocking v3: lightweight synthetic gates only. Pilot validation pending.",
        "Ringing Artifacts": (
            "Ringing v3 (combined engine) remains UNVALIDATED for ACCESS production. "
            "Sharp edges/textures can false-positive. Treat with caution."
        ),
    }
    _DIRECTIONS = {
        "Sharpness": "higher = sharper",
        "Blur": "higher badge = less blur (quality)",
        "Noise": "higher badge = cleaner (less noise)",
        "Brightness": "higher badge = better exposure",
        "Contrast": "higher badge = better contrast quality",
        "Blocking Artifacts": "higher badge = fewer blocking artifacts",
        "Ringing Artifacts": "higher badge = fewer ringing artifacts",
    }

    criteria: list[dict[str, Any]] = []
    for cname in CRITERIA_NAMES:
        badge = int(crit_scores.get(cname, 3))
        qk = _QUALITY_KEY[cname]
        q = quality_01.get(qk)
        rk = _RAW_KEY[cname]
        rv = raw.get(rk)
        criteria.append({
            "name": cname,
            "badge": badge,
            "badge_label": _BADGE_LABELS.get(badge, "Fair"),
            "quality_0_1": round(float(q), 4) if q is not None else None,
            "raw_value": round(float(rv), 4) if rv is not None else None,
            "raw_key": rk,
            "version": _VERSIONS[cname],
            "status": _STATUSES[cname],
            "direction": _DIRECTIONS[cname],
            "warning": _WARNINGS[cname],
        })

    return {
        "engine_id": result.get("engine_id", "experimental_classical_combined_v1"),
        "engine_available": True,
        "elapsed_ms": elapsed_ms,
        "criteria": criteria,
        "raw_metrics": {k: round(float(v), 4) for k, v in raw.items()
                       if isinstance(v, (int, float))},
        "unavailable_reason": None,
        "composition": result.get("composition"),
        "mapping": result.get("mapping", "equal_bin_1_5"),
        "limitations": [
            "Research classical combined v1. Not production-approved.",
            "Noise v2 UNVALIDATED on ACCESS pilot; Ringing uses v3 estimator and remains UNVALIDATED.",
            "Blocking v3: lightweight synthetic gates only.",
            "Badge mapping: equal_bin_1_5 (not production _soft_score).",
        ],
        "note": (
            "Experimental classical engine. Separate runtime from EfficientNet-B0. "
            "Thresholds unchanged from research modules."
        ),
        # Popped by evaluate() before returning to clients; used for explanations.
        "_combined_source": {
            "raw": raw,
            "quality_0_1": quality_01,
            "blocking_v3": result.get("blocking_v3"),
            "ringing_v3": result.get("ringing_v3"),
        },
    }


# ── internal helpers ──────────────────────────────────────────────────────────


def _decode(image_bytes: bytes) -> np.ndarray:
    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if bgr is None:
        raise ValueError("cv2.imdecode returned None — not a valid image.")
    # Try EXIF-aware decode; fall back silently
    try:
        from app.services.image_orientation import decode_oriented_bgr
        oriented = decode_oriented_bgr(image_bytes)
        if oriented is not None:
            bgr = oriented
    except Exception:  # noqa: BLE001
        pass
    return bgr


def _noise_alternates(bgr: np.ndarray) -> dict[str, Any]:
    out: dict[str, Any] = {}
    try:
        from tools.quality_validation.experimental_noise_v3 import estimate_noise_bgr
        r = estimate_noise_bgr(bgr)
        out["v3"] = {
            "badge": _equal_bin(float(r.get("quality_cleanliness_0_1", 0))),
            "quality_0_1": round(float(r.get("quality_cleanliness_0_1", 0)), 4),
            "noise_amount": round(float(r.get("noise_amount", 0)), 4),
            "version_id": r.get("estimator_id", "experimental_noise_v3"),
            "status": "MIXED_not_promoted",
            "warning": (
                "Noise v3: chroma/AWGN synthetic gates PASS but ACCESS pilot "
                "non-negative correlation gate FAILED (rho=-0.17). NOT promoted."
            ),
        }
    except Exception as exc:  # noqa: BLE001
        out["v3"] = {"error": str(exc)}
    try:
        from tools.quality_validation.experimental_noise_v4_pca import estimate_noise_bgr as est_v4
        r4 = est_v4(bgr)
        out["v4"] = {
            "badge": _equal_bin(float(r4.get("quality_cleanliness_0_1", 0))),
            "quality_0_1": round(float(r4.get("quality_cleanliness_0_1", 0)), 4),
            "noise_amount": round(float(r4.get("noise_amount", 0)), 4),
            "version_id": r4.get("estimator_id", "experimental_noise_v4_pca"),
            "status": "REGRESSED_on_pilot_not_promoted",
            "warning": (
                "Noise v4 (PCA BNE) REGRESSED on frozen human pilot. "
                "Not promoted. Diagnostic only."
            ),
        }
    except Exception as exc:  # noqa: BLE001
        out["v4"] = {"error": str(exc)}
    return out


def _ringing_alternates(bgr: np.ndarray) -> dict[str, Any]:
    out: dict[str, Any] = {}
    try:
        from tools.quality_validation.experimental_ringing_v3 import estimate_ringing_bgr
        r = estimate_ringing_bgr(bgr)
        out["v3"] = {
            "badge": _equal_bin(float(r.get("quality_cleanliness_0_1", 0))),
            "quality_0_1": round(float(r.get("quality_cleanliness_0_1", 0)), 4),
            "ringing_amount": round(float(r.get("ringing_amount", 0)), 4),
            "version_id": r.get("estimator_id", "experimental_ringing_v3"),
            "status": "lightweight_pass_only",
            "warning": "Ringing v3: lightweight synthetic gates PASS. Pilot validation pending.",
        }
    except Exception as exc:  # noqa: BLE001
        out["v3"] = {"error": str(exc)}
    try:
        from tools.quality_validation.experimental_ringing_v4_halo import estimate_ringing_bgr as est_v4
        r4 = est_v4(bgr)
        out["v4"] = {
            "badge": _equal_bin(float(r4.get("quality_cleanliness_0_1", 0))),
            "quality_0_1": round(float(r4.get("quality_cleanliness_0_1", 0)), 4),
            "ringing_amount": round(float(r4.get("ringing_amount", 0)), 4),
            "version_id": r4.get("estimator_id", "experimental_ringing_v4_halo"),
            "status": "REGRESSED_on_pilot_not_promoted",
            "warning": (
                "Ringing v4 (ESF bipolar halo) REGRESSED on frozen human pilot. "
                "Not promoted. Diagnostic only."
            ),
        }
    except Exception as exc:  # noqa: BLE001
        out["v4"] = {"error": str(exc)}
    return out


def _equal_bin(q: float) -> int:
    q = max(0.0, min(1.0, q))
    if q >= 1.0:
        return 5
    return 1 + int(q * 5.0)


def _error_result(msg: str) -> dict[str, Any]:
    return {
        "ok": False,
        "error": msg,
        "image_size": None,
        "thumbnail_datauri": None,
        "engine_a": None,
        "engine_b": None,
        "criteria_names": list(CRITERIA_NAMES),
        "overall_note": "",
        "research_notes": [],
        "alternates": {},
        "diagnostics": None,
        "explanations": None,
        "diagnostics_elapsed_ms": 0.0,
        "include_diagnostics": False,
    }
