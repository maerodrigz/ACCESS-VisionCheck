"""Public-dataset Phase 10: no invented labels; MOS is not a criterion."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
for p in (str(REPO), str(ROOT)):
    if p not in sys.path:
        sys.path.insert(0, p)

from metrics import spearman_bootstrap  # noqa: E402
from public_dataset_catalog import ACCESS_CRITERIA, discover  # noqa: E402
from scale_mapping import map_noisiness_raw_to_noise_quality_1_5  # noqa: E402
from run_public_attribute_validation import find_spaq_table  # noqa: E402


def test_noisiness_inverts_to_quality() -> None:
    assert map_noisiness_raw_to_noise_quality_1_5(0.0) == 5.0
    assert map_noisiness_raw_to_noise_quality_1_5(100.0) == 1.0
    mid = map_noisiness_raw_to_noise_quality_1_5(50.0)
    assert mid is not None and 2.9 < mid < 3.1


def test_koniq_is_not_runnable_criterion_set() -> None:
    d = discover()
    ids = {x["id"] for x in d["runnable_attribute_or_typed_sets"]}
    assert "koniq10k" not in ids
    assert "livec" not in ids
    assert "spaq" not in ids  # not installed locally


def test_all_seven_criteria_are_catalogued() -> None:
    assert ACCESS_CRITERIA == (
        "Sharpness",
        "Blur",
        "Noise",
        "Brightness",
        "Contrast",
        "Blocking Artifacts",
        "Ringing Artifacts",
    )


def test_bootstrap_ci_on_monotone_pair() -> None:
    x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    y = [1.0, 1.5, 3.0, 3.2, 5.0, 5.5, 7.0, 8.0]
    rec = spearman_bootstrap(x, y, n_boot=200, seed=20261107)
    assert rec["spearman_r"] is not None and rec["spearman_r"] > 0.8
    assert rec["spearman_ci_low"] is not None
    assert rec["spearman_ci_low"] <= rec["spearman_r"] <= rec["spearman_ci_high"]


def test_find_spaq_table_empty(tmp_path: Path) -> None:
    assert find_spaq_table(tmp_path) is None
