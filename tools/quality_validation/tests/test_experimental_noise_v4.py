"""Lightweight controlled tests for Noise v4 (no SPAQ / no pilot tuning)."""

from __future__ import annotations

import time

import cv2
import numpy as np

from tools.quality_validation.experimental_noise_v4_pca import (
    estimate_noise_bgr,
    wavelet_hh_mad_sigma,
)
from tools.quality_validation.experimental_quality_engine_v2 import analyze_bgr as analyze_v2
from tools.quality_validation.experimental_noise_v3 import estimate_noise_bgr as estimate_v3


def _flat(size: int = 256, level: int = 128) -> np.ndarray:
    return np.full((size, size, 3), level, dtype=np.uint8)


def _awgn(img: np.ndarray, sigma: float, seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    noise = rng.normal(0.0, sigma, img.shape)
    return np.clip(img.astype(np.float64) + noise, 0, 255).astype(np.uint8)


def _chroma_noise(img: np.ndarray, sigma: float, seed: int = 1) -> np.ndarray:
    rng = np.random.default_rng(seed)
    yuv = cv2.cvtColor(img, cv2.COLOR_BGR2YUV).astype(np.float64)
    yuv[:, :, 1] += rng.normal(0.0, sigma, yuv[:, :, 1].shape)
    yuv[:, :, 2] += rng.normal(0.0, sigma, yuv[:, :, 2].shape)
    yuv = np.clip(yuv, 0, 255).astype(np.uint8)
    return cv2.cvtColor(yuv, cv2.COLOR_YUV2BGR)


def _texture(seed: int = 7, size: int = 256) -> np.ndarray:
    """Natural-looking luma texture with smooth chroma (not chroma grain)."""
    rng = np.random.default_rng(seed)
    base = rng.integers(40, 220, size=(size, size), dtype=np.uint8)
    base = cv2.GaussianBlur(base, (0, 0), 2.5)
    u = cv2.GaussianBlur(rng.integers(90, 160, (size, size), dtype=np.uint8), (0, 0), 4.0)
    v = cv2.GaussianBlur(rng.integers(90, 160, (size, size), dtype=np.uint8), (0, 0), 4.0)
    return np.dstack([base, u, v])


def _generally_worsens(amounts: list[float], sevs: list[float], max_dips: int = 1) -> bool:
    if amounts[-1] <= amounts[0]:
        return False
    n = len(amounts)
    ms, ma = sum(sevs) / n, sum(amounts) / n
    num = sum((sevs[i] - ms) * (amounts[i] - ma) for i in range(n))
    dens = sum((s - ms) ** 2 for s in sevs) ** 0.5
    dena = sum((a - ma) ** 2 for a in amounts) ** 0.5
    if dens == 0 or dena == 0:
        return False
    corr = num / (dens * dena)
    dips = sum(1 for i in range(n - 1) if amounts[i + 1] + 0.05 < amounts[i])
    return corr > 0.5 and dips <= max_dips


def test_awgn_ladder_monotone_v4() -> None:
    base = _flat()
    sevs = [0.0, 5.0, 10.0, 20.0, 40.0]
    amounts = [estimate_noise_bgr(_awgn(base, s, seed=int(s)))["noise_amount"] for s in sevs]
    assert _generally_worsens(amounts, sevs), amounts
    assert amounts[0] < 2.0


def test_chroma_noise_raises_v4() -> None:
    base = _flat()
    clean = estimate_noise_bgr(base)["noise_amount"]
    noisy = estimate_noise_bgr(_chroma_noise(base, 18.0))["noise_amount"]
    assert noisy > clean + 0.5


def test_lowlight_noise_generally_worsens() -> None:
    dark = _flat(level=40)
    sevs = [0.0, 6.0, 12.0, 18.0]
    amounts = [estimate_noise_bgr(_awgn(dark, s, seed=10 + int(s)))["noise_amount"] for s in sevs]
    assert _generally_worsens(amounts, sevs), amounts


def test_texture_not_false_strong_vs_awgn20() -> None:
    tex = estimate_noise_bgr(_texture())["noise_amount"]
    awgn20 = estimate_noise_bgr(_awgn(_flat(), 20.0, seed=20))["noise_amount"]
    assert tex < awgn20 * 0.55, (tex, awgn20)


def test_wavelet_secondary_baseline_present() -> None:
    out = estimate_noise_bgr(_awgn(_flat(), 10.0))
    assert "wavelet_hh_mad_sigma" in out
    assert out["wavelet_hh_mad_sigma"] >= 0.0
    gray = cv2.cvtColor(_flat(), cv2.COLOR_BGR2GRAY).astype(np.float64)
    assert wavelet_hh_mad_sigma(gray) >= 0.0


def test_insufficient_patches_flag_on_tiny_image() -> None:
    tiny = np.full((12, 12, 3), 128, dtype=np.uint8)
    out = estimate_noise_bgr(tiny)
    assert out["insufficient_homogeneous_patches"] is True
    assert out["used_fallback"] is True


def test_v4_competes_with_v2_v3_on_awgn_delta() -> None:
    clean = _flat()
    heavy = _awgn(clean, 25.0, seed=25)
    v4 = estimate_noise_bgr(heavy)["noise_amount"] - estimate_noise_bgr(clean)["noise_amount"]
    v3 = estimate_v3(heavy)["noise_amount"] - estimate_v3(clean)["noise_amount"]
    v2 = (
        analyze_v2(heavy)["raw"]["homogeneous_residual_std"]
        - analyze_v2(clean)["raw"]["homogeneous_residual_std"]
    )
    assert v4 > 0 and v3 > 0 and v2 > 0


def test_runtime_budget() -> None:
    img = _awgn(_flat(), 8.0)
    t0 = time.perf_counter()
    for _ in range(5):
        estimate_noise_bgr(img)
    ms = (time.perf_counter() - t0) * 1000.0 / 5.0
    assert ms < 400.0, ms
