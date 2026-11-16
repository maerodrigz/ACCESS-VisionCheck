#!/usr/bin/env python3
"""Phase 13: technical image quality RUNTIME benchmark over SPAQ-200.

Measures per-stage latency of the technical image-quality pipeline at 512 /
1024 / 1600 px longest side:
  1. image decoding   (production app.services.image_orientation.decode_oriented_bgr)
  2. resizing         (proposed "cap longest side" policy, OpenCV INTER_AREA)
  3. OpenCV analysis  (production app.services.opencv_quality.analyze_bgr)
  4. Tenengrad        (matches tools.quality_validation.classical_quality_metrics.sharpness_tenengrad exactly)

Reports mean / median / p95 / max latency per stage per size, plus exploratory
Spearman rank correlation of each machine metric vs the existing SPAQ human
ratings. No thresholds, 1-5 maps, isotonic/ridge, or any fitting is performed;
correlations are read-only and exploratory.

Strict constraints honoured by this script:
  - No production code changes. It imports app.services.* and toolkit helpers
    read-only and never writes to app/ or ml/.
  - No EfficientNet / MUSIQ / WaveRep inference. Pure OpenCV + NumPy.
  - No dataset download. Uses the existing local SPAQ-200 JPEGs only.
  - No retraining.
  - Does not modify Phase 10-12 results. Writes only to a NEW phase13_run_001
    folder and a NEW top-level report (PHASE13_RUNTIME_BENCHMARK_REPORT.md).
  - Read-only to inputs; per-image failures are recorded, not fatal.

Usage (run from access_backend with the production venv that has cv2):

  venv312\\Scripts\\python.exe ..\\tools\\quality_validation\\phase13_runtime_benchmark.py

  # quick smoke (5 images):
  venv312\\Scripts\\python.exe ..\\tools\\quality_validation\\phase13_runtime_benchmark.py --limit 5

  # more stable per-image timing (slower):
  venv312\\Scripts\\python.exe ..\\tools\\quality_validation\\phase13_runtime_benchmark.py --repeat 3

  # list inputs / env without running inference:
  venv312\\Scripts\\python.exe ..\\tools\\quality_validation\\phase13_runtime_benchmark.py --dry-run
"""

from __future__ import annotations

import argparse
import csv
import json
import platform
import statistics
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# --- paths ------------------------------------------------------------------

_TOOLKIT = Path(__file__).resolve().parent                  # tools/quality_validation
_REPO = _TOOLKIT.parents[1]                                   # access_mobile
_BACKEND = _REPO / "access_backend"
for _p in (str(_BACKEND), str(_REPO)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

SPAQ_ROOT = _TOOLKIT / "workspace" / "datasets" / "spaq"
IMAGES = SPAQ_ROOT / "images"
SPAQ_CSV = SPAQ_ROOT / "output" / "run_001" / "spaq_200_machine_scores.csv"
DEFAULT_OUT = SPAQ_ROOT / "output" / "phase13_run_001"
TOP_REPORT = _TOOLKIT / "PHASE13_RUNTIME_BENCHMARK_REPORT.md"
SEED = 20261107
DEFAULT_SIZES = (512, 1024, 1600)

# Human fields available in the merged SPAQ CSV (existing SPAQ ratings, read-only).
HUMAN_FIELDS = {
    "mos_quality_raw",
    "attr_sharpness_raw",
    "attr_noisiness_raw",
    "attr_contrast_raw",
    "attr_brightness_raw",
}


# --- helpers ----------------------------------------------------------------

def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def percentile(values: list[float], q: float) -> float:
    if not values:
        return float("nan")
    s = sorted(values)
    if len(s) == 1:
        return float(s[0])
    pos = (len(s) - 1) * q
    lo = int(pos)
    hi = min(lo + 1, len(s) - 1)
    frac = pos - lo
    return float(s[lo] + (s[hi] - s[lo]) * frac)


def stat_block(values: list[float]) -> dict[str, Any]:
    if not values:
        return {"n": 0}
    return {
        "n": len(values),
        "min_ms": round(min(values), 4),
        "mean_ms": round(statistics.fmean(values), 4),
        "median_ms": round(statistics.median(values), 4),
        "p95_ms": round(percentile(values, 0.95), 4),
        "max_ms": round(max(values), 4),
    }


def fnum(row: dict[str, Any], key: str) -> float | None:
    v = row.get(key)
    if v is None or str(v).strip() == "":
        return None
    try:
        return float(v)
    except ValueError:
        return None


# --- imports (production + toolkit, read-only) ------------------------------

def import_runtime():
    """Import the production OpenCV analyzer + decode path + correlation helper.

    Raises SystemExit with a clear message if a dependency is unavailable.
    """
    missing = []
    for n in ("cv2", "numpy", "PIL"):
        try:
            __import__(n)
        except Exception as exc:  # noqa: BLE001
            missing.append(f"{n} ({type(exc).__name__}: {exc})")
    if missing:
        sys.exit("ABORT: missing runtime deps: " + ", ".join(missing)
                 + ". Use access_backend/venv312 (has cv2/numpy/PIL).")
    try:
        from app.services.image_orientation import decode_oriented_bgr
        from app.services.opencv_quality import analyze_bgr as prod_opencv_analyze_bgr, opencv_available
    except Exception as exc:  # noqa: BLE001
        sys.exit(f"ABORT: production OpenCV import failed ({type(exc).__name__}: {exc})")
    if not opencv_available():
        sys.exit("ABORT: opencv_available() is False in this interpreter")
    try:
        from tools.quality_validation.metrics import correlation_bootstrap
    except Exception as exc:  # noqa: BLE001
        sys.exit(f"ABORT: toolkit metrics import failed ({type(exc).__name__}: {exc})")
    return decode_oriented_bgr, prod_opencv_analyze_bgr, correlation_bootstrap


def env_block() -> dict[str, Any]:
    env: dict[str, Any] = {"python": sys.version.split()[0], "platform": platform.platform()}
    try:
        import os
        env["cpu_count"] = os.cpu_count() or 0
    except Exception:  # noqa: BLE001
        env["cpu_count"] = None
    for n in ("cv2", "numpy", "PIL"):
        try:
            m = __import__(n)
            env[n] = getattr(m, "__version__", "?")
        except Exception as exc:  # noqa: BLE001
            env[n] = f"ERR {exc}"
    return env


# --- pipeline stages (mirrors production / classical exactly) ---------------

def resize_to_longest(bgr, longest: int, inter):
    """Cap longest side at `longest`; never upscale (proposed resize policy)."""
    h, w = bgr.shape[:2]
    cur = max(h, w)
    if cur <= longest:
        return bgr
    scale = longest / float(cur)
    new_w = max(1, int(round(w * scale)))
    new_h = max(1, int(round(h * scale)))
    import cv2
    return cv2.resize(bgr, (new_w, new_h), interpolation=inter)


def tenengrad(bgr) -> float:
    """Tenengrad focus measure. Matches classical_quality_metrics.sharpness_tenengrad:
    gray=float64, Sobel ksize=3, mean(gx*gx + gy*gy)."""
    import cv2
    import numpy as np
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY).astype(np.float64)
    gx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    return float(np.mean(gx * gx + gy * gy))


def time_once(fn) -> tuple[float, Any]:
    t0 = time.perf_counter()
    out = fn()
    return (time.perf_counter() - t0) * 1000.0, out


def time_median(fn, repeats: int) -> tuple[float, Any]:
    """Return (median_ms over repeats, last result)."""
    samples: list[float] = []
    out = None
    for _ in range(max(1, repeats)):
        ms, out = time_once(fn)
        samples.append(ms)
    return float(statistics.median(samples)), out


# --- inputs -----------------------------------------------------------------

def load_rows(csv_path: Path) -> list[dict[str, str]]:
    with csv_path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def human_index(rows: list[dict[str, str]]) -> dict[str, dict[str, float | None]]:
    idx: dict[str, dict[str, float | None]] = {}
    for r in rows:
        key = r.get("source_media_key")
        if not key:
            continue
        idx[key] = {f: fnum(r, f) for f in HUMAN_FIELDS}
    return idx


# --- benchmark core ----------------------------------------------------------

def run_benchmark(rows, images_dir: Path, sizes, repeats: int, inter, decode_fn, opencv_fn, human_idx):
    import cv2
    # per-image stage samples (ms); decode is size-independent -> stored once
    decode_samples: dict[str, float] = {}            # key -> decode_ms
    per_size: dict[int, dict[str, list[float]]] = {}  # size -> stage -> [ms over images]
    for s in sizes:
        per_size[s] = {"resize": [], "opencv": [], "tenengrad": [], "pipeline": []}
    per_image_rows: list[dict[str, Any]] = []
    failures: list[dict[str, Any]] = []

    n = len(rows)
    for i, rec in enumerate(rows, start=1):
        key = rec.get("source_media_key", "")
        path = images_dir / key
        row_base = {"source_media_key": key}
        if not path.is_file():
            failures.append({"source_media_key": key, "error": "missing_file"})
            print(f"[P13 {i}/{n}] {key} SKIP missing_file", flush=True)
            continue
        try:
            content = path.read_bytes()
            decode_ms, bgr = time_median(lambda c=content: decode_fn(c), 1)
            if bgr is None:
                failures.append({"source_media_key": key, "error": "decode_none"})
                print(f"[P13 {i}/{n}] {key} SKIP decode_none", flush=True)
                continue
            decode_samples[key] = decode_ms
            native_h, native_w = bgr.shape[:2]

            size_summary: dict[int, float] = {}
            for s in sizes:
                rs_ms, resized = time_median(lambda b=bgr, ss=s: resize_to_longest(b, ss, inter), repeats)
                oc_ms, oc = time_median(lambda b=resized: opencv_fn(b), repeats)
                tg_ms, tg = time_median(lambda b=resized: tenengrad(b), repeats)
                pipe_ms = decode_ms + rs_ms + oc_ms + tg_ms

                per_size[s]["resize"].append(rs_ms)
                per_size[s]["opencv"].append(oc_ms)
                per_size[s]["tenengrad"].append(tg_ms)
                per_size[s]["pipeline"].append(pipe_ms)
                size_summary[s] = pipe_ms

                rh, rw = resized.shape[:2]
                per_image_rows.append({
                    "source_media_key": key,
                    "size": s,
                    "native_w": native_w,
                    "native_h": native_h,
                    "resized_w": rw,
                    "resized_h": rh,
                    "decode_ms": round(decode_ms, 4),
                    "resize_ms": round(rs_ms, 4),
                    "opencv_ms": round(oc_ms, 4),
                    "tenengrad_ms": round(tg_ms, 4),
                    "pipeline_ms": round(pipe_ms, 4),
                    "opencv_sharpness": oc.get("sharpness"),
                    "opencv_noise": oc.get("noise"),
                    "opencv_contrast": oc.get("contrast"),
                    "opencv_brightness": oc.get("brightness"),
                    "tenengrad": tg,
                    "ok": True,
                })
            print(f"[P13 {i}/{n}] {key} decode={decode_ms:.1f}ms "
                  f"512:{size_summary.get(512, 0):.0f} 1024:{size_summary.get(1024, 0):.0f} "
                  f"1600:{size_summary.get(1600, 0):.0f}ms (pipeline)", flush=True)
        except Exception as exc:  # noqa: BLE001
            failures.append({"source_media_key": key, "error": f"{type(exc).__name__}: {exc}"})
            print(f"[P13 {i}/{n}] {key} ERR {type(exc).__name__}: {exc}", flush=True)

    return {
        "decode_samples": decode_samples,
        "per_size": per_size,
        "per_image_rows": per_image_rows,
        "failures": failures,
    }


def correlations(per_image_rows, human_idx, corr_fn):
    """Exploratory Spearman/Pearson vs SPAQ human ratings, per size. No fitting."""
    by_size_metric: dict[int, dict[str, list[float]]] = {}
    by_size_human: dict[int, dict[str, list[float]]] = {}
    for r in per_image_rows:
        if not r.get("ok"):
            continue
        s = r["size"]
        key = r["source_media_key"]
        h = human_idx.get(key, {})
        by_size_metric.setdefault(s, {"opencv_sharpness": [], "opencv_noise": [],
                                      "tenengrad": [], "opencv_contrast": [], "opencv_brightness": []})
        by_size_human.setdefault(s, {"opencv_sharpness": [], "opencv_noise": [],
                                     "tenengrad": [], "opencv_contrast": [], "opencv_brightness": []})
        pairs = [
            ("opencv_sharpness", r.get("opencv_sharpness"), h.get("attr_sharpness_raw")),
            ("opencv_noise", r.get("opencv_noise"), h.get("attr_noisiness_raw")),
            ("tenengrad", r.get("tenengrad"), h.get("attr_sharpness_raw")),
            ("opencv_contrast", r.get("opencv_contrast"), h.get("attr_contrast_raw")),
            ("opencv_brightness", r.get("opencv_brightness"), h.get("attr_brightness_raw")),
        ]
        for metric, m_val, h_val in pairs:
            if m_val is None or h_val is None:
                continue
            by_size_metric[s][metric].append(float(m_val))
            by_size_human[s][metric].append(float(h_val))

    out: dict[int, list[dict[str, Any]]] = {}
    for s in sorted(by_size_metric):
        rows_out = []
        for metric in ("opencv_sharpness", "opencv_noise", "tenengrad", "opencv_contrast", "opencv_brightness"):
            m = by_size_metric[s][metric]
            h = by_size_human[s][metric]
            if len(m) < 5:
                rows_out.append({"metric": metric, "n": len(m), "spearman_r": None, "note": "n<5"})
                continue
            boot = corr_fn(m, h, seed=SEED, n_boot=400)
            rows_out.append({
                "metric": metric,
                "n": len(m),
                "spearman_r": boot.get("spearman_r"),
                "spearman_ci_low": boot.get("spearman_ci_low"),
                "spearman_ci_high": boot.get("spearman_ci_high"),
                "pearson_r": boot.get("pearson_r"),
            })
        out[s] = rows_out
    return out


# --- reports ----------------------------------------------------------------

def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields: list[str] = []
    for r in rows:
        for k in r:
            if k not in fields:
                fields.append(k)
    with path.open("w", newline="", encoding="utf-8") as handle:
        w = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def write_report(path: Path, p: dict[str, Any]) -> None:
    lines = [
        "# Phase 13 runtime benchmark: technical image quality on SPAQ-200",
        "",
        f"**Generated:** {p['generated_at']}",
        "",
        "Per-stage latency (decode / resize / OpenCV analysis / Tenengrad) at "
        "512 / 1024 / 1600 px longest side, plus exploratory Spearman vs the "
        "existing SPAQ human ratings. No thresholds fitted. No EfficientNet, "
        "MUSIQ, or WaveRep inference. No production code changes. No dataset "
        "download. Phase 10-12 outputs untouched.",
        "",
        "## Environment",
        "",
        "| Key | Value |",
        "|---|---|",
    ]
    for k, v in p["environment"].items():
        lines.append(f"| {k} | `{v}` |")
    lines += ["", "## Config", "", "| Key | Value |", "|---|---|"]
    for k, v in p["config"].items():
        lines.append(f"| {k} | `{v}` |")
    lines += [f"- images_found: `{p['images_found']}`", f"- images_scored: `{p['images_scored']}`",
              f"- failures: `{len(p['failures'])}`", ""]

    lines.append("## Latency by stage and size (ms, over per-image stage medians)")
    lines.append("")
    lines.append("Decode is size-independent (decoded once at native resolution); "
                 "the same decode value is shown for every size for completeness.")
    lines.append("")
    lines.append("| Stage | Size | n | min | mean | median | p95 | max |")
    lines.append("|---|---|---|---|---|---|---|---|")
    ds = p["decode_stats"]
    for s in p["sizes"]:
        # decode is size-independent (decoded once at native resolution)
        lines.append(f"| decode | {s} | {ds.get('n')} | {ds.get('min_ms')} | {ds.get('mean_ms')} | "
                     f"{ds.get('median_ms')} | {ds.get('p95_ms')} | {ds.get('max_ms')} |")
        for stage in ("resize", "opencv", "tenengrad", "pipeline"):
            sb = p["per_size"][str(s)][stage]
            lines.append(f"| {stage} | {s} | {sb.get('n')} | {sb.get('min_ms')} | {sb.get('mean_ms')} | "
                         f"{sb.get('median_ms')} | {sb.get('p95_ms')} | {sb.get('max_ms')} |")
    lines += ["", "## Exploratory rank correlation vs SPAQ human ratings (no fitting)",
              "", "| Size | Metric | n | Spearman r | 95% CI | Pearson r |",
              "|---|---|---|---|---|---|"]
    for s in p["sizes"]:
        for c in p["correlations"].get(str(s), []):
            ci = (f"{c.get('spearman_ci_low')}, {c.get('spearman_ci_high')}"
                  if c.get("spearman_r") is not None else "-")
            lines.append(f"| {s} | {c['metric']} | {c.get('n')} | "
                         f"{c.get('spearman_r')} | {ci} | {c.get('pearson_r')} |")
    lines += ["",
              "Correlations are exploratory and computed on the locked SPAQ-200. "
              "They are NOT used to fit thresholds, 1-5 maps, or calibration. "
              "No production decision is made here.",
              "", "## Failures", ""]
    if p["failures"]:
        for f in p["failures"][:50]:
            lines.append(f"- `{f['source_media_key']}`: {f['error']}")
        if len(p["failures"]) > 50:
            lines.append(f"- ... ({len(p['failures'])} total)")
    else:
        lines.append("None.")
    lines += ["", "No production code was changed. No Phase 10-12 result was modified.",
              "", f"Artifacts: `{p['config']['output_dir']}`"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


# --- main -------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--images", type=Path, default=IMAGES, help="SPAQ images dir")
    ap.add_argument("--csv", type=Path, default=SPAQ_CSV, help="merged SPAQ scores CSV (human ratings source)")
    ap.add_argument("--sizes", default="512,1024,1600", help="comma list of longest-side px")
    ap.add_argument("--output", type=Path, default=DEFAULT_OUT, help="output dir (phase13_run_001)")
    ap.add_argument("--repeat", type=int, default=1, help="repeats per stage; median used (default 1)")
    ap.add_argument("--limit", type=int, default=None, help="cap number of images (smoke)")
    ap.add_argument("--warmup", type=int, default=1, help="warmup images, timings discarded (default 1)")
    ap.add_argument("--inter", default="area", choices=["area", "linear", "cubic"], help="resize interpolation")
    ap.add_argument("--dry-run", action="store_true", help="list inputs + env, no inference")
    ap.add_argument("--no-correlation", action="store_true", help="skip Spearman computation")
    return ap


def main() -> int:
    args = build_parser().parse_args()
    sizes = [int(x) for x in args.sizes.split(",") if x.strip()]
    inter_map = {"area": 0, "linear": 1, "cubic": 2}  # cv2.INTER_AREA/LINEAR/CUBIC placeholders
    import cv2
    inter = {"area": cv2.INTER_AREA, "linear": cv2.INTER_LINEAR, "cubic": cv2.INTER_CUBIC}[args.inter]

    env = env_block()
    print(f"[P13] backend={_BACKEND}", flush=True)
    print(f"[P13] sizes={sizes} repeat={args.repeat} inter={args.inter} warmup={args.warmup} "
          f"limit={args.limit} dry_run={args.dry_run}", flush=True)
    print(f"[P13] images_dir={args.images} exists={args.images.is_dir()}", flush=True)
    print(f"[P13] csv={args.csv} exists={args.csv.is_file()}", flush=True)

    rows = load_rows(args.csv) if args.csv.is_file() else []
    if args.limit is not None:
        rows = rows[: args.limit]
    human_idx = human_index(rows)
    print(f"[P13] rows={len(rows)} human_entries={len(human_idx)}", flush=True)

    cfg = {
        "images_dir": str(args.images),
        "csv": str(args.csv),
        "sizes": sizes,
        "repeat": args.repeat,
        "limit": args.limit,
        "warmup": args.warmup,
        "inter": args.inter,
        "output_dir": str(args.output),
        "no_correlation": args.no_correlation,
    }

    if args.dry_run:
        # count images that actually exist
        exist = sum(1 for r in rows if (args.images / r.get("source_media_key", "")).is_file())
        print(f"[P13] dry-run: existing images referenced in csv = {exist}", flush=True)
        print(json.dumps({"dry_run": True, "rows": len(rows), "existing_images": exist,
                          "environment": env, "config": cfg}, indent=2, default=str), flush=True)
        return 0 if rows else 2

    if not rows:
        print("[P13] ABORT: no rows in CSV", file=sys.stderr, flush=True)
        return 2

    decode_fn, opencv_fn, corr_fn = import_runtime()

    # warmup (discard timings)
    if args.warmup > 0 and rows:
        for rec in rows[: args.warmup]:
            key = rec.get("source_media_key", "")
            p = args.images / key
            if not p.is_file():
                continue
            try:
                bgr = decode_fn(p.read_bytes())
                if bgr is not None:
                    r = resize_to_longest(bgr, sizes[0], inter)
                    opencv_fn(r)
                    tenengrad(r)
            except Exception:  # noqa: BLE001
                pass
        print(f"[P13] warmup done ({args.warmup} image(s), timings discarded)", flush=True)

    t0 = time.perf_counter()
    res = run_benchmark(rows, args.images, sizes, max(1, args.repeat), inter, decode_fn, opencv_fn, human_idx)
    wall_s = time.perf_counter() - t0
    print(f"[P13] run complete in {wall_s:.1f}s", flush=True)

    decode_stats = stat_block(list(res["decode_samples"].values()))
    per_size_stats = {str(s): {stage: stat_block(res["per_size"][s][stage]) for stage in
                       ("resize", "opencv", "tenengrad", "pipeline")} for s in sizes}

    corr = {} if args.no_correlation else correlations(res["per_image_rows"], human_idx, corr_fn)

    payload = {
        "generated_at": now_iso(),
        "environment": env,
        "config": cfg,
        "sizes": sizes,
        "images_found": len(rows),
        "images_scored": len(res["decode_samples"]),
        "failures": res["failures"],
        "wall_seconds": round(wall_s, 2),
        "decode_stats": decode_stats,
        "per_size": per_size_stats,
        "correlations": corr,
        "notes": [
            "Runtime (latency/throughput) benchmark only. Not an accuracy study.",
            "Decode uses production app.services.image_orientation.decode_oriented_bgr (PIL EXIF -> BGR).",
            "OpenCV analysis uses production app.services.opencv_quality.analyze_bgr (Laplacian-var/420 sharpness, residual-std/36 noise).",
            "Tenengrad matches classical_quality_metrics.sharpness_tenengrad (Sobel ksize=3, mean gx^2+gy^2).",
            "Resize policy = cap longest side; no upscaling (INTER_AREA).",
            "Spearman correlations are exploratory vs SPAQ human ratings; no thresholds/maps were fitted.",
            "No production code changed. No EfficientNet/MUSIQ/WaveRep inference. No dataset download.",
        ],
    }

    out_dir = args.output
    json_path = out_dir / "phase13_runtime_metrics.json"
    csv_path = out_dir / "phase13_per_image.csv"
    write_json(json_path, payload)
    write_csv(csv_path, res["per_image_rows"])
    write_report(out_dir / "PHASE13_RUNTIME_BENCHMARK_REPORT.md", payload)
    write_report(TOP_REPORT, payload)

    print("[P13] ---- summary ----", flush=True)
    print(json.dumps({
        "images_scored": payload["images_scored"],
        "failures": len(payload["failures"]),
        "wall_seconds": payload["wall_seconds"],
        "decode_median_ms": decode_stats.get("median_ms"),
        "per_size": {s: {st: per_size_stats[str(s)][st]["median_ms"]
                          for st in ("resize", "opencv", "tenengrad", "pipeline")} for s in sizes},
        "json": str(json_path),
        "csv": str(csv_path),
        "report": str(TOP_REPORT),
    }, indent=2, default=str), flush=True)
    print("PHASE13_DONE", flush=True)
    return 0 if payload["images_scored"] > 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
