"""Ensure cloud rubric export matches locked Python criteria."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.criteria import CRITERIA, CRITERION_IDS, SCALE_LABELS  # noqa: E402


def test_cloud_rubric_json_matches_python():
    path = ROOT / "cloud" / "shared" / "rubric.json"
    assert path.is_file(), "run scripts/export_rubric_for_cloud.py"
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["criterion_ids"] == list(CRITERION_IDS)
    assert data["criteria"] == list(CRITERIA)
    assert data["scale_labels"]["2"]["bisaya"] == SCALE_LABELS[2]["bisaya"]
    assert "retake" in data["scale_labels"]["2"]["en_anchor"].lower()
