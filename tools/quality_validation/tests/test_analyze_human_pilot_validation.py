"""Unit checks for pilot human-vs-machine analysis helpers."""

from __future__ import annotations

import csv
from pathlib import Path

from tools.quality_validation.analyze_human_pilot_validation import (
    EXPECTED_PILOT_IDS,
    build_consensus,
    median_available,
    validate_human_rows,
)


def _row(media_id: str, rater_id: str, **scores: str) -> dict:
    raw = {col: scores.get(col, "3") for col in (
        "sharpness", "blur", "noise", "brightness", "contrast",
        "blocking_artifacts", "ringing_artifacts", "overall_visual_quality",
    )}
    parsed = {k: float(v) if v != "" else None for k, v in raw.items()}
    # empty string -> None via parse pattern
    for k, v in list(parsed.items()):
        if raw[k] == "":
            parsed[k] = None
        else:
            parsed[k] = float(raw[k])
    return {
        "source_file": f"{rater_id}.csv",
        "source_line": 2,
        "media_id": media_id,
        "rater_id": rater_id,
        "media_type": "photo",
        "scores": parsed,
        "raw_scores": raw,
        "notes": "",
        "flickering": "N/A",
        "motion_stability": "N/A",
    }


def test_median_available_ignores_none() -> None:
    assert median_available([None, 4.0, 5.0]) == 4.5
    assert median_available([None, None]) is None


def test_validate_detects_missing_and_duplicate(tmp_path: Path) -> None:
    rows = []
    for rid in ("R1", "R2", "R3"):
        for mid in EXPECTED_PILOT_IDS:
            rows.append(_row(mid, rid))
    rows.append(_row("PILOT-001", "R1"))  # duplicate
    report = validate_human_rows(rows)
    assert report["n_errors"] >= 1
    assert any(i["issue"] == "duplicate_media_id" for i in report["issues"])


def test_consensus_uses_available_only() -> None:
    rows = []
    for rid in ("R1", "R2", "R3"):
        for mid in EXPECTED_PILOT_IDS:
            kwargs = {}
            if rid == "R2" and mid == "PILOT-001":
                kwargs["contrast"] = ""
            rows.append(_row(mid, rid, **kwargs))
    cons = build_consensus(rows)
    tech = cons["PILOT-001"]["technical"]["contrast"]
    assert tech["n_available"] == 2
    assert tech["median"] == 3.0
