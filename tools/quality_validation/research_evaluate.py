#!/usr/bin/env python3
"""Score KonIQ-10k subset with the production quality path. No HTTP, DB, AI, or Gemini."""

from __future__ import annotations

import argparse
import csv
import json
import sys
import time
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.engines import engine_availability  # noqa: E402
from tools.quality_validation.export import write_csv, write_json  # noqa: E402
from tools.quality_validation.metadata import file_sha256  # noqa: E402
from tools.quality_validation.real_world_analyze import analyze_published_mos, write_csv_summary, write_markdown  # noqa: E402
from tools.quality_validation.real_world_evaluate import evaluate_production_quality  # noqa: E402
from tools.quality_validation.real_world_schema import PHOTO_CRITERIA, load_real_world_manifest  # noqa: E402
from tools.quality_validation.research_datasets import KONIQ_ROOT, load_published_mos  # noqa: E402

DEFAULT_OUTPUT = KONIQ_ROOT / "metadata" / "output" / "run_001"
PER_IMAGE_FIELDS = (
    "media_id",
    "source_media_key",
    "relative_path",
    "mos_quality_raw",
    "mos_scale",
    "overall_mapped_1_5",
    "overall_score",
    "analysis_status",
    "error_code",
    "error_detail",
    "quality_engine",
    "opencv_fallback",
    "efficientnet_used",
    "elapsed_ms",
    "file_sha256",
    *tuple(f"criterion_{n.replace(' ', '_')}" for n in PHOTO_CRITERIA),
)


def preflight(*, dataset_root: Path, manifest: Path, published_mos: Path) -> dict[str, Any]:
    items = load_real_world_manifest(manifest, dataset_root, require_files=True)
    mos_rows = load_published_mos(published_mos)
    mos_by_id = {row["media_id"]: row for row in mos_rows}
    missing_files = [item.media_id for item in items if not (dataset_root / item.relative_path).is_file()]
    missing_mos = [item.media_id for item in items if item.media_id not in mos_by_id]
    unmapped = [item.media_id for item in items if mos_by_id.get(item.media_id, {}).get("overall_mapped_1_5") is None]
    extra_mos = sorted(set(mos_by_id) - {item.media_id for item in items})
    errors: list[str] = []
    if missing_files:
        errors.append(f"Missing image files: {missing_files}")
    if missing_mos:
        errors.append(f"Manifest IDs without published MOS: {missing_mos}")
    if unmapped:
        errors.append(f"MOS present but not mapped to 1-5: {unmapped}")
    return {
        "n_manifest": len(items),
        "n_published_mos": len(mos_rows),
        "missing_files": missing_files,
        "missing_mos": missing_mos,
        "unmapped_mos": unmapped,
        "extra_mos_ids": extra_mos,
        "engine_availability": engine_availability(),
        "errors": errors,
        "ok": not errors,
        "items": items,
        "mos_by_id": mos_by_id,
    }


def write_per_image_csv(records: list[dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(PER_IMAGE_FIELDS), extrasaction="ignore")
        writer.writeheader()
        for rec in records:
            scores = rec.get("criterion_scores") or {}
            row = {key: rec.get(key) for key in PER_IMAGE_FIELDS}
            for name in PHOTO_CRITERIA:
                row[f"criterion_{name.replace(' ', '_')}"] = scores.get(name)
            writer.writerow(row)


def score_item(item: Any, *, dataset_root: Path, mos: dict[str, Any], dry_run: bool) -> dict[str, Any]:
    path = (dataset_root / item.relative_path).resolve()
    record: dict[str, Any] = {
        "media_id": item.media_id,
        "relative_path": item.relative_path,
        "media_type": item.media_type,
        "source_path": str(path),
        "source_dataset": "KonIQ-10k",
        "source_media_key": Path(item.relative_path).name,
        "selection_seed": mos.get("selection_seed"),
        "mos_quality_raw": mos.get("mos_quality_raw"),
        "mos_scale": mos.get("mos_scale") or "1-5",
        "overall_mapped_1_5": mos.get("overall_mapped_1_5"),
        "not_criterion_ground_truth": True,
        "dry_run": dry_run,
    }
    if dry_run:
        record.update(
            {
                "analysis_status": "dry_run",
                "error_code": None,
                "overall_score": None,
                "criterion_scores": {},
                "quality_engine": None,
                "opencv_fallback": None,
                "elapsed_ms": None,
                "file_exists": path.is_file(),
            }
        )
        return record
    started = time.perf_counter()
    scored = evaluate_production_quality(path.read_bytes(), file_name=path.name)
    record["elapsed_ms"] = round((time.perf_counter() - started) * 1000.0, 3)
    record.update(scored)
    record["file_sha256"] = file_sha256(path)
    return record


def run(
    *,
    dataset_root: Path,
    manifest: Path,
    published_mos: Path,
    output_dir: Path,
    dry_run: bool,
    analyze: bool,
) -> dict[str, Any]:
    check = preflight(dataset_root=dataset_root, manifest=manifest, published_mos=published_mos)
    if not check["ok"]:
        return {"ok": False, "preflight": {k: v for k, v in check.items() if k not in {"items", "mos_by_id"}}}
    records = [
        score_item(item, dataset_root=dataset_root, mos=check["mos_by_id"][item.media_id], dry_run=dry_run)
        for item in check["items"]
    ]
    output_dir.mkdir(parents=True, exist_ok=True)
    meta = {
        "mode": "research_koniq10k_production_quality",
        "dataset": "KonIQ-10k",
        "selection_seed": records[0].get("selection_seed") if records else None,
        "n": len(records),
        "dry_run": dry_run,
        "ai_detection": False,
        "gemini": False,
        "database": False,
        "http_upload": False,
        "score_direction": "higher_is_better_1_to_5",
        "comparison": "machine_overall_vs_published_mos_overall_only",
        "engine_availability": check["engine_availability"],
        "disclaimer": (
            "Published MOS is aggregate overall quality. It is not ACCESS criterion ground truth "
            "and is not a scientific validation of EfficientNet-B0."
        ),
    }
    write_json(records, output_dir / "machine_results.json", meta)
    write_csv(records, output_dir / "machine_results.csv")
    write_per_image_csv(records, output_dir / "per_image_results.csv")
    report: dict[str, Any] = {
        "ok": True,
        "dry_run": dry_run,
        "output_dir": str(output_dir),
        "n": len(records),
        "engine_availability": check["engine_availability"],
    }
    if analyze and not dry_run:
        analysis = analyze_published_mos(machine_records=records, published_rows=list(check["mos_by_id"].values()))
        analysis_path = output_dir / "analysis_report.json"
        analysis_path.write_text(json.dumps(analysis, indent=2), encoding="utf-8")
        summary = {
            "disclaimer": analysis["disclaimer"],
            "n_system_records": analysis["n_system_records"],
            "n_system_ok": analysis["n_system_ok"],
            "n_system_failed": analysis["n_system_failed"],
            "failure_rate": analysis["n_system_failed"] / analysis["n_system_records"] if analysis["n_system_records"] else None,
            "fallback_rate": None,
            "human_media_count": analysis["n_published_rows"],
            "inter_rater_fleiss_kappa_overall": None,
            "inter_rater_note": analysis["inter_rater_note"],
            "system_overall_definition": "Arithmetic mean of ACCESS criterion integers (7 photo).",
            "human_overall_definition": "Published KonIQ MOS on 1-5; not ACCESS criterion ratings.",
            "failed_media_ids": analysis["failed_media_ids"],
            "criterion_metrics": {"Overall visual quality": analysis["overall_mapped_1_5_vs_system_overall"]},
        }
        write_csv_summary(summary, output_dir / "comparison_summary.csv")
        write_markdown(summary, output_dir / "VALIDATION_REPORT.md")
        report["analysis"] = analysis["overall_mapped_1_5_vs_system_overall"]
        report["n_system_failed"] = analysis["n_system_failed"]
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Evaluate KonIQ-10k subset with production quality scoring")
    parser.add_argument("--dataset-root", type=Path, default=KONIQ_ROOT)
    parser.add_argument("--manifest", type=Path, default=None)
    parser.add_argument("--published-mos", type=Path, default=None)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-analyze", action="store_true")
    args = parser.parse_args(argv)
    root = args.dataset_root.resolve()
    manifest = (args.manifest or (root / "metadata" / "subset_manifest.csv")).resolve()
    mos = (args.published_mos or (root / "metadata" / "published_mos.csv")).resolve()
    report = run(
        dataset_root=root,
        manifest=manifest,
        published_mos=mos,
        output_dir=args.output_dir.resolve(),
        dry_run=args.dry_run,
        analyze=not args.no_analyze,
    )
    printable = {k: v for k, v in report.items() if k != "preflight" or report.get("ok")}
    if "preflight" in report:
        printable["preflight"] = report["preflight"]
    print(json.dumps(printable, indent=2, default=str))
    return 0 if report.get("ok") else 2


if __name__ == "__main__":
    raise SystemExit(main())
