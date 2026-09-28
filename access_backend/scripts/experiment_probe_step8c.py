"""
Step 8C: Diagnostic analysis of Step 8B PROBE results (no model inference).

Usage:
  cd access_backend
  python scripts/experiment_probe_step8c.py
"""

from __future__ import annotations

import csv
import json
import math
import statistics
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
STEP8B_DIR = ROOT / "evaluation_results" / "step8b" / "20260927_040610"
STEP8B_LOG = ROOT / "experiments" / "probe" / "step8b_run_2.log"

PATCH_BUCKETS = [
    ("1-10", 1, 10),
    ("11-25", 11, 25),
    ("26-50", 26, 50),
    ("51-75", 51, 75),
    ("76-100", 76, 100),
    ("101+", 101, 10_000),
]


def spearman(x: list[float], y: list[float]) -> float | None:
    if len(x) != len(y) or len(x) < 2:
        return None
    n = len(x)

    def ranks(vals: list[float]) -> list[float]:
        order = sorted(range(n), key=lambda i: vals[i])
        r = [0.0] * n
        i = 0
        while i < n:
            j = i
            while j + 1 < n and vals[order[j + 1]] == vals[order[i]]:
                j += 1
            avg = (i + j) / 2.0 + 1.0
            for k in range(i, j + 1):
                r[order[k]] = avg
            i = j + 1
        return r

    rx, ry = ranks(x), ranks(y)
    mx, my = statistics.mean(rx), statistics.mean(ry)
    num = sum((rx[i] - mx) * (ry[i] - my) for i in range(n))
    den_x = math.sqrt(sum((rx[i] - mx) ** 2 for i in range(n)))
    den_y = math.sqrt(sum((ry[i] - my) ** 2 for i in range(n)))
    if den_x == 0 or den_y == 0:
        return None
    return num / (den_x * den_y)


def pearson(x: list[float], y: list[float]) -> float | None:
    if len(x) != len(y) or len(x) < 2:
        return None
    n = len(x)
    mx, my = statistics.mean(x), statistics.mean(y)
    num = sum((x[i] - mx) * (y[i] - my) for i in range(n))
    den_x = math.sqrt(sum((x[i] - mx) ** 2 for i in range(n)))
    den_y = math.sqrt(sum((y[i] - my) ** 2 for i in range(n)))
    if den_x == 0 or den_y == 0:
        return None
    return num / (den_x * den_y)


def load_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def file_props(path: Path) -> dict[str, Any]:
    ext = path.suffix.lower().lstrip(".")
    fmt = ext.upper() if ext else "UNKNOWN"
    is_jpeg = ext in ("jpg", "jpeg")
    is_png = ext == "png"
    size_bytes = path.stat().st_size if path.is_file() else None
    exif_present = False
    w = h = None
    if path.is_file():
        try:
            with Image.open(path) as im:
                w, h = im.size
                exif = im.getexif()
                exif_present = bool(exif and len(exif) > 0)
        except Exception:
            pass
    mp = (w * h / 1_000_000.0) if w and h else None
    aspect = (w / h) if w and h and h else None
    return {
        "file_format": fmt,
        "is_jpeg": is_jpeg,
        "is_png": is_png,
        "file_size_bytes": size_bytes,
        "file_size_kb": round(size_bytes / 1024.0, 2) if size_bytes else None,
        "image_width_file": w,
        "image_height_file": h,
        "megapixels": round(mp, 4) if mp else None,
        "aspect_ratio": round(aspect, 4) if aspect else None,
        "exif_present": exif_present,
    }


def quartiles(vals: list[float]) -> dict[str, float]:
    s = sorted(vals)
    n = len(s)

    def q(p: float) -> float:
        if n == 1:
            return s[0]
        idx = p * (n - 1)
        lo = int(math.floor(idx))
        hi = int(math.ceil(idx))
        if lo == hi:
            return s[lo]
        return s[lo] + (s[hi] - s[lo]) * (idx - lo)

    return {
        "min": s[0],
        "q1": q(0.25),
        "median": q(0.5),
        "q3": q(0.75),
        "p90": q(0.90),
        "p95": q(0.95),
        "max": s[-1],
        "mean": statistics.mean(s),
    }


def write_csv(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow(row)


def main() -> None:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = ROOT / "evaluation_results" / "step8c" / stamp
    out_dir.mkdir(parents=True, exist_ok=True)

    probe_rows = load_csv(STEP8B_DIR / "step8b_probe_results.csv")
    summary8b = json.loads((STEP8B_DIR / "step8b_summary.json").read_text(encoding="utf-8"))

    enriched: list[dict[str, Any]] = []
    for r in probe_rows:
        fp = Path(r["filepath"])
        props = file_props(fp)
        patches = int(r["number_of_patches"])
        sec = float(r["inference_seconds"])
        row = {
            **r,
            **props,
            "probe_probability": float(r["probe_probability"]) if r.get("probe_probability") else None,
            "raw_univfd_probability": float(r["raw_univfd_probability"])
            if r.get("raw_univfd_probability") not in (None, "")
            else None,
            "number_of_patches": patches,
            "inference_seconds": sec,
            "seconds_per_patch": round(sec / patches, 4) if patches else None,
        }
        enriched.append(row)

    ai_rows = [r for r in enriched if r["ground_truth"] == "AI"]
    ai_out: list[dict] = []
    for r in ai_rows:
        ai_out.append(
            {
                "filename": r["filename"],
                "generator": r["source"],
                "width": r["image_width"] or r["image_width_file"],
                "height": r["image_height"] or r["image_height_file"],
                "aspect_ratio": r["aspect_ratio"],
                "file_format": r["file_format"],
                "file_size_bytes": r["file_size_bytes"],
                "megapixels": r["megapixels"],
                "number_of_patches": r["number_of_patches"],
                "is_jpeg": r["is_jpeg"],
                "is_png": r["is_png"],
                "exif_present": r["exif_present"],
                "probe_probability": r["probe_probability"],
                "raw_univfd_probability": r["raw_univfd_probability"],
                "inference_seconds": r["inference_seconds"],
            }
        )
    write_csv(
        out_dir / "step8c_ai_generator_analysis.csv",
        ai_out,
        list(ai_out[0].keys()) if ai_out else [],
    )

    gray = [
        r
        for r in enriched
        if r["ground_truth"] == "REAL" and r["probe_probability"] is not None and r["probe_probability"] >= 0.25
    ]
    gray.sort(key=lambda x: -x["probe_probability"])
    gray_out = []
    for r in gray:
        gray_out.append(
            {
                "filename": r["filename"],
                "source": r["source"],
                "width": r["image_width"] or r["image_width_file"],
                "height": r["image_height"] or r["image_height_file"],
                "file_format": r["file_format"],
                "file_size_bytes": r["file_size_bytes"],
                "number_of_patches": r["number_of_patches"],
                "probe_probability": r["probe_probability"],
                "raw_univfd_probability": r["raw_univfd_probability"],
                "exif_present": r["exif_present"],
            }
        )
    write_csv(
        out_dir / "step8c_real_grayzone_analysis.csv",
        gray_out,
        list(gray_out[0].keys()) if gray_out else [
            "filename",
            "source",
            "width",
            "height",
            "file_format",
            "file_size_bytes",
            "number_of_patches",
            "probe_probability",
            "raw_univfd_probability",
            "exif_present",
        ],
    )

    runtime_out = []
    for r in enriched:
        runtime_out.append(
            {
                "filename": r["filename"],
                "ground_truth": r["ground_truth"],
                "source": r["source"],
                "file_format": r["file_format"],
                "file_size_bytes": r["file_size_bytes"],
                "width": r["image_width"] or r["image_width_file"],
                "height": r["image_height"] or r["image_height_file"],
                "megapixels": r["megapixels"],
                "number_of_patches": r["number_of_patches"],
                "inference_seconds": r["inference_seconds"],
                "seconds_per_patch": r["seconds_per_patch"],
                "probe_probability": r["probe_probability"],
            }
        )
    write_csv(out_dir / "step8c_runtime_analysis.csv", runtime_out, list(runtime_out[0].keys()))

    group_rows = []
    for label, lo, hi in PATCH_BUCKETS:
        bucket = [r for r in enriched if lo <= r["number_of_patches"] <= hi]
        if not bucket:
            group_rows.append(
                {
                    "patch_range": label,
                    "n": 0,
                    "median_runtime_s": None,
                    "mean_runtime_s": None,
                    "median_seconds_per_patch": None,
                }
            )
            continue
        times = [r["inference_seconds"] for r in bucket]
        spp = [r["seconds_per_patch"] for r in bucket if r["seconds_per_patch"]]
        group_rows.append(
            {
                "patch_range": label,
                "n": len(bucket),
                "median_runtime_s": round(statistics.median(times), 2),
                "mean_runtime_s": round(statistics.mean(times), 2),
                "median_seconds_per_patch": round(statistics.median(spp), 4) if spp else None,
            }
        )
    write_csv(
        out_dir / "step8c_runtime_groups.csv",
        group_rows,
        ["patch_range", "n", "median_runtime_s", "mean_runtime_s", "median_seconds_per_patch"],
    )

    times_all = [r["inference_seconds"] for r in enriched]
    rt_q = quartiles(times_all)
    spp_all = [r["seconds_per_patch"] for r in enriched if r["seconds_per_patch"]]
    median_spp = statistics.median(spp_all)

    def gen_stats(gen: str) -> dict:
        g = [r for r in ai_rows if r["source"] == gen]
        probs = [r["probe_probability"] for r in g if r["probe_probability"] is not None]
        return {
            "n": len(g),
            "probe_mean": statistics.mean(probs) if probs else None,
            "probe_median": statistics.median(probs) if probs else None,
            "probe_min": min(probs) if probs else None,
            "probe_max": max(probs) if probs else None,
            "widths": sorted(set(r["image_width"] or r["image_width_file"] for r in g)),
            "formats": sorted(set(r["file_format"] for r in g)),
            "patches": [r["number_of_patches"] for r in g],
        }

    by_gen = {g: gen_stats(g) for g in ("chatgpt", "gemini", "canva", "pixlr")}

    def corr_probe(field: str, subset: list[dict]) -> float | None:
        xs, ys = [], []
        for r in subset:
            v = r.get(field)
            p = r.get("probe_probability")
            if v is not None and p is not None:
                xs.append(float(v))
                ys.append(float(p))
        return spearman(xs, ys)

    ai_correlations = {
        "probe_vs_patches_spearman": corr_probe("number_of_patches", ai_rows),
        "probe_vs_megapixels_spearman": corr_probe("megapixels", ai_rows),
        "probe_vs_file_size_spearman": corr_probe("file_size_bytes", ai_rows),
        "probe_vs_aspect_spearman": corr_probe("aspect_ratio", ai_rows),
        "runtime_vs_patches_pearson_excl_outliers": None,
    }

    outlier_names = {
        "IMG_20230512_103539_795.jpg",
        "IMG_20230612_173018_154.jpg",
    }
    normal = [r for r in enriched if r["filename"] not in outlier_names]
    ai_correlations["runtime_vs_patches_pearson_excl_outliers"] = pearson(
        [r["number_of_patches"] for r in normal],
        [r["inference_seconds"] for r in normal],
    )
    ai_correlations["runtime_vs_patches_pearson_all"] = pearson(
        [r["number_of_patches"] for r in enriched],
        [r["inference_seconds"] for r in enriched],
    )

    similar_63 = [
        r
        for r in enriched
        if 51 <= r["number_of_patches"] <= 75 and r["filename"] != "IMG_20230512_103539_795.jpg"
    ]
    outlier_row = next(r for r in enriched if r["filename"] == "IMG_20230512_103539_795.jpg")

    log_evidence = None
    if STEP8B_LOG.is_file():
        raw = STEP8B_LOG.read_bytes()
        try:
            text = raw.decode("utf-16")
        except UnicodeDecodeError:
            text = raw.decode("utf-8", errors="replace")
        if "33656" in text and "103539_795" in text:
            log_evidence = "step8b_run_2.log records [54/100] patches=63 t=33656.8s for IMG_20230512_103539_795.jpg"

    plausible_outlier = {
        "filename": outlier_row["filename"],
        "patches": outlier_row["number_of_patches"],
        "recorded_seconds": outlier_row["inference_seconds"],
        "seconds_per_patch": outlier_row["seconds_per_patch"],
        "compare_51_75_patch_median_runtime": statistics.median([r["inference_seconds"] for r in similar_63])
        if similar_63
        else None,
        "compare_130_patch_median_runtime": statistics.median(
            [r["inference_seconds"] for r in enriched if r["number_of_patches"] == 130]
        ),
        "compare_130_patch_median_sec_per_patch": statistics.median(
            [r["seconds_per_patch"] for r in enriched if r["number_of_patches"] == 130]
        ),
        "timing_method": "perf_counter wall time per image in experiment_probe_step8b.py",
        "log_evidence": log_evidence,
        "assessment": (
            "NOT plausibly continuous CPU inference at observed sec/patch (~534 s/patch vs ~4–5 s/patch "
            "for other 51–130 patch phone photos). Elapsed timer likely includes machine sleep, suspension, "
            "or long scheduling gap (B/D). Insufficient evidence to distinguish B vs D vs CPU throttling; "
            "E (pure timing bug) unlikely given consistent logging."
        ),
        "classification": "B_or_D_likely_sleep_or_interruption_not_pure_compute",
    }

    gemini_table = [r for r in ai_out if r["generator"] == "gemini"]
    gemini_table.sort(key=lambda x: x["probe_probability"] or 0)

    summary = {
        "step8c_status": "COMPLETE",
        "step8b_input_dir": str(STEP8B_DIR),
        "output_dir": str(out_dir),
        "production_behavior_changed": False,
        "dataset": summary8b.get("dataset"),
        "ai_by_generator": by_gen,
        "ai_correlations_spearman_probe": {
            k: v for k, v in ai_correlations.items() if "probe" in k
        },
        "runtime_quartiles_seconds": rt_q,
        "median_seconds_per_patch_all": median_spp,
        "runtime_correlations": {
            k: v for k, v in ai_correlations.items() if "runtime" in k
        },
        "patch_runtime_groups": group_rows,
        "real_grayzone_count_probe_ge_0.25": len(gray_out),
        "outlier_9_35h": plausible_outlier,
        "gemini_individual": gemini_table,
    }

    (out_dir / "step8c_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    report_lines = [
        f"STEP 8C STATUS: COMPLETE",
        f"Output: {out_dir}",
        f"Step 8B source: {STEP8B_DIR}",
        "",
        "No model inference performed.",
        "PRODUCTION BEHAVIOR CHANGED: NO",
    ]
    (out_dir / "step8c_report.txt").write_text("\n".join(report_lines), encoding="utf-8")
    print(out_dir)


if __name__ == "__main__":
    main()
