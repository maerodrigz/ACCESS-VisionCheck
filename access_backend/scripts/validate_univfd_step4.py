"""
Step 4: Controlled REAL vs AI validation of UnivFD (evaluation only).

Usage:
  cd access_backend
  python scripts/validate_univfd_step4.py --smoke
  python scripts/validate_univfd_step4.py --dataset-root "C:/Users/Dell/Desktop"
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import platform
import statistics
import sys
import traceback
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Literal

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from app.services.ai_authenticity_detector import (  # noqa: E402
    AI_GENERATED_THRESHOLD,
    SUSPICIOUS_THRESHOLD,
    detect_ai_generated,
)
from app.services.dedicated_ai_detector import (  # noqa: E402
    clip_backbone_path,
    dedicated_ai_probability,
    dedicated_detector_available,
    weights_path,
)

IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp"}
GroundTruth = Literal["REAL", "AI", "uncertain"]
DatasetGroup = Literal["main_benchmark", "own_photos_robustness", "saved_from_sources_exploratory"]

THRESHOLD_GRID = [
    0.10,
    0.15,
    0.20,
    0.25,
    0.30,
    0.35,
    0.40,
    0.45,
    0.50,
    0.55,
    0.60,
    0.65,
    0.70,
    0.75,
    0.80,
    0.85,
    0.90,
]

CATEGORY_NAMES = {"animals", "city", "food", "nature", "people"}


@dataclass
class ImageSpec:
    filepath: Path
    dataset_group: DatasetGroup
    source: str
    generator: str
    category: str
    ground_truth: GroundTruth


@dataclass
class RowResult:
    spec: ImageSpec
    raw_univfd_probability: float | None = None
    fused_probability: float | None = None
    final_verdict: str = ""
    final_confidence: float | None = None
    filename_signal: float | None = None
    exif_signal: float | None = None
    opencv_signal: float | None = None
    neural_signal: float | None = None
    error: str = ""


def _iter_images(folder: Path) -> Iterable[Path]:
    if not folder.is_dir():
        return
    for path in folder.rglob("*"):
        if path.is_file() and path.suffix.lower() in IMAGE_EXT:
            yield path


def _category_from_path(path: Path) -> str:
    for part in path.parts:
        low = part.lower()
        if low in CATEGORY_NAMES:
            return low
    return ""


def _rhythmghai_truth(path: Path) -> GroundTruth | None:
    parts_lower = [p.lower() for p in path.parts]
    if "ai_generated_dataset" in parts_lower:
        return "AI"
    if "real_dataset" in parts_lower:
        return "REAL"
    return None


def discover_specs(dataset_root: Path) -> tuple[list[ImageSpec], dict[str, Any]]:
    notes: dict[str, Any] = {"missing_dirs": [], "empty_dirs": []}
    specs: list[ImageSpec] = []

    def add_folder(
        folder: Path,
        *,
        dataset_group: DatasetGroup,
        source: str,
        generator: str,
        ground_truth: GroundTruth,
    ) -> None:
        if not folder.is_dir():
            notes["missing_dirs"].append(str(folder))
            return
        files = list(_iter_images(folder))
        if not files:
            notes["empty_dirs"].append(str(folder))
        for fp in files:
            specs.append(
                ImageSpec(
                    filepath=fp,
                    dataset_group=dataset_group,
                    source=source,
                    generator=generator,
                    category=_category_from_path(fp),
                    ground_truth=ground_truth,
                )
            )

    sfrd = dataset_root / "subset_fake_real_data"
    add_folder(
        sfrd / "fake-v2",
        dataset_group="main_benchmark",
        source="subset_fake_real_data",
        generator="",
        ground_truth="AI",
    )
    add_folder(
        sfrd / "real",
        dataset_group="main_benchmark",
        source="subset_fake_real_data",
        generator="",
        ground_truth="REAL",
    )

    rhythm_root = dataset_root / "subset_dataset (1)" / "rhythmghai"
    if rhythm_root.is_dir():
        for fp in _iter_images(rhythm_root):
            gt = _rhythmghai_truth(fp)
            if gt is None:
                continue
            specs.append(
                ImageSpec(
                    filepath=fp,
                    dataset_group="main_benchmark",
                    source="rhythmghai",
                    generator="",
                    category=_category_from_path(fp),
                    ground_truth=gt,
                )
            )
    else:
        notes["missing_dirs"].append(str(rhythm_root))

    self_ai = dataset_root / "self_ai_generated"
    for gen in ("canva", "chatgpt", "google.gemini"):
        add_folder(
            self_ai / gen,
            dataset_group="main_benchmark",
            source=gen,
            generator=gen,
            ground_truth="AI",
        )

    add_folder(
        dataset_root / "own_photos",
        dataset_group="own_photos_robustness",
        source="own_photos",
        generator="",
        ground_truth="REAL",
    )

    saved = dataset_root / "saved_from_sources"
    for sub, label in (
        ("Telegram", "Telegram"),
        ("from google", "from_google"),
        ("from pinterest", "from_pinterest"),
    ):
        add_folder(
            saved / sub,
            dataset_group="saved_from_sources_exploratory",
            source="saved_from_sources",
            generator=label,
            ground_truth="uncertain",
        )

    return specs, notes


def _signals_from_response(signals: dict[str, Any] | None) -> tuple[float | None, ...]:
    if not signals:
        return None, None, None, None
    filename_s = signals.get("filename")
    exif_s = signals.get("metadata")
    opencv_keys = (
        "frequency",
        "noise_uniformity",
        "texture_entropy",
        "quality_paradox",
        "skin_smoothness",
    )
    opencv_vals = [float(signals[k]) for k in opencv_keys if k in signals]
    opencv_s = max(opencv_vals) if opencv_vals else None
    neural_s = signals.get("neural")
    return (
        float(filename_s) if filename_s is not None else None,
        float(exif_s) if exif_s is not None else None,
        float(opencv_s) if opencv_s is not None else None,
        float(neural_s) if neural_s is not None else None,
    )


def process_image(spec: ImageSpec) -> RowResult:
    row = RowResult(spec=spec)
    try:
        content = spec.filepath.read_bytes()
        row.raw_univfd_probability = dedicated_ai_probability(content)
        fused = detect_ai_generated(content, file_name=spec.filepath.name)
        row.fused_probability = float(fused.get("probability", 0))
        row.final_verdict = str(fused.get("verdict", ""))
        conf = fused.get("confidence")
        row.final_confidence = float(conf) if conf is not None else None
        fn, ex, oc, ne = _signals_from_response(fused.get("signals") or {})
        row.filename_signal = fn
        row.exif_signal = ex
        row.opencv_signal = oc
        row.neural_signal = ne
    except Exception as exc:
        row.error = f"{type(exc).__name__}: {exc}"
    return row


def _dist_stats(values: list[float]) -> dict[str, float | int]:
    if not values:
        return {"count": 0}
    return {
        "count": len(values),
        "mean": statistics.mean(values),
        "median": statistics.median(values),
        "min": min(values),
        "max": max(values),
        "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
    }


def _roc_auc(scores: list[float], labels: list[int]) -> float | None:
    """labels: 1=AI (positive), 0=REAL."""
    if len(scores) < 2 or len(set(labels)) < 2:
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
        tp_at = fp_at = 0
        while i < len(pairs) and pairs[i][0] == score:
            if pairs[i][1] == 1:
                tp_at += 1
            else:
                fp_at += 1
            i += 1
        tp += tp_at
        fp += fp_at
        tpr = tp / n_pos
        fpr = fp / n_neg
        auc += (fpr - prev_fpr) * (tpr + prev_tpr) / 2.0
        prev_fpr, prev_tpr = fpr, tpr
    return auc


def _binary_metrics(y_true: list[int], y_pred: list[int]) -> dict[str, float | int]:
    tp = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 1)
    tn = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 0)
    fp = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 1)
    fn = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 0)
    n = len(y_true)
    acc = (tp + tn) / n if n else 0.0
    prec = tp / (tp + fp) if (tp + fp) else 0.0
    rec = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = (2 * prec * rec / (prec + rec)) if (prec + rec) else 0.0
    spec = tn / (tn + fp) if (tn + fp) else 0.0
    fpr = fp / (fp + tn) if (fp + tn) else 0.0
    fnr = fn / (fn + tp) if (fn + tp) else 0.0
    return {
        "TP": tp,
        "TN": tn,
        "FP": fp,
        "FN": fn,
        "accuracy": acc,
        "precision": prec,
        "recall": rec,
        "f1": f1,
        "specificity": spec,
        "false_positive_rate": fpr,
        "false_negative_rate": fnr,
    }


def _verdict_distribution(rows: list[RowResult]) -> dict[str, int]:
    dist: dict[str, int] = {"authentic": 0, "suspicious": 0, "ai_generated": 0, "other": 0}
    for r in rows:
        v = r.final_verdict or "other"
        if v in dist:
            dist[v] += 1
        else:
            dist["other"] += 1
    return dist


def write_csv(path: Path, rows: list[RowResult]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "dataset_group",
        "source",
        "generator",
        "category",
        "filename",
        "filepath",
        "ground_truth",
        "raw_univfd_probability",
        "fused_probability",
        "final_verdict",
        "final_confidence",
        "filename_signal",
        "exif_signal",
        "opencv_signal",
        "neural_signal",
        "error",
    ]
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            s = r.spec
            w.writerow(
                {
                    "dataset_group": s.dataset_group,
                    "source": s.source,
                    "generator": s.generator,
                    "category": s.category,
                    "filename": s.filepath.name,
                    "filepath": str(s.filepath),
                    "ground_truth": s.ground_truth,
                    "raw_univfd_probability": r.raw_univfd_probability,
                    "fused_probability": r.fused_probability,
                    "final_verdict": r.final_verdict,
                    "final_confidence": r.final_confidence,
                    "filename_signal": r.filename_signal,
                    "exif_signal": r.exif_signal,
                    "opencv_signal": r.opencv_signal,
                    "neural_signal": r.neural_signal,
                    "error": r.error,
                }
            )


def threshold_analysis(rows: list[RowResult]) -> list[dict[str, Any]]:
    labeled = [
        r
        for r in rows
        if r.spec.ground_truth in ("REAL", "AI")
        and r.error == ""
        and r.raw_univfd_probability is not None
    ]
    y_true = [1 if r.spec.ground_truth == "AI" else 0 for r in labeled]
    out: list[dict[str, Any]] = []
    for thr in THRESHOLD_GRID:
        y_pred = [1 if r.raw_univfd_probability >= thr else 0 for r in labeled]
        m = _binary_metrics(y_true, y_pred)
        m["threshold"] = thr
        out.append(m)
    return out


def write_threshold_csv(path: Path, analysis: list[dict[str, Any]]) -> None:
    if not analysis:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    keys = list(analysis[0].keys())
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        for row in analysis:
            w.writerow(row)


def run_smoke(specs: list[ImageSpec]) -> None:
    main = [s for s in specs if s.dataset_group == "main_benchmark" and s.ground_truth == "REAL"]
    ai = [s for s in specs if s.dataset_group == "main_benchmark" and s.ground_truth == "AI"]
    if not main or not ai:
        raise SystemExit("Smoke test needs at least one REAL and one AI image in main benchmark.")
    for label, pick in ("REAL", main[0]), ("AI", ai[0]):
        r = process_image(pick)
        if r.error:
            raise SystemExit(f"Smoke {label} failed: {r.error}")
        if r.raw_univfd_probability is None:
            raise SystemExit(f"Smoke {label}: raw_univfd_probability is None")
        if not (0.0 <= r.raw_univfd_probability <= 1.0):
            raise SystemExit(f"Smoke {label}: raw prob out of range")
        if r.fused_probability is None or not (0.0 <= r.fused_probability <= 1.0):
            raise SystemExit(f"Smoke {label}: fused probability invalid")
        if r.final_verdict not in ("authentic", "suspicious", "ai_generated"):
            raise SystemExit(f"Smoke {label}: unexpected verdict {r.final_verdict}")
        print(f"Smoke OK {label}: {pick.filepath.name} raw={r.raw_univfd_probability:.4f} fused={r.fused_probability:.4f} verdict={r.final_verdict}")


def build_report(
    *,
    rows: list[RowResult],
    discovery_notes: dict[str, Any],
    dataset_root: Path,
    out_dir: Path,
) -> dict[str, Any]:
    main_ok = [
        r
        for r in rows
        if r.spec.dataset_group == "main_benchmark"
        and r.spec.ground_truth in ("REAL", "AI")
        and not r.error
    ]
    main_failed = [r for r in rows if r.spec.dataset_group == "main_benchmark" and r.error]
    uncertain = [r for r in rows if r.spec.ground_truth == "uncertain"]

    raw_scores = [r.raw_univfd_probability for r in main_ok if r.raw_univfd_probability is not None]
    real_raw = [r.raw_univfd_probability for r in main_ok if r.spec.ground_truth == "REAL" and r.raw_univfd_probability is not None]
    ai_raw = [r.raw_univfd_probability for r in main_ok if r.spec.ground_truth == "AI" and r.raw_univfd_probability is not None]

    y_true = [1 if r.spec.ground_truth == "AI" else 0 for r in main_ok if r.raw_univfd_probability is not None]
    raw_for_auc = [r.raw_univfd_probability for r in main_ok if r.raw_univfd_probability is not None]

    production_strict = [
        1 if r.final_verdict == "ai_generated" else 0
        for r in main_ok
        if r.raw_univfd_probability is not None
    ]
    production_flagged = [
        1 if r.final_verdict in ("ai_generated", "suspicious") else 0
        for r in main_ok
        if r.raw_univfd_probability is not None
    ]
    production_prob_strict = [
        1 if (r.fused_probability or 0) >= AI_GENERATED_THRESHOLD else 0
        for r in main_ok
        if r.raw_univfd_probability is not None
    ]

    overlap: dict[str, Any] = {}
    if real_raw and ai_raw:
        overlap = {
            "real_range": [min(real_raw), max(real_raw)],
            "ai_range": [min(ai_raw), max(ai_raw)],
            "shared_range_low": max(min(real_raw), min(ai_raw)),
            "shared_range_high": min(max(real_raw), max(ai_raw)),
            "pct_real_at_or_above_ai_median": sum(1 for x in real_raw if x >= statistics.median(ai_raw)) / len(real_raw),
            "pct_ai_at_or_below_real_median": sum(1 for x in ai_raw if x <= statistics.median(real_raw)) / len(ai_raw),
        }

    by_source: dict[str, Any] = {}
    for src in (
        "subset_fake_real_data",
        "rhythmghai",
        "canva",
        "chatgpt",
        "google.gemini",
    ):
        src_rows = [r for r in main_ok if r.spec.source == src and r.raw_univfd_probability is not None]
        if not src_rows:
            by_source[src] = {"count": 0}
            continue
        probs = [r.raw_univfd_probability for r in src_rows if r.raw_univfd_probability is not None]
        entry: dict[str, Any] = {
            "count": len(src_rows),
            "AI_count": sum(1 for r in src_rows if r.spec.ground_truth == "AI"),
            "REAL_count": sum(1 for r in src_rows if r.spec.ground_truth == "REAL"),
            "raw_univfd": _dist_stats([p for p in probs if p is not None]),
            "verdict_distribution": _verdict_distribution(src_rows),
        }
        gt_set = {r.spec.ground_truth for r in src_rows}
        if gt_set == {"AI"} or gt_set == {"REAL"}:
            entry["note"] = "single-class source; binary accuracy not computed"
        by_source[src] = entry

    by_category: dict[str, Any] = {}
    for cat in sorted({r.spec.category for r in main_ok if r.spec.category}):
        cat_rows = [r for r in main_ok if r.spec.category == cat and r.raw_univfd_probability is not None]
        probs = [float(r.raw_univfd_probability) for r in cat_rows if r.raw_univfd_probability is not None]
        by_category[cat] = {
            "count": len(cat_rows),
            **_dist_stats(probs),
            "verdict_distribution": _verdict_distribution(cat_rows),
        }

    own_rows = [r for r in rows if r.spec.dataset_group == "own_photos_robustness" and not r.error]
    saved_rows = [r for r in rows if r.spec.dataset_group == "saved_from_sources_exploratory" and not r.error]

    saved_by_gen: dict[str, Any] = {}
    for r in saved_rows:
        g = r.spec.generator or "unknown"
        saved_by_gen.setdefault(g, []).append(r)

    report: dict[str, Any] = {
        "run_metadata": {
            "timestamp_utc": datetime.now(timezone.utc).isoformat(),
            "dataset_root": str(dataset_root),
            "model": "UniversalFakeDetect CLIP:ViT-L/14",
            "clip_backbone": str(clip_backbone_path()),
            "classifier_checkpoint": str(weights_path()),
            "preprocessing": "RGB -> CenterCrop(224) -> ToTensor -> CLIP normalize (UnivFD validate.py)",
            "python_version": platform.python_version(),
            "device": "CPU",
            "production_thresholds": {
                "AI_GENERATED_THRESHOLD": AI_GENERATED_THRESHOLD,
                "SUSPICIOUS_THRESHOLD": SUSPICIOUS_THRESHOLD,
            },
            "discovery_notes": discovery_notes,
        },
        "dataset": {
            "discovered_total": len(rows),
            "main_benchmark_labeled": len([r for r in rows if r.spec.dataset_group == "main_benchmark"]),
            "labeled_REAL_main": sum(1 for r in main_ok if r.spec.ground_truth == "REAL"),
            "labeled_AI_main": sum(1 for r in main_ok if r.spec.ground_truth == "AI"),
            "uncertain_count": len(uncertain),
            "failed_main": len(main_failed),
            "successful_all": sum(1 for r in rows if not r.error),
            "failed_all": sum(1 for r in rows if r.error),
        },
        "raw_univfd": {
            "real_distribution": _dist_stats([float(x) for x in real_raw]),
            "ai_distribution": _dist_stats([float(x) for x in ai_raw]),
            "overlap": overlap,
            "ROC_AUC": _roc_auc([float(x) for x in raw_for_auc], y_true),
            "note": "No standalone raw UnivFD production threshold in code; no default binary CM for raw.",
        },
        "production_fusion": {
            "verdict_distribution": _verdict_distribution(main_ok),
            "binary_rule_strict_verdict": "positive iff final_verdict == ai_generated",
            "binary_rule_flagged_verdict": "positive iff final_verdict in (suspicious, ai_generated)",
            "binary_rule_prob_strict": f"positive iff fused_probability >= {AI_GENERATED_THRESHOLD}",
            "metrics_strict_verdict": _binary_metrics(y_true, production_strict),
            "metrics_flagged_verdict": _binary_metrics(y_true, production_flagged),
            "metrics_prob_gte_ai_threshold": _binary_metrics(y_true, production_prob_strict),
        },
        "source_breakdown": by_source,
        "category_breakdown_rhythmghai": by_category,
        "own_photos": {
            "count": len(own_rows),
            "raw_univfd": _dist_stats(
                [float(r.raw_univfd_probability) for r in own_rows if r.raw_univfd_probability is not None]
            ),
            "verdict_distribution": _verdict_distribution(own_rows),
        },
        "saved_from_sources_exploratory": {
            "count": len(saved_rows),
            "ground_truth": "uncertain (excluded from main metrics)",
            "by_generator": {
                g: {
                    "count": len(rs),
                    "raw_univfd": _dist_stats(
                        [float(r.raw_univfd_probability) for r in rs if r.raw_univfd_probability is not None]
                    ),
                    "verdict_distribution": _verdict_distribution(rs),
                }
                for g, rs in saved_by_gen.items()
            },
        },
        "outliers": {
            "high_raw_on_REAL": [
                {
                    "filepath": str(r.spec.filepath),
                    "raw": r.raw_univfd_probability,
                    "fused": r.fused_probability,
                    "verdict": r.final_verdict,
                }
                for r in sorted(
                    [x for x in main_ok if x.spec.ground_truth == "REAL" and x.raw_univfd_probability is not None],
                    key=lambda x: float(x.raw_univfd_probability or 0),
                    reverse=True,
                )[:10]
            ],
            "low_raw_on_AI": [
                {
                    "filepath": str(r.spec.filepath),
                    "raw": r.raw_univfd_probability,
                    "fused": r.fused_probability,
                    "verdict": r.final_verdict,
                }
                for r in sorted(
                    [x for x in main_ok if x.spec.ground_truth == "AI" and x.raw_univfd_probability is not None],
                    key=lambda x: float(x.raw_univfd_probability or 0),
                )[:10]
            ],
        },
        "errors": [{"filepath": str(r.spec.filepath), "error": r.error} for r in rows if r.error],
    }
    (out_dir / "step4_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Step 4 UnivFD controlled validation")
    parser.add_argument(
        "--dataset-root",
        type=Path,
        default=Path(r"C:\Users\Dell\Desktop"),
        help="Folder containing own_photos, subset_fake_real_data, etc.",
    )
    parser.add_argument("--smoke", action="store_true", help="Run smoke test only")
    parser.add_argument("--limit", type=int, default=0, help="Process at most N images (0=all)")
    args = parser.parse_args()

    if not dedicated_detector_available():
        raise SystemExit("UnivFD weights not available. Expected ml/univfd/fc_weights.pth and ViT-L-14.pt")

    specs, notes = discover_specs(args.dataset_root)
    if not specs:
        raise SystemExit(f"No images discovered under {args.dataset_root}")

    if args.smoke:
        run_smoke(specs)
        print("Smoke test passed.")
        return

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = ROOT / "evaluation_results" / "step4" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)

    run_smoke(specs)

    if args.limit > 0:
        specs = specs[: args.limit]

    results: list[RowResult] = []
    total = len(specs)
    for i, spec in enumerate(specs, start=1):
        row = process_image(spec)
        results.append(row)
        if i == 1 or i % 10 == 0 or i == total:
            status = "OK" if not row.error else "ERR"
            raw = row.raw_univfd_probability
            raw_s = f"{raw:.4f}" if raw is not None else "None"
            print(f"[{i}/{total}] {status} {spec.filepath.name} raw={raw_s} gt={spec.ground_truth}")

    csv_path = out_dir / "univfd_step4_results.csv"
    write_csv(csv_path, results)

    thr_rows = threshold_analysis([r for r in results if r.spec.dataset_group == "main_benchmark"])
    write_threshold_csv(out_dir / "univfd_threshold_analysis.csv", thr_rows)

    report = build_report(rows=results, discovery_notes=notes, dataset_root=args.dataset_root, out_dir=out_dir)

    summary_path = out_dir / "step4_summary.txt"
    ds = report["dataset"]
    raw = report["raw_univfd"]
    prod_s = report["production_fusion"]["metrics_strict_verdict"]
    prod_f = report["production_fusion"]["metrics_flagged_verdict"]
    lines = [
        f"STEP 4 run: {stamp}",
        f"Results CSV: {csv_path}",
        f"Discovered: {ds['discovered_total']}",
        f"Main REAL (ok): {ds['labeled_REAL_main']}",
        f"Main AI (ok): {ds['labeled_AI_main']}",
        f"Uncertain: {ds['uncertain_count']}",
        f"Failed: {ds['failed_all']}",
        f"Raw REAL mean: {raw['real_distribution'].get('mean')}",
        f"Raw AI mean: {raw['ai_distribution'].get('mean')}",
        f"Raw ROC-AUC: {raw.get('ROC_AUC')}",
        f"Fusion strict verdict F1: {prod_s.get('f1')}",
        f"Fusion flagged verdict F1: {prod_f.get('f1')}",
    ]
    summary_path.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))
    print(f"Report JSON: {out_dir / 'step4_report.json'}")


if __name__ == "__main__":
    main()
