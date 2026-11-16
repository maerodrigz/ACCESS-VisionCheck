"""Unit tests for Phase 1 hybrid NR-IQA research helpers (no network, no TF)."""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pytest

_TOOLKIT = Path(__file__).resolve().parents[1]
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from hybrid_nr_iqa_research import (  # noqa: E402
    classical_quality_q,
    clip01,
    equal_bin_1_5,
    linear_continuous_1_5,
)


def test_equal_bin_can_emit_1_and_5() -> None:
    assert equal_bin_1_5(0.0) == 1
    assert equal_bin_1_5(0.19) == 1
    assert equal_bin_1_5(0.2) == 2
    assert equal_bin_1_5(0.999) == 5
    assert equal_bin_1_5(1.0) == 5


def test_linear_continuous_bounds() -> None:
    assert linear_continuous_1_5(0.0) == 1.0
    assert linear_continuous_1_5(1.0) == 5.0
    assert abs(linear_continuous_1_5(0.5) - 3.0) < 1e-9


def test_classical_quality_q_on_synthetic() -> None:
    pytest.importorskip("cv2")
    # Mid-gray low-detail frame → sharpness/blur low, brightness near triangle peak.
    bgr = np.full((128, 128, 3), 122, dtype=np.uint8)
    out = classical_quality_q(bgr)
    assert set(out["q"]) >= {
        "sharpness",
        "blur",
        "brightness",
        "contrast",
        "blocking_artifacts",
    }
    assert out["badge_equal_bin"]["sharpness"] == equal_bin_1_5(out["q"]["sharpness"])
    assert out["q"]["sharpness"] == out["q"]["blur"]  # Phase 9 duplication
    assert 0.0 <= out["q"]["brightness"] <= 1.0
    assert clip01(2.0) == 1.0
