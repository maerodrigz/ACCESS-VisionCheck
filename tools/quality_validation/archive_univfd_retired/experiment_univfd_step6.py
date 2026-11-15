"""
Step 6: Deduplicated offline UnivFD / fusion experiment (does not modify production).

Usage:
  cd access_backend
  python scripts/experiment_univfd_step6.py
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import statistics
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.services.ai_authenticity_detector import (  # noqa: E402
    AI_GENERATED_THRESHOLD,
    SUSPICIOUS_THRESHOLD,
    _filename_ai_hint_score,
    _fuse_probability,
    _metadata_score,
    _verdict_from_probability,
    detect_ai_generated,
)

PROD_OPENCV_WEIGHTS = {
    "frequency": 0.18,
    "noise_uniformity": 0.16,
    "texture_entropy": 0.12,
    "quality_paradox": 0.18,
    "skin_smoothness": 0.16,
}
PROD_NEURAL_WEIGHT = 0.28
PROD_META_WEIGHT = 0.28
PROD_FILENAME_WEIGHT = 0.30
PROD_NEURAL_AUTH_SUB = 0.12
OPENCV_SUM = sum(PROD_OPENCV_WEIGHTS.values())
HEURISTIC_BLOCK = OPENCV_SUM + PROD_NEURAL_WEIGHT

RAW_THRESHOLDS = [
    0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50,
    0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95,
]


@dataclass
class ImageRecord:
    sha256: str
    canonical_path: Path
    ground_truth: str
    source: str
    generator: str
    category: str
    dataset_group: str
    is_own_photo: bool
    raw_univfd: float | None
    step4_fused: float | None
    step4_verdict: str
    signals: dict[str, float] = field(default_factory=dict)
    combined_meta: float = 0.0
    duplicate_paths: list[str] = field(default_factory=list)


def _latest_run(base: Path) -> Path:
    runs = [p for p in base.iterdir() if p.is_dir()]
    if not runs:
        raise SystemExit(f"No runs in {base}")
    return max(runs, key=lambda p: p.stat().st_mtime)


def _fnum(v: Any) -> float | None:
    if v is None or v == "":
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def apply_post_boosts(probability: float, signals: dict[str, float], combined_meta: float) -> float:
    p = probability
    if signals.get("quality_paradox", 0) >= 0.48 and combined_meta >= 0.32:
        p = min(0.98, p + 0.16)
    if signals.get("skin_smoothness", 0) >= 0.55 and signals.get("quality_paradox", 0) >= 0.45:
        p = min(0.98, p + 0.12)
    if (
        signals.get("noise_uniformity", 0) >= 0.55
        and signals.get("quality_paradox", 0) >= 0.55
        and combined_meta >= 0.32
    ):
        p = min(0.98, p + 0.10)
    return float(p)


def fuse_custom(
    signals: dict[str, float],
    combined_meta: float,
    *,
    opencv_weights: dict[str, float] | None = None,
    neural_weight: float = PROD_NEURAL_WEIGHT,
    meta_weight: float = PROD_META_WEIGHT,
    filename_weight: float = PROD_FILENAME_WEIGHT,
    neural_auth_sub: float = PROD_NEURAL_AUTH_SUB,
    include_opencv: bool = True,
    include_meta: bool = True,
    include_filename: bool = True,
    include_neural: bool = True,
    meta_mult: float = 1.0,
    filename_mult: float = 1.0,
    opencv_mult: float = 1.0,
) -> float:
    ow = opencv_weights or PROD_OPENCV_WEIGHTS
    total_w = 0.0
    acc = 0.0
    if include_opencv:
        for key, weight in ow.items():
            if key in signals:
                w = weight * opencv_mult
                acc += signals[key] * w
                total_w += w
    if include_neural and "neural" in signals:
        acc += signals["neural"] * neural_weight
        total_w += neural_weight
    if include_meta and combined_meta > 0:
        w = meta_weight * meta_mult
        acc += combined_meta * w
        total_w += w
    if include_filename and "filename" in signals:
        w = filename_weight * filename_mult
        acc += signals["filename"] * w
        total_w += w
    if include_neural and "neural_authentic" in signals:
        acc -= signals["neural_authentic"] * neural_auth_sub
        total_w += neural_auth_sub
    if total_w <= 0:
        return 0.12
    return float(np.clip(acc / total_w, 0.0, 0.98))


def production_offline(signals: dict[str, float], combined_meta: float, *, boosts: bool = True) -> float:
    p = _fuse_probability(signals, combined_meta)
    if boosts:
        p = apply_post_boosts(p, signals, combined_meta)
    return p


def scaled_opencv_weights(neural_weight: float) -> dict[str, float]:
    """Keep opencv+neural block sum = HEURISTIC_BLOCK when all opencv keys present."""
    target_opencv_sum = HEURISTIC_BLOCK - neural_weight
    scale = target_opencv_sum / OPENCV_SUM
    return {k: v * scale for k, v in PROD_OPENCV_WEIGHTS.items()}


def verdict_from_prob(p: float) -> str:
    v, _ = _verdict_from_probability(p)
    return v


def binary_metrics(y_true: list[int], y_pred: list[int]) -> dict[str, float | int]:
    tp = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 1)
    tn = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 0)
    fp = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 1)
    fn = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 0)
    n = len(y_true) or 1
    prec = tp / (tp + fp) if (tp + fp) else 0.0
    rec = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = 2 * prec * rec / (prec + rec) if (prec + rec) else 0.0
    spec = tn / (tn + fp) if (tn + fp) else 0.0
    fpr = fp / (fp + tn) if (fp + tn) else 0.0
    fnr = fn / (fn + tp) if (fn + tp) else 0.0
    return {
        "TP": tp, "TN": tn, "FP": fp, "FN": fn,
        "accuracy": (tp + tn) / n,
        "precision": prec, "recall": rec, "f1": f1,
        "specificity": spec, "false_positive_rate": fpr, "false_negative_rate": fnr,
    }


def strict_pred(verdict: str) -> int:
    return 1 if verdict == "ai_generated" else 0


def flagged_pred(verdict: str) -> int:
    return 1 if verdict in ("ai_generated", "suspicious") else 0


def roc_auc(scores: list[float], labels: list[int]) -> float | None:
    if len(set(labels)) < 2:
        return None
    pairs = sorted(zip(scores, labels), key=lambda x: x[0], reverse=True)
    n_pos = sum(labels)
    n_neg = len(labels) - n_pos
    if n_pos == 0 or n_neg == 0:
        return None
    tp = fp = 0
    prev_fpr = prev_tpr = 0.0
    auc = 0.0
    i = 0
    while i < len(pairs):
        score = pairs[i][0]
        tp_inc = fp_inc = 0
        while i < len(pairs) and pairs[i][0] == score:
            if pairs[i][1] == 1:
                tp_inc += 1
            else:
                fp_inc += 1
            i += 1
        tp += tp_inc
        fp += fp_inc
        tpr = tp / n_pos
        fpr = fp / n_neg
        auc += (fpr - prev_fpr) * (tpr + prev_tpr) / 2.0
        prev_fpr, prev_tpr = fpr, tpr
    return auc


def load_step4_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow(row)


def capture_signals(path: Path) -> tuple[dict[str, float], float]:
    content = path.read_bytes()
    fn_score, _ = _filename_ai_hint_score(path.name)
    meta_score, _ = _metadata_score(content, path.name)
    combined_meta = max(meta_score, fn_score)
    det = detect_ai_generated(content, file_name=path.name)
    signals = {k: float(v) for k, v in (det.get("signals") or {}).items()}
    return signals, combined_meta


CONFIG_BUILDERS: dict[str, tuple[str, Callable[..., float]]] = {}


def register_configs() -> None:
    CONFIG_BUILDERS.clear()
    CONFIG_BUILDERS["B_production_fusion"] = (
        "Exact production fusion + post-boosts (offline reproduction)",
        lambda s, m: production_offline(s, m, boosts=True),
    )
    CONFIG_BUILDERS["E_no_post_boosts"] = (
        "Production fusion without post-fusion boosts",
        lambda s, m: production_offline(s, m, boosts=False),
    )
    for w in (0.35, 0.40, 0.45, 0.50):
        ow = scaled_opencv_weights(w)
        name = f"C_neural_{int(w * 100):03d}"
        CONFIG_BUILDERS[name] = (
            f"Neural weight {w}; opencv weights scaled so opencv_sum+neural={HEURISTIC_BLOCK}",
            lambda s, m, ow=ow, w=w: apply_post_boosts(
                fuse_custom(s, m, opencv_weights=ow, neural_weight=w), s, m
            ),
        )
    CONFIG_BUILDERS["D1_heuristic_075"] = (
        "Production neural; metadata×0.75 filename×0.75 opencv×0.75",
        lambda s, m: apply_post_boosts(
            fuse_custom(s, m, meta_mult=0.75, filename_mult=0.75, opencv_mult=0.75), s, m
        ),
    )
    CONFIG_BUILDERS["D2_heuristic_050"] = (
        "Production neural; metadata×0.50 filename×0.50 opencv×0.50",
        lambda s, m: apply_post_boosts(
            fuse_custom(s, m, meta_mult=0.50, filename_mult=0.50, opencv_mult=0.50), s, m
        ),
    )
    CONFIG_BUILDERS["D3_meta_keep_reduce_other"] = (
        "Metadata full; filename×0.50; opencv×0.50; neural unchanged",
        lambda s, m: apply_post_boosts(
            fuse_custom(s, m, meta_mult=1.0, filename_mult=0.50, opencv_mult=0.50), s, m
        ),
    )
    CONFIG_BUILDERS["F_univfd_metadata_only"] = (
        "Diagnostic: neural + metadata only (no filename/opencv); no post-boosts",
        lambda s, m: fuse_custom(
            s, m, include_opencv=False, include_filename=False, include_meta=True, include_neural=True
        ),
    )
    CONFIG_BUILDERS["G_univfd_opencv_only"] = (
        "Diagnostic: neural + opencv only (no metadata/filename); no post-boosts",
        lambda s, m: fuse_custom(
            s, m, include_opencv=True, include_filename=False, include_meta=False, include_neural=True
        ),
    )
    CONFIG_BUILDERS["H_heuristics_only"] = (
        "Diagnostic: metadata+filename+opencv; no neural; no post-boosts",
        lambda s, m: fuse_custom(
            s, m, include_neural=False, include_opencv=True, include_meta=True, include_filename=True
        ),
    )


def eval_config(
    records: list[ImageRecord],
    prob_fn: Callable[[dict[str, float], float], float],
) -> dict[str, Any]:
    probs: list[float] = []
    verdicts: list[str] = []
    y_true = [1 if r.ground_truth == "AI" else 0 for r in records]
    for r in records:
        p = prob_fn(r.signals, r.combined_meta)
        probs.append(p)
        verdicts.append(verdict_from_prob(p))
    strict = binary_metrics(y_true, [strict_pred(v) for v in verdicts])
    flagged = binary_metrics(y_true, [flagged_pred(v) for v in verdicts])
    return {"probabilities": probs, "verdicts": verdicts, "strict": strict, "flagged": flagged}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--step4-dir", type=Path, default=None)
    parser.add_argument("--skip-detect", action="store_true", help="Use Step4 CSV only (cannot reproduce fusion)")
    args = parser.parse_args()

    step4_dir = args.step4_dir or _latest_run(ROOT / "evaluation_results" / "step4")
    step5_dir = _latest_run(ROOT / "evaluation_results" / "step5")
    csv_path = step4_dir / "univfd_step4_results.csv"
    rows = load_step4_csv(csv_path)

    register_configs()
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = ROOT / "evaluation_results" / "step6" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)

    # Hash all rows
    hash_groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    dedup_map_rows: list[dict[str, Any]] = []
    for r in rows:
        fp = Path(r.get("filepath", ""))
        if not fp.is_file():
            continue
        digest = file_sha256(fp)
        hash_groups[digest].append(r)
        dedup_map_rows.append(
            {
                "sha256": digest,
                "filepath": str(fp),
                "ground_truth": r.get("ground_truth"),
                "source": r.get("source"),
                "canonical": "",
            }
        )

    # Label conflicts
    conflicts: list[dict[str, Any]] = []
    canonical_by_hash: dict[str, ImageRecord] = {}
    for digest, group in hash_groups.items():
        gts = {g.get("ground_truth") for g in group}
        if "REAL" in gts and "AI" in gts:
            conflicts.append({"sha256": digest, "ground_truths": sorted(gts), "paths": [g["filepath"] for g in group]})
            continue
        main_entries = [
            g for g in group if g.get("dataset_group") == "main_benchmark" and g.get("ground_truth") in ("REAL", "AI")
        ]
        pick = main_entries[0] if main_entries else group[0]
        fp = Path(pick["filepath"])
        is_own = any(
            g.get("dataset_group") == "own_photos_robustness"
            or "\\own_photos\\" in g.get("filepath", "").replace("/", "\\")
            for g in group
        )
        canonical_by_hash[digest] = ImageRecord(
            sha256=digest,
            canonical_path=fp,
            ground_truth=pick.get("ground_truth", ""),
            source=pick.get("source", ""),
            generator=pick.get("generator", ""),
            category=pick.get("category", ""),
            dataset_group="main_benchmark" if main_entries else pick.get("dataset_group", ""),
            is_own_photo=is_own,
            raw_univfd=_fnum(pick.get("raw_univfd_probability")),
            step4_fused=_fnum(pick.get("fused_probability")),
            step4_verdict=pick.get("final_verdict", ""),
            duplicate_paths=[g["filepath"] for g in group],
        )

    for dm in dedup_map_rows:
        h = dm["sha256"]
        if h in canonical_by_hash:
            dm["canonical"] = str(canonical_by_hash[h].canonical_path)

    write_csv(
        out_dir / "step6_deduplication_map.csv",
        dedup_map_rows,
        ["sha256", "filepath", "ground_truth", "source", "canonical"],
    )

    if args.skip_detect:
        raise SystemExit("Full Step 6 requires signal capture via detect_ai_generated on canonical files.")

    # Capture signals once per canonical hash
    for rec in canonical_by_hash.values():
        if rec.ground_truth not in ("REAL", "AI"):
            continue
        try:
            rec.signals, rec.combined_meta = capture_signals(rec.canonical_path)
        except Exception as exc:
            print(f"WARN capture failed {rec.canonical_path}: {exc}")

    # Fusion reproduction vs Step 4 (all main benchmark rows)
    main_rows = [r for r in rows if r.get("dataset_group") == "main_benchmark" and r.get("ground_truth") in ("REAL", "AI")]
    repro_diffs: list[float] = []
    verdict_mismatch = 0
    compared = 0
    for r in main_rows:
        fp = Path(r["filepath"])
        if not fp.is_file():
            continue
        digest = file_sha256(fp)
        if digest not in canonical_by_hash:
            continue
        rec = canonical_by_hash[digest]
        if not rec.signals:
            continue
        offline_p = round(production_offline(rec.signals, rec.combined_meta, boosts=True), 3)
        stored = _fnum(r.get("fused_probability"))
        if stored is None:
            continue
        compared += 1
        diff = abs(offline_p - stored)
        repro_diffs.append(diff)
        if verdict_from_prob(offline_p) != r.get("final_verdict"):
            verdict_mismatch += 1

    max_diff = max(repro_diffs) if repro_diffs else None
    near_match = sum(1 for d in repro_diffs if d <= 0.011)

    if max_diff is not None and max_diff > 0.02:
        summary_block = {
            "step6_status": "BLOCKED",
            "reason": "Production fusion offline reproduction exceeded tolerance",
            "compared": compared,
            "max_diff": max_diff,
            "verdict_mismatches": verdict_mismatch,
        }
        (out_dir / "step6_summary.json").write_text(json.dumps(summary_block, indent=2), encoding="utf-8")
        raise SystemExit(f"Fusion reproduction failed: max_diff={max_diff} mismatches={verdict_mismatch}")

    # Clean deduplicated benchmark
    clean = [
        rec
        for rec in canonical_by_hash.values()
        if rec.ground_truth in ("REAL", "AI")
        and rec.dataset_group == "main_benchmark"
        and rec.signals
        and rec.sha256 not in {c["sha256"] for c in conflicts}
    ]
    original_labeled = len(main_rows)
    unique_labeled = len(clean)
    dup_removed = original_labeled - unique_labeled

    clean_rows_csv = [
        {
            "sha256": r.sha256,
            "canonical_path": str(r.canonical_path),
            "ground_truth": r.ground_truth,
            "source": r.source,
            "category": r.category,
            "raw_univfd": r.raw_univfd,
            "duplicate_count": len(r.duplicate_paths),
        }
        for r in clean
    ]
    write_csv(
        out_dir / "step6_clean_benchmark.csv",
        clean_rows_csv,
        list(clean_rows_csv[0].keys()) if clean_rows_csv else ["sha256"],
    )

    y_true_clean = [1 if r.ground_truth == "AI" else 0 for r in clean]
    own_clean = [
        rec
        for rec in canonical_by_hash.values()
        if rec.is_own_photo and rec.ground_truth == "REAL" and rec.signals
    ]

    # Config A raw threshold sweep
    raw_sweep: list[dict[str, Any]] = []
    labeled = [(r, float(r.raw_univfd)) for r in clean if r.raw_univfd is not None]
    yt = [1 if r.ground_truth == "AI" else 0 for r, _ in labeled]
    for thr in RAW_THRESHOLDS:
        yp = [1 if p >= thr else 0 for _, p in labeled]
        m = binary_metrics(yt, yp)
        m["threshold"] = thr
        m["configuration"] = "A_raw_univfd"
        raw_sweep.append(m)
    write_csv(out_dir / "step6_raw_threshold_sweep.csv", raw_sweep, list(raw_sweep[0].keys()) if raw_sweep else ["threshold"])

    # Fusion threshold sweep (B only, separate from weight experiment)
    b_probs = [production_offline(r.signals, r.combined_meta, boosts=True) for r in clean]
    fusion_sweep: list[dict[str, Any]] = []
    for thr in RAW_THRESHOLDS:
        yp_strict = [1 if p >= thr else 0 for p in b_probs]
        yp_flagged = [1 if p >= thr else 0 for p in b_probs]
        m_s = binary_metrics(y_true_clean, yp_strict)
        m_f = binary_metrics(y_true_clean, yp_flagged)
        fusion_sweep.append(
            {
                "configuration": "B_production_fusion",
                "threshold": thr,
                "strict_TP": m_s["TP"],
                "strict_TN": m_s["TN"],
                "strict_FP": m_s["FP"],
                "strict_FN": m_s["FN"],
                "strict_f1": m_s["f1"],
                "flagged_TP": m_f["TP"],
                "flagged_TN": m_f["TN"],
                "flagged_FP": m_f["FP"],
                "flagged_FN": m_f["FN"],
                "flagged_f1": m_f["f1"],
                "note": "THRESHOLD EXPERIMENT only; production uses 0.36/0.58 verdict bands",
            }
        )
    write_csv(
        out_dir / "step6_fusion_threshold_sweep.csv",
        fusion_sweep,
        list(fusion_sweep[0].keys()) if fusion_sweep else ["threshold"],
    )

    # Configuration comparison
    comparison_rows: list[dict[str, Any]] = []
    config_results: dict[str, dict[str, Any]] = {}

    for cfg_id, (desc, fn) in CONFIG_BUILDERS.items():
        res = eval_config(clean, fn)
        config_results[cfg_id] = res
        row: dict[str, Any] = {
            "configuration": cfg_id,
            "description": desc,
            "unique_n": len(clean),
            "real_n": sum(1 for r in clean if r.ground_truth == "REAL"),
            "ai_n": sum(1 for r in clean if r.ground_truth == "AI"),
        }
        for prefix, metrics in (("strict", res["strict"]), ("flagged", res["flagged"])):
            for k, v in metrics.items():
                row[f"{prefix}_{k}"] = v
        own_sub = eval_config(own_clean, fn) if own_clean else None
        if own_sub:
            row["own_photo_ai_generated"] = sum(1 for v in own_sub["verdicts"] if v == "ai_generated")
            row["own_photo_flagged"] = sum(
                1 for v in own_sub["verdicts"] if v in ("ai_generated", "suspicious")
            )
        for gen, col_d, col_f in (
            ("canva", "canva_detected", "canva_flagged"),
            ("chatgpt", "chatgpt_detected", "chatgpt_flagged"),
            ("google.gemini", "gemini_detected", "gemini_flagged"),
        ):
            sub = [r for r in clean if r.source == gen or r.generator == gen]
            if not sub:
                row[col_d] = row[col_f] = "N/A"
                continue
            sr = eval_config(sub, fn)
            row[col_d] = sum(1 for v in sr["verdicts"] if v == "ai_generated")
            row[col_f] = sum(1 for v in sr["verdicts"] if v in ("ai_generated", "suspicious"))
        comparison_rows.append(row)

    # A raw ROC only row
    auc = roc_auc([float(r.raw_univfd) for r in clean if r.raw_univfd is not None], y_true_clean)
    comparison_rows.insert(
        0,
        {
            "configuration": "A_raw_univfd",
            "description": "Raw UnivFD P(fake); metrics at prod thresholds N/A",
            "unique_n": len(clean),
            "real_n": sum(1 for r in clean if r.ground_truth == "REAL"),
            "ai_n": sum(1 for r in clean if r.ground_truth == "AI"),
            "ROC_AUC": auc,
        },
    )

    write_csv(
        out_dir / "step6_configuration_comparison.csv",
        comparison_rows,
        sorted({k for row in comparison_rows for k in row.keys()}),
    )

    # Own photos unique
    own_rows_out: list[dict[str, Any]] = []
    for cfg_id, (_, fn) in CONFIG_BUILDERS.items():
        res = eval_config(own_clean, fn)
        ai_gen = sum(1 for v in res["verdicts"] if v == "ai_generated")
        flagged_c = sum(1 for v in res["verdicts"] if v in ("ai_generated", "suspicious"))
        probs = res["probabilities"]
        own_rows_out.append(
            {
                "configuration": cfg_id,
                "unique_own_n": len(own_clean),
                "own_ai_generated": ai_gen,
                "own_flagged": flagged_c,
                "own_mean_prob": statistics.mean(probs) if probs else None,
                "own_median_prob": statistics.median(probs) if probs else None,
                "own_max_prob": max(probs) if probs else None,
            }
        )
    write_csv(
        out_dir / "step6_own_photos_comparison.csv",
        own_rows_out,
        list(own_rows_out[0].keys()) if own_rows_out else ["configuration"],
    )

    # Self-generated AI (deduped main benchmark)
    self_sources = ("canva", "chatgpt", "google.gemini")
    self_rows: list[dict[str, Any]] = []
    for gen in self_sources:
        subset = [r for r in clean if r.source == gen or r.generator == gen]
        for cfg_id, (_, fn) in CONFIG_BUILDERS.items():
            res = eval_config(subset, fn)
            self_rows.append(
                {
                    "generator": gen,
                    "configuration": cfg_id,
                    "n": len(subset),
                    "mean_prob": statistics.mean(res["probabilities"]) if res["probabilities"] else None,
                    "median_prob": statistics.median(res["probabilities"]) if res["probabilities"] else None,
                    "strict_detected": sum(1 for v in res["verdicts"] if v == "ai_generated"),
                    "flagged": sum(1 for v in res["verdicts"] if v in ("ai_generated", "suspicious")),
                }
            )
    write_csv(
        out_dir / "step6_self_generated_ai_comparison.csv",
        self_rows,
        list(self_rows[0].keys()) if self_rows else ["generator"],
    )

    # Source breakdown for B and C_neural_040
    src_rows: list[dict[str, Any]] = []
    for cfg_id in ("B_production_fusion", "C_neural_040", "E_no_post_boosts"):
        if cfg_id not in CONFIG_BUILDERS:
            continue
        _, fn = CONFIG_BUILDERS[cfg_id]
        for src in ("subset_fake_real_data", "rhythmghai", "canva", "chatgpt", "google.gemini"):
            sub = [r for r in clean if r.source == src]
            if not sub:
                continue
            res = eval_config(sub, fn)
            gts = {r.ground_truth for r in sub}
            entry: dict[str, Any] = {
                "configuration": cfg_id,
                "source": src,
                "n": len(sub),
                "mean_prob": statistics.mean(res["probabilities"]),
                "verdict_authentic": sum(1 for v in res["verdicts"] if v == "authentic"),
                "verdict_suspicious": sum(1 for v in res["verdicts"] if v == "suspicious"),
                "verdict_ai_generated": sum(1 for v in res["verdicts"] if v == "ai_generated"),
            }
            if gts == {"AI"} or gts == {"REAL"}:
                entry["note"] = "single-class subset"
            else:
                entry["strict"] = eval_config(sub, fn)["strict"]
            src_rows.append(entry)
    write_csv(
        out_dir / "step6_source_breakdown.csv",
        src_rows,
        sorted({k for row in src_rows for k in row.keys()}),
    )

    # Category breakdown
    cat_rows: list[dict[str, Any]] = []
    for cfg_id in ("B_production_fusion", "C_neural_040"):
        _, fn = CONFIG_BUILDERS[cfg_id]
        for cat in ("animals", "city", "food", "nature", "people"):
            sub = [r for r in clean if r.category == cat and r.source == "rhythmghai"]
            if not sub:
                continue
            res = eval_config(sub, fn)
            real_p = [res["probabilities"][i] for i, r in enumerate(sub) if r.ground_truth == "REAL"]
            ai_p = [res["probabilities"][i] for i, r in enumerate(sub) if r.ground_truth == "AI"]
            cat_rows.append(
                {
                    "configuration": cfg_id,
                    "category": cat,
                    "n": len(sub),
                    "mean_REAL": statistics.mean(real_p) if real_p else None,
                    "mean_AI": statistics.mean(ai_p) if ai_p else None,
                    "REAL_flagged": sum(
                        1
                        for i, r in enumerate(sub)
                        if r.ground_truth == "REAL" and res["verdicts"][i] in ("suspicious", "ai_generated")
                    ),
                    "AI_flagged": sum(
                        1
                        for i, r in enumerate(sub)
                        if r.ground_truth == "AI" and res["verdicts"][i] in ("suspicious", "ai_generated")
                    ),
                }
            )
    write_csv(
        out_dir / "step6_category_breakdown.csv",
        cat_rows,
        list(cat_rows[0].keys()) if cat_rows else ["category"],
    )

    b_strict = config_results["B_production_fusion"]["strict"]
    b_flagged = config_results["B_production_fusion"]["flagged"]

    summary = {
        "step6_status": "COMPLETE",
        "input": {"step4_run": str(step4_dir), "step5_run": str(step5_dir)},
        "verified_thresholds": {
            "AI_GENERATED_THRESHOLD": AI_GENERATED_THRESHOLD,
            "SUSPICIOUS_THRESHOLD": SUSPICIOUS_THRESHOLD,
        },
        "deduplication": {
            "original_labeled_main": original_labeled,
            "unique_labeled_main": unique_labeled,
            "unique_REAL": sum(1 for r in clean if r.ground_truth == "REAL"),
            "unique_AI": sum(1 for r in clean if r.ground_truth == "AI"),
            "duplicates_removed_from_main": dup_removed,
            "uncertain_excluded": sum(1 for r in rows if r.get("ground_truth") == "uncertain"),
            "cross_label_conflicts": len(conflicts),
            "conflict_details": conflicts,
        },
        "fusion_reproduction": {
            "rows_compared": compared,
            "near_matches_le_0_011": near_match,
            "max_probability_difference": max_diff,
            "verdict_mismatches": verdict_mismatch,
        },
        "raw_univfd": {"ROC_AUC_deduplicated": auc, "threshold_sweep_file": str(out_dir / "step6_raw_threshold_sweep.csv")},
        "production_fusion_deduplicated": {"strict": b_strict, "flagged": b_flagged},
        "experimental_configurations": {
            cid: {"description": CONFIG_BUILDERS[cid][0], "strict": config_results[cid]["strict"], "flagged": config_results[cid]["flagged"]}
            for cid in CONFIG_BUILDERS
        },
        "overfitting_limitation": (
            "Step 6 explores configurations on the same labeled images used in Steps 4–5. "
            "Results are exploratory; any chosen configuration should be validated on held-out data."
        ),
        "production_behavior_changed": False,
    }
    (out_dir / "step6_summary.json").write_text(json.dumps(summary, indent=2, default=str), encoding="utf-8")

    report_lines = [
        "STEP 6 STATUS: COMPLETE",
        f"Step 4: {step4_dir}",
        f"Step 5: {step5_dir}",
        f"Deduplicated main: REAL={summary['deduplication']['unique_REAL']} AI={summary['deduplication']['unique_AI']} removed={dup_removed}",
        f"Fusion repro: compared={compared} max_diff={max_diff} verdict_mismatch={verdict_mismatch}",
        f"Raw ROC-AUC: {auc}",
        f"B strict F1={b_strict['f1']:.3f} flagged F1={b_flagged['f1']:.3f}",
        "PRODUCTION BEHAVIOR CHANGED: NO",
    ]
    (out_dir / "step6_report.txt").write_text("\n".join(report_lines), encoding="utf-8")
    print("\n".join(report_lines))
    print(f"Output: {out_dir}")


if __name__ == "__main__":
    main()
