#!/usr/bin/env python3
"""Human-vs-machine analysis for the ACCESS VisionCheck 30-photo pilot.

Reads locked R1/R2/R3 CSVs, joins PILOT IDs to KonIQ Run 002 machine scores via
facilitator_manifest.csv, and writes a new timestamped output directory.

Does not modify production scoring, original rating CSVs, or Run 001/002 folders.
Does not invent missing ratings. Does not use KonIQ MOS as criterion ground truth.
"""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
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
from tools.quality_validation.metrics import (  # noqa: E402
    fleiss_kappa,
    mae_rmse,
    pearson_spearman,
    quadratic_weighted_kappa,
)
from tools.quality_validation.real_world_schema import (  # noqa: E402
    HUMAN_CSV_COLUMNS,
    OVERALL_HUMAN,
    PHOTO_CRITERIA,
    parse_score_1_5,
)

EXPECTED_PILOT_IDS = [f"PILOT-{i:03d}" for i in range(1, 31)]
EXPECTED_RATERS = ("R1", "R2", "R3")
TECH_CSV_COLS = (
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
)
CRITERION_TO_CSV = {name: col for name, col in HUMAN_CSV_COLUMNS.items() if name in PHOTO_CRITERIA}
CSV_TO_CRITERION = {col: name for name, col in CRITERION_TO_CSV.items()}
RUN002_CRITERION = {
    "Sharpness": "criterion_Sharpness",
    "Blur": "criterion_Blur",
    "Noise": "criterion_Noise",
    "Brightness": "criterion_Brightness",
    "Contrast": "criterion_Contrast",
    "Blocking Artifacts": "criterion_Blocking_Artifacts",
    "Ringing Artifacts": "criterion_Ringing_Artifacts",
}

DEFAULT_RATINGS_DIR = _TOOLKIT / "workspace" / "human_pilot" / "actual_ratings"
DEFAULT_MANIFEST = _TOOLKIT / "workspace" / "human_pilot" / "facilitator" / "facilitator_manifest.csv"
DEFAULT_MACHINE_JSON = (
    _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "run_002" / "output" / "machine_results.json"
)
DEFAULT_PER_IMAGE = (
    _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "run_002" / "output" / "per_image_results.csv"
)
DEFAULT_OUTPUT_ROOT = _TOOLKIT / "workspace" / "human_pilot" / "output"


def _fmt(value: Any, digits: int = 3) -> str:
    if value is None:
        return "N/A"
    if isinstance(value, float):
        if np.isnan(value):
            return "N/A"
        return f"{value:.{digits}f}"
    return str(value)


def _write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str] | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields = fieldnames or list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in fields})


def discover_rating_csvs(ratings_dir: Path) -> list[Path]:
    paths = sorted(ratings_dir.glob("ratings_R*.csv*"))
    # Prefer exact R1/R2/R3 files; ignore templates outside this folder.
    by_rater: dict[str, Path] = {}
    for path in paths:
        name = path.name.upper()
        for rid in EXPECTED_RATERS:
            if rid in name and rid not in by_rater:
                by_rater[rid] = path
    missing = [rid for rid in EXPECTED_RATERS if rid not in by_rater]
    if missing:
        raise FileNotFoundError(f"Missing rating files for {missing} under {ratings_dir}")
    return [by_rater[rid] for rid in EXPECTED_RATERS]


def load_rating_file(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        required = {"media_id", "rater_id"}
        if not required.issubset(set(reader.fieldnames or [])):
            raise ValueError(f"{path.name}: must include media_id and rater_id")
        for line, raw in enumerate(reader, start=2):
            media_id = (raw.get("media_id") or "").strip()
            rater_id = (raw.get("rater_id") or "").strip()
            scores: dict[str, float | None] = {}
            raw_scores: dict[str, str] = {}
            for col in TECH_CSV_COLS + ("overall_visual_quality",):
                raw_scores[col] = (raw.get(col) or "").strip()
                scores[col] = parse_score_1_5(raw.get(col))
            rows.append(
                {
                    "source_file": path.name,
                    "source_line": line,
                    "media_id": media_id,
                    "rater_id": rater_id,
                    "media_type": (raw.get("media_type") or "").strip().lower(),
                    "scores": scores,
                    "raw_scores": raw_scores,
                    "notes": (raw.get("notes") or "").strip(),
                    "flickering": (raw.get("flickering") or "").strip(),
                    "motion_stability": (raw.get("motion_stability") or "").strip(),
                }
            )
    return rows


def validate_human_rows(all_rows: list[dict[str, Any]]) -> dict[str, Any]:
    issues: list[dict[str, Any]] = []
    by_rater: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in all_rows:
        by_rater[row["rater_id"]].append(row)

    for rid in EXPECTED_RATERS:
        rows = by_rater.get(rid, [])
        if not rows:
            issues.append({"severity": "error", "rater_id": rid, "issue": "missing_rater_file_or_rows"})
            continue
        ids = [r["media_id"] for r in rows]
        counts = Counter(ids)
        for mid, n in counts.items():
            if n > 1:
                issues.append(
                    {
                        "severity": "error",
                        "rater_id": rid,
                        "media_id": mid,
                        "issue": "duplicate_media_id",
                        "count": n,
                    }
                )
        for mid in EXPECTED_PILOT_IDS:
            if mid not in counts:
                issues.append(
                    {
                        "severity": "error",
                        "rater_id": rid,
                        "media_id": mid,
                        "issue": "missing_pilot_id",
                    }
                )
        for mid in counts:
            if mid not in EXPECTED_PILOT_IDS:
                issues.append(
                    {
                        "severity": "error",
                        "rater_id": rid,
                        "media_id": mid,
                        "issue": "unexpected_media_id",
                    }
                )
        for row in rows:
            if row["rater_id"] not in EXPECTED_RATERS:
                issues.append(
                    {
                        "severity": "error",
                        "rater_id": row["rater_id"],
                        "media_id": row["media_id"],
                        "issue": "unexpected_rater_id",
                    }
                )
            for col in TECH_CSV_COLS + ("overall_visual_quality",):
                raw = row["raw_scores"][col]
                parsed = row["scores"][col]
                if raw == "":
                    issues.append(
                        {
                            "severity": "warning",
                            "rater_id": row["rater_id"],
                            "media_id": row["media_id"],
                            "criterion": col,
                            "issue": "missing_score",
                            "raw": raw,
                        }
                    )
                elif parsed is None:
                    issues.append(
                        {
                            "severity": "error",
                            "rater_id": row["rater_id"],
                            "media_id": row["media_id"],
                            "criterion": col,
                            "issue": "invalid_score",
                            "raw": raw,
                        }
                    )
                elif float(parsed) != int(parsed):
                    issues.append(
                        {
                            "severity": "warning",
                            "rater_id": row["rater_id"],
                            "media_id": row["media_id"],
                            "criterion": col,
                            "issue": "non_integer_score",
                            "raw": raw,
                        }
                    )

    n_error = sum(1 for i in issues if i["severity"] == "error")
    n_warn = sum(1 for i in issues if i["severity"] == "warning")
    return {
        "n_rows": len(all_rows),
        "raters_present": sorted(by_rater.keys()),
        "n_issues": len(issues),
        "n_errors": n_error,
        "n_warnings": n_warn,
        "issues": issues,
        "ok_to_analyze": n_error == 0,
    }


def load_facilitator_manifest(path: Path) -> dict[str, dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    out: dict[str, dict[str, str]] = {}
    for raw in rows:
        aid = (raw.get("anonymous_id") or "").strip()
        if not aid:
            continue
        if aid in out:
            raise ValueError(f"Duplicate anonymous_id in manifest: {aid}")
        out[aid] = {k: (v or "").strip() for k, v in raw.items()}
    missing = [mid for mid in EXPECTED_PILOT_IDS if mid not in out]
    if missing:
        raise ValueError(f"Manifest missing pilot IDs: {missing}")
    return out


def load_run002_machine(*, machine_json: Path, per_image_csv: Path) -> dict[str, dict[str, Any]]:
    """Index Run 002 machine scores by KONIQ2 media_id. No inference."""
    by_id: dict[str, dict[str, Any]] = {}
    if machine_json.is_file():
        _, results = load_machine_results(machine_json)
        for rec in results:
            mid = (rec.get("media_id") or "").strip()
            if not mid:
                continue
            scores = dict(rec.get("criterion_scores") or {})
            by_id[mid] = {
                "media_id": mid,
                "analysis_status": rec.get("analysis_status"),
                "quality_engine": rec.get("quality_engine"),
                "opencv_fallback": bool(rec.get("opencv_fallback")),
                "overall_score": rec.get("overall_score"),
                "criterion_scores": {
                    name: parse_score_1_5(scores.get(name)) for name in PHOTO_CRITERIA
                },
                "source": "machine_results.json",
            }
    # Prefer / fill from per_image_results.csv for criterion columns.
    if per_image_csv.is_file():
        with per_image_csv.open(newline="", encoding="utf-8-sig") as handle:
            for raw in csv.DictReader(handle):
                mid = (raw.get("media_id") or "").strip()
                if not mid:
                    continue
                criteria = {
                    name: parse_score_1_5(raw.get(col)) for name, col in RUN002_CRITERION.items()
                }
                overall = parse_score_1_5(raw.get("overall_score"))
                if overall is None:
                    try:
                        overall = float(raw.get("overall_score")) if (raw.get("overall_score") or "").strip() else None
                    except ValueError:
                        overall = None
                existing = by_id.get(mid, {})
                by_id[mid] = {
                    "media_id": mid,
                    "analysis_status": (raw.get("analysis_status") or existing.get("analysis_status") or "").strip(),
                    "quality_engine": (raw.get("quality_engine") or existing.get("quality_engine") or "").strip(),
                    "opencv_fallback": str(raw.get("opencv_fallback") or "").lower() in {"1", "true", "yes"}
                    or bool(existing.get("opencv_fallback")),
                    "overall_score": overall if overall is not None else existing.get("overall_score"),
                    "criterion_scores": criteria
                    if any(v is not None for v in criteria.values())
                    else existing.get("criterion_scores", {}),
                    "mos_quality_raw": (raw.get("mos_quality_raw") or "").strip(),
                    "overall_mapped_1_5": (raw.get("overall_mapped_1_5") or "").strip(),
                    "source_media_key": (raw.get("source_media_key") or "").strip(),
                    "file_sha256": (raw.get("file_sha256") or "").strip(),
                    "source": "per_image_results.csv+json" if mid in by_id else "per_image_results.csv",
                }
    return by_id


def median_available(values: list[float | None]) -> float | None:
    present = [float(v) for v in values if v is not None]
    if not present:
        return None
    return float(statistics.median(present))


def build_consensus(
    rows: list[dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    by_media: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        by_media[row["media_id"]].append(row)
    out: dict[str, dict[str, Any]] = {}
    for mid in EXPECTED_PILOT_IDS:
        group = by_media.get(mid, [])
        by_rater = {r["rater_id"]: r for r in group}
        tech: dict[str, Any] = {}
        for col in TECH_CSV_COLS:
            vals = [by_rater.get(rid, {}).get("scores", {}).get(col) for rid in EXPECTED_RATERS]
            tech[col] = {
                "R1": vals[0],
                "R2": vals[1],
                "R3": vals[2],
                "n_available": sum(v is not None for v in vals),
                "median": median_available(vals),
            }
        overall_vals = [
            by_rater.get(rid, {}).get("scores", {}).get("overall_visual_quality") for rid in EXPECTED_RATERS
        ]
        out[mid] = {
            "media_id": mid,
            "n_raters_present": len(by_rater),
            "rater_ids": sorted(by_rater.keys()),
            "technical": tech,
            "overall_visual_quality": {
                "R1": overall_vals[0],
                "R2": overall_vals[1],
                "R3": overall_vals[2],
                "n_available": sum(v is not None for v in overall_vals),
                "median": median_available(overall_vals),
            },
        }
    return out


def pairwise_agreement(a: list[float], b: list[float]) -> dict[str, Any]:
    if not a:
        return {
            "n_paired": 0,
            "exact_agreement_rate": None,
            "within_one_agreement_rate": None,
            "quadratic_weighted_kappa": None,
        }
    aa = np.asarray(a, dtype=float)
    bb = np.asarray(b, dtype=float)
    exact = float(np.mean(aa == bb))
    within1 = float(np.mean(np.abs(aa - bb) <= 1.0))
    qwk = quadratic_weighted_kappa([int(x) for x in aa], [int(x) for x in bb])
    return {
        "n_paired": len(a),
        "exact_agreement_rate": exact,
        "within_one_agreement_rate": within1,
        "quadratic_weighted_kappa": qwk,
    }


def inter_rater_for_criterion(rows: list[dict[str, Any]], col: str) -> dict[str, Any]:
    by_media: dict[str, dict[str, float | None]] = {}
    for mid in EXPECTED_PILOT_IDS:
        by_media[mid] = {rid: None for rid in EXPECTED_RATERS}
    for row in rows:
        mid = row["media_id"]
        rid = row["rater_id"]
        if mid in by_media and rid in by_media[mid]:
            by_media[mid][rid] = row["scores"].get(col)

    matrix = np.full((len(EXPECTED_PILOT_IDS), len(EXPECTED_RATERS)), np.nan, dtype=float)
    for i, mid in enumerate(EXPECTED_PILOT_IDS):
        for j, rid in enumerate(EXPECTED_RATERS):
            val = by_media[mid][rid]
            if val is not None:
                matrix[i, j] = float(val)

    n_missing_cells = int(np.isnan(matrix).sum())
    pairwise: dict[str, Any] = {}
    pairs = (("R1", "R2"), ("R1", "R3"), ("R2", "R3"))
    for left, right in pairs:
        li = EXPECTED_RATERS.index(left)
        ri = EXPECTED_RATERS.index(right)
        a: list[float] = []
        b: list[float] = []
        for i in range(len(EXPECTED_PILOT_IDS)):
            if np.isnan(matrix[i, li]) or np.isnan(matrix[i, ri]):
                continue
            a.append(float(matrix[i, li]))
            b.append(float(matrix[i, ri]))
        pairwise[f"{left}_vs_{right}"] = pairwise_agreement(a, b)

    # Mean pairwise rates across available pairs.
    exact_vals = [p["exact_agreement_rate"] for p in pairwise.values() if p["exact_agreement_rate"] is not None]
    within_vals = [
        p["within_one_agreement_rate"] for p in pairwise.values() if p["within_one_agreement_rate"] is not None
    ]
    qwk_vals = [p["quadratic_weighted_kappa"] for p in pairwise.values() if p["quadratic_weighted_kappa"] is not None]

    # Items with at least 2 ratings for Fleiss.
    fleiss = fleiss_kappa(matrix)
    return {
        "criterion": col,
        "n_items": len(EXPECTED_PILOT_IDS),
        "n_missing_cells": n_missing_cells,
        "fleiss_kappa": fleiss,
        "mean_pairwise_exact_agreement": float(np.mean(exact_vals)) if exact_vals else None,
        "mean_pairwise_within_one_agreement": float(np.mean(within_vals)) if within_vals else None,
        "mean_pairwise_quadratic_weighted_kappa": float(np.mean(qwk_vals)) if qwk_vals else None,
        "pairwise": pairwise,
        "missing_handling": (
            "Pairwise metrics use only item-rater pairs where both raters provided a valid 1-5 score. "
            "Fleiss kappa skips items with fewer than 2 valid ratings and treats other missing cells as absent."
        ),
    }


def compare_machine_human(
    *,
    consensus: dict[str, dict[str, Any]],
    manifest: dict[str, dict[str, str]],
    machine_by_koniq: dict[str, dict[str, Any]],
) -> tuple[list[dict[str, Any]], dict[str, Any], dict[str, Any]]:
    per_image: list[dict[str, Any]] = []
    join_issues: list[dict[str, Any]] = []

    for mid in EXPECTED_PILOT_IDS:
        fac = manifest[mid]
        kid = fac["koniq2_media_id"]
        machine = machine_by_koniq.get(kid)
        if machine is None:
            join_issues.append({"media_id": mid, "koniq2_media_id": kid, "issue": "missing_machine_score"})
            continue
        if (machine.get("analysis_status") or "").lower() != "ok":
            join_issues.append(
                {
                    "media_id": mid,
                    "koniq2_media_id": kid,
                    "issue": "machine_not_ok",
                    "analysis_status": machine.get("analysis_status"),
                }
            )
        row: dict[str, Any] = {
            "media_id": mid,
            "koniq2_media_id": kid,
            "source_media_key": fac.get("source_media_key", ""),
            "stratum_label": fac.get("stratum_label", ""),
            "analysis_status": machine.get("analysis_status"),
            "quality_engine": machine.get("quality_engine"),
            "machine_overall_score": machine.get("overall_score"),
            "human_overall_median": consensus[mid]["overall_visual_quality"]["median"],
            "human_overall_n": consensus[mid]["overall_visual_quality"]["n_available"],
            "mos_quality_raw_not_criterion_gt": machine.get("mos_quality_raw", fac.get("mos_quality_raw", "")),
        }
        for name, col in CRITERION_TO_CSV.items():
            h = consensus[mid]["technical"][col]
            m = (machine.get("criterion_scores") or {}).get(name)
            row[f"human_{col}_median"] = h["median"]
            row[f"human_{col}_n"] = h["n_available"]
            row[f"machine_{col}"] = m
            if h["median"] is not None and m is not None:
                row[f"error_{col}_machine_minus_human"] = float(m) - float(h["median"])
            else:
                row[f"error_{col}_machine_minus_human"] = ""
        if row["human_overall_median"] is not None and row["machine_overall_score"] is not None:
            row["error_overall_machine_minus_human"] = float(row["machine_overall_score"]) - float(
                row["human_overall_median"]
            )
        else:
            row["error_overall_machine_minus_human"] = ""
        per_image.append(row)

    criterion_summary: dict[str, Any] = {}
    for name, col in CRITERION_TO_CSV.items():
        human_vals: list[float] = []
        machine_vals: list[float] = []
        for row in per_image:
            if (row.get("analysis_status") or "").lower() != "ok":
                continue
            h = row.get(f"human_{col}_median")
            m = row.get(f"machine_{col}")
            if h is None or m is None or h == "" or m == "":
                continue
            human_vals.append(float(h))
            machine_vals.append(float(m))
        err = mae_rmse(machine_vals, human_vals)
        corr = pearson_spearman(machine_vals, human_vals)
        bias = float(np.mean(np.asarray(machine_vals) - np.asarray(human_vals))) if human_vals else None
        within1 = (
            float(np.mean(np.abs(np.asarray(machine_vals) - np.asarray(human_vals)) <= 1.0)) if human_vals else None
        )
        criterion_summary[name] = {
            "criterion": name,
            "csv_column": col,
            "n_paired": len(human_vals),
            "mae": err["mae"],
            "rmse": err["rmse"],
            "bias_machine_minus_human": bias,
            "spearman_r": corr.get("spearman_r"),
            "spearman_p": corr.get("spearman_p"),
            "pearson_r": corr.get("pearson_r"),
            "pearson_p": corr.get("pearson_p"),
            "abs_error_le_1_rate": within1,
            "note": "Human reference is median of available R1/R2/R3 ratings. KonIQ MOS was not used.",
        }

    # Overall construct comparison (different constructs).
    h_over: list[float] = []
    m_over: list[float] = []
    for row in per_image:
        if (row.get("analysis_status") or "").lower() != "ok":
            continue
        h = row.get("human_overall_median")
        m = row.get("machine_overall_score")
        if h is None or m is None or h == "" or m == "":
            continue
        h_over.append(float(h))
        m_over.append(float(m))
    err_o = mae_rmse(m_over, h_over)
    corr_o = pearson_spearman(m_over, h_over)
    bias_o = float(np.mean(np.asarray(m_over) - np.asarray(h_over))) if h_over else None
    within1_o = float(np.mean(np.abs(np.asarray(m_over) - np.asarray(h_over)) <= 1.0)) if h_over else None
    overall_summary = {
        "comparison": "human_overall_visual_quality_median_vs_machine_overall_score",
        "construct_note": (
            "Different constructs: human overall_visual_quality is an independent gestalt rating; "
            "machine overall_score is the arithmetic mean of the seven technical badge integers."
        ),
        "n_paired": len(h_over),
        "mae": err_o["mae"],
        "rmse": err_o["rmse"],
        "bias_machine_minus_human": bias_o,
        "spearman_r": corr_o.get("spearman_r"),
        "spearman_p": corr_o.get("spearman_p"),
        "pearson_r": corr_o.get("pearson_r"),
        "pearson_p": corr_o.get("pearson_p"),
        "abs_error_le_1_rate": within1_o,
        "koniq_mos_used_as_criterion_gt": False,
    }
    return per_image, criterion_summary, {"overall": overall_summary, "join_issues": join_issues}


def write_markdown_report(path: Path, payload: dict[str, Any]) -> None:
    dq = payload["data_quality"]
    irr = payload["inter_rater"]
    crit = payload["criterion_comparison"]
    overall = payload["overall_comparison"]["overall"]
    lines = [
        "# ACCESS VisionCheck — human vs machine pilot analysis",
        "",
        f"Generated (UTC): {payload['generated_at']}",
        f"Output directory: `{payload['output_dir']}`",
        "",
        "## Scope and safety",
        "",
        "- Pilot: 30 blinded photos (`PILOT-001` … `PILOT-030`), three raters (`R1`, `R2`, `R3`).",
        "- Machine scores: existing KonIQ Run 002 EfficientNet-B0 badges. **No re-inference.**",
        "- Join key: `facilitator_manifest.csv` (`anonymous_id` → `koniq2_media_id`).",
        "- KonIQ MOS was **not** used as ground truth for any of the seven criteria.",
        "- Original human CSVs and Run 001/002 folders were not modified.",
        "- These statistics describe agreement on this pilot set. They are **not** a claim of production accuracy or successful scientific validation of EfficientNet-B0.",
        "",
        "## Data quality",
        "",
        f"- Human rows loaded: {dq['n_rows']}",
        f"- Raters present: {', '.join(dq['raters_present'])}",
        f"- Validation errors: {dq['n_errors']}",
        f"- Validation warnings (including explicit missing cells): {dq['n_warnings']}",
        f"- OK to analyze: {dq['ok_to_analyze']}",
        "",
    ]
    missing = [i for i in dq["issues"] if i.get("issue") == "missing_score"]
    if missing:
        lines.append("### Explicit missing human cells")
        lines.append("")
        lines.append("| Rater | Media | Criterion |")
        lines.append("|---|---|---|")
        for item in missing:
            lines.append(f"| {item['rater_id']} | {item['media_id']} | {item['criterion']} |")
        lines.append("")
        lines.append("Missing cells were excluded from pairwise IRR and from medians for that rater only.")
        lines.append("")

    lines.extend(
        [
            "## Inter-rater reliability",
            "",
            "Pairwise exact and within-one rates average the three rater pairs. "
            "Fleiss' kappa uses ordinal categories 1–5 with missing cells omitted as documented in the JSON.",
            "",
            "| Criterion | Missing cells | Mean exact | Mean within-1 | Mean QWK | Fleiss κ |",
            "|---|---:|---:|---:|---:|---:|",
        ]
    )
    for col in TECH_CSV_COLS + ("overall_visual_quality",):
        block = irr[col]
        lines.append(
            "| {c} | {m} | {e} | {w} | {q} | {f} |".format(
                c=col,
                m=block["n_missing_cells"],
                e=_fmt(block["mean_pairwise_exact_agreement"]),
                w=_fmt(block["mean_pairwise_within_one_agreement"]),
                q=_fmt(block["mean_pairwise_quadratic_weighted_kappa"]),
                f=_fmt(block["fleiss_kappa"]),
            )
        )
    lines.extend(
        [
            "",
            "## Human consensus vs machine (seven criteria)",
            "",
            "Human reference = median of available R1/R2/R3 integers. "
            "Machine values are Run 002 criterion integers. Bias = machine − human.",
            "",
            "| Criterion | n | MAE | RMSE | Bias | Spearman r | Within-1 |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for name in PHOTO_CRITERIA:
        block = crit[name]
        lines.append(
            "| {c} | {n} | {mae} | {rmse} | {bias} | {sp} | {w} |".format(
                c=name,
                n=block["n_paired"],
                mae=_fmt(block["mae"]),
                rmse=_fmt(block["rmse"]),
                bias=_fmt(block["bias_machine_minus_human"]),
                sp=_fmt(block["spearman_r"]),
                w=_fmt(block["abs_error_le_1_rate"]),
            )
        )
    lines.extend(
        [
            "",
            "## Overall construct comparison (separate)",
            "",
            overall["construct_note"],
            "",
            f"- n_paired: {overall['n_paired']}",
            f"- MAE: {_fmt(overall['mae'])}",
            f"- RMSE: {_fmt(overall['rmse'])}",
            f"- Bias (machine − human): {_fmt(overall['bias_machine_minus_human'])}",
            f"- Spearman r: {_fmt(overall['spearman_r'])} (p={_fmt(overall['spearman_p'], 4)})",
            f"- Within-1 rate: {_fmt(overall['abs_error_le_1_rate'])}",
            f"- KonIQ MOS used as criterion GT: {overall['koniq_mos_used_as_criterion_gt']}",
            "",
            "## Limitations",
            "",
        ]
    )
    for note in payload["limitations"]:
        lines.append(f"- {note}")
    lines.extend(
        [
            "",
            "## Interpretation guardrails",
            "",
            "- Do not treat within-1 rate as model accuracy percentage.",
            "- Do not retrain, retune `_soft_score`, or change production weights from this pilot alone.",
            "- Low Spearman with low variance in machine badges can reflect restricted range, not necessarily rubric failure.",
            "",
            "## Generated artifacts",
            "",
        ]
    )
    for rel in payload["artifacts"]:
        lines.append(f"- `{rel}`")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def run(
    *,
    ratings_dir: Path,
    manifest_path: Path,
    machine_json: Path,
    per_image_csv: Path,
    output_root: Path,
) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = output_root / f"pilot_hvsm_{stamp}"
    if out_dir.exists():
        raise FileExistsError(f"Refusing to overwrite existing directory: {out_dir}")
    out_dir.mkdir(parents=True, exist_ok=False)

    rating_paths = discover_rating_csvs(ratings_dir)
    all_rows: list[dict[str, Any]] = []
    for path in rating_paths:
        all_rows.extend(load_rating_file(path))

    data_quality = validate_human_rows(all_rows)
    _write_csv(out_dir / "data_quality_issues.csv", data_quality["issues"])
    if not data_quality["ok_to_analyze"]:
        (out_dir / "STOP.json").write_text(json.dumps(data_quality, indent=2), encoding="utf-8")
        raise SystemExit(
            f"STOP: validation errors={data_quality['n_errors']}. See {out_dir / 'data_quality_issues.csv'}"
        )

    manifest = load_facilitator_manifest(manifest_path)
    machine_by_koniq = load_run002_machine(machine_json=machine_json, per_image_csv=per_image_csv)

    # Confirm join coverage before metrics.
    missing_machine = []
    for mid in EXPECTED_PILOT_IDS:
        kid = manifest[mid]["koniq2_media_id"]
        if kid not in machine_by_koniq:
            missing_machine.append({"media_id": mid, "koniq2_media_id": kid})
    if missing_machine:
        _write_csv(out_dir / "missing_machine_scores.csv", missing_machine)
        raise SystemExit(f"STOP: {len(missing_machine)} pilot images lack Run 002 machine scores.")

    consensus = build_consensus(all_rows)

    # Combined human long table (copy for analysis; originals untouched).
    human_long = []
    for row in all_rows:
        flat = {
            "media_id": row["media_id"],
            "rater_id": row["rater_id"],
            "media_type": row["media_type"],
            "source_file": row["source_file"],
            "notes": row["notes"],
        }
        for col in TECH_CSV_COLS + ("overall_visual_quality",):
            flat[col] = "" if row["scores"][col] is None else int(row["scores"][col])
        human_long.append(flat)
    _write_csv(
        out_dir / "human_ratings_combined.csv",
        human_long,
        [
            "media_id",
            "rater_id",
            "media_type",
            *TECH_CSV_COLS,
            "overall_visual_quality",
            "notes",
            "source_file",
        ],
    )

    consensus_rows = []
    for mid in EXPECTED_PILOT_IDS:
        block = consensus[mid]
        fac = manifest[mid]
        row = {
            "media_id": mid,
            "koniq2_media_id": fac["koniq2_media_id"],
            "source_media_key": fac["source_media_key"],
            "stratum_label": fac["stratum_label"],
            "n_raters_present": block["n_raters_present"],
        }
        for col in TECH_CSV_COLS:
            tech = block["technical"][col]
            row[f"{col}_R1"] = tech["R1"] if tech["R1"] is not None else ""
            row[f"{col}_R2"] = tech["R2"] if tech["R2"] is not None else ""
            row[f"{col}_R3"] = tech["R3"] if tech["R3"] is not None else ""
            row[f"{col}_n"] = tech["n_available"]
            row[f"{col}_median"] = tech["median"] if tech["median"] is not None else ""
        ov = block["overall_visual_quality"]
        row["overall_visual_quality_R1"] = ov["R1"] if ov["R1"] is not None else ""
        row["overall_visual_quality_R2"] = ov["R2"] if ov["R2"] is not None else ""
        row["overall_visual_quality_R3"] = ov["R3"] if ov["R3"] is not None else ""
        row["overall_visual_quality_n"] = ov["n_available"]
        row["overall_visual_quality_median"] = ov["median"] if ov["median"] is not None else ""
        consensus_rows.append(row)
    _write_csv(out_dir / "human_consensus_by_image.csv", consensus_rows)

    machine_joined = []
    for mid in EXPECTED_PILOT_IDS:
        fac = manifest[mid]
        kid = fac["koniq2_media_id"]
        m = machine_by_koniq[kid]
        row = {
            "media_id": mid,
            "koniq2_media_id": kid,
            "source_media_key": fac["source_media_key"],
            "stratum_label": fac["stratum_label"],
            "analysis_status": m.get("analysis_status"),
            "quality_engine": m.get("quality_engine"),
            "opencv_fallback": m.get("opencv_fallback"),
            "overall_score": m.get("overall_score"),
            "mos_quality_raw_not_used_as_criterion_gt": m.get("mos_quality_raw", fac.get("mos_quality_raw", "")),
            "machine_source": m.get("source"),
        }
        for name, col in CRITERION_TO_CSV.items():
            val = (m.get("criterion_scores") or {}).get(name)
            row[col] = val if val is not None else ""
        machine_joined.append(row)
    _write_csv(out_dir / "machine_scores_joined.csv", machine_joined)

    irr = {col: inter_rater_for_criterion(all_rows, col) for col in TECH_CSV_COLS + ("overall_visual_quality",)}
    irr_rows = []
    for col, block in irr.items():
        base = {
            "criterion": col,
            "n_items": block["n_items"],
            "n_missing_cells": block["n_missing_cells"],
            "fleiss_kappa": block["fleiss_kappa"],
            "mean_pairwise_exact_agreement": block["mean_pairwise_exact_agreement"],
            "mean_pairwise_within_one_agreement": block["mean_pairwise_within_one_agreement"],
            "mean_pairwise_quadratic_weighted_kappa": block["mean_pairwise_quadratic_weighted_kappa"],
        }
        for pair_name, pair in block["pairwise"].items():
            base[f"{pair_name}_n"] = pair["n_paired"]
            base[f"{pair_name}_exact"] = pair["exact_agreement_rate"]
            base[f"{pair_name}_within_one"] = pair["within_one_agreement_rate"]
            base[f"{pair_name}_qwk"] = pair["quadratic_weighted_kappa"]
        irr_rows.append(base)
    _write_csv(out_dir / "inter_rater_agreement.csv", irr_rows)

    per_image, criterion_summary, overall_bundle = compare_machine_human(
        consensus=consensus,
        manifest=manifest,
        machine_by_koniq=machine_by_koniq,
    )
    _write_csv(out_dir / "per_image_human_vs_machine.csv", per_image)
    crit_rows = [criterion_summary[name] for name in PHOTO_CRITERIA]
    _write_csv(out_dir / "criterion_comparison_summary.csv", crit_rows)
    _write_csv(out_dir / "overall_construct_comparison.csv", [overall_bundle["overall"]])
    if overall_bundle["join_issues"]:
        _write_csv(out_dir / "join_issues.csv", overall_bundle["join_issues"])

    limitations = [
        "n=30 photos and 3 raters; confidence intervals are wide and not claimed here.",
        "Several human cells are intentionally blank; medians use only available ratings.",
        "Machine criterion badges on this pilot show restricted range (often 3–5 only), which can depress Spearman.",
        "Human overall_visual_quality and machine overall_score are different constructs.",
        "KonIQ published MOS is overall-only and was not used as criterion ground truth.",
        "This pilot does not authorize production threshold/weight changes.",
        "Results are descriptive for ACCESS documentation quality on this set, not a general IQA leaderboard claim.",
    ]

    artifacts = [
        "data_quality_issues.csv",
        "human_ratings_combined.csv",
        "human_consensus_by_image.csv",
        "machine_scores_joined.csv",
        "inter_rater_agreement.csv",
        "per_image_human_vs_machine.csv",
        "criterion_comparison_summary.csv",
        "overall_construct_comparison.csv",
        "analysis_report.json",
        "HUMAN_VS_MACHINE_PILOT_REPORT.md",
    ]

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "output_dir": str(out_dir),
        "inputs": {
            "rating_files": [str(p) for p in rating_paths],
            "facilitator_manifest": str(manifest_path),
            "machine_json": str(machine_json),
            "per_image_csv": str(per_image_csv),
            "inference_rerun": False,
        },
        "data_quality": data_quality,
        "inter_rater": irr,
        "criterion_comparison": criterion_summary,
        "overall_comparison": overall_bundle,
        "limitations": limitations,
        "artifacts": artifacts,
        "disclaimer": (
            "These statistics describe agreement with available human labels on the pilot set. "
            "They are not a scientific validation of EfficientNet-B0 and do not claim production accuracy."
        ),
    }
    (out_dir / "analysis_report.json").write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    write_markdown_report(out_dir / "HUMAN_VS_MACHINE_PILOT_REPORT.md", payload)
    return out_dir


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ratings-dir", type=Path, default=DEFAULT_RATINGS_DIR)
    parser.add_argument("--facilitator-manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--machine-json", type=Path, default=DEFAULT_MACHINE_JSON)
    parser.add_argument("--per-image-csv", type=Path, default=DEFAULT_PER_IMAGE)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    args = parser.parse_args(argv)

    forbidden = [
        _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "run_002" / "output",
        _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "metadata" / "output" / "run_001",
    ]
    out_root = args.output_root.resolve()
    for path in forbidden:
        if out_root == path.resolve() or path.resolve() in out_root.parents:
            raise SystemExit(f"Refusing to write under Run 001/002 output: {out_root}")

    out_dir = run(
        ratings_dir=args.ratings_dir.resolve(),
        manifest_path=args.facilitator_manifest.resolve(),
        machine_json=args.machine_json.resolve(),
        per_image_csv=args.per_image_csv.resolve(),
        output_root=out_root,
    )
    print(json.dumps({"status": "ok", "output_dir": str(out_dir)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
