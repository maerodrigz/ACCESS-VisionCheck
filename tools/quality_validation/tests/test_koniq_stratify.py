"""Stratified KonIQ Run 002 selection tests. Does not extract or score."""

from __future__ import annotations

import sys
from pathlib import Path

_TOOLKIT = Path(__file__).resolve().parents[1]
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.koniq_stratify import select_stratified  # noqa: E402
from tools.quality_validation.research_datasets import (  # noqa: E402
    assign_mos_quintile,
    empirical_percentile,
    koniq_quintile_cuts,
)


def test_percentile_endpoints() -> None:
    xs = [1.0, 2.0, 3.0, 4.0, 5.0]
    assert empirical_percentile(xs, 0) == 1.0
    assert empirical_percentile(xs, 100) == 5.0
    assert empirical_percentile(xs, 50) == 3.0


def test_quintile_assignment_inclusive_lower_cut() -> None:
    cuts = (1.0, 2.0, 3.0, 4.0, 4.5, 5.0)
    assert assign_mos_quintile(1.0, cuts) == 1
    assert assign_mos_quintile(2.0, cuts) == 1
    assert assign_mos_quintile(2.0001, cuts) == 2
    assert assign_mos_quintile(5.0, cuts) == 5


def test_select_excludes_run001_and_is_seed_stable() -> None:
    rows = []
    for i in range(50):
        mos = 1.2 + (i % 5) * 0.7 + i * 0.001
        rows.append(
            {
                "source_media_key": f"{i:05d}.jpg",
                "mos_quality_raw": mos,
                "overall_mapped_1_5": round(mos, 4),
                "mos_scale": "1-5",
            }
        )
    exclude = {"00000.jpg", "00001.jpg"}
    a, summary = select_stratified(rows, exclude=exclude, n_per_stratum=2, seed=20261107)
    b, _ = select_stratified(rows, exclude=exclude, n_per_stratum=2, seed=20261107)
    c, _ = select_stratified(rows, exclude=exclude, n_per_stratum=2, seed=1)
    keys_a = [r["source_media_key"] for r in a]
    assert keys_a == [r["source_media_key"] for r in b]
    assert keys_a != [r["source_media_key"] for r in c]
    assert set(keys_a).isdisjoint(exclude)
    assert len(a) == 10
    assert summary["selected_counts"] == {1: 2, 2: 2, 3: 2, 4: 2, 5: 2}
    assert all(r["media_id"].startswith("KONIQ2-") for r in a)


def test_observed_koniq_cuts_have_five_nonempty_bins() -> None:
    cuts = koniq_quintile_cuts([1.09615384615385, 2.7, 3.1, 3.4, 3.64, 4.31] * 20)
    assert cuts[0] < cuts[1] < cuts[2] < cuts[3] < cuts[4] < cuts[5]
