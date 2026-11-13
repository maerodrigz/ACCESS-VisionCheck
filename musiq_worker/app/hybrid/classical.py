"""Phase 1 classical OpenCV/NumPy criterion measurements for quality shadow scoring.

Frozen a priori maps from Phase 9 TECHNICAL_SCORING (LAP_SCALE=420, brightness
triangle 0.48, blocking boundary ratio). Not percentile-fitted on the human pilot.
Does not call production EfficientNet or `_soft_score`.
"""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

LAP_SCALE = 420.0
BLOCK_RATIO_REF = 1.0
RESIZE_CAP = 1024
CLASSICAL_MAP_VERSION = "phase9_a_priori_equal_bin_v1"


def clip01(x: float) -> float:
    return max(0.0, min(1.0, float(x)))


def equal_bin_1_5(q: float) -> int:
    """Monotone bins that can emit 1 and 5. q in [0,1], higher=better."""
    x = clip01(q)
    if x >= 1.0:
        return 5
    return 1 + int(x * 5.0)


def production_brightness_q(mean_luma: float) -> float:
    return clip01(1.0 - abs(float(mean_luma) - 0.48) * 2.2)


def _resize_cap_bgr(bgr: np.ndarray, cap: int = RESIZE_CAP) -> np.ndarray:
    if cv2 is None:
        raise RuntimeError("OpenCV is required for shadow classical criteria")
    h, w = bgr.shape[:2]
    longest = max(h, w)
    if longest <= cap:
        return bgr
    scale = cap / float(longest)
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    return cv2.resize(bgr, (nw, nh), interpolation=cv2.INTER_AREA)


def _immerkaer(gray: np.ndarray) -> float:
    kernel = np.array([[1, -2, 1], [-2, 4, -2], [1, -2, 1]], dtype=np.float64)
    conv = cv2.filter2D(gray, cv2.CV_64F, kernel)
    h, w = gray.shape
    if h < 3 or w < 3:
        return 0.0
    return float(np.sqrt(np.pi / 2.0) * np.mean(np.abs(conv[1:-1, 1:-1])) / 6.0)


def _residual_std(gray: np.ndarray) -> float:
    g8 = np.clip(gray, 0, 255).astype(np.uint8)
    blur = cv2.GaussianBlur(g8, (5, 5), 0)
    return float(np.std(np.abs(g8.astype(np.float64) - blur.astype(np.float64))))


def _blocking_boundary_ratio(gray: np.ndarray) -> float:
    h, w = gray.shape
    if h < 16 or w < 16:
        return 0.0

    def _ratio(axis: int) -> float:
        bound: list[float] = []
        interior: list[float] = []
        length = w if axis == 1 else h
        for i in range(1, length):
            if axis == 1:
                delta = float(np.mean(np.abs(gray[:, i] - gray[:, i - 1])))
            else:
                delta = float(np.mean(np.abs(gray[i, :] - gray[i - 1, :])))
            if i % 8 == 0:
                bound.append(delta)
            else:
                interior.append(delta)
        if not bound or not interior:
            return 0.0
        return float(np.mean(bound) / (float(np.mean(interior)) + 1e-6))

    return 0.5 * (_ratio(1) + _ratio(0))


def _flat_block_frac(gray: np.ndarray) -> float:
    h, w = gray.shape
    block = 8
    if h < block * 2 or w < block * 2:
        return 0.0
    flat = 0
    total = 0
    for y in range(0, h - block, block):
        for x in range(0, w - block, block):
            patch = gray[y : y + block, x : x + block]
            total += 1
            if float(np.var(patch)) < 8.0:
                flat += 1
    return flat / total if total else 0.0


def _ringing_edge_lap(gray_u8: np.ndarray) -> float:
    edges = cv2.Canny(gray_u8, 80, 160)
    lap = cv2.Laplacian(gray_u8, cv2.CV_64F)
    mask = edges > 0
    if int(np.count_nonzero(mask)) == 0:
        return 0.0
    return float(np.mean(np.abs(lap[mask])))


def analyze_bgr_raw(bgr: np.ndarray) -> dict[str, float]:
    if cv2 is None:
        raise RuntimeError("OpenCV is required for shadow classical criteria")
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY).astype(np.float64)
    mean = float(np.mean(gray))
    std = float(np.std(gray))
    lap = cv2.Laplacian(gray, cv2.CV_64F)
    gx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    tenengrad = float(np.mean(gx * gx + gy * gy))
    laplacian_var = float(np.var(lap))
    shadow = float(np.mean(gray < 8.0))
    highlight = float(np.mean(gray > 247.0))
    gmin, gmax = float(np.min(gray)), float(np.max(gray))
    michelson = (gmax - gmin) / (gmax + gmin + 1e-6)
    return {
        "sharpness_laplacian_var": laplacian_var,
        "sharpness_tenengrad": tenengrad,
        "blur_inv_laplacian": 1.0 / (1.0 + laplacian_var / LAP_SCALE),
        "noise_immerkaer": _immerkaer(gray),
        "noise_residual_std": _residual_std(gray),
        "brightness_mean": mean / 255.0,
        "exposure_clip_frac": shadow + highlight,
        "exposure_triangle_048": max(0.0, min(1.0, 1.0 - abs(mean / 255.0 - 0.48) * 2.2)),
        "contrast_rms": std / 72.0,
        "contrast_michelson": float(michelson),
        "blocking_boundary_ratio": _blocking_boundary_ratio(gray),
        "blocking_flat_frac": _flat_block_frac(gray),
        "ringing_edge_lap": _ringing_edge_lap(gray.astype(np.uint8)),
    }


def classical_quality_from_bgr(bgr: np.ndarray) -> dict[str, Any]:
    """Higher-is-better continuous q + equal-bin badges (research shadow only)."""
    resized = _resize_cap_bgr(bgr)
    raw = analyze_bgr_raw(resized)
    lap = float(raw["sharpness_laplacian_var"])
    sharpness_q = clip01(lap / LAP_SCALE)
    blur_q = sharpness_q  # Phase 9 duplication: same Laplacian axis
    luma = float(raw["brightness_mean"])
    clipf = clip01(float(raw["exposure_clip_frac"]))
    brightness_q = clip01(production_brightness_q(luma) * (1.0 - clipf))
    contrast_q = clip01(clip01(float(raw["contrast_rms"])) * (1.0 - clipf))
    bound = float(raw["blocking_boundary_ratio"])
    blocking_q = clip01(1.0 / (1.0 + max(0.0, bound - BLOCK_RATIO_REF)))
    q = {
        "sharpness": sharpness_q,
        "blur": blur_q,
        "brightness": brightness_q,
        "contrast": contrast_q,
        "blocking_artifacts": blocking_q,
    }
    return {
        "map_version": CLASSICAL_MAP_VERSION,
        "resize_cap": RESIZE_CAP,
        "raw": raw,
        "q": q,
        "badge_equal_bin": {k: equal_bin_1_5(v) for k, v in q.items()},
        "notes": {
            "sharpness_blur_duplication": True,
            "soft_score_applied": False,
        },
    }


def decode_bgr_from_bytes(content: bytes) -> np.ndarray | None:
    if cv2 is None or not content:
        return None
    arr = np.frombuffer(content, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    return bgr


def color_criteria_from_bgr(bgr: np.ndarray) -> dict[str, Any]:
    from app.hybrid.color_quality_criteria import (
        analyze_color_balance_criterion_bgr,
        analyze_color_saturation_criterion_bgr,
    )

    bal = analyze_color_balance_criterion_bgr(bgr)
    sat = analyze_color_saturation_criterion_bgr(bgr)
    return {
        "color_balance": {
            "available": bool(bal.get("available", False)),
            "badge": int(bal["score"]) if bal.get("available") else None,
            "estimate_kind": bal.get("estimate_kind"),
        },
        "color_saturation": {
            "available": bool(sat.get("available", False)),
            "badge": int(sat["score"]) if sat.get("available") else None,
            "estimate_kind": sat.get("estimate_kind"),
        },
    }
