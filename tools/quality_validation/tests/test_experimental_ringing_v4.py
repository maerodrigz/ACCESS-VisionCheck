"""Lightweight controlled tests for Ringing v4 (no SPAQ / no pilot tuning)."""

from __future__ import annotations

import time

import cv2
import numpy as np

from tools.quality_validation.experimental_quality_engine_v2 import analyze_bgr as analyze_v2
from tools.quality_validation.experimental_ringing_v3 import estimate_ringing_bgr as estimate_v3
from tools.quality_validation.experimental_ringing_v4_halo import estimate_ringing_bgr as estimate_v4
from tools.quality_validation.scoring_candidates import equal_bin_1_5


def _clean_step(size: int = 256) -> np.ndarray:
    img = np.zeros((size, size, 3), dtype=np.uint8)
    img[:, : size // 2] = 40
    img[:, size // 2 :] = 220
    return img


def _apply_unsharp(img: np.ndarray, amount: float, radius: float = 1.6) -> np.ndarray:
    blur = cv2.GaussianBlur(img, (0, 0), radius)
    out = cv2.addWeighted(img, 1.0 + amount, blur, -amount, 0)
    return np.clip(out, 0, 255).astype(np.uint8)


def _apply_sinc(img: np.ndarray, strength: int) -> np.ndarray:
    kernel = np.array(
        [0.03, -0.06, 0.12, -0.22, 1.26, -0.22, 0.12, -0.06, 0.03], dtype=np.float32
    )
    kernel /= kernel.sum()
    out = img.astype(np.float32)
    for _ in range(int(strength)):
        out = cv2.filter2D(out, -1, kernel.reshape(1, -1))
        out = cv2.filter2D(out, -1, kernel.reshape(-1, 1))
    return np.clip(out, 0, 255).astype(np.uint8)


def _texture(seed: int = 11, size: int = 256) -> np.ndarray:
    rng = np.random.default_rng(seed)
    base = rng.integers(50, 200, size=(size, size), dtype=np.uint8)
    base = cv2.GaussianBlur(base, (0, 0), 2.0)
    chroma = rng.integers(90, 170, size=(size, size, 2), dtype=np.uint8)
    return np.dstack([base, chroma[:, :, 0], chroma[:, :, 1]])


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


def test_clean_step_high_cleanliness() -> None:
    out = estimate_v4(_clean_step())
    badge = equal_bin_1_5(out["quality_cleanliness_0_1"])
    assert out["reliable_edge_profile"] is True
    assert out["ringing_amount"] < 2.0, out
    assert badge >= 4


def test_unsharp_generally_worsens() -> None:
    base = _clean_step()
    sevs = [0.0, 1.2, 2.4]
    amounts = []
    for a in sevs:
        img = base if a == 0 else _apply_unsharp(base, a)
        amounts.append(estimate_v4(img)["ringing_amount"])
    assert _generally_worsens(amounts, sevs), amounts
    assert amounts[-1] > amounts[0]


def test_sinc_ladder_generally_worsens() -> None:
    base = _clean_step()
    sevs = [0.0, 1.0, 2.0, 3.0]
    amounts = []
    badges = []
    for s in sevs:
        img = base if s == 0 else _apply_sinc(base, int(s))
        out = estimate_v4(img)
        amounts.append(out["ringing_amount"])
        badges.append(equal_bin_1_5(out["quality_cleanliness_0_1"]))
    assert _generally_worsens(amounts, sevs), list(zip(sevs, amounts, badges))
    assert badges[0] >= 4
    assert badges[-1] <= badges[0]


def test_texture_not_false_strong() -> None:
    tex = estimate_v4(_texture())
    heavy = estimate_v4(_apply_sinc(_clean_step(), 2))
    assert tex["ringing_amount"] < heavy["ringing_amount"] * 0.45 + 1e-6
    assert equal_bin_1_5(tex["quality_cleanliness_0_1"]) >= 4


def test_jpeg_not_scored_as_strong_ringing() -> None:
    # Smooth gradient JPEG is Blocking's job; ringing should stay relatively clean.
    yy, xx = np.mgrid[0:256, 0:256]
    grad = np.stack(
        [xx.astype(np.uint8), yy.astype(np.uint8), ((xx + yy) // 2).astype(np.uint8)],
        axis=-1,
    )
    buf = cv2.imencode(".jpg", grad, [int(cv2.IMWRITE_JPEG_QUALITY), 15])[1]
    img = cv2.imdecode(buf, cv2.IMREAD_COLOR)
    out = estimate_v4(img)
    heavy = estimate_v4(_apply_unsharp(_clean_step(), 2.4))
    assert out["ringing_amount"] < heavy["ringing_amount"] * 0.75 + 0.5
    assert equal_bin_1_5(out["quality_cleanliness_0_1"]) >= 3


def test_limitation_when_no_reliable_profile() -> None:
    flat = np.full((64, 64, 3), 128, dtype=np.uint8)
    out = estimate_v4(flat)
    assert out["reliable_edge_profile"] is False
    assert out["limitation"] is not None
    assert out["quality_cleanliness_0_1"] == 1.0


def test_clean_step_less_harsh_than_v3() -> None:
    step = _clean_step()
    v4 = estimate_v4(step)["ringing_amount"]
    v3 = estimate_v3(step)["ringing_amount"]
    # v4 must not floor clean steps the way v3 often did on photos; on synthetic step both may be low.
    assert v4 <= max(v3, 1.0) + 1.0
    assert equal_bin_1_5(estimate_v4(step)["quality_cleanliness_0_1"]) >= 4


def test_runtime_budget() -> None:
    img = _clean_step()
    t0 = time.perf_counter()
    for _ in range(5):
        estimate_v4(img)
    ms = (time.perf_counter() - t0) * 1000.0 / 5.0
    assert ms < 400.0, ms
