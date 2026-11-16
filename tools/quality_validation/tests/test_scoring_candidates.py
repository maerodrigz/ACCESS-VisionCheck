"""Mapping candidates: 1 reachable, directions explicit."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
for p in (str(REPO), str(ROOT)):
    if p not in sys.path:
        sys.path.insert(0, p)

from scoring_candidates import (  # noqa: E402
    equal_bin_1_5,
    linear_continuous_1_5,
    production_soft_score,
)


def test_soft_score_never_emits_1() -> None:
    assert production_soft_score(0.0) == 2
    assert min(production_soft_score(x / 100.0) for x in range(101)) == 2


def test_equal_bin_emits_1_and_5() -> None:
    assert equal_bin_1_5(0.0) == 1
    assert equal_bin_1_5(0.19) == 1
    assert equal_bin_1_5(0.5) == 3
    assert equal_bin_1_5(0.99) == 5
    assert equal_bin_1_5(1.0) == 5


def test_linear_continuous_span() -> None:
    assert linear_continuous_1_5(0.0) == 1.0
    assert linear_continuous_1_5(1.0) == 5.0
    assert 2.9 < linear_continuous_1_5(0.5) < 3.1
