"""Distortion helpers and classical metrics without EfficientNet."""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
for p in (str(REPO), str(REPO / "access_backend"), str(ROOT)):
    if p not in sys.path:
        sys.path.insert(0, p)

from classical_quality_metrics import analyze_bgr  # noqa: E402
from controlled_distortion import (  # noqa: E402
    LADDERS,
    SEED,
    apply_awgn,
    apply_gaussian_blur,
    apply_jpeg,
    decode_bgr,
    select_originals,
)


def _patch() -> np.ndarray:
    img = np.zeros((64, 64, 3), dtype=np.uint8)
    img[:, :] = (40, 80, 120)
    img[16:48, 16:48] = (200, 200, 200)
    img[20:44:2, :] = (255, 255, 255)
    return img


def test_ladders_are_documented() -> None:
    assert set(LADDERS) == {
        "gaussian_blur",
        "awgn",
        "underexposure",
        "overexposure",
        "low_contrast",
        "high_contrast",
        "jpeg",
        "ringing",
    }
    assert SEED == "20261107_phase8"


def test_gaussian_blur_reduces_laplacian() -> None:
    bgr = _patch()
    sharp = analyze_bgr(bgr)["sharpness_laplacian_var"]
    blurred = decode_bgr(apply_gaussian_blur(bgr, sigma=4.0))
    soft = analyze_bgr(blurred)["sharpness_laplacian_var"]
    assert soft < sharp


def test_awgn_is_seeded() -> None:
    bgr = _patch()
    a = apply_awgn(bgr, std=20.0, media_id="CTRL-001")
    b = apply_awgn(bgr, std=20.0, media_id="CTRL-001")
    c = apply_awgn(bgr, std=20.0, media_id="CTRL-002")
    assert a == b
    assert a != c


def test_jpeg_quality_changes_bytes() -> None:
    bgr = _patch()
    hi = apply_jpeg(bgr, quality=90)
    lo = apply_jpeg(bgr, quality=8)
    assert len(lo) < len(hi)
    assert decode_bgr(lo).shape == bgr.shape


def test_select_originals_deterministic(tmp_path: Path) -> None:
    for i in range(6):
        (tmp_path / f"{i}.jpg").write_bytes(b"x")
    a = [p.name for p in select_originals(tmp_path, 3, SEED)]
    b = [p.name for p in select_originals(tmp_path, 3, SEED)]
    assert a == b
    assert len(a) == 3
