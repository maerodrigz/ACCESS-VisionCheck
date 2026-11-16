"""OpenCV technical quality metrics for online media evaluation."""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

# Blocking-artifact contract (do not change without parity + product review).
BLOCKING_BLOCK_SIZE = 8
BLOCKING_VARIANCE_THRESHOLD = 8.0
BLOCKING_FALLBACK_SCORE = 0.1


def opencv_available() -> bool:
    return cv2 is not None


def decode_image(content: bytes) -> np.ndarray | None:
    from app.services.image_orientation import decode_oriented_bgr

    return decode_oriented_bgr(content)


def analyze_image_bytes(content: bytes) -> dict[str, Any] | None:
    bgr = decode_image(content)
    if bgr is None:
        return None
    return analyze_bgr(bgr)


def analyze_bgr(bgr: np.ndarray) -> dict[str, Any]:
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape[:2]

    lap_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    sharpness = _normalize(lap_var, scale=420.0)
    blur = 1.0 - sharpness

    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    residual = cv2.absdiff(gray, blurred)
    noise = _normalize(float(np.std(residual)), scale=36.0)

    brightness = float(np.mean(gray) / 255.0)
    contrast = _normalize(float(np.std(gray)), scale=72.0)

    blocking = _blocking_artifacts(gray)
    ringing = _ringing_artifacts(gray)

    return {
        "sharpness": sharpness,
        "blur": blur,
        "noise": noise,
        "brightness": brightness,
        "contrast": contrast,
        "blocking_artifacts": blocking,
        "ringing_artifacts": ringing,
        "width": int(w),
        "height": int(h),
    }


def _normalize(value: float, *, scale: float) -> float:
    if scale <= 0:
        return 0.0
    return max(0.0, min(1.0, value / scale))


def _blocking_grid_counts(h: int, w: int, block: int = BLOCKING_BLOCK_SIZE) -> tuple[int, int]:
    """Block grid size matching ``range(0, dim - block, block)`` in the legacy loop."""
    stop_y = h - block
    stop_x = w - block
    if stop_y <= 0 or stop_x <= 0:
        return 0, 0
    n_rows = (stop_y - 1) // block + 1
    n_cols = (stop_x - 1) // block + 1
    return int(n_rows), int(n_cols)


def _blocking_artifacts_loop_reference(gray: np.ndarray) -> float:
    """Original nested-loop blocking metric (rollback / parity reference).

    Formula: fraction of non-overlapping 8x8 blocks whose population variance
    (float32, ddof=0) is strictly less than 8.0. Undersized images return 0.1.
    """
    h, w = gray.shape[:2]
    block = BLOCKING_BLOCK_SIZE
    if h < block * 2 or w < block * 2:
        return BLOCKING_FALLBACK_SCORE

    flat_blocks = 0
    total_blocks = 0
    for y in range(0, h - block, block):
        for x in range(0, w - block, block):
            patch = gray[y : y + block, x : x + block].astype(np.float32)
            if patch.size == 0:
                continue
            variance = float(np.var(patch))
            if variance < BLOCKING_VARIANCE_THRESHOLD:
                flat_blocks += 1
            total_blocks += 1
    if total_blocks == 0:
        return BLOCKING_FALLBACK_SCORE
    return flat_blocks / total_blocks


def _blocking_artifacts_vectorized(gray: np.ndarray) -> float:
    """NumPy vectorized equivalent of ``_blocking_artifacts_loop_reference``."""
    if gray.ndim != 2:
        raise ValueError("blocking artifacts expect a 2-D grayscale array")
    h, w = gray.shape[:2]
    block = BLOCKING_BLOCK_SIZE
    if h < block * 2 or w < block * 2:
        return BLOCKING_FALLBACK_SCORE

    n_rows, n_cols = _blocking_grid_counts(h, w, block)
    if n_rows <= 0 or n_cols <= 0:
        return BLOCKING_FALLBACK_SCORE

    usable_h = n_rows * block
    usable_w = n_cols * block
    # Same patches as the loop: starts at (0,0), (0,8), ... then (8,0), ...
    region = np.ascontiguousarray(gray[:usable_h, :usable_w], dtype=np.float32)
    blocks = region.reshape(n_rows, block, n_cols, block)
    # Population variance over the 8x8 spatial axes (NumPy default ddof=0).
    variances = np.var(blocks, axis=(1, 3))
    total_blocks = int(variances.size)
    if total_blocks == 0:
        return BLOCKING_FALLBACK_SCORE
    flat_blocks = int(np.count_nonzero(variances < BLOCKING_VARIANCE_THRESHOLD))
    return flat_blocks / total_blocks


# Activate only after phase7f parity script passes (see scripts/verify_opencv_blocking_phase7f.py).
# False = production uses loop reference; True = vectorized (same formula).
USE_VECTORIZED_BLOCKING = True


def _blocking_artifacts(gray: np.ndarray) -> float:
    """Production blocking metric (vectorized by default; loop retained for rollback)."""
    if USE_VECTORIZED_BLOCKING:
        return _blocking_artifacts_vectorized(gray)
    return _blocking_artifacts_loop_reference(gray)


def _ringing_artifacts(gray: np.ndarray) -> float:
    h, w = gray.shape
    if h < 16 or w < 16:
        return 0.08

    edges = cv2.Canny(gray, 80, 160)
    oscillations = 0
    edge_pixels = 0
    step_y = max(1, h // 24)
    for y in range(0, h, step_y):
        row = gray[y, :]
        edge_row = edges[y, :] > 0
        if not np.any(edge_row):
            continue
        diffs = np.diff(row.astype(np.float32))
        signs = np.sign(diffs)
        for i in range(1, len(signs)):
            if edge_row[i] and signs[i] != 0 and signs[i - 1] != 0 and signs[i] != signs[i - 1]:
                oscillations += 1
        edge_pixels += int(np.sum(edge_row))
    if edge_pixels == 0:
        return 0.08
    return max(0.0, min(1.0, oscillations / edge_pixels))
