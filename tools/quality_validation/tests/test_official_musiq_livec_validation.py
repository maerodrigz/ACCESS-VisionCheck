"""Join/rank helpers for Phase 6 (no TF)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from official_musiq_engine_verification import EQUIVALENCE_TOLERANCE  # noqa: E402
from official_musiq_livec_validation import PHASE5_RESULT, ranking_disagreements  # noqa: E402


def test_phase5_thresholds_not_relaxed() -> None:
    assert EQUIVALENCE_TOLERANCE["spearman_min"] == 0.999
    assert PHASE5_RESULT["primary_equivalent"] is False
    assert PHASE5_RESULT["spearman_r"] < 0.999


def test_ranking_disagreements_counts_swaps() -> None:
    py = [3.0, 2.0, 1.0]
    of = [2.9, 3.1, 1.0]
    out = ranking_disagreements(py, of, ["a", "b", "c"])
    assert out["n_rank_changed"] == 2
    assert out["max_abs_rank_delta"] == 1
