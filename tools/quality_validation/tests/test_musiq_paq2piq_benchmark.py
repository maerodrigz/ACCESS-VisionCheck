"""Unit tests for MUSIQ research helpers. Does not download weights or run inference."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

_TOOLKIT = Path(__file__).resolve().parents[1]
_REPO = _TOOLKIT.parents[1]
if str(_REPO) not in sys.path:
    sys.path.insert(0, str(_REPO))

from tools.quality_validation.musiq_paq2piq_benchmark import (  # noqa: E402
    PROTECTED_OUTPUTS,
    RUN_001_CSV,
    RUN_002_CSV,
    assert_output_safe,
    collect_eval_set,
    scores_on_comparable_1_5_scale,
)


def test_paq2piq_range_is_not_treated_as_mos_1_5() -> None:
    raw = [62.1, 71.4, 48.0]
    assert scores_on_comparable_1_5_scale(raw, "~0, ~100") is False


def test_true_1_5_range_is_comparable() -> None:
    raw = [2.1, 3.4, 4.0]
    assert scores_on_comparable_1_5_scale(raw, "1, 5") is True


def test_refuses_to_write_into_baseline_run_folders(tmp_path: Path) -> None:
    with pytest.raises(SystemExit):
        assert_output_safe(PROTECTED_OUTPUTS[0])
    with pytest.raises(SystemExit):
        assert_output_safe(RUN_002_CSV.parent / "nested")
    assert_output_safe(tmp_path / "musiq_out")


def test_eval_set_is_140_unique_existing_jpegs() -> None:
    if not RUN_001_CSV.is_file() or not RUN_002_CSV.is_file():
        return
    rows, errors = collect_eval_set()
    assert errors == []
    assert len(rows) == 140
    assert len({r["source_media_key"] for r in rows}) == 140
    assert all(r["image_exists"] for r in rows)
    assert sum(1 for r in rows if r["run_id"] == "run_001") == 40
    assert sum(1 for r in rows if r["run_id"] == "run_002") == 100
