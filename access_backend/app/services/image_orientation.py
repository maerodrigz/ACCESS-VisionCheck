"""Apply stored EXIF / container orientation before quality scoring."""

from __future__ import annotations

from io import BytesIO
from typing import Any

import numpy as np

try:
    from PIL import Image, ImageOps
except ImportError:  # pragma: no cover
    Image = None  # type: ignore
    ImageOps = None  # type: ignore

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore


def oriented_pil_image(content: bytes) -> Any | None:
    if Image is None or not content:
        return None
    try:
        image = Image.open(BytesIO(content))
        image.load()
        transposed = ImageOps.exif_transpose(image) if ImageOps is not None else image
        return (transposed or image).convert("RGB")
    except Exception:
        return None


def decode_oriented_bgr(content: bytes) -> np.ndarray | None:
    """Decode still image to BGR with EXIF orientation applied when present."""
    pil = oriented_pil_image(content)
    if pil is not None:
        rgb = np.array(pil)
        if rgb.ndim == 3 and rgb.shape[2] >= 3:
            return rgb[:, :, :3][:, :, ::-1].copy()
        return None
    if cv2 is None or not content:
        return None
    arr = np.frombuffer(content, dtype=np.uint8)
    return cv2.imdecode(arr, cv2.IMREAD_COLOR)


def rotate_bgr(frame: np.ndarray, degrees: int) -> np.ndarray:
    if cv2 is None or frame is None:
        return frame
    deg = int(degrees) % 360
    if deg == 90:
        return cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)
    if deg == 180:
        return cv2.rotate(frame, cv2.ROTATE_180)
    if deg == 270:
        return cv2.rotate(frame, cv2.ROTATE_90_COUNTERCLOCKWISE)
    return frame
