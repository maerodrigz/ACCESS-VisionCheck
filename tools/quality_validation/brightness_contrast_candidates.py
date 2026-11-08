#!/usr/bin/env python3
"""ACCESS VisionCheck — research-only Brightness/Exposure & Contrast quality
candidates (B1, B2, C1, C2). NOT production scoring. No production imports.

Revisions applied vs the initial design:
  - B1: luminance-distribution baseline (preserved).
  - C1: global + local contrast baseline, saturating (preserved).
  - B2: BOUNDED clipping-aware exposure penalties. Distinguishes a clipped
    spike (pixels AT the extreme, levels 0-1 / 254-255) from ordinary tonal
    extremes (a smooth tail near but not at the edge). Penalties are bounded so
    naturally dark/bright scenes are not treated as fully defective.
  - C2: ALL outputs kept in [0,1]. Uses ONE combined, bounded "extremes"
    fraction (shadow + highlight + harshness overlap), so penalties are not
    double-counted.
  - Gradient / detail-preservation measurements are computed and recorded for
    DIAGNOSTICS ONLY. They are NOT included in the primary B or C quality
    formulas until independently validated.
  - The 1-5 anchors below are TEMPORARY DIAGNOSTIC LABELS, unvalidated, and NOT
    suitable for member-facing production use.

All parameters are a-priori placeholders to be validated on independent
human-rated data. Nothing here is fit on SPAQ-200 or on controlled distortions.
"""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore


# --- a-priori placeholder parameters (NOT fit; declared, to be validated) --------
PARAMS: dict[str, dict[str, float]] = {
    "B1": {"c": 0.5, "w": 2.0, "delta": 0.2, "mid_lo": 0.10, "mid_hi": 0.90},
    "B2": {
        "c": 0.5, "w": 2.0,
        "edge_lo": 0.004, "edge_hi": 0.996,    # "at the extreme" = clipped spike (levels 0-1 / 254-255)
        "band_lo": 0.02, "band_hi": 0.98,      # ordinary tonal-extreme band (near, not at, the edge)
        "alpha_clip": 0.6, "cap_clip": 0.15,   # bounded clipped-spike penalty (caps total effect)
        "alpha_band": 0.2, "cap_band": 0.30,   # smaller, bounded ordinary-extreme penalty
    },
    "C1": {"g_ref": 0.18, "k_g": 0.6, "k_l": 0.4, "tau": 0.5, "block_frac": 16},
    "C2": {
        "g_ref": 0.18, "k_g": 0.6, "k_l": 0.4, "tau": 0.5, "block_frac": 16,
        "t_d": 0.02, "t_h": 0.98,              # extremes band (single combined fraction)
        "kappa": 0.8, "cap_ext": 0.25,         # bounded combined-extremes penalty
    },
}

# TEMPORARY DIAGNOSTIC 1-5 anchors (UNVALIDATED; NOT for production). <a0->1...
ANCHORS: list[float] = [0.20, 0.40, 0.62, 0.82]
ANCHORS_NOTE = "Temporary diagnostic anchors, unvalidated, not for member-facing production use."


def _clip(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, x))


def to_luma01(image: np.ndarray) -> np.ndarray:
    """Return luma in [0,1] as float64. Accepts BGR (HxWx3) or grayscale (HxW)."""
    if image.ndim == 2:
        gray = image.astype(np.float64)
    else:
        if cv2 is None:
            raise RuntimeError("OpenCV required for BGR->gray")
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY).astype(np.float64)
    return gray / 255.0


def block_local_std(Y: np.ndarray, bs: int) -> float:
    """Mean per-block std (local contrast). Returns 0 for blocks too large for the image."""
    h, w = Y.shape
    if bs < 2 or h < bs or w < bs:
        return 0.0
    stds: list[float] = []
    for y in range(0, h - bs + 1, bs):
        for x in range(0, w - bs + 1, bs):
            stds.append(float(np.std(Y[y:y + bs, x:x + bs])))
    return float(np.mean(stds)) if stds else 0.0


def mid_tone_gradient_energy(image: np.ndarray, Y: np.ndarray) -> float:
    """DIAGNOSTIC ONLY (not used in B/C quality). Mean Sobel energy in mid-tone pixels.
    Unbounded raw value; recorded for diagnostics, not normalized to a quality scale."""
    if cv2 is None:
        return 0.0
    gray = (Y * 255).astype(np.uint8)
    gx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    energy = gx * gx + gy * gy
    mid = (Y >= 0.10) & (Y <= 0.90)
    if not np.any(mid):
        return 0.0
    return float(np.mean(energy[mid]))


def features(image: np.ndarray) -> dict[str, Any]:
    """Extract raw features used by candidates + diagnostics. Image: BGR or grayscale."""
    if cv2 is None:
        raise RuntimeError("OpenCV required")
    Y = to_luma01(image)
    h, w = Y.shape
    mu = float(np.mean(Y))
    sigma = float(np.std(Y))
    p2 = float(np.percentile(Y, 2))
    p98 = float(np.percentile(Y, 98))
    mid_cov = float(np.mean((Y >= 0.10) & (Y <= 0.90)))
    # clipping: "at the extreme" (clipped spike) vs ordinary tonal-extreme band
    clip_lo = float(np.mean(Y <= 0.004))    # levels 0-1
    clip_hi = float(np.mean(Y >= 0.996))    # levels 254-255
    band_lo = float(np.mean((Y > 0.004) & (Y < 0.02)))
    band_hi = float(np.mean((Y > 0.98) & (Y < 0.996)))
    extremes = float(np.mean((Y < 0.02) | (Y > 0.98)))  # combined for C2 (no double count)
    gmin = float(np.min(Y))
    gmax = float(np.max(Y))
    mich = (gmax - gmin) / (gmax + gmin + 1e-6)
    bs = max(8, max(h, w) // 16)
    local_std = block_local_std(Y, bs)
    detail_mid = mid_tone_gradient_energy(image, Y)
    return {
        "width": int(w), "height": int(h),
        "luma_mean": round(mu, 6),
        "luma_std": round(sigma, 6),
        "p2": round(p2, 6), "p98": round(p98, 6),
        "mid_cov": round(mid_cov, 6),
        "clip_lo": round(clip_lo, 6), "clip_hi": round(clip_hi, 6),
        "band_lo": round(band_lo, 6), "band_hi": round(band_hi, 6),
        "extremes": round(extremes, 6),
        "gmin": round(gmin, 6), "gmax": round(gmax, 6), "michelson": round(mich, 6),
        "local_std": round(local_std, 6),
        "detail_mid_raw": round(detail_mid, 4),
    }


def triangle(mu: float, c: float, w: float) -> float:
    return _clip(1.0 - abs(mu - c) * w)


def q_b1(f: dict[str, Any], p: dict[str, float] = PARAMS["B1"]) -> float:
    """B1 luminance-distribution baseline. Rewards mid-gray bulk + mid-tone coverage."""
    tri = triangle(f["luma_mean"], p["c"], p["w"])
    return _clip(tri * (p["delta"] + (1.0 - p["delta"]) * f["mid_cov"]))


def q_b2(f: dict[str, Any], p: dict[str, float] = PARAMS["B2"]) -> float:
    """B2 bounded clipping-aware exposure quality. Separates clipped spike from
    ordinary tonal extremes; bounded penalties; no detail term in primary formula."""
    tri = triangle(f["luma_mean"], p["c"], p["w"])
    clip_pen = min(f["clip_lo"] + f["clip_hi"], p["cap_clip"]) / p["cap_clip"]      # 0..1, bounded
    band_pen = min(f["band_lo"] + f["band_hi"], p["cap_band"]) / p["cap_band"]    # 0..1, bounded
    pen = (1.0 - p["alpha_clip"] * clip_pen) * (1.0 - p["alpha_band"] * band_pen)
    return _clip(tri * pen)


def _contrast_combo(f: dict[str, Any], p: dict[str, float]) -> tuple[float, float]:
    g = _clip(f["luma_std"] / p["g_ref"], 0.0, 2.0)
    l = _clip(f["local_std"] / p["g_ref"], 0.0, 2.0)
    combo = p["k_g"] * g + p["k_l"] * l
    sat = combo / (combo + p["tau"])  # 0..1 saturating
    return combo, sat


def q_c1(f: dict[str, Any], p: dict[str, float] = PARAMS["C1"]) -> float:
    """C1 global+local contrast baseline, saturating (plateaus, no clipping penalty)."""
    _combo, sat = _contrast_combo(f, p)
    return _clip(sat)


def q_c2(f: dict[str, Any], p: dict[str, float] = PARAMS["C2"]) -> float:
    """C2 clipping-aware contrast. Single combined, bounded extremes penalty (no
    double-count); output in [0,1]. Penzes harsh/crushed contrast."""
    _combo, sat = _contrast_combo(f, p)
    ext = min(f["extremes"], p["cap_ext"]) / p["cap_ext"]      # 0..1, bounded, combined
    pen = 1.0 - p["kappa"] * ext
    return _clip(sat * pen)


def label_1_5(q: float, anchors: list[float] = ANCHORS) -> int:
    """TEMPORARY DIAGNOSTIC label (unvalidated, not for production)."""
    if q < anchors[0]:
        return 1
    if q < anchors[1]:
        return 2
    if q < anchors[2]:
        return 3
    if q < anchors[3]:
        return 4
    return 5


def candidates_for_image(image: np.ndarray) -> dict[str, Any]:
    """Compute all candidate Q values, diagnostic 1-5 labels, and raw features."""
    f = features(image)
    qb1, qb2 = q_b1(f), q_b2(f)
    qc1, qc2 = q_c1(f), q_c2(f)
    return {
        "features": f,
        "Q_B1": round(qb1, 6), "Q_B2": round(qb2, 6),
        "Q_C1": round(qc1, 6), "Q_C2": round(qc2, 6),
        "label_B1": label_1_5(qb1), "label_B2": label_1_5(qb2),
        "label_C1": label_1_5(qc1), "label_C2": label_1_5(qc2),
    }
