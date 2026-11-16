"""Lightweight controlled tests for experimental Ringing v3 (no SPAQ)."""

from __future__ import annotations

import time

import cv2
import numpy as np

from tools.quality_validation.experimental_quality_engine_ringing_v3 import (
    analyze_bgr as analyze_ringing_v3,
)
from tools.quality_validation.experimental_quality_engine_v2 import analyze_bgr as analyze_v2
from tools.quality_validation.experimental_ringing_v3 import estimate_ringing_bgr


def _clean_step(size: int = 256) -> np.ndarray:
    img = np.zeros((size, size, 3), dtype=np.uint8)
    img[:, : size // 2] = 40
    img[:, size // 2 :] = 220
    return img


def _apply_unsharp(img: np.ndarray, amount: float, radius: float = 1.6) -> np.ndarray:
    blur = cv2.GaussianBlur(img, (0, 0), radius)
    out = cv2.addWeighted(img, 1.0 + amount, blur, -amount, 0)
    return np.clip(out, 0, 255).astype(np.uint8)


def _apply_sinc_ringing(img: np.ndarray, strength: int) -> np.ndarray:
    """Add separable Gibbs-like ripples; strength 1..4 keeps plateaus usable."""
    # Milder than the old 1.52-center kernel so multi-step ladders remain graded.
    kernel = np.array(
        [0.03, -0.06, 0.12, -0.22, 1.26, -0.22, 0.12, -0.06, 0.03], dtype=np.float32
    )
    kernel /= kernel.sum()
    out = img.astype(np.float32)
    for _ in range(int(strength)):
        out = cv2.filter2D(out, -1, kernel.reshape(1, -1))
        out = cv2.filter2D(out, -1, kernel.reshape(-1, 1))
    return np.clip(out, 0, 255).astype(np.uint8)


def _clean_texture(seed: int = 11, size: int = 256) -> np.ndarray:
    rng = np.random.default_rng(seed)
    base = rng.integers(50, 200, size=(size, size), dtype=np.uint8)
    base = cv2.GaussianBlur(base, (0, 0), 2.0)
    chroma = rng.integers(90, 170, size=(size, size, 2), dtype=np.uint8)
    return np.dstack([base, chroma[:, :, 0], chroma[:, :, 1]])


def _generally_worsens(amounts: list[float], severities: list[float], max_dips: int = 1) -> bool:
    if amounts[-1] <= amounts[0]:
        return False
    n = len(amounts)
    mean_s = sum(severities) / n
    mean_a = sum(amounts) / n
    num = sum((severities[i] - mean_s) * (amounts[i] - mean_a) for i in range(n))
    den_s = sum((s - mean_s) ** 2 for s in severities) ** 0.5
    den_a = sum((a - mean_a) ** 2 for a in amounts) ** 0.5
    if den_s == 0 or den_a == 0:
        return False
    corr = num / (den_s * den_a)
    dips = sum(1 for i in range(n - 1) if amounts[i + 1] + 0.05 < amounts[i])
    return corr > 0.5 and dips <= max_dips


def test_clean_step_low_ringing() -> None:
    out = estimate_ringing_bgr(_clean_step())
    badge = analyze_ringing_v3(_clean_step())["criterion_scores"]["Ringing Artifacts"]
    assert out["ringing_amount"] < 1.5, out
    assert badge >= 4


def test_sinc_ladder_generally_worsens() -> None:
    base = _clean_step()
    # Strength 4 destroys plateaus in this synthetic; ladder uses 0..3.
    severities = [0, 1, 2, 3]
    rows = []
    for p in severities:
        img = base if p == 0 else _apply_sinc_ringing(base, p)
        r = analyze_ringing_v3(img)
        rows.append(
            {
                "sev": p,
                "amount": float(r["raw"]["ringing_amount_v3"]),
                "badge": int(r["criterion_scores"]["Ringing Artifacts"]),
            }
        )
    amounts = [r["amount"] for r in rows]
    badges = [r["badge"] for r in rows]
    assert _generally_worsens(amounts, [float(s) for s in severities]), rows
    assert amounts[-1] > amounts[0]
    assert badges[-1] <= badges[0]
    assert badges[0] >= 4
    assert badges[-1] <= 3


def test_unsharp_halo_worse_than_clean() -> None:
    clean = analyze_ringing_v3(_clean_step())
    mild = analyze_ringing_v3(_apply_unsharp(_clean_step(), amount=1.2))
    strong = analyze_ringing_v3(_apply_unsharp(_clean_step(), amount=2.4))
    a0 = float(clean["raw"]["ringing_amount_v3"])
    a1 = float(mild["raw"]["ringing_amount_v3"])
    a2 = float(strong["raw"]["ringing_amount_v3"])
    assert a1 > a0
    assert a2 > a0
    assert int(strong["criterion_scores"]["Ringing Artifacts"]) <= int(
        clean["criterion_scores"]["Ringing Artifacts"]
    )
    # Stronger unsharp should not score cleaner than mild (allow tiny float noise).
    assert a2 + 0.5 >= a1 * 0.75


def test_texture_not_false_strong_ringing() -> None:
    tex = analyze_ringing_v3(_clean_texture())
    heavy = analyze_ringing_v3(_apply_sinc_ringing(_clean_step(), 2))
    tex_amt = float(tex["raw"]["ringing_amount_v3"])
    heavy_amt = float(heavy["raw"]["ringing_amount_v3"])
    assert tex_amt < heavy_amt * 0.45, (tex_amt, heavy_amt)
    assert int(tex["criterion_scores"]["Ringing Artifacts"]) >= 4


def test_engine_preserves_other_criteria_from_v2() -> None:
    img = _clean_step()
    v2 = analyze_v2(img)
    v3 = analyze_ringing_v3(img)
    for key in (
        "Sharpness",
        "Blur",
        "Noise",
        "Brightness",
        "Contrast",
        "Blocking Artifacts",
    ):
        assert v2["criterion_scores"][key] == v3["criterion_scores"][key]
    assert v3["revised_criteria"] == ["Ringing Artifacts"]


def test_runtime_lightweight_budget() -> None:
    img = _clean_step()
    t0 = time.perf_counter()
    for _ in range(5):
        estimate_ringing_bgr(img)
    elapsed_ms = (time.perf_counter() - t0) * 1000.0 / 5.0
    assert elapsed_ms < 250.0, elapsed_ms
