#!/usr/bin/env python3
"""Research-only experimental photo-quality engine v2.

Preserves experimental_classical_v1 unchanged. This candidate revises:
  Blur, Noise, Blocking Artifacts, Ringing Artifacts.

Design fixes vs v1 failure modes:
  - Blur: absolute edge-grad saturated near ceiling. v2 uses log1p(Laplacian
    variance) so Gaussian blur severity reduces the metric monotonically.
  - Noise: global residual confuses texture. v2 uses homogeneous-region residual.
  - Blocking: whole-image 8-grid ratio after resize destroyed JPEG lattice and
    over-fired. v2 measures seam strength on a native multiple-of-8 crop
    (no resize) with smoothness weighting.
  - Ringing: edge |Laplacian| tracked sharpness, wrong-signed vs humans. v2 uses
    a conservative near-edge oscillation proxy that stays low on clean sharp
    edges and rises under synthetic Gibbs/unsharp overshoot.

Scales are a priori from synthetic ladders. NOT fitted on SPAQ or ACCESS pilot.
"""

from __future__ import annotations

from typing import Any

import numpy as np

from tools.quality_validation.experimental_quality_engine import (
    RESIZE_CAP,
    TENENGRAD_TAU,
    _resize_longest,
    _tenengrad,
    clip01,
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

ENGINE_ID = "experimental_classical_v2"

# A priori scales from synthetic severity ladders (not SPAQ / not ACCESS pilot).
LAP_VAR_LOG_REF = float(np.log1p(8000.0))  # sharp textured content at ~1k px
HOMOG_NOISE_REF = 12.0
BLOCK_SEAM_REF = 6.0  # smooth-weighted seam |Δ| under heavy JPEG
RING_OSC_REF = 20.0  # smooth-side near-edge oscillation under synthetic overshoot

CRITERION_META = {
    "Sharpness": {
        "proxy": False,
        "raw_name": "tenengrad",
        "direction": "higher_raw_is_better",
        "notes": "Unchanged from v1: Tenengrad energy at 1024 px.",
    },
    "Blur": {
        "proxy": True,
        "raw_name": "laplacian_var",
        "direction": "higher_raw_is_sharper",
        "notes": (
            "log1p(Laplacian variance) freedom-from-blur proxy. Correlated with "
            "Sharpness but not forced to 1-sharpness. Sensitive to defocus/Gaussian "
            "blur; natural shallow DOF also lowers the score."
        ),
    },
    "Noise": {
        "proxy": True,
        "raw_name": "homogeneous_residual_std",
        "direction": "higher_raw_is_more_noise",
        "notes": (
            "Residual std on low-gradient pixels only, reducing texture false alarms. "
            "Badge is cleanliness (inverted)."
        ),
    },
    "Brightness": {
        "proxy": False,
        "raw_name": "exposure_quality_q",
        "direction": "higher_q_is_better",
        "notes": "Unchanged from v1.",
    },
    "Contrast": {
        "proxy": True,
        "raw_name": "contrast_quality_q",
        "direction": "higher_q_is_better",
        "notes": "Unchanged from v1.",
    },
    "Blocking Artifacts": {
        "proxy": True,
        "raw_name": "smooth_weighted_seam_delta",
        "direction": "higher_raw_is_more_blocking",
        "notes": (
            "Mean smoothness-weighted |Δ| on native 8-pixel seams (no resize). "
            "Preserves JPEG lattice; downweights textured seams."
        ),
    },
    "Ringing Artifacts": {
        "proxy": True,
        "raw_name": "near_edge_oscillation",
        "direction": "higher_raw_is_more_ringing",
        "notes": (
            "PROXY: mean absolute second-difference along edge normals in a halo "
            "band. Targets oscillatory overshoot; clean step edges stay low."
        ),
    },
}


def _laplacian_var(gray_u8: np.ndarray) -> float:
    return float(np.var(cv2.Laplacian(gray_u8, cv2.CV_64F)))


def _homogeneous_residual_std(gray_u8: np.ndarray) -> float:
    g = gray_u8.astype(np.float64)
    blur = cv2.GaussianBlur(gray_u8, (5, 5), 0).astype(np.float64)
    residual = np.abs(g - blur)
    gx = cv2.Sobel(g, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(g, cv2.CV_64F, 0, 1, ksize=3)
    mag = np.sqrt(gx * gx + gy * gy)
    thr = max(float(np.percentile(mag, 30)), 8.0)
    mask = mag <= thr
    if int(np.count_nonzero(mask)) < 256:
        return float(np.std(residual))
    return float(np.std(residual[mask]))


def _native_multiple_of_8(gray_u8: np.ndarray) -> np.ndarray:
    h, w = gray_u8.shape
    nh, nw = h - (h % 8), w - (w % 8)
    if nh < 16 or nw < 16:
        return gray_u8
    return gray_u8[:nh, :nw]


def _smooth_weighted_seam_delta(gray_u8: np.ndarray) -> float:
    """Blocking amount on native 8-grid seams (no resize)."""
    gray = _native_multiple_of_8(gray_u8).astype(np.float64)
    h, w = gray.shape
    if h < 16 or w < 16:
        return 0.0
    mu = cv2.GaussianBlur(gray, (5, 5), 0)
    mu2 = cv2.GaussianBlur(gray * gray, (5, 5), 0)
    local_var = np.maximum(mu2 - mu * mu, 0.0)
    weight = 1.0 / (1.0 + local_var / 25.0)

    seam_vals: list[float] = []
    # Vertical seams at x = 8,16,...
    for x in range(8, w, 8):
        delta = np.abs(gray[:, x] - gray[:, x - 1])
        wts = 0.5 * (weight[:, x] + weight[:, x - 1])
        mass = float(np.sum(wts)) + 1e-6
        seam_vals.append(float(np.sum(delta * wts) / mass))
    # Horizontal seams at y = 8,16,...
    for y in range(8, h, 8):
        delta = np.abs(gray[y, :] - gray[y - 1, :])
        wts = 0.5 * (weight[y, :] + weight[y - 1, :])
        mass = float(np.sum(wts)) + 1e-6
        seam_vals.append(float(np.sum(delta * wts) / mass))
    if not seam_vals:
        return 0.0
    return float(np.mean(seam_vals))


def _near_edge_oscillation(gray_u8: np.ndarray) -> float:
    """Oscillatory amplitude on the smooth side of edges (ringing proxy)."""
    g = gray_u8.astype(np.float64)
    gx = cv2.Sobel(g, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(g, cv2.CV_64F, 0, 1, ksize=3)
    mag = np.sqrt(gx * gx + gy * gy) + 1e-6
    edges = cv2.Canny(gray_u8, 80, 160)
    ys, xs = np.where(edges > 0)
    if len(xs) < 40:
        return 0.0
    mu = cv2.GaussianBlur(g, (5, 5), 0)
    mu2 = cv2.GaussianBlur(g * g, (5, 5), 0)
    local_var = np.maximum(mu2 - mu * mu, 0.0)
    step = max(1, len(xs) // 180)
    amps: list[float] = []
    h, w = g.shape
    for i in range(0, len(xs), step):
        x, y = int(xs[i]), int(ys[i])
        dx, dy = float(gx[y, x] / mag[y, x]), float(gy[y, x] / mag[y, x])
        for sign in (-1.0, 1.0):
            samples: list[float] = []
            vars_: list[float] = []
            for t in (2, 3, 4, 5, 6):
                xx = int(round(x + sign * t * dx))
                yy = int(round(y + sign * t * dy))
                if 0 <= xx < w and 0 <= yy < h:
                    samples.append(float(g[yy, xx]))
                    vars_.append(float(local_var[yy, xx]))
            if len(samples) < 4:
                continue
            # Skip textured side of the edge (avoids confusing texture with ringing).
            if float(np.mean(vars_)) > 80.0:
                continue
            arr = np.asarray(samples, dtype=float)
            d2 = arr[2:] - 2.0 * arr[1:-1] + arr[:-2]
            amps.append(float(np.mean(np.abs(d2))))
    if not amps:
        return 0.0
    return float(np.median(np.asarray(amps, dtype=float)))


def analyze_bgr(bgr: np.ndarray) -> dict[str, Any]:
    if cv2 is None:
        raise RuntimeError("OpenCV is required for the experimental engine")

    # Blocking on native lattice BEFORE resize.
    gray_native = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    block_seam = _smooth_weighted_seam_delta(gray_native)
    ring_osc_native = _near_edge_oscillation(gray_native)

    work = _resize_longest(bgr, RESIZE_CAP)
    gray = cv2.cvtColor(work, cv2.COLOR_BGR2GRAY)
    gray_f = gray.astype(np.float64)

    tenengrad = _tenengrad(gray_f)
    lap_var = _laplacian_var(gray)
    homog_noise = _homogeneous_residual_std(gray)
    # Ringing also evaluated after resize as secondary; prefer native when available.
    ring_osc_resized = _near_edge_oscillation(gray)
    ring_osc = max(ring_osc_native, ring_osc_resized)

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
    q_block = clip01(1.0 - block_seam / BLOCK_SEAM_REF)
    q_ring = clip01(1.0 - ring_osc / RING_OSC_REF)

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
            "laplacian_var": lap_var,
            "homogeneous_residual_std": homog_noise,
            "brightness_mean": luma01,
            "exposure_clip_frac": clip_frac,
            "contrast_rms_over_72": rms_q,
            "smooth_weighted_seam_delta": block_seam,
            "near_edge_oscillation": ring_osc,
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
        "parent_engine": "experimental_classical_v1",
        "revised_criteria": ["Blur", "Noise", "Blocking Artifacts", "Ringing Artifacts"],
        "a_priori_scales": {
            "TENENGRAD_TAU": TENENGRAD_TAU,
            "LAP_VAR_LOG_REF": LAP_VAR_LOG_REF,
            "HOMOG_NOISE_REF": HOMOG_NOISE_REF,
            "BLOCK_SEAM_REF": BLOCK_SEAM_REF,
            "RING_OSC_REF": RING_OSC_REF,
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
