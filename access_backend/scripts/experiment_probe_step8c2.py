"""
Step 8C.2: PROBE with max_long_edge=1344 on frozen Step 8B dataset (experimental only).

Usage:
  cd access_backend
  python scripts/experiment_probe_step8c2.py
"""

from __future__ import annotations

import csv
import hashlib
import json
import platform
import statistics
import sys
import time
from collections import defaultdict
from datetime import datetime
from io import BytesIO
from pathlib import Path
from typing import Any

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

PROBE_ROOT = ROOT / "experiments" / "probe"
VENDOR = PROBE_ROOT / "vendor_lib"
if str(VENDOR) not in sys.path:
    sys.path.insert(0, str(VENDOR))
sys.path.insert(0, str(PROBE_ROOT))

from probe_inference import HF_MODEL_ID, load_probe_dino_checkpoint, probe_image_scores  # noqa: E402

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
STEP8B_DIR = ROOT / "evaluation_results" / "step8b" / "20260927_040610"
STEP8B_CSV = STEP8B_DIR / "step8b_probe_results.csv"
MAX_LONG_EDGE = 1344
PATCH_BATCH_SIZE = 8

STEP8B_BASELINE = {
    "ROC_AUC": 0.733,
    "REAL_mean": 0.141,
    "REAL_median": 0.084,
    "AI_mean": 0.552,
    "AI_median": 0.763,
    "author_0_5": {
        "TP": 26,
        "TN": 47,
        "FP": 3,
        "FN": 24,
        "accuracy": 0.73,
        "precision": 0.897,
        "recall": 0.52,
        "F1": 0.658,
        "specificity": 0.94,
        "FPR": 0.06,
        "FNR": 0.48,
    },
}


def checkpoint_sha256(path: Path) -> tuple[int, str]:
    h = hashlib.sha256()
    size = 0
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
            size += len(chunk)
    return size, h.hexdigest()


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


def dist_stats(values: list[float]) -> dict[str, Any]:
    if not values:
        return {"n": 0, "mean": None, "median": None, "min": None, "max": None}
    return {
        "n": len(values),
        "mean": statistics.mean(values),
        "median": statistics.median(values),
        "min": min(values),
        "max": max(values),
    }


def diag_05(probs: list[float], labels: list[str]) -> dict[str, float]:
    tp = sum(1 for p, g in zip(probs, labels) if g == "AI" and p >= 0.5)
    tn = sum(1 for p, g in zip(probs, labels) if g == "REAL" and p < 0.5)
    fp = sum(1 for p, g in zip(probs, labels) if g == "REAL" and p >= 0.5)
    fn = sum(1 for p, g in zip(probs, labels) if g == "AI" and p < 0.5)
    n = len(probs) or 1
    prec = tp / (tp + fp) if (tp + fp) else 0.0
    rec = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = 2 * prec * rec / (prec + rec) if (prec + rec) else 0.0
    spec = tn / (tn + fp) if (tn + fp) else 0.0
    fpr = fp / (fp + tn) if (fp + tn) else 0.0
    fnr = fn / (fn + tp) if (fn + tp) else 0.0
    return {
        "TP": tp,
        "TN": tn,
        "FP": fp,
        "FN": fn,
        "accuracy": (tp + tn) / n,
        "precision": prec,
        "recall": rec,
        "F1": f1,
        "specificity": spec,
        "FPR": fpr,
        "FNR": fnr,
    }


def quartile(vals: list[float], p: float) -> float:
    s = sorted(vals)
    if not s:
        return 0.0
    if len(s) == 1:
        return s[0]
    idx = p * (len(s) - 1)
    lo, hi = int(idx), min(int(idx) + 1, len(s) - 1)
    if lo == hi:
        return s[lo]
    return s[lo] + (s[hi] - s[lo]) * (idx - lo)


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow(row)


def load_step8b() -> list[dict[str, str]]:
    with STEP8B_CSV.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def verify_integrity(step8b_rows: list[dict[str, str]]) -> dict[str, Any]:
    shas = [r["sha256"] for r in step8b_rows]
    unique = len(set(shas))
    real = sum(1 for r in step8b_rows if r["ground_truth"] == "REAL")
    ai = sum(1 for r in step8b_rows if r["ground_truth"] == "AI")
    by_sha: dict[str, set[str]] = defaultdict(set)
    for r in step8b_rows:
        by_sha[r["sha256"]].add(r["ground_truth"])
    conflicts = [s for s, gts in by_sha.items() if len(gts) > 1]
    ok = (
        len(step8b_rows) == 100
        and unique == 100
        and real == 50
        and ai == 50
        and len(conflicts) == 0
    )
    return {
        "ok": ok,
        "total": len(step8b_rows),
        "unique_sha256": unique,
        "real": real,
        "ai": ai,
        "label_conflicts": len(conflicts),
    }


def main() -> None:
    if not CKPT_PATH.is_file():
        raise SystemExit(f"BLOCKED: checkpoint missing {CKPT_PATH}")
    if not STEP8B_CSV.is_file():
        raise SystemExit(f"BLOCKED: Step 8B CSV missing {STEP8B_CSV}")

    step8b_rows = load_step8b()
    integrity = verify_integrity(step8b_rows)
    if not integrity["ok"]:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        out_dir = ROOT / "evaluation_results" / "step8c2" / stamp
        out_dir.mkdir(parents=True, exist_ok=True)
        blocked = {"step8c2_status": "BLOCKED", "dataset_integrity": integrity}
        (out_dir / "step8c2_summary.json").write_text(json.dumps(blocked, indent=2), encoding="utf-8")
        raise SystemExit(f"BLOCKED dataset integrity: {integrity}")

    ck_size, ck_sha = checkpoint_sha256(CKPT_PATH)
    import torch

    device = torch.device("cpu")
    env = {
        "python": platform.python_version(),
        "torch": torch.__version__,
        "device": "cpu",
        "max_long_edge": MAX_LONG_EDGE,
        "checkpoint_sha256": ck_sha,
        "checkpoint_bytes": ck_size,
        "backbone": HF_MODEL_ID,
    }
    print("STEP 8C.2 environment:", json.dumps(env, indent=2))

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = ROOT / "evaluation_results" / "step8c2" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)
    partial = out_dir / "step8c2_1344_results.partial.csv"

    HF_CACHE.mkdir(parents=True, exist_ok=True)
    model = load_probe_dino_checkpoint(CKPT_PATH, hf_cache=HF_CACHE)
    model.to(device)

    results: list[dict[str, Any]] = []
    t_total_wall0 = time.perf_counter()
    t_total_cpu0 = time.process_time()

    for idx, s8 in enumerate(step8b_rows, 1):
        fp = Path(s8["filepath"])
        if not fp.is_file():
            raise SystemExit(f"BLOCKED: missing file {fp}")
        content = fp.read_bytes()
        with Image.open(BytesIO(content)) as im:
            im = im.convert("RGB")
            orig_w, orig_h = im.size

        err = ""
        capped_prob = None
        n_cap = 0
        inf_w = inf_h = 0
        wall0 = time.perf_counter()
        cpu0 = time.process_time()
        try:
            _, capped_prob, n_cap, (inf_w, inf_h) = probe_image_scores(
                model,
                content,
                device=device,
                patch_batch_size=PATCH_BATCH_SIZE,
                max_long_edge=MAX_LONG_EDGE,
            )
        except Exception as exc:
            err = str(exc)
        wall_s = time.perf_counter() - wall0
        cpu_s = time.process_time() - cpu0

        full_prob = float(s8["probe_probability"])
        n_full = int(s8["number_of_patches"])
        delta = (capped_prob - full_prob) if capped_prob is not None else None

        row = {
            "filepath": str(fp),
            "sha256": s8["sha256"],
            "ground_truth": s8["ground_truth"],
            "source": s8["source"],
            "original_width": orig_w,
            "original_height": orig_h,
            "inference_width": inf_w,
            "inference_height": inf_h,
            "original_step8b_patch_count": n_full,
            "capped_patch_count": n_cap,
            "fullres_step8b_probability": full_prob,
            "capped_probability": capped_prob,
            "probability_delta": delta,
            "wall_seconds": wall_s,
            "process_cpu_seconds": cpu_s,
            "error": err,
        }
        results.append(row)
        print(
            f"[{idx}/100] cap_p={capped_prob} delta={delta} patches {n_full}->{n_cap} "
            f"wall={wall_s:.1f}s {fp.name}",
            flush=True,
        )
        write_csv(partial, results, list(row.keys()))

    total_wall = time.perf_counter() - t_total_wall0
    total_cpu = time.process_time() - t_total_cpu0

    ok = [r for r in results if r["capped_probability"] is not None and not r["error"]]
    if len(ok) < 100:
        raise SystemExit(f"Errors on {100 - len(ok)} images")

    fieldnames = list(results[0].keys())
    write_csv(out_dir / "step8c2_1344_results.csv", results, fieldnames)

    y_true = [1 if r["ground_truth"] == "AI" else 0 for r in ok]
    capped_scores = [float(r["capped_probability"]) for r in ok]
    full_scores = [float(r["fullres_step8b_probability"]) for r in ok]
    capped_auc = roc_auc(capped_scores, y_true)
    rho = spearman_rho(full_scores, capped_scores)

    real_p = [float(r["capped_probability"]) for r in ok if r["ground_truth"] == "REAL"]
    ai_p = [float(r["capped_probability"]) for r in ok if r["ground_truth"] == "AI"]

    gen_breakdown = []
    for gen in ("chatgpt", "gemini", "canva", "pixlr"):
        sub = [r for r in ok if r["source"] == gen]
        full_m = [float(r["fullres_step8b_probability"]) for r in sub]
        cap_m = [float(r["capped_probability"]) for r in sub]
        deltas = [float(r["probability_delta"]) for r in sub]
        gen_breakdown.append(
            {
                "generator": gen,
                "n": len(sub),
                "fullres_mean": statistics.mean(full_m) if full_m else None,
                "capped_1344_mean": statistics.mean(cap_m) if cap_m else None,
                "fullres_median": statistics.median(full_m) if full_m else None,
                "capped_1344_median": statistics.median(cap_m) if cap_m else None,
                "mean_probability_delta": statistics.mean(deltas) if deltas else None,
            }
        )
    write_csv(
        out_dir / "step8c2_generator_breakdown.csv",
        gen_breakdown,
        list(gen_breakdown[0].keys()),
    )

    gray = [r for r in ok if r["ground_truth"] == "REAL" and float(r["fullres_step8b_probability"]) >= 0.25]
    gray.sort(key=lambda r: -float(r["fullres_step8b_probability"]))
    gray_rows = []
    for r in gray:
        fp = float(r["fullres_step8b_probability"])
        cp = float(r["capped_probability"])
        gray_rows.append(
            {
                "filename": Path(r["filepath"]).name,
                "source": r["source"],
                "fullres_probability": fp,
                "capped_1344_probability": cp,
                "probability_delta": cp - fp,
                "fullres_patches": r["original_step8b_patch_count"],
                "capped_patches": r["capped_patch_count"],
                "original_dims": f"{r['original_width']}x{r['original_height']}",
                "inference_dims": f"{r['inference_width']}x{r['inference_height']}",
            }
        )
    write_csv(
        out_dir / "step8c2_real_analysis.csv",
        gray_rows,
        list(gray_rows[0].keys()) if gray_rows else ["filename"],
    )

    labels = [r["ground_truth"] for r in ok]
    diag = diag_05(capped_scores, labels)

    walls = [float(r["wall_seconds"]) for r in ok]
    cpus = [float(r["process_cpu_seconds"]) for r in ok]
    cap_patches = [int(r["capped_patch_count"]) for r in ok]
    full_patches = [int(r["original_step8b_patch_count"]) for r in ok]

    step8b_perf = json.loads((STEP8B_DIR / "step8b_summary.json").read_text(encoding="utf-8")).get("performance", {})

    summary = {
        "step8c2_status": "COMPLETE",
        "max_long_edge": MAX_LONG_EDGE,
        "production_behavior_changed": False,
        "dataset_integrity": integrity,
        "environment": env,
        "step8b_baseline_dir": str(STEP8B_DIR),
        "capped_1344_probe": {
            "ROC_AUC": capped_auc,
            "REAL": dist_stats(real_p),
            "AI": dist_stats(ai_p),
            "spearman_fullres_vs_capped": rho,
        },
        "step8b_fullres_baseline_reference": STEP8B_BASELINE,
        "author_0_5_diagnostic_only_capped_1344": diag,
        "author_0_5_diagnostic_only_step8b_reference": STEP8B_BASELINE["author_0_5"],
        "performance": {
            "total_wall_seconds": total_wall,
            "total_process_cpu_seconds": total_cpu,
            "median_wall_seconds_per_image": statistics.median(walls),
            "median_cpu_seconds_per_image": statistics.median(cpus),
            "p90_wall_seconds": quartile(walls, 0.90),
            "p95_wall_seconds": quartile(walls, 0.95),
            "max_wall_seconds": max(walls),
            "median_capped_patch_count": statistics.median(cap_patches),
            "max_capped_patch_count": max(cap_patches),
            "median_fullres_patch_count_step8b": statistics.median(full_patches),
            "max_fullres_patch_count_step8b": max(full_patches),
            "step8b_total_wall_seconds_reference": step8b_perf.get("total_wall_seconds"),
            "step8b_median_wall_seconds_reference": step8b_perf.get("median_seconds_per_image"),
        },
        "generator_breakdown": gen_breakdown,
        "real_grayzone_count": len(gray_rows),
        "output_dir": str(out_dir),
    }
    (out_dir / "step8c2_summary.json").write_text(json.dumps(summary, indent=2, default=str), encoding="utf-8")

    report = [
        "STEP 8C.2 STATUS: COMPLETE",
        f"max_long_edge={MAX_LONG_EDGE}",
        f"capped_ROC_AUC={capped_auc}",
        f"spearman_full_vs_cap={rho}",
        f"total_wall_s={total_wall:.1f}",
        "PRODUCTION BEHAVIOR CHANGED: NO",
        f"Output: {out_dir}",
    ]
    (out_dir / "step8c2_report.txt").write_text("\n".join(report), encoding="utf-8")
    print("\n".join(report))


if __name__ == "__main__":
    main()
