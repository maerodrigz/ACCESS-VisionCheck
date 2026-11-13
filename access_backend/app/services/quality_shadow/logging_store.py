"""Research-only JSONL (+ optional CSV mirror) for quality shadow results.

Retention policy (documented): keep logs under QUALITY_SHADOW_LOG_DIR with
restricted filesystem ACLs; default retention target 90 days
(QUALITY_SHADOW_RETENTION_DAYS). Operators prune manually or via ops job.
Never store media bytes, filenames, URLs, EXIF, emails, or display names.
"""

from __future__ import annotations

import csv
import json
import logging
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

_write_lock = threading.Lock()

# Flat CSV columns (research mirror). Nested fields are JSON-encoded strings.
CSV_FIELDS = (
    "timestamp_utc",
    "evaluation_id",
    "media_anon_id",
    "shadow_engine_version",
    "classical_map_version",
    "status",
    "musiq_status",
    "musiq_opq_raw",
    "musiq_scale",
    "musiq_model_id",
    "musiq_engine_handle",
    "duration_ms_total",
    "duration_ms_classical",
    "duration_ms_musiq",
    "error",
    "feedback_ruleset_version",
    "experimental_issue_count",
)


def ensure_log_dir(log_dir: Path) -> Path:
    log_dir.mkdir(parents=True, exist_ok=True)
    readme = log_dir / "README_RETENTION.txt"
    if not readme.is_file():
        readme.write_text(
            "ACCESS VisionCheck quality shadow logs (research only).\n"
            "Do not commit. Do not share outside controlled research access.\n"
            "Contains anonymized media ids (HMAC) and numeric scores only.\n"
            "No image bytes, no PII, no file URLs.\n"
            "Retention target: QUALITY_SHADOW_RETENTION_DAYS (default 90).\n"
            "Delete files older than retention; keep QUALITY_SHADOW_ENABLED=false in production.\n",
            encoding="utf-8",
        )
    return log_dir


def append_shadow_record(log_dir: Path, record: dict[str, Any]) -> Path:
    """Append one JSONL line and mirror a CSV row. Returns JSONL path."""
    ensure_log_dir(log_dir)
    day = datetime.now(timezone.utc).strftime("%Y%m%d")
    jsonl_path = log_dir / f"quality_shadow_{day}.jsonl"
    csv_path = log_dir / f"quality_shadow_{day}.csv"
    line = json.dumps(record, ensure_ascii=True, default=str)
    with _write_lock:
        with jsonl_path.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")
        _append_csv_row(csv_path, record)
    return jsonl_path


def _append_csv_row(csv_path: Path, record: dict[str, Any]) -> None:
    row = {k: record.get(k, "") for k in CSV_FIELDS}
    # Pack nested research fields as compact JSON for CSV consumers.
    fb = record.get("experimental_feedback")
    if isinstance(fb, dict):
        row["feedback_ruleset_version"] = fb.get("feedback_ruleset_version", "")
        row["experimental_issue_count"] = fb.get("issue_count", "")
    for key in (
        "criteria_raw",
        "criteria_q",
        "criteria_badge_equal_bin",
        "color",
        "experimental_feedback",
    ):
        if key in record:
            row[key] = json.dumps(record.get(key), ensure_ascii=True, default=str)
    write_header = not csv_path.is_file()
    fieldnames = list(CSV_FIELDS) + [
        "criteria_raw",
        "criteria_q",
        "criteria_badge_equal_bin",
        "color",
        "experimental_feedback",
    ]
    with csv_path.open("a", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        if write_header:
            writer.writeheader()
        writer.writerow(row)
