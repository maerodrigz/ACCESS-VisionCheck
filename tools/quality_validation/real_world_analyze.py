#!/usr/bin/env python3
"""Compare production quality scores with independent human ratings."""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

import numpy as np

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.export import load_machine_results  # noqa: E402
from tools.quality_validation.metrics import fleiss_kappa, mae_rmse, pearson_spearman  # noqa: E402
from tools.quality_validation.real_world_schema import (  # noqa: E402
    OVERALL_HUMAN,
    PHOTO_CRITERIA,
    VIDEO_CRITERIA,
    load_human_ratings_access,
    load_real_world_manifest,
)
from tools.quality_validation.research_datasets import load_published_mos  # noqa: E402


def _median(values: list[float]) -> float | None:
    if not values:
        return None
    return float(statistics.median(values))


def aggregate_human(ratings: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    by_media: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in ratings:
        by_media[row["media_id"]].append(row)
    out: dict[str, dict[str, Any]] = {}
    for media_id, rows in by_media.items():
        criteria = {}
        all_names = set(PHOTO_CRITERIA) | set(VIDEO_CRITERIA) | {OVERALL_HUMAN}
        for name in all_names:
            vals = [r["scores"][name] for r in rows if r["scores"].get(name) is not None]
            criteria[name] = _median(vals)
        overall_vals = [r["scores"][OVERALL_HUMAN] for r in rows if r["scores"].get(OVERALL_HUMAN) is not None]
        out[media_id] = {
            "n_raters": len({r["rater_id"] for r in rows}),
            "median_scores": criteria,
            "independent_overall": _median(overall_vals),
            "rater_ids": sorted({r["rater_id"] for r in rows}),
        }
    return out


def _pairs(human_vals: list[float | None], machine_vals: list[float | None]) -> tuple[list[float], list[float]]:
    xs: list[float] = []
    ys: list[float] = []
    for h, m in zip(human_vals, machine_vals, strict=True):
        if h is None or m is None:
            continue
        xs.append(float(h))
        ys.append(float(m))
    return xs, ys


def _metric_block(human: list[float], machine: list[float]) -> dict[str, Any]:
    err = mae_rmse(machine, human)
    corr = pearson_spearman(machine, human)
    bias = float(np.mean(np.asarray(machine) - np.asarray(human))) if human else None
    within1 = None
    if human:
        within1 = float(np.mean(np.abs(np.asarray(machine) - np.asarray(human)) <= 1.0))
    return {
        "n_paired": len(human),
        "mae": err["mae"],
        "rmse": err["rmse"],
        "spearman_r": corr["spearman_r"],
        "spearman_p": corr["spearman_p"],
        "pearson_r": corr["pearson_r"],
        "pearson_p": corr["pearson_p"],
        "bias_system_minus_human": bias,
        "abs_error_le_1_rate": within1,
        "abs_error_le_1_definition": "fraction of paired samples with |system - human| <= 1 on the 1-5 scale",
    }


def analyze(
    *,
    machine_records: list[dict[str, Any]],
    human_rows: list[dict[str, Any]],
    manifest_items: list | None = None,
) -> dict[str, Any]:
    human = aggregate_human(human_rows)
    condition = {item.media_id: item.quality_condition for item in manifest_items or []}
    ok = [r for r in machine_records if r.get("analysis_status") == "ok"]
    failed = [r for r in machine_records if r.get("analysis_status") == "failed"]
    total = len(machine_records) or 1

    criterion_metrics = {}
    for name in list(VIDEO_CRITERIA) + [OVERALL_HUMAN]:
        h_list: list[float | None] = []
        m_list: list[float | None] = []
        for rec in ok:
            mid = rec.get("media_id")
            hum = human.get(mid, {}).get("median_scores", {})
            if name == OVERALL_HUMAN:
                h_list.append(human.get(mid, {}).get("independent_overall"))
                m_list.append(rec.get("overall_score"))
            else:
                h_list.append(hum.get(name))
                m_list.append((rec.get("criterion_scores") or {}).get(name))
        xs, ys = _pairs(h_list, m_list)
        if xs:
            criterion_metrics[name] = _metric_block(xs, ys)
        else:
            criterion_metrics[name] = {"n_paired": 0, "note": "no paired observations"}

    by_type: dict[str, Any] = {}
    for media_type in ("photo", "video"):
        subset = [r for r in ok if r.get("media_type") == media_type]
        xs, ys = _pairs(
            [human.get(r.get("media_id"), {}).get("independent_overall") for r in subset],
            [r.get("overall_score") for r in subset],
        )
        by_type[media_type] = _metric_block(xs, ys) if xs else {"n_paired": 0}

    by_condition: dict[str, Any] = {}
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for rec in ok:
        key = condition.get(rec.get("media_id"), "") or rec.get("quality_condition") or "unspecified"
        grouped[str(key)].append(rec)
    for key, subset in grouped.items():
        xs, ys = _pairs(
            [human.get(r.get("media_id"), {}).get("independent_overall") for r in subset],
            [r.get("overall_score") for r in subset],
        )
        by_condition[key] = _metric_block(xs, ys) if xs else {"n_paired": 0}

    by_engine: dict[str, Any] = {}
    eng_group: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for rec in ok:
        label = str(rec.get("quality_engine") or "unknown")
        if rec.get("opencv_fallback"):
            label += "+fallback"
        eng_group[label].append(rec)
    for key, subset in eng_group.items():
        xs, ys = _pairs(
            [human.get(r.get("media_id"), {}).get("independent_overall") for r in subset],
            [r.get("overall_score") for r in subset],
        )
        by_engine[key] = {
            **(_metric_block(xs, ys) if xs else {"n_paired": 0}),
            "n_system_ok": len(subset),
        }

    overall_matrix = []
    rater_ids = sorted({r["rater_id"] for r in human_rows})
    media_ids = sorted(human.keys())
    for mid in media_ids:
        row_vals = []
        by_rater = {r["rater_id"]: r for r in human_rows if r["media_id"] == mid}
        for rid in rater_ids:
            score = by_rater.get(rid, {}).get("scores", {}).get(OVERALL_HUMAN)
            row_vals.append(float(score) if score is not None else np.nan)
        overall_matrix.append(row_vals)
    kappa = fleiss_kappa(np.array(overall_matrix, dtype=float)) if overall_matrix else None

    return {
        "disclaimer": (
            "These statistics describe agreement with available human ratings. "
            "They are not a scientific validation of EfficientNet-B0."
        ),
        "n_system_records": len(machine_records),
        "n_system_ok": len(ok),
        "n_system_failed": len(failed),
        "failure_rate": len(failed) / total,
        "fallback_rate": sum(1 for r in ok if r.get("opencv_fallback")) / len(ok) if ok else None,
        "failed_media_ids": [r.get("media_id") for r in failed],
        "human_media_count": len(human),
        "inter_rater_fleiss_kappa_overall": kappa,
        "inter_rater_note": "Fleiss kappa on independent overall visual quality; missing ratings are skipped per item.",
        "system_overall_definition": "Arithmetic mean of ACCESS criterion integers (7 photo / 9 video).",
        "human_overall_definition": "Independent 1-5 overall visual quality, not forced to equal the rater mean.",
        "criterion_metrics": criterion_metrics,
        "by_media_type": by_type,
        "by_quality_condition": by_condition,
        "by_quality_engine": by_engine,
        "score_direction": "higher_is_better_1_to_5",
    }


def analyze_published_mos(
    *,
    machine_records: list[dict[str, Any]],
    published_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    """Overall MOS vs system overall only. Never Fleiss kappa. Never criterion scores."""
    by_id = {r["media_id"]: r for r in published_rows}
    ok = [r for r in machine_records if r.get("analysis_status") == "ok"]
    failed = [r for r in machine_records if r.get("analysis_status") == "failed"]
    missing_mos: list[str] = []
    missing_mapped: list[str] = []
    unpaired_system: list[str] = []
    h_list: list[float | None] = []
    m_list: list[float | None] = []
    for rec in ok:
        mid = rec.get("media_id")
        pub = by_id.get(mid)
        if pub is None:
            unpaired_system.append(str(mid))
            continue
        mapped = pub.get("overall_mapped_1_5")
        if mapped is None:
            missing_mapped.append(str(mid))
        if pub.get("mos_quality_raw") is None:
            missing_mos.append(str(mid))
        h_list.append(mapped)
        m_list.append(rec.get("overall_score"))
    xs, ys = _pairs(h_list, m_list)
    metrics = _metric_block(xs, ys) if xs else {"n_paired": 0, "note": "no paired observations"}
    return {
        "validation_kind": "dataset_published_mos_overall",
        "disclaimer": (
            "Published MOS is an aggregate overall label. It is not three ACCESS raters "
            "and is not criterion-specific. These statistics are not a scientific validation "
            "of EfficientNet-B0."
        ),
        "n_published_rows": len(published_rows),
        "n_system_records": len(machine_records),
        "n_system_ok": len(ok),
        "n_system_failed": len(failed),
        "failed_media_ids": [r.get("media_id") for r in failed],
        "unpaired_system_media_ids": unpaired_system,
        "missing_raw_mos": missing_mos,
        "missing_mapped_1_5": missing_mapped,
        "inter_rater_fleiss_kappa_overall": None,
        "inter_rater_note": "Fleiss kappa is not computed from aggregate MOS.",
        "overall_mapped_1_5_vs_system_overall": metrics,
        "score_direction": "higher_is_better_1_to_5",
    }


def write_csv_summary(report: dict[str, Any], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, block in (report.get("criterion_metrics") or {}).items():
        row = {"section": "criterion", "name": name}
        row.update({k: v for k, v in block.items() if k != "abs_error_le_1_definition"})
        rows.append(row)
    for name, block in (report.get("by_media_type") or {}).items():
        row = {"section": "media_type", "name": name}
        row.update(block)
        rows.append(row)
    for name, block in (report.get("by_quality_condition") or {}).items():
        row = {"section": "quality_condition", "name": name}
        row.update({k: v for k, v in block.items() if k != "abs_error_le_1_definition"})
        rows.append(row)
    for name, block in (report.get("by_quality_engine") or {}).items():
        row = {"section": "quality_engine", "name": name}
        row.update({k: v for k, v in block.items() if k != "abs_error_le_1_definition"})
        rows.append(row)
    if not rows:
        path.write_text("section,name,n_paired\n", encoding="utf-8")
        return
    fieldnames = sorted({key for row in rows for key in row.keys()})
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_markdown(report: dict[str, Any], path: Path) -> None:
    lines = [
        "# ACCESS VisionCheck — real-world quality validation report",
        "",
        report["disclaimer"],
        "",
        f"- System records: {report['n_system_records']} (ok {report['n_system_ok']}, failed {report['n_system_failed']})",
        f"- Failure rate: {report['failure_rate']}",
        f"- OpenCV fallback rate among successful runs: {report['fallback_rate']}",
        f"- Human-rated media: {report['human_media_count']}",
        f"- Fleiss kappa (independent overall): {report['inter_rater_fleiss_kappa_overall']}",
        "",
        report["system_overall_definition"],
        report["human_overall_definition"],
        "",
        "Score direction: 1–5, higher is better, including Blur and Noise.",
        "",
        "## Per-criterion paired results",
        "",
        "| Criterion | n | MAE | Spearman r | Pearson r | bias (system-human) |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for name, block in (report.get("criterion_metrics") or {}).items():
        if not block.get("n_paired"):
            lines.append(f"| {name} | 0 | N/A | N/A | N/A | N/A |")
            continue
        lines.append(
            "| {name} | {n} | {mae} | {sp} | {pe} | {bias} |".format(
                name=name,
                n=block.get("n_paired"),
                mae=_fmt(block.get("mae")),
                sp=_fmt(block.get("spearman_r")),
                pe=_fmt(block.get("pearson_r")),
                bias=_fmt(block.get("bias_system_minus_human")),
            )
        )
    lines.extend(
        [
            "",
            "MAE is mean |system - human median| on the 1–5 scale. "
            "`abs_error_le_1_rate` in the CSV is the fraction of pairs within one point; it is not model accuracy.",
            "",
            "Failed system evaluations are excluded from MAE and correlations and listed as failures.",
            "",
        ]
    )
    if report.get("failed_media_ids"):
        lines.append("Failed media IDs: " + ", ".join(str(x) for x in report["failed_media_ids"]))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _fmt(value: Any) -> str:
    if value is None:
        return "N/A"
    if isinstance(value, float):
        return f"{value:.3f}"
    return str(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Analyze real-world quality ratings vs system scores")
    parser.add_argument("--machine-results", type=Path, required=True)
    parser.add_argument("--human-ratings", type=Path, default=None, help="Independent ACCESS criterion ratings CSV")
    parser.add_argument("--published-mos", type=Path, default=None, help="Dataset aggregate MOS CSV from research_import")
    parser.add_argument("--manifest", type=Path, default=None)
    parser.add_argument("--dataset-root", type=Path, default=None)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args(argv)

    if args.human_ratings is None and args.published_mos is None:
        parser.error("Provide --human-ratings and/or --published-mos")

    _, records = load_machine_results(args.machine_results)
    items = None
    if args.manifest:
        root = args.dataset_root or args.manifest.parent
        items = load_real_world_manifest(args.manifest, root, require_files=False)

    report: dict[str, Any] = {
        "disclaimer": (
            "These statistics describe agreement with available labels. "
            "They are not a scientific validation of EfficientNet-B0."
        )
    }
    if args.human_ratings:
        humans = load_human_ratings_access(args.human_ratings)
        report["criterion_specific_human_validation"] = analyze(
            machine_records=records, human_rows=humans, manifest_items=items
        )
        report.update(report["criterion_specific_human_validation"])
    if args.published_mos:
        published = load_published_mos(args.published_mos)
        report["dataset_published_mos_overall"] = analyze_published_mos(
            machine_records=records, published_rows=published
        )
        if not args.human_ratings:
            report.update(report["dataset_published_mos_overall"])
            report["criterion_metrics"] = {
                "Overall visual quality": report["dataset_published_mos_overall"]["overall_mapped_1_5_vs_system_overall"]
            }
            report["n_system_records"] = report["dataset_published_mos_overall"]["n_system_records"]
            report["n_system_ok"] = report["dataset_published_mos_overall"]["n_system_ok"]
            report["n_system_failed"] = report["dataset_published_mos_overall"]["n_system_failed"]
            report["failure_rate"] = (
                report["n_system_failed"] / report["n_system_records"] if report["n_system_records"] else None
            )
            report["fallback_rate"] = None
            report["human_media_count"] = report["dataset_published_mos_overall"]["n_published_rows"]
            report["inter_rater_fleiss_kappa_overall"] = None
            report["inter_rater_note"] = "Fleiss kappa is not computed from aggregate MOS."
            report["system_overall_definition"] = "Arithmetic mean of ACCESS criterion integers (7 photo / 9 video)."
            report["human_overall_definition"] = "Published dataset MOS mapped to 1-5; not ACCESS criterion ratings."
            report["failed_media_ids"] = report["dataset_published_mos_overall"]["failed_media_ids"]
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    (out / "analysis_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    write_csv_summary(report, out / "comparison_summary.csv")
    write_markdown(report, out / "VALIDATION_REPORT.md")
    print(f"Wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
