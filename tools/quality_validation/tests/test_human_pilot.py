"""Blind 30-photo pack: empty sheets, JPEG check, MAE policy."""

from __future__ import annotations

import csv
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
for p in (str(REPO), str(ROOT)):
    if p not in sys.path:
        sys.path.insert(0, p)

from analyze_phase10_single_rater import filled_count, load_ratings, metric_block  # noqa: E402
from prepare_human_pilot import (  # noqa: E402
    inspect_jpeg,
    rater_texts_are_blind,
    salted_rank,
    write_rater_sheet,
)


def _tiny_jpeg(path: Path) -> None:
    Image.new("RGB", (32, 24), (40, 80, 120)).save(path, format="JPEG", quality=90)


def test_salted_rank_is_deterministic() -> None:
    keys = ["b.jpg", "a.jpg", "c.jpg"]
    a = salted_rank(keys, 20261107, "pilot30|Q1_very_low")
    b = salted_rank(keys, 20261107, "pilot30|Q1_very_low")
    assert a == b
    assert set(a) == set(keys)


def test_inspect_jpeg_reads_file(tmp_path: Path) -> None:
    path = tmp_path / "x.jpg"
    _tiny_jpeg(path)
    meta = inspect_jpeg(path)
    assert meta["width"] == 32
    assert meta["height"] == 24
    assert meta["format"] == "JPEG"


def test_rater_sheet_does_not_prefill_scores(tmp_path: Path) -> None:
    path = tmp_path / "ratings_DEV.csv"
    write_rater_sheet(path, "DEV", ["PILOT-001", "PILOT-002"])
    rows = list(csv.DictReader(path.open(newline="", encoding="utf-8")))
    assert rows[0]["media_id"] == "PILOT-001"
    assert rows[0]["sharpness"] == ""
    assert rows[0]["overall_visual_quality"] == ""
    assert rows[0]["flickering"] == "N/A"
    assert filled_count(load_ratings(path)) == 0


def test_blind_check_flags_mos_token(tmp_path: Path) -> None:
    (tmp_path / "INSTRUCTIONS.md").write_text("published_mos must not appear", encoding="utf-8")
    leaks = rater_texts_are_blind(tmp_path, ["published_mos"])
    assert leaks


def test_mae_only_for_integer_pairs() -> None:
    human = [1.0, 2.0, 3.0, 4.0]
    machine_int = [2.0, 2.0, 3.0, 5.0]
    machine_cont = [1.2, 2.4, 3.1, 4.8]
    allowed = metric_block(human, machine_int, mae_allowed=True)
    blocked = metric_block(human, machine_cont, mae_allowed=False)
    assert allowed["mae_reported"] is True
    assert allowed["mae"] is not None
    assert blocked["mae_reported"] is False
    assert blocked["mae"] is None
