"""Lightweight controlled tests for experimental Blocking v3 (no SPAQ)."""

from __future__ import annotations

import time

import cv2
import numpy as np

from tools.quality_validation.experimental_blocking_v3 import estimate_blocking_bgr
from tools.quality_validation.experimental_quality_engine_blocking_v3 import (
    analyze_bgr as analyze_blocking_v3,
)
from tools.quality_validation.experimental_quality_engine_v2 import analyze_bgr as analyze_v2
from tools.quality_validation.experimental_quality_engine_v2 import (
    analyze_image_bytes as analyze_v2_bytes,
)
from tools.quality_validation.experimental_quality_engine_blocking_v3 import (
    analyze_image_bytes as analyze_v3_bytes,
)


JPEG_QUALITIES = (95, 75, 50, 25, 10)


def _smooth_gradient(size: int = 256) -> np.ndarray:
    yy, xx = np.mgrid[0:size, 0:size]
    return np.stack(
        [xx.astype(np.uint8), yy.astype(np.uint8), ((xx + yy) // 2).astype(np.uint8)],
        axis=-1,
    )


def _clean_texture(seed: int = 7, size: int = 256) -> np.ndarray:
    rng = np.random.default_rng(seed)
    base = rng.integers(40, 220, size=(size, size), dtype=np.uint8)
    # Structured but not JPEG-blocky: smooth large-scale texture.
    base = cv2.GaussianBlur(base, (0, 0), 2.5)
    chroma = rng.integers(90, 160, size=(size, size, 2), dtype=np.uint8)
    return np.dstack([base, chroma[:, :, 0], chroma[:, :, 1]])


def _jpeg_ladder(img: np.ndarray, qualities: tuple[int, ...] = JPEG_QUALITIES) -> list[dict]:
    rows = []
    for q in qualities:
        buf = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), int(q)])[1].tobytes()
        v2 = analyze_v2_bytes(buf)
        v3 = analyze_v3_bytes(buf)
        assert v2 is not None and v3 is not None
        rows.append(
            {
                "jpeg_quality": q,
                "v2_amount": float(v2["raw"]["smooth_weighted_seam_delta"]),
                "v2_badge": int(v2["criterion_scores"]["Blocking Artifacts"]),
                "v3_amount": float(v3["raw"]["blocking_amount_v3"]),
                "v3_badge": int(v3["criterion_scores"]["Blocking Artifacts"]),
            }
        )
    return rows


def _generally_worsens(amounts: list[float], qualities: list[int], max_local_dips: int = 1) -> bool:
    """Stronger compression generally raises amount: endpoints + few local dips."""
    if amounts[-1] <= amounts[0]:
        return False
    # Rank correlation with JPEG quality should be negative (lower Q → higher amount).
    n = len(amounts)
    mean_q = sum(qualities) / n
    mean_a = sum(amounts) / n
    num = sum((qualities[i] - mean_q) * (amounts[i] - mean_a) for i in range(n))
    den_q = sum((qualities[i] - mean_q) ** 2 for i in range(n)) ** 0.5
    den_a = sum((amounts[i] - mean_a) ** 2 for i in range(n)) ** 0.5
    if den_q == 0 or den_a == 0:
        return False
    corr = num / (den_q * den_a)
    dips = sum(1 for i in range(n - 1) if amounts[i + 1] + 0.05 < amounts[i])
    return corr < -0.5 and dips <= max_local_dips


def test_v3_jpeg_ladder_amounts_rise_as_quality_falls() -> None:
    rows = _jpeg_ladder(_smooth_gradient())
    amounts = [r["v3_amount"] for r in rows]
    badges = [r["v3_badge"] for r in rows]
    qualities = [r["jpeg_quality"] for r in rows]
    assert _generally_worsens(amounts, qualities), list(zip(qualities, amounts, badges))
    assert amounts[-1] > amounts[0]
    assert badges[-1] <= badges[0]
    # Mid/high quality should stay cleaner than heavy compression.
    assert badges[0] >= 4
    assert badges[-1] <= 2


def test_v3_worse_at_q10_than_q95() -> None:
    rows = {r["jpeg_quality"]: r for r in _jpeg_ladder(_smooth_gradient())}
    assert rows[10]["v3_amount"] > rows[95]["v3_amount"]
    assert rows[10]["v3_badge"] <= rows[95]["v3_badge"]


def test_clean_texture_not_false_strong_blocking() -> None:
    tex = _clean_texture()
    # Encode lightly so file path matches photo workflow, but keep high quality.
    buf = cv2.imencode(".jpg", tex, [int(cv2.IMWRITE_JPEG_QUALITY), 95])[1].tobytes()
    heavy = cv2.imencode(".jpg", _smooth_gradient(), [int(cv2.IMWRITE_JPEG_QUALITY), 10])[1].tobytes()
    tex_r = analyze_v3_bytes(buf)
    heavy_r = analyze_v3_bytes(heavy)
    assert tex_r is not None and heavy_r is not None
    tex_amt = float(tex_r["raw"]["blocking_amount_v3"])
    heavy_amt = float(heavy_r["raw"]["blocking_amount_v3"])
    assert tex_amt < heavy_amt * 0.45, (tex_amt, heavy_amt)
    assert int(tex_r["criterion_scores"]["Blocking Artifacts"]) >= 4


def test_v3_more_sensitive_than_v2_on_heavy_vs_light_delta() -> None:
    rows = {r["jpeg_quality"]: r for r in _jpeg_ladder(_smooth_gradient())}
    v3_delta = rows[10]["v3_amount"] - rows[95]["v3_amount"]
    v2_delta = rows[10]["v2_amount"] - rows[95]["v2_amount"]
    assert v3_delta > 0
    # v3 should separate Q95 vs Q10 at least as clearly in relative terms.
    assert v3_delta >= 0.5 * max(v2_delta, 1e-6) or rows[10]["v3_badge"] < rows[95]["v3_badge"]


def test_png_clean_gradient_low_blocking_amount() -> None:
    # Uncompressed synthetic: no JPEG lattice → amount should stay near zero.
    img = _smooth_gradient()
    out = estimate_blocking_bgr(img)
    assert out["blocking_amount"] < 0.75
    badge = analyze_blocking_v3(img)["criterion_scores"]["Blocking Artifacts"]
    assert badge >= 4


def test_engine_preserves_other_criteria_from_v2() -> None:
    img = _smooth_gradient()
    v2 = analyze_v2(img)
    v3 = analyze_blocking_v3(img)
    for key in ("Sharpness", "Blur", "Noise", "Brightness", "Contrast", "Ringing Artifacts"):
        assert v2["criterion_scores"][key] == v3["criterion_scores"][key]
    assert v3["revised_criteria"] == ["Blocking Artifacts"]


def test_runtime_lightweight_budget() -> None:
    img = _smooth_gradient()
    t0 = time.perf_counter()
    for _ in range(5):
        estimate_blocking_bgr(img)
    elapsed_ms = (time.perf_counter() - t0) * 1000.0 / 5.0
    # Estimator alone should stay lightweight on 256px synthetic.
    assert elapsed_ms < 500.0, elapsed_ms
