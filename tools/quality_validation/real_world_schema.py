"""ACCESS 1–5 quality criteria used in production and in real-world ratings."""

from __future__ import annotations

import csv
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

PHOTO_CRITERIA = (
    "Sharpness",
    "Blur",
    "Noise",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Ringing Artifacts",
)
VIDEO_EXTRA_CRITERIA = ("Flickering", "Motion Stability")
VIDEO_CRITERIA = PHOTO_CRITERIA + VIDEO_EXTRA_CRITERIA
OVERALL_HUMAN = "Overall visual quality"

HUMAN_CSV_COLUMNS = {
    "Sharpness": "sharpness",
    "Blur": "blur",
    "Noise": "noise",
    "Brightness": "brightness",
    "Contrast": "contrast",
    "Blocking Artifacts": "blocking_artifacts",
    "Ringing Artifacts": "ringing_artifacts",
    "Flickering": "flickering",
    "Motion Stability": "motion_stability",
    "Overall visual quality": "overall_visual_quality",
}

PHOTO_EXT = frozenset({".jpg", ".jpeg", ".png", ".webp", ".bmp", ".heic", ".heif"})
VIDEO_EXT = frozenset({".mp4", ".mov", ".avi", ".mkv", ".webm", ".m4v"})

MISSING_TOKENS = frozenset({"", "NA", "N/A", "NAN", "CANNOT_RATE", "CANNOT RATE", "CR", "NONE", "-"})


def parse_score_1_5(raw: Any) -> float | None:
    if raw is None:
        return None
    if isinstance(raw, float) and math.isnan(raw):
        return None
    text = str(raw).strip().upper().replace("–", "-")
    if text in MISSING_TOKENS:
        return None
    try:
        value = float(text)
    except ValueError:
        return None
    if 1.0 <= value <= 5.0:
        return value
    return None


def higher_is_better(criterion: str) -> bool:
    return criterion in PHOTO_CRITERIA or criterion in VIDEO_EXTRA_CRITERIA or criterion == OVERALL_HUMAN


@dataclass(frozen=True)
class RealWorldItem:
    media_id: str
    relative_path: str
    media_type: str
    quality_condition: str
    notes: str


def media_type_for_path(path: Path) -> str | None:
    ext = path.suffix.lower()
    if ext in PHOTO_EXT:
        return "photo"
    if ext in VIDEO_EXT:
        return "video"
    return None


def load_real_world_manifest(manifest_path: Path, dataset_root: Path, *, require_files: bool = True) -> list[RealWorldItem]:
    rows: list[RealWorldItem] = []
    with manifest_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        required = {"media_id", "relative_path", "media_type"}
        if not required.issubset(set(reader.fieldnames or [])):
            raise ValueError(f"Manifest must include columns: {sorted(required)}")
        seen: set[str] = set()
        for line, raw in enumerate(reader, start=2):
            mid = (raw.get("media_id") or "").strip()
            rel = (raw.get("relative_path") or "").strip()
            mtype = (raw.get("media_type") or "").strip().lower()
            if not mid or not rel:
                raise ValueError(f"Line {line}: media_id and relative_path required")
            if mid in seen:
                raise ValueError(f"Line {line}: duplicate media_id {mid}")
            seen.add(mid)
            if mtype not in ("photo", "video"):
                raise ValueError(f"Line {line}: media_type must be photo or video")
            if require_files:
                full = (dataset_root / rel).resolve()
                if not full.is_file():
                    raise FileNotFoundError(f"Line {line}: missing file {full}")
            rows.append(
                RealWorldItem(
                    media_id=mid,
                    relative_path=rel,
                    media_type=mtype,
                    quality_condition=(raw.get("quality_condition") or "").strip(),
                    notes=(raw.get("notes") or "").strip(),
                )
            )
    return rows


def scan_workspace(dataset_root: Path) -> list[RealWorldItem]:
    items: list[RealWorldItem] = []
    photo_dir = dataset_root / "photos"
    video_dir = dataset_root / "videos"
    if photo_dir.is_dir():
        photos = sorted(p for p in photo_dir.iterdir() if p.is_file() and media_type_for_path(p) == "photo")
        for index, path in enumerate(photos, start=1):
            items.append(
                RealWorldItem(
                    media_id=f"PHOTO-{index:03d}",
                    relative_path=path.relative_to(dataset_root).as_posix(),
                    media_type="photo",
                    quality_condition="",
                    notes="",
                )
            )
    if video_dir.is_dir():
        videos = sorted(p for p in video_dir.iterdir() if p.is_file() and media_type_for_path(p) == "video")
        for index, path in enumerate(videos, start=1):
            items.append(
                RealWorldItem(
                    media_id=f"VIDEO-{index:03d}",
                    relative_path=path.relative_to(dataset_root).as_posix(),
                    media_type="video",
                    quality_condition="",
                    notes="",
                )
            )
    return items


def write_manifest(path: Path, items: list[RealWorldItem]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["media_id", "relative_path", "media_type", "quality_condition", "notes"],
        )
        writer.writeheader()
        for item in items:
            writer.writerow(
                {
                    "media_id": item.media_id,
                    "relative_path": item.relative_path,
                    "media_type": item.media_type,
                    "quality_condition": item.quality_condition,
                    "notes": item.notes,
                }
            )


def load_human_ratings_access(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames or "media_id" not in reader.fieldnames or "rater_id" not in reader.fieldnames:
            raise ValueError("Human ratings CSV must include media_id and rater_id")
        for raw in reader:
            media_id = (raw.get("media_id") or "").strip()
            rater_id = (raw.get("rater_id") or "").strip()
            if not media_id or not rater_id:
                continue
            scores: dict[str, float | None] = {}
            for criterion, column in HUMAN_CSV_COLUMNS.items():
                scores[criterion] = parse_score_1_5(raw.get(column))
            rows.append(
                {
                    "media_id": media_id,
                    "rater_id": rater_id,
                    "media_type": (raw.get("media_type") or "").strip().lower(),
                    "scores": scores,
                    "notes": (raw.get("notes") or "").strip(),
                }
            )
    return rows
