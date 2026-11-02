#!/usr/bin/env python3
"""Batch-evaluate local media with forced EfficientNet or OpenCV engines."""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

# Bootstrap: repo root + access_backend on sys.path
_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for p in (_BACKEND, _REPO):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from tools.quality_validation.dataset import discover_from_folders, load_manifest  # noqa: E402
from tools.quality_validation.engines import ENGINE_EFFICIENTNET, ENGINE_OPENCV, EngineId  # noqa: E402
from tools.quality_validation.evaluate import evaluate_bytes_validation, media_type_for_path  # noqa: E402
from tools.quality_validation.export import write_csv, write_json  # noqa: E402
from tools.quality_validation.metadata import build_run_metadata, file_sha256, write_metadata  # noqa: E402


def _anon_id(content: bytes, prefix: str) -> str:
    return f"{prefix}_{hashlib.sha256(content).hexdigest()[:12]}"


def run_batch(
    *,
    dataset_root: Path,
    manifest: Path | None,
    engines: list[EngineId],
    output_dir: Path,
    video_sample_frames: int | None,
    split_filter: str | None,
) -> list[dict]:
    if manifest:
        items = load_manifest(manifest, dataset_root)
    else:
        items = discover_from_folders(dataset_root)
        if not items:
            raise SystemExit(f"No media found under {dataset_root}/dev or held_out")

    if split_filter:
        items = [i for i in items if i.dataset_split == split_filter]
        if not items:
            raise SystemExit(f"No items for split {split_filter!r}")

    records: list[dict] = []
    for row in items:
        path = (dataset_root / row.relative_path).resolve()
        content = path.read_bytes()
        checksum = file_sha256(path)
        media_id = row.media_id or _anon_id(content, "media")
        inferred = media_type_for_path(path)
        if inferred and inferred != row.media_type:
            print(f"Warning: {path.name} manifest type {row.media_type} != inferred {inferred}")

        for engine in engines:
            result = evaluate_bytes_validation(
                content,
                file_name=path.name,
                engine=engine,
                video_sample_frames=video_sample_frames,
            )
            result["media_id"] = media_id
            result["dataset_split"] = row.dataset_split
            result["file_sha256"] = checksum
            result["source_path"] = str(path)
            records.append(result)
            status = result.get("analysis_status")
            err = result.get("error_code") or ""
            print(f"{media_id} [{row.dataset_split}] engine={engine} status={status} {err}".strip())

    meta = build_run_metadata(
        engines=list(engines),
        video_sample_frames=video_sample_frames,
        dataset_manifest=str(manifest) if manifest else str(dataset_root),
    )
    output_dir.mkdir(parents=True, exist_ok=True)
    write_json(records, output_dir / "machine_results.json", meta)
    write_csv(records, output_dir / "machine_results.csv")
    write_metadata(output_dir / "run_metadata.json", meta)
    return records


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="ACCESS quality validation batch runner")
    parser.add_argument(
        "--dataset-root",
        type=Path,
        required=True,
        help="Root folder containing dev/held_out or manifest paths",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=None,
        help="Optional CSV manifest (media_id, relative_path, media_type, dataset_split)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("tools/quality_validation/output/latest"),
        help="Directory for JSON/CSV/metadata outputs",
    )
    parser.add_argument(
        "--engine",
        action="append",
        choices=[ENGINE_EFFICIENTNET, ENGINE_OPENCV],
        dest="engines",
        help="Repeat for each engine (default: both)",
    )
    parser.add_argument(
        "--split",
        choices=["dev", "held_out"],
        default=None,
        help="Evaluate only this split",
    )
    parser.add_argument(
        "--video-sample-frames",
        type=int,
        default=None,
        help="Override EVALUATION_VIDEO_SAMPLE_FRAMES for this run",
    )
    args = parser.parse_args(argv)
    engines: list[EngineId] = args.engines or [ENGINE_EFFICIENTNET, ENGINE_OPENCV]
    dataset_root = args.dataset_root.resolve()
    if not dataset_root.is_dir():
        print(f"Dataset root not found: {dataset_root}", file=sys.stderr)
        return 1
    try:
        run_batch(
            dataset_root=dataset_root,
            manifest=args.manifest.resolve() if args.manifest else None,
            engines=engines,
            output_dir=args.output_dir.resolve(),
            video_sample_frames=args.video_sample_frames,
            split_filter=args.split,
        )
    except (FileNotFoundError, ValueError) as exc:
        print(exc, file=sys.stderr)
        return 1
    print(f"Wrote results to {args.output_dir.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
