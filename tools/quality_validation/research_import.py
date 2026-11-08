#!/usr/bin/env python3
"""Import official MOS metadata and write a reproducible subset. No scoring. No download."""

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

from tools.quality_validation.importers.koniq10k import import_koniq10k_rows  # noqa: E402
from tools.quality_validation.importers.live_vqc import import_live_vqc  # noqa: E402
from tools.quality_validation.importers.mapping_config import load_mapping_config  # noqa: E402
from tools.quality_validation.research_datasets import (  # noqa: E402
    DEFAULT_PHOTO_N,
    DEFAULT_SEED,
    DEFAULT_VIDEO_N,
    KONIQ_ROOT,
    LIVE_ROOT,
    build_subset_records,
    find_score_file,
    list_media_files,
    write_published_mos,
    write_subset_manifest,
)
from tools.quality_validation.scale_mapping import parse_optional_float  # noqa: E402

PHOTO_EXT = frozenset({".jpg", ".jpeg", ".png", ".bmp", ".webp"})
VIDEO_EXT = frozenset({".mp4", ".mov", ".avi", ".mkv", ".webm", ".m4v"})
KONIQ_MAPPING = _TOOLKIT / "templates" / "import_mapping.koniq10k.json"
LIVE_MAPPING_EXAMPLE = _TOOLKIT / "templates" / "import_mapping.live_vqc.example.json"


def _koniq() -> tuple[Path, Path, Path]:
    return KONIQ_ROOT / "images", KONIQ_ROOT / "metadata", KONIQ_ROOT


def _live() -> tuple[Path, Path, Path]:
    return LIVE_ROOT / "videos", LIVE_ROOT / "metadata", LIVE_ROOT


def import_koniq_subset(*, n: int, seed: int, mapping: Path | None) -> dict:
    images_dir, meta_dir, root = _koniq()
    source = find_score_file(
        meta_dir,
        ("koniq10k_scores_and_distributions.tab", "koniq10k_scores_and_distributions.csv"),
    )
    if source is None:
        raise FileNotFoundError(
            "Place koniq10k_scores_and_distributions.tab in workspace/datasets/koniq10k/metadata/"
        )
    rows, warnings = import_koniq10k_rows(source, mapping_path=mapping or KONIQ_MAPPING)
    files = list_media_files(images_dir, PHOTO_EXT)
    records, stats = build_subset_records(
        rows,
        media_files=files,
        dataset_root=root,
        n=n,
        seed=seed,
        media_type="photo",
        id_prefix="KONIQ",
    )
    write_subset_manifest(records, meta_dir / "subset_manifest.csv")
    write_published_mos(
        records,
        meta_dir / "published_mos.csv",
        license_note="KonIQ-10k; follow the dataset license from MMSP / DaRUS. Research use only.",
    )
    return {"dataset": "KonIQ-10k", "warnings": warnings, "subset": stats, "records": records}


def import_live_subset(*, n: int, seed: int, mapping: Path) -> dict:
    load_mapping_config(mapping, allow_placeholders=False)
    videos_dir, meta_dir, root = _live()
    source = find_score_file(meta_dir, ("data.mat", "live_vqc_mos.csv", "MOS.csv"))
    if source is None:
        raise FileNotFoundError("Place LIVE-VQC data.mat or a MOS CSV in workspace/datasets/live_vqc/metadata/")
    ref_rows, warnings = import_live_vqc(source, mapping, strict_scale=True)
    preview_rows = []
    for rec in ref_rows:
        preview_rows.append(
            {
                "source_dataset": rec.get("source_dataset") or "LIVE-VQC",
                "source_media_key": rec.get("source_media_key"),
                "label_provenance": rec.get("label_provenance") or "human_subjective",
                "mos_quality_raw": parse_optional_float(rec.get("mos_quality_raw")),
                "mos_scale": rec.get("mos_scale") or "0-100",
                "overall_mapped_1_5": parse_optional_float(rec.get("overall_documentation_mapped_1_5")),
            }
        )
    files = list_media_files(videos_dir, VIDEO_EXT)
    records, stats = build_subset_records(
        preview_rows,
        media_files=files,
        dataset_root=root,
        n=n,
        seed=seed,
        media_type="video",
        id_prefix="VQC",
    )
    write_subset_manifest(records, meta_dir / "subset_manifest.csv")
    write_published_mos(
        records,
        meta_dir / "published_mos.csv",
        license_note="LIVE Video Quality Challenge; follow the LIVE lab license. Research use only.",
    )
    return {"dataset": "LIVE-VQC", "warnings": warnings, "subset": stats, "records": records}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Import dataset MOS and write a seeded subset (no scoring)")
    parser.add_argument("--dataset", choices=("koniq10k", "live_vqc"), required=True)
    parser.add_argument("--n", type=int, default=None)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--mapping", type=Path, default=None)
    args = parser.parse_args(argv)
    try:
        if args.dataset == "koniq10k":
            report = import_koniq_subset(n=args.n or DEFAULT_PHOTO_N, seed=args.seed, mapping=args.mapping)
        else:
            mapping = args.mapping or LIVE_MAPPING_EXAMPLE
            report = import_live_subset(n=args.n or DEFAULT_VIDEO_N, seed=args.seed, mapping=mapping)
    except (FileNotFoundError, ValueError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2))
        return 2
    slim = {
        "ok": True,
        "dataset": report["dataset"],
        "warnings": report["warnings"],
        "subset": report["subset"],
        "preview_ids": [
            {
                "media_id": r["media_id"],
                "source_media_key": r["source_media_key"],
                "file_exists": r["file_exists"],
            }
            for r in report["records"][:10]
        ],
    }
    print(json.dumps(slim, indent=2, default=str))
    if report["subset"]["files_missing"] or report["subset"]["mos_missing"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
