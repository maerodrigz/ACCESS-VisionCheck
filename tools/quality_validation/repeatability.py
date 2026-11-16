#!/usr/bin/env python3
"""Run repeated evaluations on the same files for repeatability stats."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for p in (_BACKEND, _REPO):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from tools.quality_validation.batch_runner import run_batch  # noqa: E402
from tools.quality_validation.export import load_machine_results, write_json  # noqa: E402
from tools.quality_validation.metadata import build_run_metadata  # noqa: E402
from tools.quality_validation.metrics import repeatability_std  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Repeatability runs for quality validation")
    parser.add_argument("--dataset-root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=None)
    parser.add_argument("--engine", required=True, choices=["efficientnet", "opencv"])
    parser.add_argument("--repeats", type=int, default=5)
    parser.add_argument("--output-dir", type=Path, default=Path("tools/quality_validation/output/repeatability"))
    args = parser.parse_args(argv)

    all_records: list[dict] = []
    for i in range(args.repeats):
        out = args.output_dir / f"run_{i:02d}"
        run_batch(
            dataset_root=args.dataset_root.resolve(),
            manifest=args.manifest.resolve() if args.manifest else None,
            engines=[args.engine],
            output_dir=out,
            video_sample_frames=None,
            split_filter=None,
        )
        _, recs = load_machine_results(out / "machine_results.json")
        for r in recs:
            r["repeat_index"] = i
        all_records.extend(recs)

    summary: dict = {}
    from collections import defaultdict

    buckets: dict[tuple, list[float]] = defaultdict(list)
    for r in all_records:
        if r.get("analysis_status") != "ok":
            continue
        key = (r.get("media_id"), r.get("engine"))
        o = r.get("overall_score")
        if o is not None:
            buckets[key].append(float(o))
    for key, vals in buckets.items():
        summary[f"{key[0]}|{key[1]}"] = repeatability_std(vals)

    meta = build_run_metadata(
        engines=[args.engine],
        video_sample_frames=None,
        dataset_manifest=str(args.manifest or args.dataset_root),
    )
    meta["repeatability_repeats"] = args.repeats
    write_json(all_records, args.output_dir / "all_repeats.json", meta)
    summary_path = args.output_dir / "repeatability_summary.json"
    summary_path.write_text(
        json.dumps({"metadata": meta, "summary": summary}, indent=2),
        encoding="utf-8",
    )
    print(f"Repeatability summary: {args.output_dir / 'repeatability_summary.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
