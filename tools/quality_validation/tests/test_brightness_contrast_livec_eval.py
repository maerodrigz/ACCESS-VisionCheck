"""Focused tests for LIVEC Brightness/Contrast selection (no inference, no SPAQ)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

_TOOLKIT = Path(__file__).resolve().parents[1]
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from brightness_contrast_livec_eval import (  # noqa: E402
    ARTIFACTS,
    N_PER_QUINTILE,
    N_SELECT,
    SELECTION_SEED,
    abort_if_existing,
    assign_strata,
    select_livec200,
)
from research_datasets import assign_mos_quintile  # noqa: E402


def _synthetic_test_rows(n: int = 250) -> list[dict]:
    """Even MOS spread; 50 per quintile if n=250."""
    rows = []
    for i in range(n):
        mos = 5.0 + (90.0 * i / max(n - 1, 1))
        rows.append(
            {
                "index": i + 7,
                "source_media_key": f"{i:04d}.jpg",
                "stem": f"{i:04d}",
                "mos_quality_raw": mos,
                "split": "test",
                "image_path": f"/tmp/{i:04d}.jpg",
            }
        )
    return rows


def test_seed_and_sample_size_declared_a_priori() -> None:
    assert SELECTION_SEED == 20261108
    assert N_SELECT == 200
    assert N_PER_QUINTILE == 40
    assert N_SELECT == 5 * N_PER_QUINTILE


def test_select_200_balanced_unique_and_reproducible() -> None:
    rows = _synthetic_test_rows(250)
    assign_strata(rows)
    a = select_livec200(rows, seed=SELECTION_SEED, n_per=N_PER_QUINTILE)
    b = select_livec200(rows, seed=SELECTION_SEED, n_per=N_PER_QUINTILE)
    assert len(a) == 200
    keys = [r["source_media_key"] for r in a]
    assert len(set(keys)) == 200
    assert keys == [r["source_media_key"] for r in b]
    from collections import Counter

    counts = Counter(r["stratum_id"] for r in a)
    assert counts == {1: 40, 2: 40, 3: 40, 4: 40, 5: 40}
    assert all(r["split"] == "test" for r in a)


def test_excludes_training_and_controlled_stems() -> None:
    rows = _synthetic_test_rows(250)
    rows[10]["split"] = "subject_training"
    rows[10]["source_media_key"] = "t1.bmp"
    rows[10]["stem"] = "t1"
    assign_strata(rows)
    selected = select_livec200(
        rows,
        seed=SELECTION_SEED,
        n_per=N_PER_QUINTILE,
        exclude_stems={"0042", "t1"},
    )
    keys = {r["source_media_key"] for r in selected}
    assert "t1.bmp" not in keys
    assert "0042.jpg" not in keys
    assert len(selected) == 200


def test_abort_if_output_exists(tmp_path: Path) -> None:
    abort_if_existing(tmp_path)
    (tmp_path / ARTIFACTS[0]).write_text("x", encoding="utf-8")
    with pytest.raises(SystemExit, match="refusing to overwrite"):
        abort_if_existing(tmp_path)


def test_mos_quintile_helper_stable() -> None:
    cuts = (0.0, 20.0, 40.0, 60.0, 80.0, 100.0)
    assert assign_mos_quintile(20.0, cuts) == 1
    assert assign_mos_quintile(20.01, cuts) == 2
    assert assign_mos_quintile(100.0, cuts) == 5
