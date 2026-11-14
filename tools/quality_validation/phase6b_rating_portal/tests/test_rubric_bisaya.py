"""Assert Bisaya UI copy stays plain-language while English rubric meaning is locked."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.criteria import CRITERIA, CRITERION_IDS, NA_LABEL, SCALE_LABELS  # noqa: E402


def test_eight_criteria_preserved():
    assert CRITERION_IDS == (
        "sharpness",
        "blur",
        "noise",
        "brightness",
        "contrast",
        "blocking_artifacts",
        "ringing_artifacts",
        "overall_visual_quality",
    )
    assert len(CRITERIA) == 8


def test_conversational_bisaya_scale_labels():
    assert SCALE_LABELS[1]["bisaya"] == "Dili gyud maayo"
    assert SCALE_LABELS[2]["bisaya"] == "Dili kaayo maayo"
    assert SCALE_LABELS[3]["bisaya"] == "Sakto-sakto lang"
    assert SCALE_LABELS[4]["bisaya"] == "Maayo"
    assert SCALE_LABELS[5]["bisaya"] == "Maayo kaayo"
    assert NA_LABEL["bisaya"] == "Dili applicable"
    assert NA_LABEL["code"] == "N/A"


def test_locked_english_scale_labels_unchanged():
    assert SCALE_LABELS[1]["en"] == "Poor"
    assert SCALE_LABELS[2]["en"] == "Needs improvement"
    assert SCALE_LABELS[3]["en"] == "Fair"
    assert SCALE_LABELS[4]["en"] == "Good"
    assert SCALE_LABELS[5]["en"] == "Excellent"


def test_score2_retake_and_score3_visible_defect():
    assert "retake" in SCALE_LABELS[2]["en_anchor"].lower()
    assert "retake" in SCALE_LABELS[2]["bisaya_anchor"].lower()
    assert "clearly visible" in SCALE_LABELS[3]["en_anchor"].lower()
    assert "depekto" in SCALE_LABELS[3]["bisaya_anchor"].lower()


def test_restored_criterion_details():
    by_id = {c["id"]: c for c in CRITERIA}
    assert "intended subject" in by_id["sharpness"]["en_prompt"].lower()
    assert "subject" in by_id["sharpness"]["bisaya_prompt"].lower()
    assert "artistic background" in by_id["brightness"]["en_prompt"].lower()
    assert "artistic background" in by_id["brightness"]["bisaya_prompt"].lower()
    assert "flat areas" in by_id["blocking_artifacts"]["en_prompt"].lower()
    assert "flat regions" in by_id["blocking_artifacts"]["bisaya_prompt"].lower()
    assert "sky" in by_id["blocking_artifacts"]["bisaya_prompt"].lower()
    assert "mean of the seven" in by_id["overall_visual_quality"]["en_prompt"].lower()
    assert "average sa pito" in by_id["overall_visual_quality"]["bisaya_prompt"].lower()


def test_criterion_low_high_guides_present():
    for c in CRITERIA:
        assert c["bisaya_low"].startswith("1:")
        assert c["bisaya_high"].startswith("5:")
        assert c["higher_means"]
