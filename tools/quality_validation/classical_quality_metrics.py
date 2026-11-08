"""Research-only classical NR metrics. Not used by production scoring."""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore


def analyze_bgr(bgr: np.ndarray) -> dict[str, float]:
    if cv2 is None:
        raise RuntimeError("OpenCV is required for classical research metrics")
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
        "blur_inv_laplacian": 1.0 / (1.0 + laplacian_var / 420.0),
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


def analyze_image_bytes(content: bytes) -> dict[str, float] | None:
    if cv2 is None or not content:
        return None
    arr = np.frombuffer(content, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if bgr is None:
        return None
    return analyze_bgr(bgr)


def _residual_std(gray: np.ndarray) -> float:
    g8 = np.clip(gray, 0, 255).astype(np.uint8)
    blur = cv2.GaussianBlur(g8, (5, 5), 0)
    return float(np.std(np.abs(g8.astype(np.float64) - blur.astype(np.float64))))


def _immerkaer(gray: np.ndarray) -> float:
    """σ estimate from Immerkaer Laplacian convolution."""
    kernel = np.array([[1, -2, 1], [-2, 4, -2], [1, -2, 1]], dtype=np.float64)
    conv = cv2.filter2D(gray, cv2.CV_64F, kernel)
    h, w = gray.shape
    if h < 3 or w < 3:
        return 0.0
    return float(np.sqrt(np.pi / 2.0) * np.mean(np.abs(conv[1:-1, 1:-1])) / 6.0)


def _blocking_boundary_ratio(gray: np.ndarray) -> float:
    """Mean |Δ| on 8-pixel grid lines vs off-grid neighbors. Higher = more blocking."""
    h, w = gray.shape
    if h < 16 or w < 16:
        return 0.0

    def _ratio(axis: int) -> float:
        # axis=1: vertical edges (columns); axis=0: horizontal edges (rows)
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
    if cv2 is None:
        return 0.0
    edges = cv2.Canny(gray_u8, 80, 160)
    lap = cv2.Laplacian(gray_u8, cv2.CV_64F)
    mask = edges > 0
    if int(np.count_nonzero(mask)) == 0:
        return 0.0
    return float(np.mean(np.abs(lap[mask])))


def metric_direction(name: str) -> str:
    """Whether a larger classical value means more defect or more quality."""
    quality_high = {
        "sharpness_laplacian_var",
        "sharpness_tenengrad",
        "exposure_triangle_048",
        "contrast_rms",
        "contrast_michelson",
        "brightness_mean",
    }
    return "higher_is_quality" if name in quality_high else "higher_is_defect"
