"""Unit tests for the research-only experimental quality engine."""

from __future__ import annotations

import numpy as np

from tools.quality_validation.experimental_quality_engine import analyze_bgr
from tools.quality_validation.scoring_candidates import equal_bin_1_5


def _solid(value: int, size: int = 64) -> np.ndarray:
    return np.full((size, size, 3), value, dtype=np.uint8)


def test_equal_bin_can_emit_1_and_5() -> None:
    assert equal_bin_1_5(0.0) == 1
    assert equal_bin_1_5(1.0) == 5


def test_underexposed_brightness_not_max() -> None:
    dark = analyze_bgr(_solid(5))
    mid = analyze_bgr(_solid(120))
    assert dark["criterion_scores"]["Brightness"] < mid["criterion_scores"]["Brightness"]


def test_blurred_image_has_lower_sharpness_than_edges() -> None:
    import cv2

    sharp = np.zeros((128, 128, 3), dtype=np.uint8)
    sharp[:, :64] = 255
    blurred = cv2.GaussianBlur(sharp, (0, 0), 4.0)
    s = analyze_bgr(sharp)
    b = analyze_bgr(blurred)
    assert s["quality_0_1"]["sharpness"] > b["quality_0_1"]["sharpness"]
    assert s["criterion_scores"]["Sharpness"] >= b["criterion_scores"]["Sharpness"]


def test_blur_channel_not_forced_mirror_of_sharpness_integer() -> None:
    """Experimental Blur must not be hard-wired as 6 - Sharpness."""
    img = np.random.default_rng(0).integers(0, 255, size=(96, 96, 3), dtype=np.uint8)
    result = analyze_bgr(img)
    sharp = result["criterion_scores"]["Sharpness"]
    blur = result["criterion_scores"]["Blur"]
    assert blur != 6 - sharp or sharp == 3  # allow coincidence at mid; mainly ensure keys exist
    assert "Blur" in result["criterion_meta"]
    assert result["criterion_meta"]["Blur"]["proxy"] is True
