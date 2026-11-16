"""Unit tests for sample selection and declared equivalence gates (no TF, no images)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from official_musiq_engine_verification import (  # noqa: E402
    EQUIVALENCE_TOLERANCE,
    judge_equivalence,
    select_sample,
)


def test_tolerance_declared() -> None:
    assert EQUIVALENCE_TOLERANCE["pearson_min"] == 0.999
    assert EQUIVALENCE_TOLERANCE["spearman_min"] == 0.999
    assert EQUIVALENCE_TOLERANCE["mean_abs_diff_max"] == 0.50
    assert EQUIVALENCE_TOLERANCE["max_abs_diff_max"] == 2.0


def test_sample_is_deterministic() -> None:
    rows = [
        {"musiq_raw_score": str(float(i)), "run_id": "run_001", "media_id": f"K{i:03d}"}
        for i in range(100)
    ]
    a = select_sample(rows, 24, "20261107_engine")
    b = select_sample(rows, 24, "20261107_engine")
    assert [r["media_id"] for r in a] == [r["media_id"] for r in b]
    assert len(a) == 24


def test_judge_equivalence_fail_on_weak_correlation() -> None:
    corr = {"pearson_r": 0.80, "spearman_r": 0.77}
    diffs = {"mean_abs_diff": 0.1, "max_abs_diff": 0.2}
    verdict = judge_equivalence(corr, diffs, 1.0)
    assert verdict["primary_equivalent"] is False
