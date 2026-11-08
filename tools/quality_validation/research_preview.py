#!/usr/bin/env python3
"""Inspect KonIQ-10k / LIVE-VQC metadata and subset files. No scoring. No download."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.importers.koniq10k import (  # noqa: E402
    import_koniq10k_rows,
    read_koniq_table,
    validate_koniq_headers,
)
from tools.quality_validation.research_datasets import (  # noqa: E402
    DEFAULT_PHOTO_N,
    DEFAULT_SEED,
    DEFAULT_VIDEO_N,
    KONIQ_ROOT,
    LIVE_ROOT,
    build_subset_records,
    find_score_file,
    inspect_live_vqc_metadata,
    list_media_files,
)

PHOTO_EXT = frozenset({".jpg", ".jpeg", ".png", ".bmp", ".webp"})
VIDEO_EXT = frozenset({".mp4", ".mov", ".avi", ".mkv", ".webm", ".m4v"})


def preview_koniq(*, n: int, seed: int, inspect_only: bool) -> dict:
    meta_dir = KONIQ_ROOT / "metadata"
    images_dir = KONIQ_ROOT / "images"
    score_path = find_score_file(
        meta_dir,
        (
            "koniq10k_scores_and_distributions.tab",
            "koniq10k_scores_and_distributions.csv",
        ),
    )
    report: dict = {
        "dataset": "KonIQ-10k",
        "images_dir": str(images_dir),
        "metadata_dir": str(meta_dir),
        "score_file": str(score_path) if score_path else None,
        "image_count_on_disk": len(list_media_files(images_dir, PHOTO_EXT)),
        "errors": [],
        "warnings": [],
    }
    if score_path is None:
        report["errors"].append(
            "No scores file yet. Download koniq10k_scores_and_distributions.tab into metadata/."
        )
        return report
    headers, table = read_koniq_table(score_path)
    report["headers"] = headers
    report["header_errors"] = validate_koniq_headers(headers)
    report["catalog_rows"] = len(table)
    if report["header_errors"]:
        report["errors"].extend(report["header_errors"])
        return report
    if inspect_only:
        return report
    rows, warnings = import_koniq10k_rows(score_path)
    report["warnings"].extend(warnings)
    files = list_media_files(images_dir, PHOTO_EXT)
    subset, stats = build_subset_records(
        rows,
        media_files=files,
        dataset_root=KONIQ_ROOT,
        n=n,
        seed=seed,
        media_type="photo",
        id_prefix="KONIQ",
    )
    report["subset"] = stats
    report["preview_ids"] = [
        {"media_id": r["media_id"], "source_media_key": r["source_media_key"], "file_exists": r["file_exists"]}
        for r in subset[: min(10, len(subset))]
    ]
    out = meta_dir / "preview_report.json"
    out.write_text(json.dumps({**report, "subset_records": subset}, indent=2, default=str), encoding="utf-8")
    report["wrote"] = str(out)
    return report


def preview_live(*, n: int, seed: int, inspect_only: bool) -> dict:
    meta_dir = LIVE_ROOT / "metadata"
    videos_dir = LIVE_ROOT / "videos"
    score_path = find_score_file(meta_dir, ("data.mat", "live_vqc_mos.csv", "MOS.csv"))
    files = list_media_files(videos_dir, VIDEO_EXT)
    report: dict = {
        "dataset": "LIVE-VQC",
        "videos_dir": str(videos_dir),
        "metadata_dir": str(meta_dir),
        "score_file": str(score_path) if score_path else None,
        "video_count_on_disk": len(files),
        "selection_seed": seed,
        "requested_n": n,
        "errors": [],
        "warnings": [
            "LIVE-VQC MAT/CSV field names are not hardcoded. Inspect keys, then fill import mapping.",
            "Published MOS is aggregate 0-100 (literature). Do not use it as criterion ratings or Fleiss kappa.",
        ],
    }
    if score_path is None:
        report["errors"].append("No LIVE-VQC scores file yet (expected data.mat or a CSV export).")
        return report
    report["metadata_inspect"] = inspect_live_vqc_metadata(score_path)
    if inspect_only:
        return report
    report["errors"].append(
        "Subset preview for LIVE-VQC requires a filled mapping JSON after inspect. "
        "Do not import until REPLACE_WITH_* placeholders are replaced."
    )
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Preview research dataset metadata (no scoring)")
    parser.add_argument("--dataset", choices=("koniq10k", "live_vqc", "all"), default="all")
    parser.add_argument("--inspect-only", action="store_true", help="Headers/keys only; no subset write")
    parser.add_argument("--photo-n", type=int, default=DEFAULT_PHOTO_N)
    parser.add_argument("--video-n", type=int, default=DEFAULT_VIDEO_N)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    args = parser.parse_args(argv)
    reports = []
    if args.dataset in ("koniq10k", "all"):
        reports.append(preview_koniq(n=args.photo_n, seed=args.seed, inspect_only=args.inspect_only))
    if args.dataset in ("live_vqc", "all"):
        reports.append(preview_live(n=args.video_n, seed=args.seed, inspect_only=args.inspect_only))
    print(json.dumps(reports, indent=2, default=str))
    if any(r.get("errors") for r in reports):
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
