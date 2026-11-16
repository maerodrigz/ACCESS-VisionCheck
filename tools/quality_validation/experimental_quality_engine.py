#!/usr/bin/env python3
"""Research-only experimental photo-quality engine for ACCESS VisionCheck.

Isolated from production. Does not write to the database, does not change
`_soft_score`, EfficientNet weights, Flutter, or API contracts.

Design notes (a priori; not fitted on SPAQ-200 or the 30-image ACCESS pilot):
- Resize longest side to 1024 (INTER_AREA, no upscale) before classical metrics.
- Sharpness: Tenengrad energy (higher = sharper).
- Blur: relative Laplacian collapse under mild Gaussian blur (higher badge =
  freer from blur). This is intentionally NOT `1 - sharpness`, so the two
  channels are not forced to be exact mirrors, though both remain focus-related
  proxies.
- Noise cleanliness: Immerkaer sigma inverted (higher = cleaner). No 0.85 floor.
- Brightness: two-sided exposure triangle around 0.48 × (1 - clip fraction).
- Contrast: RMS contrast × (1 - clip fraction) so harsh clipping is penalized.
- Blocking: 8×8 boundary discontinuity ratio (not flat-patch fraction).
- Ringing: mean |Laplacian| on Canny edges (PROXY for overshoot; labeled as such).
- 1-5 map: equal-width bins that can emit 1 and 5 (unlike production `_soft_score`).

Overall remains the arithmetic mean of the seven integers for API-shaped
compatibility in research exports only.
"""

from __future__ import annotations

from typing import Any

import numpy as np

from tools.quality_validation.classical_quality_metrics import (
    _blocking_boundary_ratio,
    _immerkaer,
    _ringing_edge_lap,
)
from tools.quality_validation.scoring_candidates import (
    BLOCK_RATIO_REF,
    NOISE_SIGMA_SCALE,
    RING_LAP_SCALE,
    equal_bin_1_5,
    production_brightness_q,
    production_soft_score,
)

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

ENGINE_ID = "experimental_classical_v1"
RESIZE_CAP = 1024

# A priori scales. Not fitted on SPAQ-200, LIVEC, KonIQ pilot, or ACCESS humans.
# Tenengrad tau: soft saturation for 8-bit Sobel energy at ~1k px (research default).
TENENGRAD_TAU = 5000.0
# Mean Sobel magnitude on Canny edges for near-sharp 8-bit photos (a priori).
EDGE_GRAD_REF = 120.0
# Residual high-pass std that should map near "very noisy" (a priori; ~strong AWGN).
RESIDUAL_NOISE_REF = 18.0
# Blocking: boundary/interior ratio excess above near-natural floor.
BLOCK_RATIO_FLOOR = 0.98
BLOCK_RATIO_EXCESS_REF = 0.25
# Ringing edge-Laplacian energy reference (from scoring_candidates).
# RING_LAP_SCALE imported.

CRITERION_META = {
    "Sharpness": {
        "proxy": False,
        "raw_name": "tenengrad",
        "direction": "higher_raw_is_better",
        "notes": "Tenengrad mean(gx^2+gy^2); focus/detail energy proxy.",
    },
    "Blur": {
        "proxy": True,
        "raw_name": "edge_grad_mean",
        "direction": "higher_raw_is_sharper_edges",
        "notes": (
            "Mean Sobel magnitude on Canny edges (edge acuity proxy). "
            "Not a motion-blur classifier and not identical to Tenengrad energy, "
            "but still focus-related. Natural bokeh lowers this score."
        ),
    },
    "Noise": {
        "proxy": True,
        "raw_name": "residual_noise_std",
        "direction": "higher_raw_is_more_noise",
        "notes": (
            "High-pass residual std (|gray-GaussianBlur|). Badge is cleanliness "
            "(inverted). Texture can elevate the residual; not pure sensor noise."
        ),
    },
    "Brightness": {
        "proxy": False,
        "raw_name": "exposure_quality_q",
        "direction": "higher_q_is_better",
        "notes": "Mean-luma triangle at 0.48 with highlight/shadow clip penalty.",
    },
    "Contrast": {
        "proxy": True,
        "raw_name": "contrast_quality_q",
        "direction": "higher_q_is_better",
        "notes": "RMS contrast with clipping penalty; not perceptual local contrast.",
    },
    "Blocking Artifacts": {
        "proxy": True,
        "raw_name": "blocking_boundary_ratio",
        "direction": "higher_raw_is_more_blocking",
        "notes": "8x8 boundary discontinuity ratio vs interior; JPEG-block proxy.",
    },
    "Ringing Artifacts": {
        "proxy": True,
        "raw_name": "ringing_edge_lap",
        "direction": "higher_raw_is_more_ringing",
        "notes": "PROXY: edge |Laplacian| energy; also responds to sharp texture.",
    },
}


def clip01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))


def _resize_longest(bgr: np.ndarray, cap: int = RESIZE_CAP) -> np.ndarray:
    h, w = bgr.shape[:2]
    longest = max(h, w)
    if longest <= cap:
        return bgr
    scale = cap / float(longest)
    nh, nw = max(1, int(round(h * scale))), max(1, int(round(w * scale)))
    return cv2.resize(bgr, (nw, nh), interpolation=cv2.INTER_AREA)


def _tenengrad(gray: np.ndarray) -> float:
    gx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    return float(np.mean(gx * gx + gy * gy))


def _edge_gradient_mean(gray_u8: np.ndarray) -> float:
    """Mean Sobel magnitude on Canny edges. Low when edges are soft or absent."""
    edges = cv2.Canny(gray_u8, 60, 160)
    gx = cv2.Sobel(gray_u8, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray_u8, cv2.CV_64F, 0, 1, ksize=3)
    mag = np.sqrt(gx * gx + gy * gy)
    mask = edges > 0
    if int(np.count_nonzero(mask)) < 32:
        return 0.0
    return float(np.mean(mag[mask]))


def _residual_noise_std(gray_u8: np.ndarray) -> float:
    blur = cv2.GaussianBlur(gray_u8, (5, 5), 0)
    return float(np.std(np.abs(gray_u8.astype(np.float64) - blur.astype(np.float64))))


def analyze_bgr(bgr: np.ndarray) -> dict[str, Any]:
    if cv2 is None:
        raise RuntimeError("OpenCV is required for the experimental engine")
    work = _resize_longest(bgr, RESIZE_CAP)
    gray = cv2.cvtColor(work, cv2.COLOR_BGR2GRAY)
    gray_f = gray.astype(np.float64)

    tenengrad = _tenengrad(gray_f)
    edge_grad = _edge_gradient_mean(gray)
    immer = _immerkaer(gray_f)
    residual = _residual_noise_std(gray)
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
    block_ratio = _blocking_boundary_ratio(gray_f)
    ring_lap = _ringing_edge_lap(gray)

    # Quality axes in [0,1], higher = better for member-facing badges.
    q_sharp = clip01(1.0 - float(np.exp(-tenengrad / TENENGRAD_TAU)))
    q_blur = clip01(edge_grad / EDGE_GRAD_REF)
    q_noise = clip01(1.0 - residual / RESIDUAL_NOISE_REF)
    q_bright = exposure_q
    q_contrast = contrast_q
    q_block = clip01(1.0 - max(0.0, block_ratio - BLOCK_RATIO_FLOOR) / BLOCK_RATIO_EXCESS_REF)
    q_ring = clip01(1.0 - ring_lap / RING_LAP_SCALE)

    badges = {
        "Sharpness": equal_bin_1_5(q_sharp),
        "Blur": equal_bin_1_5(q_blur),
        "Noise": equal_bin_1_5(q_noise),
        "Brightness": equal_bin_1_5(q_bright),
        "Contrast": equal_bin_1_5(q_contrast),
        "Blocking Artifacts": equal_bin_1_5(q_block),
        "Ringing Artifacts": equal_bin_1_5(q_ring),
    }
    overall = round(sum(badges.values()) / len(badges), 2)

    # Illustrative: same experimental q through production soft_score (compression check).
    soft_badges = {
        name: production_soft_score(q)
        for name, q in {
            "Sharpness": q_sharp,
            "Blur": q_blur,
            "Noise": q_noise,
            "Brightness": q_bright,
            "Contrast": q_contrast,
            "Blocking Artifacts": q_block,
            "Ringing Artifacts": q_ring,
        }.items()
    }

    return {
        "engine_id": ENGINE_ID,
        "analysis_status": "ok",
        "resize_cap": RESIZE_CAP,
        "width": int(work.shape[1]),
        "height": int(work.shape[0]),
        "raw": {
            "tenengrad": tenengrad,
            "edge_grad_mean": edge_grad,
            "immerkaer_sigma": immer,
            "residual_noise_std": residual,
            "brightness_mean": luma01,
            "exposure_clip_frac": clip_frac,
            "contrast_rms_over_72": rms_q,
            "blocking_boundary_ratio": block_ratio,
            "ringing_edge_lap": ring_lap,
            "shadow_frac": shadow,
            "highlight_frac": highlight,
        },
        "quality_0_1": {
            "sharpness": q_sharp,
            "blur": q_blur,
            "noise": q_noise,
            "brightness": q_bright,
            "contrast": q_contrast,
            "blocking_artifacts": q_block,
            "ringing_artifacts": q_ring,
        },
        "criterion_scores": badges,
        "overall_score": overall,
        "system_overall_is_mean_of_criteria": True,
        "soft_score_on_experimental_q": soft_badges,
        "criterion_meta": CRITERION_META,
        "mapping": "equal_bin_1_5",
        "a_priori_scales": {
            "TENENGRAD_TAU": TENENGRAD_TAU,
            "EDGE_GRAD_REF": EDGE_GRAD_REF,
            "RESIDUAL_NOISE_REF": RESIDUAL_NOISE_REF,
            "BLOCK_RATIO_FLOOR": BLOCK_RATIO_FLOOR,
            "BLOCK_RATIO_EXCESS_REF": BLOCK_RATIO_EXCESS_REF,
            "RING_LAP_SCALE": RING_LAP_SCALE,
            "NOISE_SIGMA_SCALE_unused_immerkaer": NOISE_SIGMA_SCALE,
            "BLOCK_RATIO_REF_legacy": BLOCK_RATIO_REF,
            "brightness_peak": 0.48,
            "fitted_on_spaq": False,
            "fitted_on_access_pilot": False,
        },
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
