#!/usr/bin/env python3
"""Batch-evaluate real-world validation media with the production quality path."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.export import write_csv, write_json  # noqa: E402
from tools.quality_validation.metadata import file_sha256  # noqa: E402
from tools.quality_validation.real_world_evaluate import evaluate_production_quality  # noqa: E402
from tools.quality_validation.real_world_schema import (  # noqa: E402
    load_real_world_manifest,
    scan_workspace,
    write_manifest,
)

DEFAULT_ROOT = _TOOLKIT / "workspace" / "real_world"


def prepare_workspace(dataset_root: Path) -> list:
    items = scan_workspace(dataset_root)
    write_manifest(dataset_root / "manifest.csv", items)
    n_photo = sum(1 for item in items if item.media_type == "photo")
    n_video = sum(1 for item in items if item.media_type == "video")
    print(f"Wrote {dataset_root / 'manifest.csv'}")
    print(f"Found {n_photo} photos (target 40) and {n_video} videos (target 20).")
    if n_photo < 40 or n_video < 20:
        print("Dataset is incomplete. Add original real files; do not generate substitutes.")
    return items


def run_batch(*, dataset_root: Path, manifest: Path, output_dir: Path, dry_run: bool) -> list[dict]:
    items = load_real_world_manifest(manifest, dataset_root, require_files=not dry_run)
    records: list[dict] = []
    for item in items:
        path = (dataset_root / item.relative_path).resolve()
        record = {
            "media_id": item.media_id,
            "relative_path": item.relative_path,
            "media_type": item.media_type,
            "quality_condition": item.quality_condition,
            "source_path": str(path),
            "dry_run": dry_run,
        }
        if dry_run:
            record.update(
                {
                    "analysis_status": "dry_run",
                    "error_code": None,
                    "overall_score": None,
                    "criterion_scores": {},
                    "file_exists": path.is_file(),
                }
            )
            print(f"{item.media_id} dry-run exists={path.is_file()} {path.name}")
        else:
            content = path.read_bytes()
            scored = evaluate_production_quality(content, file_name=path.name)
            record.update(scored)
            record["file_sha256"] = file_sha256(path)
            status = scored.get("analysis_status")
            engine = scored.get("quality_engine")
            fallback = scored.get("opencv_fallback")
            err = scored.get("error_code") or ""
            print(f"{item.media_id} status={status} engine={engine} opencv_fallback={fallback} {err}".strip())
        records.append(record)

    if not dry_run:
        output_dir.mkdir(parents=True, exist_ok=True)
        meta = {
            "mode": "production_quality_only",
            "ai_detection": False,
            "gemini": False,
            "database": False,
            "item_count": len(records),
        }
        write_json(records, output_dir / "machine_results.json", meta)
        write_csv(records, output_dir / "machine_results.csv")
        print(f"Wrote {output_dir}")
    return records


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Real-world ACCESS quality validation batch")
    parser.add_argument(
        "--dataset-root",
        type=Path,
        default=DEFAULT_ROOT,
        help="Workspace with photos/ and videos/",
    )
    parser.add_argument("--manifest", type=Path, default=None)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_ROOT / "output" / "latest",
    )
    parser.add_argument("--prepare", action="store_true", help="Scan folders and write manifest.csv")
    parser.add_argument("--dry-run", action="store_true", help="List samples; do not score")
    args = parser.parse_args(argv)
    root = args.dataset_root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    (root / "photos").mkdir(exist_ok=True)
    (root / "videos").mkdir(exist_ok=True)
    if args.prepare:
        prepare_workspace(root)
        return 0
    manifest = (args.manifest or (root / "manifest.csv")).resolve()
    if not manifest.is_file():
        print(f"Missing manifest {manifest}. Run with --prepare after adding media.", file=sys.stderr)
        return 1
    run_batch(dataset_root=root, manifest=manifest, output_dir=args.output_dir.resolve(), dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
