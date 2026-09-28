"""
Step 7: Held-out validation on Desktop/fresh_validation (no production changes).

Usage:
  cd access_backend
  python scripts/validate_univfd_step7.py
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import platform
import statistics
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.services.ai_authenticity_detector import (  # noqa: E402
    AI_GENERATED_THRESHOLD,
    SUSPICIOUS_THRESHOLD,
    _filename_ai_hint_score,
    _metadata_score,
    detect_ai_generated,
)
from app.services.dedicated_ai_detector import (  # noqa: E402
    clip_backbone_path,
    dedicated_ai_probability,
    weights_path,
)

# Step 6 frozen configuration implementations (authoritative)
_step6_path = ROOT / "scripts" / "experiment_univfd_step6.py"
_spec = importlib.util.spec_from_file_location("experiment_univfd_step6", _step6_path)
step6 = importlib.util.module_from_spec(_spec)
sys.modules["experiment_univfd_step6"] = step6
assert _spec.loader is not None
_spec.loader.exec_module(step6)

FROZEN_CONFIGS = ("B_production_fusion", "E_no_post_boosts", "D1_heuristic_075")

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}
DEFAULT_DATASET = Path.home() / "Desktop" / "fresh_validation"

SOURCE_GT: dict[tuple[str, str], tuple[str, str]] = {
    ("ai", "chatgpt"): ("AI", "chatgpt"),
    ("ai", "gemini"): ("AI", "gemini"),
    ("ai", "canva"): ("AI", "canva"),
    ("ai", "pixlr"): ("AI", "pixlr"),
    ("real", "own_new_photos"): ("REAL", "own_new_photos"),
    ("real", "verified_external"): ("REAL", "verified_external"),
}


@dataclass
class SampleRow:
    filepath: Path
    filename: str
    ground_truth: str
    source: str
    sha256: str = ""
    status: str = "ok"
    exclude_reason: str = ""
    raw_univfd: float | None = None
    prod_probability: float | None = None
    prod_verdict: str = ""
    prod_confidence: float | None = None
    signals: dict[str, float] = field(default_factory=dict)
    combined_meta: float = 0.0
    error: str = ""
    b_offline: float | None = None
    e_prob: float | None = None
    d1_prob: float | None = None
    b_verdict: str = ""
    e_verdict: str = ""
    d1_verdict: str = ""
    is_primary: bool = True
    duplicate_of: str = ""


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def checkpoint_sha256(path: Path) -> str:
    if not path.is_file():
        return "MISSING"
    return file_sha256(path)


def _latest_run(base: Path) -> Path | None:
    if not base.is_dir():
        return None
    runs = [p for p in base.iterdir() if p.is_dir()]
    return max(runs, key=lambda p: p.stat().st_mtime) if runs else None


def load_prior_hashes(step6_run: Path | None, step4_run: Path | None) -> set[str]:
    prior: set[str] = set()
    if step6_run:
        dedup = step6_run / "step6_deduplication_map.csv"
        if dedup.is_file():
            with dedup.open(newline="", encoding="utf-8") as f:
                for row in csv.DictReader(f):
                    if row.get("sha256"):
                        prior.add(row["sha256"])
    if step4_run:
        csv_path = step4_run / "univfd_step4_results.csv"
        if csv_path.is_file():
            with csv_path.open(newline="", encoding="utf-8") as f:
                for row in csv.DictReader(f):
                    fp = Path(row.get("filepath", ""))
                    if fp.is_file():
                        try:
                            prior.add(file_sha256(fp))
                        except OSError:
                            pass
    return prior


def discover_dataset(root: Path) -> tuple[list[SampleRow], list[dict[str, Any]]]:
    inventory: list[SampleRow] = []
    unsupported: list[dict[str, Any]] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        ext = path.suffix.lower()
        if ext not in IMAGE_EXTS:
            unsupported.append({"filepath": str(path), "reason": "unsupported_extension"})
            continue
        rel = path.relative_to(root)
        if len(rel.parts) < 3:
            unsupported.append({"filepath": str(path), "reason": "unexpected_path_depth"})
            continue
        key = (rel.parts[0].lower(), rel.parts[1].lower())
        if key not in SOURCE_GT:
            unsupported.append({"filepath": str(path), "reason": f"unknown_folder_{key}"})
            continue
        gt, source = SOURCE_GT[key]
        inventory.append(
            SampleRow(
                filepath=path,
                filename=path.name,
                ground_truth=gt,
                source=source,
            )
        )
    return inventory, unsupported


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow(row)


def dist_stats(values: list[float]) -> dict[str, float | None]:
    if not values:
        return {"mean": None, "median": None, "min": None, "max": None}
    return {
        "mean": statistics.mean(values),
        "median": statistics.median(values),
        "min": min(values),
        "max": max(values),
    }


def verdict_counts(verdicts: list[str]) -> dict[str, int]:
    return {
        "authentic": sum(1 for v in verdicts if v == "authentic"),
        "suspicious": sum(1 for v in verdicts if v == "suspicious"),
        "ai_generated": sum(1 for v in verdicts if v == "ai_generated"),
    }


def eval_metrics(records: list[SampleRow], prob_key: str, verdict_key: str) -> dict[str, Any]:
    y_true = [1 if r.ground_truth == "AI" else 0 for r in records]
    verdicts = [getattr(r, verdict_key) for r in records]
    strict = step6.binary_metrics(y_true, [step6.strict_pred(v) for v in verdicts])
    flagged = step6.binary_metrics(y_true, [step6.flagged_pred(v) for v in verdicts])
    return {"strict": strict, "flagged": flagged}


def prob_for_config(config_id: str, signals: dict[str, float], combined_meta: float) -> float:
    step6.register_configs()
    _, fn = step6.CONFIG_BUILDERS[config_id]
    return float(fn(signals, combined_meta))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--step6-dir", type=Path, default=None)
    args = parser.parse_args()

    dataset_root = args.dataset.resolve()
    if not dataset_root.is_dir():
        raise SystemExit(f"Dataset not found: {dataset_root}")

    step6_dir = args.step6_dir or _latest_run(ROOT / "evaluation_results" / "step6")
    step4_dir = _latest_run(ROOT / "evaluation_results" / "step4")
    prior_hashes = load_prior_hashes(step6_dir, step4_dir)

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = ROOT / "evaluation_results" / "step7" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)

    inventory, unsupported = discover_dataset(dataset_root)
    per_source = defaultdict(int)
    for row in inventory:
        per_source[row.source] += 1

    # Hash and duplicate handling
    dup_rows: list[dict[str, Any]] = []
    by_hash: dict[str, list[SampleRow]] = defaultdict(list)
    for row in inventory:
        try:
            row.sha256 = file_sha256(row.filepath)
        except OSError as exc:
            row.status = "unreadable"
            row.error = str(exc)
            continue
        by_hash[row.sha256].append(row)

    label_conflicts: list[dict[str, Any]] = []
    for digest, group in by_hash.items():
        gts = {g.ground_truth for g in group}
        if len(gts) > 1:
            label_conflicts.append(
                {"sha256": digest, "ground_truths": sorted(gts), "paths": [str(g.filepath) for g in group]}
            )
            for g in group:
                g.is_primary = False
                g.exclude_reason = "LABEL_CONFLICT"
            continue
        canonical = group[0]
        for g in group:
            if g is not canonical:
                g.is_primary = False
                g.duplicate_of = str(canonical.filepath)
                dup_rows.append(
                    {
                        "sha256": digest,
                        "filepath": str(g.filepath),
                        "canonical": str(canonical.filepath),
                        "kind": "internal_duplicate",
                    }
                )
        if digest in prior_hashes:
            for g in group:
                g.is_primary = False
                g.exclude_reason = "PRIOR_DATASET_DUPLICATE"
                dup_rows.append(
                    {
                        "sha256": digest,
                        "filepath": str(g.filepath),
                        "canonical": str(canonical.filepath),
                        "kind": "prior_benchmark_duplicate",
                    }
                )

    primary = [r for r in inventory if r.is_primary and r.status == "ok" and not r.exclude_reason]

    write_csv(
        out_dir / "step7_dataset_inventory.csv",
        [
            {
                "filepath": str(r.filepath),
                "filename": r.filename,
                "ground_truth": r.ground_truth,
                "source": r.source,
                "sha256": r.sha256,
                "status": r.status,
                "is_primary": r.is_primary,
                "exclude_reason": r.exclude_reason,
            }
            for r in inventory
        ]
        + [{"filepath": u["filepath"], "status": "unsupported", "exclude_reason": u["reason"]} for u in unsupported],
        ["filepath", "filename", "ground_truth", "source", "sha256", "status", "is_primary", "exclude_reason"],
    )
    write_csv(
        out_dir / "step7_duplicate_check.csv",
        dup_rows + [{"sha256": c["sha256"], "kind": "label_conflict", **c} for c in label_conflicts],
        ["sha256", "filepath", "canonical", "kind", "ground_truths", "paths"],
    )

    step6.register_configs()
    repro_diffs: list[float] = []
    verdict_mismatch = 0
    repro_compared = 0
    blocked = False

    for row in inventory:
        if row.status != "ok":
            continue
        try:
            content = row.filepath.read_bytes()
        except OSError as exc:
            row.status = "unreadable"
            row.error = str(exc)
            continue
        try:
            row.raw_univfd = dedicated_ai_probability(content)
        except Exception as exc:
            row.error = f"raw: {exc}"
        try:
            det = detect_ai_generated(content, file_name=row.filename)
            row.prod_probability = float(det.get("probability", 0))
            row.prod_verdict = str(det.get("verdict", ""))
            row.prod_confidence = float(det.get("confidence", 0))
            row.signals = {k: float(v) for k, v in (det.get("signals") or {}).items()}
            fn_score, _ = _filename_ai_hint_score(row.filename)
            meta_score, _ = _metadata_score(content, row.filename)
            row.combined_meta = max(meta_score, fn_score)
            row.b_offline = prob_for_config("B_production_fusion", row.signals, row.combined_meta)
            row.e_prob = prob_for_config("E_no_post_boosts", row.signals, row.combined_meta)
            row.d1_prob = prob_for_config("D1_heuristic_075", row.signals, row.combined_meta)
            row.b_verdict = step6.verdict_from_prob(row.b_offline)
            row.e_verdict = step6.verdict_from_prob(row.e_prob)
            row.d1_verdict = step6.verdict_from_prob(row.d1_prob)
        except Exception as exc:
            row.error = (row.error + "; " if row.error else "") + f"detect: {exc}"
            continue

        if row.prod_probability is not None and row.b_offline is not None:
            repro_compared += 1
            diff = abs(round(row.b_offline, 3) - round(row.prod_probability, 3))
            repro_diffs.append(diff)
            if row.b_verdict != row.prod_verdict:
                verdict_mismatch += 1

    max_repro_diff = max(repro_diffs) if repro_diffs else None
    if max_repro_diff is not None and max_repro_diff > 0.02:
        blocked = True

    primary_ok = [r for r in primary if r.raw_univfd is not None and r.b_offline is not None]

    result_rows: list[dict[str, Any]] = []
    for r in inventory:
        result_rows.append(
            {
                "filepath": str(r.filepath),
                "filename": r.filename,
                "ground_truth": r.ground_truth,
                "source": r.source,
                "sha256": r.sha256,
                "is_primary": r.is_primary,
                "exclude_reason": r.exclude_reason,
                "raw_univfd_probability": r.raw_univfd,
                "prod_probability": r.prod_probability,
                "prod_verdict": r.prod_verdict,
                "B_probability": r.b_offline,
                "B_verdict": r.b_verdict,
                "E_probability": r.e_prob,
                "E_verdict": r.e_verdict,
                "D1_probability": r.d1_prob,
                "D1_verdict": r.d1_verdict,
                "signals_json": json.dumps(r.signals),
                "error": r.error,
            }
        )
    write_csv(out_dir / "step7_results.csv", result_rows, list(result_rows[0].keys()) if result_rows else ["filepath"])

    def metrics_for_config(prob_attr: str, verdict_attr: str) -> dict[str, Any] | None:
        if blocked:
            return None
        return eval_metrics(primary_ok, prob_attr, verdict_attr)

    b_metrics = metrics_for_config("b_offline", "b_verdict") if not blocked else None
    e_metrics = metrics_for_config("e_prob", "e_verdict") if not blocked else None
    d1_metrics = metrics_for_config("d1_prob", "d1_verdict") if not blocked else None

    y_true = [1 if r.ground_truth == "AI" else 0 for r in primary_ok]
    raw_scores = [float(r.raw_univfd) for r in primary_ok if r.raw_univfd is not None]
    raw_auc = step6.roc_auc(raw_scores, y_true) if len(set(y_true)) == 2 else None
    real_raw = [float(r.raw_univfd) for r in primary_ok if r.ground_truth == "REAL" and r.raw_univfd is not None]
    ai_raw = [float(r.raw_univfd) for r in primary_ok if r.ground_truth == "AI" and r.raw_univfd is not None]

    comparison_rows: list[dict[str, Any]] = []
    for cfg_id, metrics, label in (
        ("A_raw_univfd", None, "Raw UnivFD P(fake); binary metrics N/A"),
        ("B_production_fusion", b_metrics, step6.CONFIG_BUILDERS["B_production_fusion"][0]),
        ("E_no_post_boosts", e_metrics, step6.CONFIG_BUILDERS["E_no_post_boosts"][0]),
        ("D1_heuristic_075", d1_metrics, step6.CONFIG_BUILDERS["D1_heuristic_075"][0]),
    ):
        row: dict[str, Any] = {
            "configuration": cfg_id,
            "description": label,
            "heldout_n": len(primary_ok),
            "real_n": sum(1 for r in primary_ok if r.ground_truth == "REAL"),
            "ai_n": sum(1 for r in primary_ok if r.ground_truth == "AI"),
        }
        if cfg_id == "A_raw_univfd":
            row["ROC_AUC"] = raw_auc
        elif metrics:
            for prefix, m in (("strict", metrics["strict"]), ("flagged", metrics["flagged"])):
                for k, v in m.items():
                    row[f"{prefix}_{k}"] = v
        comparison_rows.append(row)
    write_csv(
        out_dir / "step7_configuration_comparison.csv",
        comparison_rows,
        sorted({k for r in comparison_rows for k in r.keys()}),
    )

    def subset_report(source: str, prob_attr: str, verdict_attr: str) -> dict[str, Any]:
        sub = [r for r in primary_ok if r.source == source]
        raw = [float(r.raw_univfd) for r in sub if r.raw_univfd is not None]
        probs = [float(getattr(r, prob_attr)) for r in sub if getattr(r, prob_attr) is not None]
        verdicts = [getattr(r, verdict_attr) for r in sub]
        vc = verdict_counts(verdicts)
        return {
            "source": source,
            "n": len(sub),
            "raw": dist_stats(raw),
            **{f"{prob_attr}_stats": dist_stats(probs)},
            **vc,
            "strict_ai_generated_REAL": sum(
                1 for r in sub if r.ground_truth == "REAL" and getattr(r, verdict_attr) == "ai_generated"
            ),
            "flagged_REAL": sum(
                1
                for r in sub
                if r.ground_truth == "REAL" and getattr(r, verdict_attr) in ("suspicious", "ai_generated")
            ),
        }

    own_rows = []
    for cfg, pa, va in (("B", "b_offline", "b_verdict"), ("E", "e_prob", "e_verdict"), ("D1", "d1_prob", "d1_verdict")):
        rep = subset_report("own_new_photos", pa, va)
        rep["configuration"] = cfg
        own_rows.append(rep)
    write_csv(out_dir / "step7_own_photos.csv", own_rows, sorted({k for r in own_rows for k in r.keys()}))

    ext_rows = []
    for cfg, pa, va in (("B", "b_offline", "b_verdict"), ("E", "e_prob", "e_verdict"), ("D1", "d1_prob", "d1_verdict")):
        rep = subset_report("verified_external", pa, va)
        rep["configuration"] = cfg
        ext_rows.append(rep)
    write_csv(out_dir / "step7_verified_external.csv", ext_rows, sorted({k for r in ext_rows for k in r.keys()}))

    gen_rows: list[dict[str, Any]] = []
    for gen in ("chatgpt", "gemini", "canva", "pixlr"):
        sub = [r for r in primary_ok if r.source == gen]
        raw = [float(r.raw_univfd) for r in sub if r.raw_univfd is not None]
        entry: dict[str, Any] = {"generator": gen, "n": len(sub), "raw_univfd": dist_stats(raw)}
        for cfg, _pa, va in (("B", "b_offline", "b_verdict"), ("E", "e_prob", "e_verdict"), ("D1", "d1_prob", "d1_verdict")):
            verdicts = [getattr(r, va) for r in sub]
            vc = verdict_counts(verdicts)
            entry[f"{cfg}_authentic"] = vc["authentic"]
            entry[f"{cfg}_suspicious"] = vc["suspicious"]
            entry[f"{cfg}_ai_generated"] = vc["ai_generated"]
            entry[f"{cfg}_strict_detected"] = vc["ai_generated"]
            entry[f"{cfg}_flagged"] = sum(1 for v in verdicts if v in ("suspicious", "ai_generated"))
        gen_rows.append(entry)
    write_csv(
        out_dir / "step7_generator_breakdown.csv",
        gen_rows,
        sorted({k for r in gen_rows for k in r.keys()}),
    )

    # Error cases
    error_cases: list[dict[str, Any]] = []

    def add_ranked(title: str, records: list[SampleRow], sort_key, reverse: bool, limit: int = 15):
        ranked = sorted(records, key=sort_key, reverse=reverse)[:limit]
        for i, r in enumerate(ranked, 1):
            error_cases.append(
                {
                    "list": title,
                    "rank": i,
                    "filepath": str(r.filepath),
                    "source": r.source,
                    "ground_truth": r.ground_truth,
                    "raw": r.raw_univfd,
                    "B_prob": r.b_offline,
                    "B_verdict": r.b_verdict,
                    "E_prob": r.e_prob,
                    "E_verdict": r.e_verdict,
                    "D1_prob": r.d1_prob,
                    "D1_verdict": r.d1_verdict,
                }
            )

    real_p = [r for r in primary_ok if r.ground_truth == "REAL"]
    ai_p = [r for r in primary_ok if r.ground_truth == "AI"]
    add_ranked("REAL_highest_raw", real_p, lambda r: r.raw_univfd or -1, True)
    add_ranked("REAL_highest_B", real_p, lambda r: r.b_offline or -1, True)
    add_ranked("REAL_highest_E", real_p, lambda r: r.e_prob or -1, True)
    add_ranked("REAL_highest_D1", real_p, lambda r: r.d1_prob or -1, True)
    add_ranked("AI_lowest_raw", ai_p, lambda r: r.raw_univfd if r.raw_univfd is not None else 2, False)
    add_ranked("AI_lowest_B", ai_p, lambda r: r.b_offline if r.b_offline is not None else 2, False)
    add_ranked("AI_lowest_E", ai_p, lambda r: r.e_prob if r.e_prob is not None else 2, False)
    add_ranked("AI_lowest_D1", ai_p, lambda r: r.d1_prob if r.d1_prob is not None else 2, False)

    for r in primary_ok:
        if r.ground_truth == "REAL" and r.b_verdict == "ai_generated":
            error_cases.append({"list": "STRICT_FP_B", **{"filepath": str(r.filepath), "source": r.source, "raw": r.raw_univfd, "B_prob": r.b_offline, "B_verdict": r.b_verdict, "E_prob": r.e_prob, "D1_prob": r.d1_prob}})
        if r.ground_truth == "AI" and r.b_verdict != "ai_generated":
            error_cases.append({"list": "STRICT_FN_B", **{"filepath": str(r.filepath), "source": r.source, "raw": r.raw_univfd, "B_prob": r.b_offline, "B_verdict": r.b_verdict}})
        if r.ground_truth == "REAL" and r.b_verdict in ("suspicious", "ai_generated"):
            error_cases.append({"list": "FLAGGED_FP_B", **{"filepath": str(r.filepath), "source": r.source, "B_verdict": r.b_verdict, "B_prob": r.b_offline}})
        if r.ground_truth == "AI" and r.b_verdict == "authentic":
            error_cases.append({"list": "FLAGGED_FN_B", **{"filepath": str(r.filepath), "source": r.source, "B_verdict": r.b_verdict, "B_prob": r.b_offline}})
    write_csv(out_dir / "step7_error_cases.csv", error_cases, sorted({k for r in error_cases for k in r.keys()}))

    # Step 6 comparison
    step6_summary_path = (step6_dir / "step6_summary.json") if step6_dir else None
    step6_data = json.loads(step6_summary_path.read_text(encoding="utf-8")) if step6_summary_path and step6_summary_path.is_file() else {}
    s6_cmp_rows: list[dict[str, Any]] = []
    for cfg_key, step7_key, prob_attr, verdict_attr in (
        ("B_production_fusion", "B", "b_offline", "b_verdict"),
        ("E_no_post_boosts", "E", "e_prob", "e_verdict"),
        ("D1_heuristic_075", "D1", "d1_prob", "d1_verdict"),
    ):
        s6_cfg = step6_data.get("experimental_configurations", {}).get(cfg_key, {})
        s7m = metrics_for_config(prob_attr, verdict_attr) if not blocked else None
        for mode in ("strict", "flagged"):
            s6m = s6_cfg.get(mode, {})
            row = {
                "configuration": cfg_key,
                "mode": mode,
                "step6_recall": s6m.get("recall"),
                "step6_REAL_FP": s6m.get("FP"),
                "step6_REAL_FPR": s6m.get("false_positive_rate"),
            }
            if s7m:
                s7part = s7m[mode]
                row.update(
                    {
                        "step7_recall": s7part.get("recall"),
                        "step7_REAL_FP": s7part.get("FP"),
                        "step7_REAL_FPR": s7part.get("false_positive_rate"),
                    }
                )
                for metric in ("recall", "REAL_FPR"):
                    a = row.get(f"step6_{metric}")
                    b = row.get(f"step7_{metric}")
                    if a is not None and b is not None:
                        if abs(b - a) < 0.05:
                            row[f"{metric}_vs_step6"] = "similar"
                        elif b > a:
                            row[f"{metric}_vs_step6"] = "increased"
                        else:
                            row[f"{metric}_vs_step6"] = "decreased"
            s6_cmp_rows.append(row)
    write_csv(out_dir / "step7_step6_comparison.csv", s6_cmp_rows, sorted({k for r in s6_cmp_rows for k in r.keys()}))

    try:
        import torch

        device = str(torch.device("cuda" if torch.cuda.is_available() else "cpu"))
    except ImportError:
        device = "cpu (torch import unavailable)"

    fc_path = Path(weights_path())
    clip_path = Path(clip_backbone_path())

    summary = {
        "step7_status": "BLOCKED" if blocked else "COMPLETE",
        "timestamp": stamp,
        "python_version": platform.python_version(),
        "device": device,
        "dataset_root": str(dataset_root),
        "discovered_images": len(inventory),
        "unsupported_files": len(unsupported),
        "unreadable": sum(1 for r in inventory if r.status == "unreadable"),
        "per_source_counts": dict(per_source),
        "holdout_integrity": {
            "internal_duplicate_paths": len([d for d in dup_rows if d.get("kind") == "internal_duplicate"]),
            "prior_benchmark_duplicates": len([d for d in dup_rows if d.get("kind") == "prior_benchmark_duplicate"]),
            "label_conflicts": len(label_conflicts),
            "primary_heldout_n": len(primary_ok),
        },
        "model": {
            "architecture": "CLIP ViT-L/14 + UnivFD fc_weights.pth",
            "classifier_checkpoint": str(fc_path),
            "clip_checkpoint": str(clip_path),
            "classifier_sha256": checkpoint_sha256(fc_path),
            "clip_sha256": checkpoint_sha256(clip_path),
        },
        "production_thresholds": {
            "SUSPICIOUS_THRESHOLD": SUSPICIOUS_THRESHOLD,
            "AI_GENERATED_THRESHOLD": AI_GENERATED_THRESHOLD,
        },
        "step6_config_source": str(_step6_path),
        "step6_run_comparison": str(step6_dir) if step6_dir else None,
        "fusion_reproduction": {
            "rows_compared": repro_compared,
            "max_probability_difference": max_repro_diff,
            "verdict_mismatches": verdict_mismatch,
        },
        "raw_univfd_primary": {
            "ROC_AUC": raw_auc,
            "REAL": dist_stats(real_raw),
            "AI": dist_stats(ai_raw),
        },
        "configurations": {
            "B": b_metrics,
            "E": e_metrics,
            "D1": d1_metrics,
        },
        "production_behavior_changed": False,
        "no_tuning_on_step7": True,
    }
    (out_dir / "step7_summary.json").write_text(json.dumps(summary, indent=2, default=str), encoding="utf-8")

    status = "BLOCKED" if blocked else "COMPLETE"
    report = [
        f"STEP 7 STATUS: {status}",
        f"Dataset: {dataset_root}",
        f"Discovered: {len(inventory)} primary held-out: {len(primary_ok)}",
        f"Fusion repro max_diff={max_repro_diff} verdict_mismatch={verdict_mismatch}",
        f"Raw ROC-AUC={raw_auc}",
        "PRODUCTION BEHAVIOR CHANGED: NO",
        f"Output: {out_dir}",
    ]
    (out_dir / "step7_report.txt").write_text("\n".join(report), encoding="utf-8")
    print("\n".join(report))


if __name__ == "__main__":
    main()
