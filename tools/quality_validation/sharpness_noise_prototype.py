#!/usr/bin/env python3
"""ACCESS VisionCheck — isolated research prototype: Tenengrad Sharpness + OpenCV
residual Noise at a 1024 px resize cap, compared against the existing production
raw scores and 1-5 badges.

Research-only. Does NOT modify production scoring, does NOT switch engines, does
NOT fit any thresholds on SPAQ-200, does NOT download data, does NOT run
EfficientNet / MUSIQ / WaveRep. It imports production analyzers read-only
(app.services.image_orientation, app.services.opencv_quality) and the toolkit
correlation helper.

Direction contract:
  - Tenengrad sharpness: RAW ENERGY, higher = sharper = BETTER quality.
  - OpenCV residual noise: RAW AMOUNT (std of high-pass residual), higher = MORE
    NOISE = WORSE quality. The member-facing "Noise" badge is a CLEANLINESS score
    (higher = less noise = better), so a quality badge must INVERT this axis.

What it measures on each SPAQ-200 image (at 1024 px longest side, INTER_AREA, no
upscale):
  - tenengrad            : mean(gx*gx + gy*gy), Sobel ksize=3 (matches classical)
  - residual_noise_std   : std(|gray - GaussianBlur(gray,5,5)|) (the raw amount;
                           production opencv noise == this / 36)
  - opencv_sharpness_1024: production analyze_bgr sharpness (Laplacian var / 420)
  - opencv_noise_1024    : production analyze_bgr noise (residual std / 36)

It joins these to the existing SPAQ merged CSV columns (read-only):
  prod_raw_sharpness, prod_raw_noise, prod_crit_sharpness, prod_crit_noise,
  attr_sharpness_raw, attr_noisiness_raw, overall_score.

It then reports:
  - distributions of candidate raw vs production raw (min/median/mean/p95/max, n_unique)
  - production badge distributions (criterion_Sharpness, criterion_Noise 1-5 counts)
  - ILLUSTRATIVE candidate badge distributions by feeding the production [0,1]
    metrics (opencv_sharpness_1024, cleanliness = 1 - opencv_noise_1024) through
    the EXISTING _soft_score, to expose the compression behaviour (NOT a fitted
    calibration; no SPAQ percentiles are used)
  - the _soft_score compression analysis (formula, thresholds, unreachable-1 proof,
    noise-cleanliness restricted range)
  - exploratory Spearman vs SPAQ human ratings and vs production raw (NO fitting)

Outputs (NEW folder, does not touch Phase 10-13 outputs):
  sharpness_noise_prototype/sharpness_noise_prototype.csv
  sharpness_noise_prototype/sharpness_noise_prototype.json
"""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for _p in (str(_BACKEND), str(_REPO)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

SPAQ_ROOT = _TOOLKIT / "workspace" / "datasets" / "spaq"
IMAGES = SPAQ_ROOT / "images"
SPAQ_CSV = SPAQ_ROOT / "output" / "run_001" / "spaq_200_machine_scores.csv"
DEFAULT_OUT = SPAQ_ROOT / "output" / "sharpness_noise_prototype"
RESIZE_CAP = 1024
SEED = 20261107

# Production _soft_score (copied EXACTLY from media_evaluator._soft_score for the
# illustrative compression analysis; never modified, never used to fit anything).
def _soft_score(metric: float) -> int:
    boosted = max(0.0, min(1.0, metric * 0.5 + 0.42))
    if boosted >= 0.80:
        return 5
    if boosted >= 0.64:
        return 4
    if boosted >= 0.46:
        return 3
    if boosted >= 0.28:
        return 2
    return 1


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
    return float(s[lo] + (s[hi] - s[lo]) * (pos - lo))


def dist(values: list[float]) -> dict[str, Any]:
    if not values:
        return {"n": 0}
    return {
        "n": len(values),
        "min": round(min(values), 6),
        "p5": round(percentile(values, 0.05), 6),
        "median": round(statistics.median(values), 6),
        "mean": round(statistics.fmean(values), 6),
        "p95": round(percentile(values, 0.95), 6),
        "max": round(max(values), 6),
        "n_unique": len({round(v, 6) for v in values}),
    }


def badge_counts(values: list[int]) -> dict[str, int]:
    out = {str(k): 0 for k in range(1, 6)}
    for v in values:
        k = int(v)
        if 1 <= k <= 5:
            out[str(k)] += 1
    return out


def fnum(row: dict[str, Any], key: str) -> float | None:
    v = row.get(key)
    if v is None or str(v).strip() == "":
        return None
    try:
        return float(v)
    except ValueError:
        return None


def import_runtime():
    missing = []
    for n in ("cv2", "numpy", "PIL"):
        try:
            __import__(n)
        except Exception as exc:  # noqa: BLE001
            missing.append(f"{n} ({exc})")
    if missing:
        sys.exit("ABORT: missing deps: " + ", ".join(missing) + " (use access_backend/venv312)")
    from app.services.image_orientation import decode_oriented_bgr
    from app.services.opencv_quality import analyze_bgr as prod_opencv_analyze, opencv_available
    if not opencv_available():
        sys.exit("ABORT: opencv_available() is False")
    from tools.quality_validation.metrics import correlation_bootstrap
    return decode_oriented_bgr, prod_opencv_analyze, correlation_bootstrap


def resize_to_longest(bgr, longest: int):
    import cv2
    h, w = bgr.shape[:2]
    if max(h, w) <= longest:
        return bgr
    scale = longest / float(max(h, w))
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    return cv2.resize(bgr, (nw, nh), interpolation=cv2.INTER_AREA)


def tenengrad(bgr) -> float:
    import cv2
    import numpy as np
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY).astype(np.float64)
    gx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    return float(np.mean(gx * gx + gy * gy))


def residual_noise_std(bgr) -> float:
    import cv2
    import numpy as np
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    g8 = np.clip(gray, 0, 255).astype(np.uint8)
    blur = cv2.GaussianBlur(g8, (5, 5), 0)
    return float(np.std(np.abs(g8.astype(np.float64) - blur.astype(np.float64))))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--images", type=Path, default=IMAGES)
    ap.add_argument("--csv", type=Path, default=SPAQ_CSV)
    ap.add_argument("--output", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--cap", type=int, default=RESIZE_CAP)
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--warmup", type=int, default=1)
    args = ap.parse_args()

    decode_fn, opencv_fn, corr_fn = import_runtime()
    import cv2

    rows = []
    with args.csv.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    if args.limit is not None:
        rows = rows[: args.limit]
    print(f"[PROTO] rows={len(rows)} cap={args.cap} images={args.images}", flush=True)

    # warmup
    if args.warmup and rows:
        k = rows[0].get("source_media_key", "")
        p = args.images / k
        if p.is_file():
            try:
                b = decode_fn(p.read_bytes())
                if b is not None:
                    r = resize_to_longest(b, args.cap)
                    opencv_fn(r)
                    tenengrad(r)
                    residual_noise_std(r)
            except Exception:  # noqa: BLE001
                pass
        print("[PROTO] warmup done (timings discarded)", flush=True)

    per_image: list[dict[str, Any]] = []
    failures: list[dict[str, Any]] = []
    t0 = time.perf_counter()
    n = len(rows)
    for i, rec in enumerate(rows, start=1):
        key = rec.get("source_media_key", "")
        p = args.images / key
        if not p.is_file():
            failures.append({"source_media_key": key, "error": "missing_file"})
            print(f"[PROTO {i}/{n}] {key} SKIP missing_file", flush=True)
            continue
        try:
            bgr = decode_fn(p.read_bytes())
            if bgr is None:
                failures.append({"source_media_key": key, "error": "decode_none"})
                continue
            nh, nw = bgr.shape[:2]
            r = resize_to_longest(bgr, args.cap)
            rh, rw = r.shape[:2]
            tg = tenengrad(r)
            rn = residual_noise_std(r)
            oc = opencv_fn(r)
            per_image.append({
                "source_media_key": key,
                "native_w": nw, "native_h": nh,
                "resized_w": rw, "resized_h": rh,
                "tenengrad": tg,
                "residual_noise_std": rn,
                "opencv_sharpness_1024": oc.get("sharpness"),
                "opencv_noise_1024": oc.get("noise"),
                "prod_raw_sharpness": fnum(rec, "raw_sharpness"),
                "prod_raw_noise": fnum(rec, "raw_noise"),
                "prod_crit_sharpness": fnum(rec, "criterion_Sharpness"),
                "prod_crit_noise": fnum(rec, "criterion_Noise"),
                "attr_sharpness_raw": fnum(rec, "attr_sharpness_raw"),
                "attr_noisiness_raw": fnum(rec, "attr_noisiness_raw"),
                "overall_score": fnum(rec, "overall_score"),
            })
            print(f"[PROTO {i}/{n}] {key} tg={tg:.1f} res_noise={rn:.2f} "
                  f"oc_sharp={oc.get('sharpness')} oc_noise={oc.get('noise')}", flush=True)
        except Exception as exc:  # noqa: BLE001
            failures.append({"source_media_key": key, "error": f"{type(exc).__name__}: {exc}"})
            print(f"[PROTO {i}/{n}] {key} ERR {exc}", flush=True)
    wall_s = time.perf_counter() - t0

    # ---- distributions ----
    def col(name: str) -> list[float]:
        return [r[name] for r in per_image if isinstance(r.get(name), (int, float))]

    distributions = {
        "tenengrad": dist(col("tenengrad")),
        "residual_noise_std": dist(col("residual_noise_std")),
        "opencv_sharpness_1024": dist(col("opencv_sharpness_1024")),
        "opencv_noise_1024": dist(col("opencv_noise_1024")),
        "prod_raw_sharpness": dist(col("prod_raw_sharpness")),
        "prod_raw_noise": dist(col("prod_raw_noise")),
        "attr_sharpness_raw": dist(col("attr_sharpness_raw")),
        "attr_noisiness_raw": dist(col("attr_noisiness_raw")),
    }

    # ---- production badge distributions ----
    prod_badges = {
        "criterion_Sharpness": badge_counts([int(v) for v in col("prod_crit_sharpness") if v is not None]),
        "criterion_Noise": badge_counts([int(v) for v in col("prod_crit_noise") if v is not None]),
    }

    # ---- ILLUSTRATIVE candidate badges via EXISTING _soft_score (no fitting) ----
    # Only for the production-style [0,1] metrics at 1024 (no SPAQ-derived normalization).
    cand_sharp_badges = badge_counts([_soft_score(v) for v in col("opencv_sharpness_1024") if v is not None])
    cleanliness = [1.0 - min(v, 0.85) for v in col("opencv_noise_1024") if v is not None]
    cand_noise_badges = badge_counts([_soft_score(v) for v in cleanliness])

    # ---- _soft_score compression analysis (analytical, no fitting) ----
    # boosted = clip(metric*0.5+0.42,0,1); buckets at 0.80/0.64/0.46/0.28 -> 5/4/3/2/1
    # For metric in [0,1]: boosted in [0.42,0.92]; badge 1 requires boosted<0.28 i.e.
    # metric < -0.28 -> UNREACHABLE. Noise cleanliness = 1-min(noise,0.85) in [0.15,1.0]
    # -> boosted in [0.495,0.92] -> badges in {3,4,5} only.
    soft_score_analysis = {
        "formula": "boosted = clip(metric*0.5 + 0.42, 0, 1)",
        "thresholds": {"5": ">=0.80", "4": ">=0.64", "3": ">=0.46", "2": ">=0.28", "1": "<0.28"},
        "metric_to_badge_edges": {
            "5": "metric >= 0.76",
            "4": "0.44 <= metric < 0.76",
            "3": "0.08 <= metric < 0.44",
            "2": "0.00 <= metric < 0.08",
            "1": "metric < -0.28 (unreachable for metric in [0,1])",
        },
        "unreachable_1": "badge 1 requires boosted<0.28 -> metric<-0.28; impossible for any [0,1] input",
        "noise_cleanliness_range": "1 - min(noise,0.85) in [0.15,1.0] -> boosted in [0.495,0.92] -> badges in {3,4,5} only (1 and 2 unreachable)",
        "consequence": "Any [0,1]-bounded metric fed to _soft_score can never produce badge 1 and tends to pile at 4-5. Confirms Phase 11/12 'pile-up at 5 / unreachable 1'.",
    }

    # ---- exploratory correlations (NO fitting) ----
    def pairs(a: str, b: str) -> tuple[list[float], list[float]]:
        xs, ys = [], []
        for r in per_image:
            av, bv = r.get(a), r.get(b)
            if isinstance(av, (int, float)) and isinstance(bv, (int, float)):
                xs.append(float(av)); ys.append(float(bv))
        return xs, ys

    def corr(a: str, b: str) -> dict[str, Any]:
        xs, ys = pairs(a, b)
        if len(xs) < 5:
            return {"n": len(xs), "spearman_r": None, "note": "n<5"}
        boot = corr_fn(xs, ys, seed=SEED, n_boot=400)
        return {"n": len(xs), "spearman_r": boot.get("spearman_r"),
                "spearman_ci_low": boot.get("spearman_ci_low"),
                "spearman_ci_high": boot.get("spearman_ci_high"),
                "pearson_r": boot.get("pearson_r")}

    correlations = {
        "tenengrad_vs_attr_sharpness_raw": corr("tenengrad", "attr_sharpness_raw"),
        "residual_noise_std_vs_attr_noisiness_raw": corr("residual_noise_std", "attr_noisiness_raw"),
        "opencv_sharpness_1024_vs_attr_sharpness_raw": corr("opencv_sharpness_1024", "attr_sharpness_raw"),
        "opencv_noise_1024_vs_attr_noisiness_raw": corr("opencv_noise_1024", "attr_noisiness_raw"),
        "tenengrad_vs_prod_raw_sharpness": corr("tenengrad", "prod_raw_sharpness"),
        "residual_noise_std_vs_prod_raw_noise": corr("residual_noise_std", "prod_raw_noise"),
        "tenengrad_vs_prod_crit_sharpness": corr("tenengrad", "prod_crit_sharpness"),
        "residual_noise_std_vs_prod_crit_noise": corr("residual_noise_std", "prod_crit_noise"),
        "prod_raw_sharpness_vs_attr_sharpness_raw": corr("prod_raw_sharpness", "attr_sharpness_raw"),
        "prod_raw_noise_vs_attr_noisiness_raw": corr("prod_raw_noise", "attr_noisiness_raw"),
    }

    payload = {
        "generated_at": now_iso(),
        "resize_cap": args.cap,
        "images_scored": len(per_image),
        "failures": failures,
        "wall_seconds": round(wall_s, 2),
        "direction_contract": {
            "tenengrad": "higher = sharper = better quality (raw energy)",
            "residual_noise_std": "higher = more noise = WORSE quality (raw amount); member badge must invert",
            "member_noise_badge": "cleanliness = higher = less noise = better",
        },
        "distributions": distributions,
        "prod_badge_distributions": prod_badges,
        "illustrative_candidate_badges_via_existing_soft_score": {
            "note": "Illustrative only: existing _soft_score applied to [0,1] metrics at 1024. NOT a fitted calibration; no SPAQ percentiles used.",
            "opencv_sharpness_1024_as_sharpness_badge": cand_sharp_badges,
            "cleanliness_1_minus_opencv_noise_1024_as_noise_badge": cand_noise_badges,
        },
        "soft_score_analysis": soft_score_analysis,
        "correlations_exploratory": correlations,
        "notes": [
            "Research-only prototype. No production code changed. No engine switch. No threshold fitting on SPAQ-200.",
            "Tenengrad and residual noise are computed at 1024 px longest side (INTER_AREA, no upscale).",
            "Tenengrad is unbounded energy; it CANNOT be fed to _soft_score without an a-priori [0,1] normalization, and any such normalization still inherits the unreachable-1 defect. A new a-priori ladder is required for Tenengrad.",
            "Correlations are exploratory vs SPAQ human ratings / production raw; they are NOT used to fit thresholds or 1-5 maps.",
            "Independent labeled dev data (ACCESS-native 1-5 pack via HUMAN_RATING_RUBRIC.md) is required before any deploy; SPAQ-200 is a related proxy only and must NOT be used for calibration fitting.",
        ],
    }

    out_dir = args.output
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "sharpness_noise_prototype.json").write_text(
        json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
    # per-image csv
    fields = ["source_media_key", "native_w", "native_h", "resized_w", "resized_h",
              "tenengrad", "residual_noise_std", "opencv_sharpness_1024", "opencv_noise_1024",
              "prod_raw_sharpness", "prod_raw_noise", "prod_crit_sharpness", "prod_crit_noise",
              "attr_sharpness_raw", "attr_noisiness_raw", "overall_score"]
    with (out_dir / "sharpness_noise_prototype.csv").open("w", newline="", encoding="utf-8") as h:
        w = csv.DictWriter(h, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(per_image)

    print("[PROTO] ---- summary ----", flush=True)
    print(json.dumps({
        "images_scored": payload["images_scored"],
        "failures": len(payload["failures"]),
        "wall_seconds": payload["wall_seconds"],
        "prod_crit_sharpness_badges": prod_badges["criterion_Sharpness"],
        "prod_crit_noise_badges": prod_badges["criterion_Noise"],
        "illustrative_cand_sharpness_badges": cand_sharp_badges,
        "illustrative_cand_noise_badges": cand_noise_badges,
        "tenengrad_vs_attr_sharpness": correlations["tenengrad_vs_attr_sharpness_raw"].get("spearman_r"),
        "residual_noise_vs_attr_noisiness": correlations["residual_noise_std_vs_attr_noisiness_raw"].get("spearman_r"),
        "out": str(out_dir),
    }, indent=2, default=str), flush=True)
    print("PROTOTYPE_DONE", flush=True)
    return 0 if per_image else 2


if __name__ == "__main__":
    raise SystemExit(main())
