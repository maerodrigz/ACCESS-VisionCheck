from __future__ import annotations

import sys
from pathlib import Path

_TOOLKIT = Path(__file__).resolve().parents[1]
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from phase12_benchmark import DECLARED_PAIRS, sign_ok  # noqa: E402


def test_declared_pairs_cover_four_spaq_attributes() -> None:
    humans = {p["human"] for p in DECLARED_PAIRS}
    assert "attr_sharpness_raw" in humans
    assert "attr_noisiness_raw" in humans
    assert "attr_brightness_raw" in humans
    assert "attr_contrast_raw" in humans
    assert "mos_quality_raw" in humans
    assert not any("blur" in p["human"].lower() for p in DECLARED_PAIRS)


def test_sign_ok() -> None:
    assert sign_ok("+", 0.2) is True
    assert sign_ok("+", -0.2) is False
    assert sign_ok("-", -0.2) is True
    assert sign_ok("?", 0.9) is None
