"""Dataset manifest loading and split enforcement."""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path

VALID_SPLITS = frozenset({"dev", "held_out"})


@dataclass(frozen=True)
class ManifestRow:
    media_id: str
    relative_path: str
    media_type: str
    dataset_split: str


def load_manifest(manifest_path: Path, dataset_root: Path) -> list[ManifestRow]:
    rows: list[ManifestRow] = []
    with manifest_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        required = {"media_id", "relative_path", "media_type", "dataset_split"}
        if not required.issubset(set(reader.fieldnames or [])):
            raise ValueError(f"Manifest must include columns: {sorted(required)}")
        for line, raw in enumerate(reader, start=2):
            split = (raw.get("dataset_split") or "").strip().lower()
            if split not in VALID_SPLITS:
                raise ValueError(f"Line {line}: invalid dataset_split {split!r}")
            rel = (raw.get("relative_path") or "").strip()
            mid = (raw.get("media_id") or "").strip()
            if not mid or not rel:
                raise ValueError(f"Line {line}: media_id and relative_path required")
            mtype = (raw.get("media_type") or "").strip().lower()
            if mtype not in ("photo", "video"):
                raise ValueError(f"Line {line}: media_type must be photo or video")
            full = (dataset_root / rel).resolve()
            if not full.is_file():
                raise FileNotFoundError(f"Line {line}: missing file {full}")
            rows.append(
                ManifestRow(
                    media_id=mid,
                    relative_path=rel,
                    media_type=mtype,
                    dataset_split=split,
                )
            )
    return rows


def discover_from_folders(dataset_root: Path) -> list[ManifestRow]:
    """Convention: dataset_root/dev|held_out/photos|videos/*"""
    rows: list[ManifestRow] = []
    for split in ("dev", "held_out"):
        split_dir = dataset_root / split
        if not split_dir.is_dir():
            continue
        for media_type in ("photos", "videos"):
            folder = split_dir / media_type
            if not folder.is_dir():
                continue
            mtype = "photo" if media_type == "photos" else "video"
            for path in sorted(folder.iterdir()):
                if not path.is_file():
                    continue
                rel = path.relative_to(dataset_root).as_posix()
                media_id = path.stem
                rows.append(
                    ManifestRow(
                        media_id=media_id,
                        relative_path=rel,
                        media_type=mtype,
                        dataset_split=split,
                    )
                )
    return rows
