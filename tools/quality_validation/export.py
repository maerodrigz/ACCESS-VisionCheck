"""CSV/JSON export for batch validation results."""

from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any, Iterable


CRITERION_COLUMNS = [
    "Sharpness",
    "Blur",
    "Noise",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Ringing Artifacts",
    "Flickering",
    "Motion Stability",
]


def flatten_row(record: dict[str, Any]) -> dict[str, Any]:
    scores = record.get("criterion_scores") or {}
    row = {
        "media_id": record.get("media_id"),
        "media_type": record.get("media_type"),
        "dataset_split": record.get("dataset_split"),
        "engine": record.get("engine"),
        "analysis_status": record.get("analysis_status"),
        "error_code": record.get("error_code"),
        "overall_score": record.get("overall_score"),
        "legacy_overall_score": record.get("legacy_overall_score"),
        "quality_level": record.get("quality_level"),
        "frame_count": record.get("frame_count"),
        "frames_scored": record.get("frames_scored"),
        "video_sample_frames": record.get("video_sample_frames"),
        "scoring_model": record.get("scoring_model"),
        "scoring_engine": record.get("scoring_engine"),
        "quality_engine": record.get("quality_engine"),
        "opencv_fallback": record.get("opencv_fallback"),
        "quality_condition": record.get("quality_condition"),
        "frames_analyzed": record.get("frames_analyzed"),
        "insufficient_evidence_flags": "|".join(record.get("insufficient_evidence_flags") or []),
        "file_sha256": record.get("file_sha256"),
        "source_path": record.get("source_path"),
    }
    for name in CRITERION_COLUMNS:
        row[f"criterion_{name.replace(' ', '_')}"] = scores.get(name)
    raw = record.get("raw_metrics") or {}
    for key in (
        "sharpness",
        "blur",
        "noise",
        "brightness",
        "contrast",
        "blocking_artifacts",
        "ringing_artifacts",
    ):
        row[f"raw_{key}"] = raw.get(key)
    return row


def write_json(records: list[dict[str, Any]], path: Path, metadata: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {"metadata": metadata, "results": records}
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def write_csv(records: list[dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = [flatten_row(r) for r in records]
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fieldnames = list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def load_machine_results(path: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, list):
        return {}, data
    return data.get("metadata") or {}, data.get("results") or []
