"""Regression tests for experimental Noise v3."""

from __future__ import annotations

import numpy as np
import pytest

cv2 = pytest.importorskip("cv2")

from tools.quality_validation.experimental_noise_v3 import (  # noqa: E402
    NOISE_V3_ID,
    estimate_noise_bgr,
)
from tools.quality_validation.experimental_quality_engine_v2 import (  # noqa: E402
    analyze_bgr as analyze_v2,
)
from tools.quality_validation.experimental_quality_engine_v3 import (  # noqa: E402
    ENGINE_ID,
    analyze_bgr as analyze_v3,
)


def _flat(value: int = 120, size: int = 256) -> np.ndarray:
    return np.full((size, size, 3), value, dtype=np.uint8)


def _awgn(img: np.ndarray, sigma: float, seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return np.clip(
        img.astype(np.int16) + rng.normal(0, sigma, img.shape).astype(np.int16),
        0,
        255,
    ).astype(np.uint8)


def _periodic_texture(size: int = 256) -> np.ndarray:
    yy, xx = np.mgrid[0:size, 0:size]
    img = np.zeros((size, size, 3), dtype=np.uint8)
    img[:, :, 0] = (xx * 5) % 256
    img[:, :, 1] = (yy * 5) % 256
    img[:, :, 2] = ((xx + yy) * 3) % 256
    return img


def test_engine_ids() -> None:
    out = analyze_v3(_flat())
    assert out["engine_id"] == ENGINE_ID == "experimental_classical_v3"
    assert out["noise_v3"]["estimator_id"] == NOISE_V3_ID
    assert out["revised_criteria"] == ["Noise"]


def test_gaussian_noise_monotone_worse_cleanliness() -> None:
    base = _flat()
    amounts = []
    badges = []
    for sigma in (0, 5, 10, 20, 40):
        img = base if sigma == 0 else _awgn(base, sigma, seed=sigma)
        out = analyze_v3(img)
        amounts.append(out["raw"]["noise_amount_v3"])
        badges.append(out["criterion_scores"]["Noise"])
    assert all(amounts[i] <= amounts[i + 1] for i in range(len(amounts) - 1))
    assert badges[0] >= badges[-1]
    assert badges[0] == 5
    assert badges[-1] <= 2


def test_chroma_noise_raises_amount_vs_clean_photo_like() -> None:
    rng = np.random.default_rng(7)
    photo = _flat(100)
    # Add mild structure so chroma has context, keep large flat areas.
    photo[80:176, 80:176] = 160
    clean = estimate_noise_bgr(photo)["noise_amount"]
    yuv = cv2.cvtColor(photo, cv2.COLOR_BGR2YUV).astype(np.int16)
    yuv[:, :, 1] += rng.normal(0, 16, yuv[:, :, 1].shape).astype(np.int16)
    yuv[:, :, 2] += rng.normal(0, 16, yuv[:, :, 2].shape).astype(np.int16)
    noisy = cv2.cvtColor(np.clip(yuv, 0, 255).astype(np.uint8), cv2.COLOR_YUV2BGR)
    chroma_amount = estimate_noise_bgr(noisy)["noise_amount"]
    assert chroma_amount > clean


def test_periodic_texture_not_as_noisy_as_strong_awgn() -> None:
    tex_amount = estimate_noise_bgr(_periodic_texture())["noise_amount"]
    awgn_amount = estimate_noise_bgr(_awgn(_flat(), 20, seed=3))["noise_amount"]
    assert awgn_amount > tex_amount * 3.0


def test_v3_more_chroma_sensitive_than_v2() -> None:
    rng = np.random.default_rng(11)
    photo = _flat(110)
    photo[60:200, 60:200] = 150
    yuv = cv2.cvtColor(photo, cv2.COLOR_BGR2YUV).astype(np.int16)
    yuv[:, :, 1] += rng.normal(0, 20, yuv[:, :, 1].shape).astype(np.int16)
    yuv[:, :, 2] += rng.normal(0, 20, yuv[:, :, 2].shape).astype(np.int16)
    noisy = cv2.cvtColor(np.clip(yuv, 0, 255).astype(np.uint8), cv2.COLOR_YUV2BGR)
    v2_clean = analyze_v2(photo)["criterion_scores"]["Noise"]
    v2_noisy = analyze_v2(noisy)["criterion_scores"]["Noise"]
    v3_clean = analyze_v3(photo)["criterion_scores"]["Noise"]
    v3_noisy = analyze_v3(noisy)["criterion_scores"]["Noise"]
    # v3 should drop at least as much as v2 (usually more).
    assert (v3_clean - v3_noisy) >= (v2_clean - v2_noisy)


def test_low_light_awgn_detected() -> None:
    dark = _flat(40)
    clean = analyze_v3(dark)["raw"]["noise_amount_v3"]
    noisy = analyze_v3(_awgn(dark, 12, seed=9))["raw"]["noise_amount_v3"]
    assert noisy > clean
