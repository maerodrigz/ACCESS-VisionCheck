#!/usr/bin/env python3
"""Unit tests for brightness_contrast_candidates (research-only).

Covers: solid black, solid white, constant gray, tiny images, grayscale
inputs, extreme clipping, and output bounds. Run with venv312:
  python tools/quality_validation/tests/test_brightness_contrast_candidates.py
"""

from __future__ import annotations

import sys
from pathlib import Path

_TOOLKIT = Path(__file__).resolve().parents[1]
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

import numpy as np  # noqa: E402

from brightness_contrast_candidates import (  # noqa: E402
    candidates_for_image,
    features,
    label_1_5,
    q_b1,
    q_b2,
    q_c1,
    q_c2,
    to_luma01,
)

_PASS = 0
_FAIL = 0


def check(name: str, cond: bool, detail: str = "") -> None:
    global _PASS, _FAIL
    if cond:
        _PASS += 1
        print(f"  ok   {name} {detail}")
    else:
        _FAIL += 1
        print(f"  FAIL {name} {detail}")


def _bgr(value: int, h: int = 64, w: int = 64) -> np.ndarray:
    return np.full((h, w, 3), value, dtype=np.uint8)


def _gray(value: int, h: int = 64, w: int = 64) -> np.ndarray:
    return np.full((h, w), value, dtype=np.uint8)


def test_output_bounds() -> None:
    print("[output_bounds]")
    imgs = [_bgr(0), _bgr(255), _bgr(128), _bgr(64), _gray(200), np.random.randint(0, 256, (40, 40, 3), dtype=np.uint8)]
    for i, im in enumerate(imgs):
        c = candidates_for_image(im)
        for k in ("Q_B1", "Q_B2", "Q_C1", "Q_C2"):
            v = c[k]
            check(f"img{i} {k} in [0,1]", 0.0 <= v <= 1.0, f"={v}")
        for k in ("label_B1", "label_B2", "label_C1", "label_C2"):
            v = c[k]
            check(f"img{i} {k} in 1..5", 1 <= v <= 5, f"={v}")


def test_solid_black() -> None:
    print("[solid_black]")
    c = candidates_for_image(_bgr(0))
    check("Q_B1==0", c["Q_B1"] == 0.0, f"={c['Q_B1']}")
    check("Q_B2==0", c["Q_B2"] == 0.0, f"={c['Q_B2']}")
    check("Q_C1==0 (no contrast)", c["Q_C1"] == 0.0, f"={c['Q_C1']}")
    check("Q_C2==0", c["Q_C2"] == 0.0, f"={c['Q_C2']}")
    check("label_B1==1", c["label_B1"] == 1)
    check("label_C1==1", c["label_C1"] == 1)
    check("clip_lo==1.0", c["features"]["clip_lo"] == 1.0, f"={c['features']['clip_lo']}")


def test_solid_white() -> None:
    print("[solid_white]")
    c = candidates_for_image(_bgr(255))
    check("Q_B1==0", c["Q_B1"] == 0.0, f"={c['Q_B1']}")
    check("Q_B2==0", c["Q_B2"] == 0.0, f"={c['Q_B2']}")
    check("Q_C1==0", c["Q_C1"] == 0.0, f"={c['Q_C1']}")
    check("Q_C2==0", c["Q_C2"] == 0.0, f"={c['Q_C2']}")
    check("label_B1==1", c["label_B1"] == 1)
    check("clip_hi==1.0", c["features"]["clip_hi"] == 1.0, f"={c['features']['clip_hi']}")


def test_constant_gray() -> None:
    print("[constant_gray]")
    c = candidates_for_image(_bgr(128))  # ~0.502
    check("Q_B1 high (well-exposed mid-gray)", c["Q_B1"] > 0.9, f"={c['Q_B1']}")
    check("Q_C1==0 (flat, no contrast)", c["Q_C1"] == 0.0, f"={c['Q_C1']}")
    check("label_B1==5", c["label_B1"] == 5)
    check("label_C1==1 (flat)", c["label_C1"] == 1)
    check("std==0", c["features"]["luma_std"] == 0.0)


def test_tiny_image() -> None:
    print("[tiny_image]")
    tiny = np.array([[[10, 120, 200], [50, 60, 70]], [[200, 10, 240], [120, 130, 5]]], dtype=np.uint8)
    c = candidates_for_image(tiny)
    check("no crash, bounds ok", 0.0 <= c["Q_B1"] <= 1.0 and 0.0 <= c["Q_C2"] <= 1.0,
          f"B1={c['Q_B1']} C2={c['Q_C2']}")
    check("local_std==0 (block>image)", c["features"]["local_std"] == 0.0,
          f"={c['features']['local_std']}")


def test_grayscale_input() -> None:
    print("[grayscale_input]")
    g = _gray(128, 32, 32)
    y = to_luma01(g)
    check("luma_mean ~0.502", abs(float(y.mean()) - 128 / 255.0) < 1e-6, f"={y.mean()}")
    c = candidates_for_image(g)
    check("grayscale B1 high", c["Q_B1"] > 0.9, f"={c['Q_B1']}")
    check("grayscale C1==0 (flat)", c["Q_C1"] == 0.0, f"={c['Q_C1']}")


def test_extreme_clipping() -> None:
    print("[extreme_clipping]")
    half = np.zeros((64, 64, 3), dtype=np.uint8)
    half[:, 32:] = 255  # left black, right white -> clipped at both edges
    c = candidates_for_image(half)
    f = c["features"]
    check("clip spikes present", f["clip_lo"] > 0.4 and f["clip_hi"] > 0.4, f"lo={f['clip_lo']} hi={f['clip_hi']}")
    # B2 lacks B1's mid_cov term, so compare B2 to its no-clip reference (triangle peaks ~1.0 at mu=0.5):
    check("B2 reduced below no-clip ref (clipping penalized)", c["Q_B2"] < 0.9, f"B2={c['Q_B2']}")
    check("C2 < C1 (extremes penalized)", c["Q_C2"] < c["Q_C1"], f"C2={c['Q_C2']} C1={c['Q_C1']}")
    check("C2 low (harsh)", c["Q_C2"] < 0.5, f"={c['Q_C2']}")
    check("extremes combined ~1.0", f["extremes"] > 0.9, f"={f['extremes']}")


def test_smooth_dark_tail_not_treated_as_clipped() -> None:
    """A naturally dark image with a smooth tail (band, not spike) should incur the
    smaller band penalty, not the clipped-spike penalty."""
    print("[smooth_dark_tail]")
    rng = np.random.default_rng(0)
    vals = np.clip(rng.normal(60, 25, (64, 64)), 0, 255).astype(np.uint8)  # dark, smooth, few at 0
    c = candidates_for_image(np.stack([vals, vals, vals], axis=-1))
    f = c["features"]
    check("clip_lo small (no spike)", f["clip_lo"] < 0.05, f"={f['clip_lo']}")
    check("band may be present", f["band_lo"] >= 0.0)
    # B2 should not collapse to 0 purely from being dark if there is no clipped spike
    check("B2 not zero (no spike)", c["Q_B2"] > 0.0, f"={c['Q_B2']}")


def main() -> int:
    test_output_bounds()
    test_solid_black()
    test_solid_white()
    test_constant_gray()
    test_tiny_image()
    test_grayscale_input()
    test_extreme_clipping()
    test_smooth_dark_tail_not_treated_as_clipped()
    print(f"\nPASS={_PASS} FAIL={_FAIL}")
    return 0 if _FAIL == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
