"""Phase 4A holdout selection leakage safeguards."""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

import pytest

_TOOLKIT = Path(__file__).resolve().parents[1]
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from select_phase4a_holdout import (  # noqa: E402
    _pilot_keys,
    _pool_candidates,
    stratified_sample,
)


@pytest.mark.skipif(
    not (_TOOLKIT / "workspace" / "human_pilot" / "facilitator" / "facilitator_manifest.csv").is_file(),
    reason="pilot manifest missing",
)
def test_pool_excludes_pilot_keys() -> None:
    pilot = _pilot_keys()
    assert len(pilot) == 30
    pool = _pool_candidates(pilot)
    keys = {c["source_media_key"] for c in pool}
    assert keys.isdisjoint(pilot)
    assert len(pool) >= 70


@pytest.mark.skipif(
    not (_TOOLKIT / "workspace" / "datasets" / "koniq10k" / "run_002" / "images").is_dir(),
    reason="koniq images missing",
)
def test_stratified_sample_no_duplicates() -> None:
    pilot = _pilot_keys()
    pool = _pool_candidates(pilot)
    if len(pool) < 50:
        pytest.skip("insufficient pool")
    selected = stratified_sample(pool, n=50, seed="20261113_phase4a_indval")
    keys = [c["source_media_key"] for c in selected]
    assert len(keys) == len(set(keys)) == 50
    assert set(keys).isdisjoint(pilot)


def test_analyze_refuses_empty_human(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    import analyze_phase4a_results as an

    root = tmp_path / "phase4a"
    pack = root / "human_packs"
    pack.mkdir(parents=True)
    # empty rating files
    for r in ("R1", "R2", "R3"):
        (pack / f"image_quality_ratings_{r}.csv").write_text(
            "media_id,rater_id,sharpness\nINDVAL-001," + r + ",\n", encoding="utf-8"
        )
        (pack / f"issue_labels_{r}.csv").write_text(
            "media_id,rater_id,soft_focus\nINDVAL-001," + r + ",\n", encoding="utf-8"
        )
        (pack / f"feedback_quality_ratings_{r}.csv").write_text(
            "media_id,rater_id,observation_correctness_1to5\nINDVAL-001," + r + ",\n",
            encoding="utf-8",
        )
    mout = root / "machine_output"
    mout.mkdir()
    (mout / "machine_scores.csv").write_text("indval_id\nINDVAL-001\n", encoding="utf-8")

    monkeypatch.setattr(sys, "argv", ["analyze_phase4a_results.py", "--root", str(root)])
    with pytest.raises(SystemExit) as ei:
        an.main()
    assert "fabricate" in str(ei.value).lower() or "incomplete" in str(ei.value).lower()
