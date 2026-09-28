"""
Step 8B: Standalone PROBE-DINOv2 vs raw UnivFD on frozen fresh_validation set.

Usage:
  cd access_backend
  python scripts/experiment_probe_step8b.py
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import platform
import statistics
import sys
import time
import tracemalloc
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

PROBE_ROOT = ROOT / "experiments" / "probe"
VENDOR = PROBE_ROOT / "vendor_lib"
if str(VENDOR) not in sys.path:
    sys.path.insert(0, str(VENDOR))
sys.path.insert(0, str(PROBE_ROOT))

from probe_inference import (  # noqa: E402
    CROP_SIZE,
    HF_MODEL_ID,
    load_probe_dino_checkpoint,
    probe_image_scores,
)

CKPT_PATH = (
    PROBE_ROOT
    / "modelscope_cache"
    / "models"
    / "shuinishaojiu--PROBE-AIGI-Detection"
    / "snapshots"
    / "master"
    / "DINOv2_best_model_step_34999.pth"
)
HF_CACHE = PROBE_ROOT / "hf_cache"
DATASET_DEFAULT = Path.home() / "Desktop" / "fresh_validation"
STEP7_RESULTS = ROOT / "evaluation_results" / "step7" / "20260926_224651" / "step7_results.csv"

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}
SOURCE_GT = {
    ("ai", "chatgpt"): ("AI", "chatgpt"),
    ("ai", "gemini"): ("AI", "gemini"),
    ("ai", "canva"): ("AI", "canva"),
    ("ai", "pixlr"): ("AI", "pixlr"),
    ("real", "own_new_photos"): ("REAL", "own_new_photos"),
    ("real", "verified_external"): ("REAL", "verified_external"),
}


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def checkpoint_sha256(path: Path) -> tuple[int, str]:
    h = hashlib.sha256()
    size = 0
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
            size += len(chunk)
    return size, h.hexdigest()


def discover_dataset(root: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in IMAGE_EXTS:
            continue
        rel = path.relative_to(root)
        if len(rel.parts) < 3:
            continue
        key = (rel.parts[0].lower(), rel.parts[1].lower())
        if key not in SOURCE_GT:
            continue
        gt, source = SOURCE_GT[key]
        rows.append({"filepath": path, "filename": path.name, "ground_truth": gt, "source": source})
    return rows


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


def spearman_rho(x: list[float], y: list[float]) -> float | None:
    if len(x) != len(y) or len(x) < 2:
        return None
    n = len(x)

    def rank(vals: list[float]) -> list[float]:
        order = sorted(range(n), key=lambda i: vals[i])
        r = [0.0] * n
        i = 0
        while i < n:
            j = i
            while j + 1 < n and vals[order[j + 1]] == vals[order[i]]:
                j += 1
            avg_rank = (i + j) / 2.0 + 1.0
            for k in range(i, j + 1):
                r[order[k]] = avg_rank
            i = j + 1
        return r

    rx, ry = rank(x), rank(y)
    mx, my = statistics.mean(rx), statistics.mean(ry)
    num = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    den_x = sum((a - mx) ** 2 for a in rx) ** 0.5
    den_y = sum((b - my) ** 2 for b in ry) ** 0.5
    if den_x == 0 or den_y == 0:
        return None
    return num / (den_x * den_y)


def dist_stats(values: list[float]) -> dict[str, float | None]:
    if not values:
        return {"mean": None, "median": None, "min": None, "max": None, "n": 0}
    return {
        "n": len(values),
        "mean": statistics.mean(values),
        "median": statistics.median(values),
        "min": min(values),
        "max": max(values),
    }


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow(row)


def load_step7_by_sha(path: Path) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    if not path.is_file():
        return out
    with path.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            sha = row.get("sha256", "")
            if sha:
                out[sha] = row
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=Path, default=DATASET_DEFAULT)
    parser.add_argument("--step7-csv", type=Path, default=STEP7_RESULTS)
    parser.add_argument("--patch-batch-size", type=int, default=8)
    args = parser.parse_args()

    if not CKPT_PATH.is_file():
        raise SystemExit(f"PROBE checkpoint missing: {CKPT_PATH}")

    ck_size, ck_sha = checkpoint_sha256(CKPT_PATH)
    dataset_root = args.dataset.resolve()
    inventory = discover_dataset(dataset_root)

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = ROOT / "evaluation_results" / "step8b" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)
    partial_csv = out_dir / "step8b_probe_results.partial.csv"

    # Hash / dedup check
    by_hash: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in inventory:
        row["sha256"] = file_sha256(row["filepath"])
        by_hash[row["sha256"]].append(row)

    conflicts = [h for h, g in by_hash.items() if len({x["ground_truth"] for x in g}) > 1]
    if conflicts:
        raise SystemExit(f"Label conflicts for hashes: {conflicts[:3]}")

    tracemalloc.start()
    import torch

    device = torch.device("cpu")
    t_load0 = time.perf_counter()
    HF_CACHE.mkdir(parents=True, exist_ok=True)
    model = load_probe_dino_checkpoint(CKPT_PATH, hf_cache=HF_CACHE)
    model.to(device)
    load_seconds = time.perf_counter() - t_load0

    step7_map = load_step7_by_sha(args.step7_csv)
    results: list[dict[str, Any]] = []
    infer_times: list[float] = []
    t_total0 = time.perf_counter()

    for idx, row in enumerate(inventory, 1):
        fp: Path = row["filepath"]
        content = fp.read_bytes()
        t0 = time.perf_counter()
        err = ""
        mean_logit = prob = None
        n_patches = 0
        w = h = 0
        try:
            mean_logit, prob, n_patches, (w, h) = probe_image_scores(
                model, content, device=device, patch_batch_size=args.patch_batch_size
            )
        except Exception as exc:
            err = str(exc)
        infer_times.append(time.perf_counter() - t0)

        s7 = step7_map.get(row["sha256"], {})
        raw_univfd = s7.get("raw_univfd_probability")
        if raw_univfd in ("", None):
            raw_univfd = None
        else:
            raw_univfd = float(raw_univfd)
        results.append(
            {
                "filepath": str(fp),
                "filename": row["filename"],
                "sha256": row["sha256"],
                "ground_truth": row["ground_truth"],
                "source": row["source"],
                "image_width": w,
                "image_height": h,
                "number_of_patches": n_patches,
                "probe_mean_logit": mean_logit,
                "probe_probability": prob,
                "raw_univfd_probability": raw_univfd,
                "step7_univfd_probability": raw_univfd,
                "inference_seconds": infer_times[-1],
                "error": err,
            }
        )
        print(f"[{idx}/{len(inventory)}] probe={prob} patches={n_patches} t={infer_times[-1]:.1f}s {fp.name}", flush=True)
        write_csv(partial_csv, results, list(results[0].keys()))

    total_infer = time.perf_counter() - t_total0
    _current, peak_ram = tracemalloc.get_traced_memory()
    tracemalloc.stop()

    ok = [r for r in results if r["probe_probability"] is not None and not r["error"]]
    if len(ok) < len(inventory):
        raise SystemExit(f"PROBE errors on {len(inventory) - len(ok)} images; aborting metrics.")

    write_csv(
        out_dir / "step8b_dataset_inventory.csv",
        [{k: r[k] for k in ("filepath", "filename", "ground_truth", "source", "sha256")} for r in results],
        ["filepath", "filename", "ground_truth", "source", "sha256"],
    )
    write_csv(out_dir / "step8b_probe_results.csv", results, list(results[0].keys()))

    y_true = [1 if r["ground_truth"] == "AI" else 0 for r in ok]
    probe_scores = [float(r["probe_probability"]) for r in ok]
    univfd_scores = [float(r["raw_univfd_probability"]) for r in ok if r["raw_univfd_probability"] is not None]

    probe_auc = roc_auc(probe_scores, y_true)
    univfd_auc = roc_auc(univfd_scores, y_true)

    real_p = [float(r["probe_probability"]) for r in ok if r["ground_truth"] == "REAL"]
    ai_p = [float(r["probe_probability"]) for r in ok if r["ground_truth"] == "AI"]
    real_u = [float(r["raw_univfd_probability"]) for r in ok if r["ground_truth"] == "REAL" and r["raw_univfd_probability"] is not None]
    ai_u = [float(r["raw_univfd_probability"]) for r in ok if r["ground_truth"] == "AI" and r["raw_univfd_probability"] is not None]

    matched_sha = sum(1 for r in ok if r["sha256"] in step7_map)
    rho = spearman_rho(probe_scores, univfd_scores) if len(probe_scores) == len(univfd_scores) else None

    # Breakdowns
    gen_rows = []
    for src in ("chatgpt", "gemini", "canva", "pixlr"):
        sub = [float(r["probe_probability"]) for r in ok if r["source"] == src]
        gen_rows.append({"generator": src, **dist_stats(sub)})
    write_csv(out_dir / "step8b_generator_breakdown.csv", gen_rows, ["generator", "n", "mean", "median", "min", "max"])

    real_rows = []
    for src in ("own_new_photos", "verified_external"):
        sub = [float(r["probe_probability"]) for r in ok if r["source"] == src]
        real_rows.append({"real_source": src, **dist_stats(sub)})
    write_csv(out_dir / "step8b_real_breakdown.csv", real_rows, ["real_source", "n", "mean", "median", "min", "max"])

    # vs univfd table
    vs_rows = []
    for r in ok:
        vs_rows.append(
            {
                "sha256": r["sha256"],
                "source": r["source"],
                "ground_truth": r["ground_truth"],
                "probe_probability": r["probe_probability"],
                "raw_univfd_probability": r["raw_univfd_probability"],
                "step7_stored_univfd": r["step7_univfd_probability"],
            }
        )
    write_csv(
        out_dir / "step8b_probe_vs_univfd.csv",
        vs_rows,
        list(vs_rows[0].keys()) if vs_rows else ["sha256"],
    )

    # Error cases
    error_cases: list[dict[str, Any]] = []
    real_ok = [r for r in ok if r["ground_truth"] == "REAL"]
    ai_ok = [r for r in ok if r["ground_truth"] == "AI"]
    for title, subset, key, reverse in (
        ("REAL_highest_PROBE", real_ok, "probe_probability", True),
        ("AI_lowest_PROBE", ai_ok, "probe_probability", False),
    ):
        ranked = sorted(subset, key=lambda r: float(r[key]), reverse=reverse)[:10]
        for i, r in enumerate(ranked, 1):
            error_cases.append(
                {
                    "list": title,
                    "rank": i,
                    "filepath": r["filepath"],
                    "source": r["source"],
                    "ground_truth": r["ground_truth"],
                    "probe_probability": r["probe_probability"],
                    "raw_univfd_probability": r["raw_univfd_probability"],
                }
            )
    write_csv(out_dir / "step8b_error_cases.csv", error_cases, sorted({k for r in error_cases for k in r}))

    # Author 0.5 diagnostic
    def diag_05(records: list[dict[str, Any]]) -> dict[str, Any]:
        tp = sum(1 for r in records if r["ground_truth"] == "AI" and r["probe_probability"] >= 0.5)
        tn = sum(1 for r in records if r["ground_truth"] == "REAL" and r["probe_probability"] < 0.5)
        fp = sum(1 for r in records if r["ground_truth"] == "REAL" and r["probe_probability"] >= 0.5)
        fn = sum(1 for r in records if r["ground_truth"] == "AI" and r["probe_probability"] < 0.5)
        n = len(records) or 1
        return {"TP": tp, "TN": tn, "FP": fp, "FN": fn, "accuracy": (tp + tn) / n}

    diag = diag_05(ok)

    summary = {
        "step8b_status": "COMPLETE",
        "official_model": {
            "repository": "https://github.com/Amamiya-C/PROBE-AIGI-Detection",
            "checkpoint_source": "https://modelscope.cn/models/shuinishaojiu/PROBE-AIGI-Detection",
            "checkpoint_filename": CKPT_PATH.name,
            "checkpoint_sha256": ck_sha,
            "checkpoint_bytes": ck_size,
            "architecture": "DinoClassifier linear head on DINOv2-with-registers ViT-L",
            "backbone_config": HF_MODEL_ID,
            "license_status": "UNCLEAR (empty License on ModelScope; no LICENSE in GitHub repo)",
        },
        "environment": {
            "python": platform.python_version(),
            "torch": torch.__version__,
            "device": str(device),
            "vendor_lib": str(VENDOR),
        },
        "dataset": {
            "root": str(dataset_root),
            "discovered": len(inventory),
            "unique_sha256": len(by_hash),
            "real": sum(1 for r in inventory if r["ground_truth"] == "REAL"),
            "ai": sum(1 for r in inventory if r["ground_truth"] == "AI"),
            "label_conflicts": len(conflicts),
        },
        "probe_raw": {
            "ROC_AUC": probe_auc,
            "REAL": dist_stats(real_p),
            "AI": dist_stats(ai_p),
        },
        "univfd_raw_baseline_from_step7_csv": {
            "ROC_AUC": univfd_auc,
            "REAL": dist_stats(real_u),
            "AI": dist_stats(ai_u),
            "note": "Scores loaded from step7_results.csv by SHA-256 (not re-inferred)",
        },
        "step7_univfd_reference": {
            "csv": str(args.step7_csv),
            "sha256_matched": matched_sha,
            "spearman_probe_vs_univfd": rho,
        },
        "author_0_5_diagnostic_only": diag,
        "performance": {
            "model_load_seconds": load_seconds,
            "total_wall_seconds": total_infer,
            "mean_seconds_per_image": statistics.mean(infer_times),
            "median_seconds_per_image": statistics.median(infer_times),
            "max_seconds_per_image": max(infer_times),
            "peak_traced_ram_bytes": peak_ram,
        },
        "production_behavior_changed": False,
    }
    (out_dir / "step8b_summary.json").write_text(json.dumps(summary, indent=2, default=str), encoding="utf-8")

    report = [
        "STEP 8B STATUS: COMPLETE",
        f"Checkpoint: {CKPT_PATH.name} sha256={ck_sha[:16]}...",
        f"Dataset n={len(ok)} probe_AUC={probe_auc} univfd_AUC={univfd_auc}",
        f"PROBE REAL mean={dist_stats(real_p)['mean']:.4f} AI mean={dist_stats(ai_p)['mean']:.4f}",
        f"Load {load_seconds:.1f}s total {total_infer:.1f}s mean/img {statistics.mean(infer_times):.2f}s",
        "PRODUCTION BEHAVIOR CHANGED: NO",
        f"Output: {out_dir}",
    ]
    (out_dir / "step8b_report.txt").write_text("\n".join(report), encoding="utf-8")
    print("\n".join(report))


if __name__ == "__main__":
    main()
