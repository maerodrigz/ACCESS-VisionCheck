"""OpenCV technical quality metrics for online media evaluation."""

from __future__ import annotations

from typing import Any

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore


def opencv_available() -> bool:
    return cv2 is not None


def decode_image(content: bytes) -> np.ndarray | None:
    if cv2 is None or not content:
        return None
    arr = np.frombuffer(content, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    return bgr


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


def _blocking_artifacts(gray: np.ndarray) -> float:
    h, w = gray.shape
    block = 8
    if h < block * 2 or w < block * 2:
        return 0.1

    flat_blocks = 0
    total_blocks = 0
    for y in range(0, h - block, block):
        for x in range(0, w - block, block):
            patch = gray[y : y + block, x : x + block].astype(np.float32)
            if patch.size == 0:
                continue
            variance = float(np.var(patch))
            if variance < 8.0:
                flat_blocks += 1
            total_blocks += 1
    if total_blocks == 0:
        return 0.1
    return flat_blocks / total_blocks


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
