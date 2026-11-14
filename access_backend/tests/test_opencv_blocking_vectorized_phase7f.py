"""Phase 7F: vectorized blocking artifacts must match the loop reference."""

from __future__ import annotations

import numpy as np
import pytest

from app.services import opencv_quality as oq


def test_grid_counts_match_range_semantics() -> None:
    block = 8
    for h in (15, 16, 17, 20, 23, 24, 25, 100, 1001):
        for w in (15, 16, 17, 20, 31, 32, 33, 100, 999):
            expected_rows = len(range(0, h - block, block)) if h - block > 0 else 0
            expected_cols = len(range(0, w - block, block)) if w - block > 0 else 0
            n_rows, n_cols = oq._blocking_grid_counts(h, w, block)
            if h < 16 or w < 16:
                # Production early-return path; grid helper may still report counts.
                continue
            assert (n_rows, n_cols) == (expected_rows, expected_cols)


@pytest.mark.parametrize(
    "shape",
    [
        (16, 16),
        (17, 19),  # non-multiple of 8
        (23, 32),
        (64, 65),
        (100, 100),
        (128, 97),
        (15, 64),  # undersized height -> fallback
        (64, 15),  # undersized width -> fallback
        (8, 8),
    ],
)
def test_blocking_vectorized_matches_loop_synthetic(shape: tuple[int, int]) -> None:
    rng = np.random.default_rng(42)
    h, w = shape
    gray = rng.integers(0, 256, size=(h, w), dtype=np.uint8)
    # Sprinkle flat blocks
    if h >= 16 and w >= 16:
        gray[0:8, 0:8] = 40
        gray[8:16, 8:16] = rng.integers(0, 256, size=(8, 8), dtype=np.uint8)

    loop = oq._blocking_artifacts_loop_reference(gray)
    vec = oq._blocking_artifacts_vectorized(gray)
    prod = oq._blocking_artifacts(gray)
    assert vec == pytest.approx(loop, abs=1e-12)
    assert prod == pytest.approx(loop, abs=1e-12)


def test_blocking_grayscale_float_input() -> None:
    gray = np.linspace(0, 255, 64 * 48, dtype=np.float32).reshape(64, 48)
    loop = oq._blocking_artifacts_loop_reference(gray)
    vec = oq._blocking_artifacts_vectorized(gray)
    assert vec == pytest.approx(loop, abs=1e-12)


def test_analyze_bgr_blocking_matches_loop(monkeypatch: pytest.MonkeyPatch) -> None:
    """Full analyze_bgr metric equality when only blocking impl differs."""
    rng = np.random.default_rng(7)
    bgr = rng.integers(0, 256, size=(120, 130, 3), dtype=np.uint8)

    monkeypatch.setattr(oq, "USE_VECTORIZED_BLOCKING", False)
    ref = oq.analyze_bgr(bgr)

    monkeypatch.setattr(oq, "USE_VECTORIZED_BLOCKING", True)
    opt = oq.analyze_bgr(bgr)

    for key in (
        "sharpness",
        "blur",
        "noise",
        "brightness",
        "contrast",
        "blocking_artifacts",
        "ringing_artifacts",
        "width",
        "height",
    ):
        assert opt[key] == pytest.approx(ref[key], abs=1e-12), key


def test_use_vectorized_flag_selects_implementation(monkeypatch: pytest.MonkeyPatch) -> None:
    gray = np.zeros((32, 32), dtype=np.uint8)
    monkeypatch.setattr(oq, "USE_VECTORIZED_BLOCKING", True)
    assert oq._blocking_artifacts(gray) == oq._blocking_artifacts_vectorized(gray)
    monkeypatch.setattr(oq, "USE_VECTORIZED_BLOCKING", False)
    assert oq._blocking_artifacts(gray) == oq._blocking_artifacts_loop_reference(gray)