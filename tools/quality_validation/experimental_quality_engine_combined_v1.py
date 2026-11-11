#!/usr/bin/env python3
"""Research-only combined experimental quality engine (seven criteria).

Composition (explicit; not fitted on SPAQ or ACCESS pilot):
  - Sharpness, Blur, Noise, Brightness, Contrast → experimental_classical_v2 metrics
  - Blocking Artifacts → experimental_blocking_v3
  - Ringing Artifacts → experimental_ringing_v3

Noise v3 remains an alternate research estimator and is NOT used here.

Efficiency: decode once. Compute the five retained v2 heads without running
v2's superseded Blocking/Ringing proxies (those are expensive on large natives
and would be overwritten anyway).

Does not modify production or prior engine source files.
"""

from __future__ import annotations

from typing import Any

import numpy as np

from tools.quality_validation.experimental_blocking_v3 import (
    BLOCKING_V3_ID,
    estimate_blocking_bgr,
)
from tools.quality_validation.experimental_quality_engine import (
    RESIZE_CAP,
    TENENGRAD_TAU,
    _resize_longest,
    _tenengrad,
    clip01,
)
from tools.quality_validation.experimental_quality_engine_v2 import (
    CRITERION_META as V2_CRITERION_META,
)
from tools.quality_validation.experimental_quality_engine_v2 import (
    ENGINE_ID as V2_ENGINE_ID,
)
from tools.quality_validation.experimental_quality_engine_v2 import (
    BLOCK_SEAM_REF,
    HOMOG_NOISE_REF,
    LAP_VAR_LOG_REF,
    RING_OSC_REF,
    _homogeneous_residual_std,
    _laplacian_var,
)
from tools.quality_validation.experimental_ringing_v3 import (
    RINGING_V3_ID,
    estimate_ringing_bgr,
)
from tools.quality_validation.scoring_candidates import (
    equal_bin_1_5,
    production_brightness_q,
    production_soft_score,
)

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

ENGINE_ID = "experimental_classical_combined_v1"

CRITERIA = (
    "Sharpness",
    "Blur",
    "Noise",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Ringing Artifacts",
)

V2_CRITERIA = ("Sharpness", "Blur", "Noise", "Brightness", "Contrast")

COMPOSITION = {
    "Sharpness": "experimental_classical_v2",
    "Blur": "experimental_classical_v2",
    "Noise": "experimental_classical_v2",
    "Brightness": "experimental_classical_v2",
    "Contrast": "experimental_classical_v2",
    "Blocking Artifacts": BLOCKING_V3_ID,
    "Ringing Artifacts": RINGING_V3_ID,
    "Noise_v3_status": "alternate_not_promoted",
}


def _v2_five_criteria(bgr: np.ndarray) -> dict[str, Any]:
    """Sharpness/Blur/Noise/Brightness/Contrast only (v2 metrics, no block/ring)."""
    work = _resize_longest(bgr, RESIZE_CAP)
    gray = cv2.cvtColor(work, cv2.COLOR_BGR2GRAY)
    gray_f = gray.astype(np.float64)

    tenengrad = _tenengrad(gray_f)
    lap_var = _laplacian_var(gray)
    homog_noise = _homogeneous_residual_std(gray)

    mean = float(np.mean(gray_f))
    std = float(np.std(gray_f))
    shadow = float(np.mean(gray_f < 8.0))
    highlight = float(np.mean(gray_f > 247.0))
    clip_frac = shadow + highlight
    luma01 = mean / 255.0
    triangle = production_brightness_q(luma01)
    exposure_q = clip01(triangle * (1.0 - clip01(clip_frac)))
    rms_q = clip01(std / 72.0)
    contrast_q = clip01(rms_q * (1.0 - clip01(clip_frac)))

    q_sharp = clip01(1.0 - float(np.exp(-tenengrad / TENENGRAD_TAU)))
    q_blur = clip01(float(np.log1p(lap_var)) / LAP_VAR_LOG_REF)
    q_noise = clip01(1.0 - homog_noise / HOMOG_NOISE_REF)
    q_bright = exposure_q
    q_contrast = contrast_q

    badges = {
        "Sharpness": equal_bin_1_5(q_sharp),
        "Blur": equal_bin_1_5(q_blur),
        "Noise": equal_bin_1_5(q_noise),
        "Brightness": equal_bin_1_5(q_bright),
        "Contrast": equal_bin_1_5(q_contrast),
    }
    soft = {
        "Sharpness": production_soft_score(q_sharp),
        "Blur": production_soft_score(q_blur),
        "Noise": production_soft_score(q_noise),
        "Brightness": production_soft_score(q_bright),
        "Contrast": production_soft_score(q_contrast),
    }
    return {
        "width": int(work.shape[1]),
        "height": int(work.shape[0]),
        "raw": {
            "tenengrad": tenengrad,
            "laplacian_var": lap_var,
            "homogeneous_residual_std": homog_noise,
            "brightness_mean": luma01,
            "exposure_clip_frac": clip_frac,
            "contrast_rms_over_72": rms_q,
            "shadow_frac": shadow,
            "highlight_frac": highlight,
        },
        "quality_0_1": {
            "sharpness": q_sharp,
            "blur": q_blur,
            "noise": q_noise,
            "brightness": q_bright,
            "contrast": q_contrast,
        },
        "criterion_scores": badges,
        "soft_score_on_experimental_q": soft,
    }


def analyze_bgr(bgr: np.ndarray) -> dict[str, Any]:
    if cv2 is None:
        raise RuntimeError("OpenCV is required for the combined experimental engine")

    five = _v2_five_criteria(bgr)
    blocking = estimate_blocking_bgr(bgr)
    ringing = estimate_ringing_bgr(bgr)

    q_block = float(blocking["quality_cleanliness_0_1"])
    q_ring = float(ringing["quality_cleanliness_0_1"])
    badge_block = equal_bin_1_5(q_block)
    badge_ring = equal_bin_1_5(q_ring)

    criterion_scores = {name: int(five["criterion_scores"][name]) for name in V2_CRITERIA}
    criterion_scores["Blocking Artifacts"] = badge_block
    criterion_scores["Ringing Artifacts"] = badge_ring
    if set(criterion_scores) != set(CRITERIA):
        raise RuntimeError(f"combined engine criterion set mismatch: {sorted(criterion_scores)}")
    overall = round(sum(criterion_scores.values()) / len(criterion_scores), 2)

    quality = dict(five["quality_0_1"])
    quality["blocking_artifacts"] = q_block
    quality["ringing_artifacts"] = q_ring

    raw = dict(five["raw"])
    raw["blocking_amount_v3"] = blocking["blocking_amount"]
    raw["blocking_vertical_excess_v3"] = blocking["vertical_excess"]
    raw["blocking_horizontal_excess_v3"] = blocking["horizontal_excess"]
    raw["ringing_amount_v3"] = ringing["ringing_amount"]
    raw["ringing_median_overshoot_v3"] = ringing["median_overshoot"]
    raw["ringing_median_oscillation_v3"] = ringing["median_oscillation"]

    meta = {k: dict(v) for k, v in V2_CRITERION_META.items() if k in V2_CRITERIA}
    meta["Noise"] = {
        **meta["Noise"],
        "estimator_id": V2_ENGINE_ID,
        "alternate_available": "experimental_noise_v3 (not promoted)",
        "quality_badge_direction": "higher_badge_is_cleaner",
    }
    meta["Blocking Artifacts"] = {
        "proxy": True,
        "raw_name": "blocking_amount_v3",
        "direction": "higher_raw_is_more_blocking",
        "quality_badge_direction": "higher_badge_is_cleaner",
        "estimator_id": BLOCKING_V3_ID,
        "notes": "Combined: Blocking v3 lattice excess; cleanliness badge via equal_bin_1_5.",
    }
    meta["Ringing Artifacts"] = {
        "proxy": True,
        "raw_name": "ringing_amount_v3",
        "direction": "higher_raw_is_more_ringing",
        "quality_badge_direction": "higher_badge_is_cleaner",
        "estimator_id": RINGING_V3_ID,
        "notes": "Combined: Ringing v3 plateau overshoot/oscillation; cleanliness badge via equal_bin_1_5.",
    }

    soft = dict(five["soft_score_on_experimental_q"])
    soft["Blocking Artifacts"] = production_soft_score(q_block)
    soft["Ringing Artifacts"] = production_soft_score(q_ring)

    scales = {
        "TENENGRAD_TAU": TENENGRAD_TAU,
        "LAP_VAR_LOG_REF": LAP_VAR_LOG_REF,
        "HOMOG_NOISE_REF": HOMOG_NOISE_REF,
        "BLOCK_SEAM_REF_unused_legacy": BLOCK_SEAM_REF,
        "RING_OSC_REF_unused_legacy": RING_OSC_REF,
        "parent_engine": V2_ENGINE_ID,
        "blocking_estimator": BLOCKING_V3_ID,
        "ringing_estimator": RINGING_V3_ID,
        "noise_estimator": V2_ENGINE_ID,
        "noise_v3_promoted": False,
        "fitted_on_spaq": False,
        "fitted_on_access_pilot": False,
        "skipped_v2_block_ring_proxies": True,
    }
    scales.update(blocking.get("a_priori_scales") or {})
    scales.update(ringing.get("a_priori_scales") or {})

    return {
        "engine_id": ENGINE_ID,
        "analysis_status": "ok",
        "resize_cap": RESIZE_CAP,
        "width": five["width"],
        "height": five["height"],
        "raw": raw,
        "quality_0_1": quality,
        "criterion_scores": criterion_scores,
        "overall_score": overall,
        "system_overall_is_mean_of_criteria": True,
        "soft_score_on_experimental_q": soft,
        "criterion_meta": meta,
        "mapping": "equal_bin_1_5",
        "parent_engine": V2_ENGINE_ID,
        "revised_criteria": ["Blocking Artifacts", "Ringing Artifacts"],
        "retained_from_v2": list(V2_CRITERIA),
        "composition": COMPOSITION,
        "blocking_v3": blocking,
        "ringing_v3": ringing,
        "a_priori_scales": scales,
        "quality_scale_note": "All seven badges are quality-oriented 1-5 (5=better).",
    }


def analyze_image_bytes(content: bytes) -> dict[str, Any] | None:
    if cv2 is None or not content:
        return None
    arr = np.frombuffer(content, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if bgr is None:
        return None
    try:
        from app.services.image_orientation import decode_oriented_bgr

        oriented = decode_oriented_bgr(content)
        if oriented is not None:
            bgr = oriented
    except Exception:
        pass
    return analyze_bgr(bgr)
