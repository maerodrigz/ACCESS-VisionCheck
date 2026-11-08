#!/usr/bin/env python3
"""ACCESS VisionCheck — Brightness & Contrast controlled diagnostic (research only).

Determines whether the member-facing Brightness and Contrast 1-5 ratings reflect
exposure/contrast QUALITY vs. raw brightness/contrast MAGNITUDE, by scoring
controlled variants of the same source images through BOTH production paths
(EfficientNet-B0 primary, OpenCV fallback) independently, with no silent
substitution.

Strict constraints:
  - No production code/weights/API/threshold changes. Production scorers and the
    exact transforms (_brightness_metric, _soft_score) are IMPORTED read-only.
  - No SPAQ-200 access, no retraining, no frozen Sharpness/Noise calibration touched.
  - All outputs stay under the research workspace.
  - Controlled distortions are diagnostic only; they do NOT establish human-rated
    accuracy and no human ground-truth labels are invented.

Variants (a-priori declared gains; exposure/contrast semantics match
controlled_distortion.apply_exposure / apply_contrast exactly):
  1 original, 2 underexposed (0.55), 3 severely_underexposed (0.25),
  4 overexposed (1.6), 5 severely_overexposed (2.8),
  6 low_contrast (0.4), 7 excessively_high_contrast (2.2).

Expected records: 40 sources x 7 variants x 2 engines = 560 (one row per
source x variant x engine; failures kept as explicit error rows, never dropped
and never substituted).
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

KONIQ_IMAGES = _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "images"
DEFAULT_OUT_ROOT = _TOOLKIT / "workspace" / "datasets" / "brightness_contrast_controlled"

# variant: (name, family, gain)
VARIANTS = [
    ("original", "none", None),
    ("underexposed", "exposure", 0.55),
    ("severely_underexposed", "exposure", 0.25),
    ("overexposed", "exposure", 1.6),
    ("severely_overexposed", "exposure", 2.8),
    ("low_contrast", "contrast", 0.4),
    ("excessively_high_contrast", "contrast", 2.2),
]
ENGINES = ("efficientnet-b0", "opencv")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# --- variant generation (matches controlled_distortion exactly) ----------------

def decode_bgr(content: bytes):
    import cv2
    import numpy as np
    arr = np.frombuffer(content, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if bgr is None:
        raise RuntimeError("decode failed")
    return bgr


def encode_png(bgr) -> bytes:
    import cv2
    ok, buf = cv2.imencode(".png", bgr)
    if not ok:
        raise RuntimeError("png encode failed")
    return bytes(buf)


def apply_exposure(bgr, gain: float) -> bytes:
    import numpy as np
    out = np.clip(bgr.astype(np.float64) * float(gain), 0, 255).astype(np.uint8)
    return encode_png(out)


def apply_contrast(bgr, gain: float) -> bytes:
    import numpy as np
    x = bgr.astype(np.float64)
    out = np.clip((x - 127.5) * float(gain) + 127.5, 0, 255).astype(np.uint8)
    return encode_png(out)


def make_variant(bgr, name: str, gain):
    if name == "original":
        return encode_png(bgr), bgr
    if "underexposed" in name or "overexposed" in name:
        return apply_exposure(bgr, gain), None
    # contrast family
    return apply_contrast(bgr, gain), None


def objective_luma_std(bgr):
    """Actual mean luminance (0-1) and grayscale std of the variant image."""
    import cv2
    import numpy as np
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    return float(np.mean(gray) / 255.0), float(np.std(gray))


# --- scoring (direct per-engine; no fallback / no substitution) -----------------

def import_scorers():
    missing = []
    for n in ("cv2", "numpy", "PIL", "torch", "torchvision"):
        try:
            __import__(n)
        except Exception as exc:  # noqa: BLE001
            missing.append(f"{n} ({exc})")
    if missing:
        sys.exit("ABORT: missing deps: " + ", ".join(missing) + " (use access_backend/venv312)")
    from app.services.efficientnet_b0_scorer import (
        analyze_image_bytes as enet_analyze,
        efficientnet_available,
        ensure_weights,
    )
    from app.services.opencv_quality import analyze_image_bytes as opencv_analyze, opencv_available
    from app.services.media_evaluator import _brightness_metric, _soft_score
    enet_ok = bool(efficientnet_available() and ensure_weights())
    return {
        "enet_analyze": enet_analyze,
        "opencv_analyze": opencv_analyze,
        "opencv_available": bool(opencv_available()),
        "brightness_metric": _brightness_metric,
        "soft_score": _soft_score,
        "enet_ok": enet_ok,
    }


def score_one(content: bytes, engine: str, rt) -> dict[str, Any]:
    """Return raw brightness/contrast, transformed metrics, badges, or error. Never substitutes."""
    out: dict[str, Any] = {"engine": engine, "error": None}
    try:
        if engine == "efficientnet-b0":
            raw = rt["enet_analyze"](content)
            if raw is None:
                out["error"] = "enet_returned_none"
        else:
            raw = rt["opencv_analyze"](content)
            if raw is None:
                out["error"] = "opencv_returned_none"
    except Exception as exc:  # noqa: BLE001
        out["error"] = f"{type(exc).__name__}: {exc}"
        raw = None
    if raw is None:
        return out
    rb = raw.get("brightness")
    rc = raw.get("contrast")
    bm = rt["brightness_metric"](rb) if isinstance(rb, (int, float)) else None
    ct = min(rc, 1.0) if isinstance(rc, (int, float)) else None
    bb = rt["soft_score"](bm) if isinstance(bm, (int, float)) else None
    cb = rt["soft_score"](ct) if isinstance(ct, (int, float)) else None
    out.update({
        "raw_brightness": rb, "raw_contrast": rc,
        "brightness_metric": bm, "contrast_transformed": ct,
        "brightness_badge": bb, "contrast_badge": cb,
        "width": raw.get("width"), "height": raw.get("height"),
    })
    return out


# --- stats helpers ---------------------------------------------------------------

def spearman(xs, ys):
    try:
        from scipy import stats
        if len(xs) < 3 or len(xs) != len(ys):
            return None
        if len(set(xs)) == 1 or len(set(ys)) == 1:
            return None
        return float(stats.spearmanr(xs, ys).correlation)
    except Exception:  # noqa: BLE001
        return None


def badge_counts(values):
    out = {str(k): 0 for k in range(1, 6)}
    for v in values:
        if isinstance(v, (int, float)) and 1 <= int(v) <= 5:
            out[str(int(v))] += 1
    return out


def mean_safe(values):
    vals = [v for v in values if isinstance(v, (int, float))]
    return round(statistics.fmean(vals), 4) if vals else None


# --- main ------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--source-dir", type=Path, default=KONIQ_IMAGES)
    ap.add_argument("--output", type=Path, default=DEFAULT_OUT_ROOT)
    ap.add_argument("--limit", type=int, default=None, help="cap number of source images (smoke)")
    ap.add_argument("--warmup", type=int, default=1)
    args = ap.parse_args()

    rt = import_scorers()
    print(f"[BC] enet_ok={rt['enet_ok']} opencv_available={rt['opencv_available']}", flush=True)
    print(f"[BC] source_dir={args.source_dir} output={args.output}", flush=True)

    srcs = sorted([p for p in args.source_dir.iterdir()
                   if p.suffix.lower() in {".jpg", ".jpeg", ".png"} and p.is_file()])
    if args.limit is not None:
        srcs = srcs[: args.limit]
    n_src = len(srcs)
    print(f"[BC] sources={n_src} variants={len(VARIANTS)} engines={len(ENGINES)} "
          f"expected_records={n_src * len(VARIANTS) * len(ENGINES)}", flush=True)

    gen_dir = args.output / "generated"
    out_dir = args.output / "output"
    gen_dir.mkdir(parents=True, exist_ok=True)
    out_dir.mkdir(parents=True, exist_ok=True)

    # warmup (load ENET model once, discard timing)
    if args.warmup and srcs and rt["enet_ok"]:
        try:
            rt["enet_analyze"](srcs[0].read_bytes())
        except Exception as exc:  # noqa: BLE001
            print(f"[BC] warmup enet error: {exc}", flush=True)
        print("[BC] warmup done (timings discarded)", flush=True)

    records: list[dict[str, Any]] = []
    failures: list[dict[str, Any]] = []
    t0 = time.perf_counter()
    for si, src in enumerate(srcs, start=1):
        sid = src.stem  # e.g. 10187102065
        try:
            content = src.read_bytes()
            bgr = decode_bgr(content)
        except Exception as exc:  # noqa: BLE001
            for vname, vfamily, vgain in VARIANTS:
                for eng in ENGINES:
                    failures.append({"source_id": sid, "variant": vname, "engine": eng,
                                     "error": f"source_decode: {exc}"})
            print(f"[BC {si}/{n_src}] {sid} SOURCE_DECODE_ERROR {exc}", flush=True)
            continue
        src_dir = gen_dir / sid
        src_dir.mkdir(parents=True, exist_ok=True)
        for vname, vfamily, vgain in VARIANTS:
            try:
                vbytes, vbgr = make_variant(bgr, vname, vgain)
                (src_dir / f"{vname}.png").write_bytes(vbytes)
                # objective measurement from the actual variant pixels
                meas_bgr = vbgr if vbgr is not None else decode_bgr(vbytes)
                luma, gstd = objective_luma_std(meas_bgr)
            except Exception as exc:  # noqa: BLE001
                for eng in ENGINES:
                    failures.append({"source_id": sid, "variant": vname, "engine": eng,
                                     "error": f"variant_gen: {exc}"})
                print(f"[BC {si}/{n_src}] {sid} {vname} GEN_ERROR {exc}", flush=True)
                continue
            for eng in ENGINES:
                sc = score_one(vbytes, eng, rt)
                rec = {
                    "source_id": sid,
                    "variant": vname,
                    "family": vfamily,
                    "gain": vgain,
                    "engine": eng,
                    "luma_mean": round(luma, 6),
                    "gray_std": round(gstd, 4),
                    "error": sc.get("error"),
                    "raw_brightness": sc.get("raw_brightness"),
                    "raw_contrast": sc.get("raw_contrast"),
                    "brightness_metric": sc.get("brightness_metric"),
                    "contrast_transformed": sc.get("contrast_transformed"),
                    "brightness_badge": sc.get("brightness_badge"),
                    "contrast_badge": sc.get("contrast_badge"),
                }
                records.append(rec)
                if sc.get("error"):
                    failures.append({"source_id": sid, "variant": vname, "engine": eng,
                                      "error": sc["error"]})
            print(f"[BC {si}/{n_src}] {sid} {vname} luma={luma:.3f} std={gstd:.1f} "
                  f"enet_b={sc.get('brightness_badge') if eng=='efficientnet-b0' else '?'}", flush=True)
    wall = time.perf_counter() - t0
    print(f"[BC] scoring complete in {wall:.1f}s; records={len(records)} failures={len(failures)}", flush=True)

    # ---- validation ----
    expected = n_src * len(VARIANTS) * len(ENGINES)
    srcs_seen = sorted({r["source_id"] for r in records})
    variant_engine_pairs = sorted({(r["variant"], r["engine"]) for r in records})
    validation = {
        "expected_records": expected,
        "actual_records": len(records),
        "records_ok": len(records) == expected,
        "sources_expected": n_src,
        "sources_seen": len(srcs_seen),
        "sources_ok": len(srcs_seen) == n_src,
        "variant_engine_pairs_expected": len(VARIANTS) * len(ENGINES),
        "variant_engine_pairs_seen": len(variant_engine_pairs),
        "failures": failures,
        "n_failures": len(failures),
    }

    # ---- per-engine series ----
    def eng_recs(eng, variant=None):
        out = [r for r in records if r["engine"] == eng and not r.get("error")]
        if variant is not None:
            out = [r for r in out if r["variant"] == variant]
        return out

    # ---- distributions + ceiling/floor + badge-1 reachability ----
    dists = {}
    for eng in ENGINES:
        er = eng_recs(eng)
        dists[eng] = {
            "n_ok": len(er),
            "brightness_badge_counts": badge_counts([r["brightness_badge"] for r in er]),
            "contrast_badge_counts": badge_counts([r["contrast_badge"] for r in er]),
            "raw_brightness_mean": mean_safe([r["raw_brightness"] for r in er]),
            "raw_contrast_mean": mean_safe([r["raw_contrast"] for r in er]),
            "badge_1_reachable": any(r["brightness_badge"] == 1 or r["contrast_badge"] == 1 for r in er),
            "brightness_ceiling_5": sum(1 for r in er if r["brightness_badge"] == 5),
            "brightness_floor_1": sum(1 for r in er if r["brightness_badge"] == 1),
            "contrast_ceiling_5": sum(1 for r in er if r["contrast_badge"] == 5),
            "contrast_floor_1": sum(1 for r in er if r["contrast_badge"] == 1),
        }

    # ---- mean badge by variant x engine ----
    mean_badge = {}
    for eng in ENGINES:
        mean_badge[eng] = {}
        for vname, _, _ in VARIANTS:
            er = eng_recs(eng, vname)
            mean_badge[eng][vname] = {
                "brightness_badge_mean": mean_safe([r["brightness_badge"] for r in er]),
                "contrast_badge_mean": mean_safe([r["contrast_badge"] for r in er]),
                "luma_mean": mean_safe([r["luma_mean"] for r in er]),
                "gray_std_mean": mean_safe([r["gray_std"] for r in er]),
            }

    # ---- raw-vs-objective tracking (does engine raw follow actual luma/std?) ----
    tracking = {}
    for eng in ENGINES:
        er = eng_recs(eng)
        tracking[eng] = {
            "spearman_raw_brightness_vs_luma": spearman(
                [r["raw_brightness"] for r in er], [r["luma_mean"] for r in er]),
            "spearman_raw_contrast_vs_gray_std": spearman(
                [r["raw_contrast"] for r in er], [r["gray_std"] for r in er]),
            "n": len(er),
        }

    # ---- per-source direction flags ----
    per_source = []
    bright_exposure_consistent = {eng: 0 for eng in ENGINES}
    bright_over_beats_original = {eng: 0 for eng in ENGINES}
    bright_severe_under_low = {eng: 0 for eng in ENGINES}
    bright_severe_over_low = {eng: 0 for eng in ENGINES}
    contrast_monotone_in_magnitude = {eng: 0 for eng in ENGINES}
    contrast_excessive_ge_original = {eng: 0 for eng in ENGINES}
    inconsistent_cases: list[dict[str, Any]] = []

    def badge_of(rows, vname, crit):
        for r in rows:
            if r["variant"] == vname:
                return r.get(f"{crit}_badge")
        return None

    for sid in srcs_seen:
        for eng in ENGINES:
            rows = [r for r in records if r["source_id"] == sid and r["engine"] == eng and not r.get("error")]
            if len(rows) != len(VARIANTS):
                continue
            b_orig = badge_of(rows, "original", "brightness")
            b_under = badge_of(rows, "underexposed", "brightness")
            b_sev_under = badge_of(rows, "severely_underexposed", "brightness")
            b_over = badge_of(rows, "overexposed", "brightness")
            b_sev_over = badge_of(rows, "severely_overexposed", "brightness")
            c_orig = badge_of(rows, "original", "contrast")
            c_low = badge_of(rows, "low_contrast", "contrast")
            c_exc = badge_of(rows, "excessively_high_contrast", "contrast")

            def ok(v):
                return isinstance(v, (int, float))

            exp_ok = (ok(b_orig) and ok(b_under) and ok(b_over)
                      and b_orig >= b_under and b_orig >= b_over)
            over_beats = ok(b_over) and ok(b_orig) and b_over > b_orig
            sev_under_low = ok(b_sev_under) and b_sev_under <= 2
            sev_over_low = ok(b_sev_over) and b_sev_over <= 2
            con_mono = (ok(c_low) and ok(c_orig) and ok(c_exc)
                        and c_low <= c_orig <= c_exc)
            con_exc_ge = ok(c_exc) and ok(c_orig) and c_exc >= c_orig

            if exp_ok:
                bright_exposure_consistent[eng] += 1
            if over_beats:
                bright_over_beats_original[eng] += 1
            if sev_under_low:
                bright_severe_under_low[eng] += 1
            if sev_over_low:
                bright_severe_over_low[eng] += 1
            if con_mono:
                contrast_monotone_in_magnitude[eng] += 1
            if con_exc_ge:
                contrast_excessive_ge_original[eng] += 1

            flags = []
            if over_beats:
                flags.append("overexposed_brightness_beats_original")
            if ok(b_sev_under) and b_sev_under >= 4:
                flags.append("severely_underexposed_brightness>=4")
            if ok(b_sev_over) and b_sev_over >= 4:
                flags.append("severely_overexposed_brightness>=4")
            if con_exc_ge and ok(c_exc) and c_exc >= 4:
                flags.append("excessive_contrast_badge>=4")
            if flags:
                inconsistent_cases.append({
                    "source_id": sid, "engine": eng, "flags": flags,
                    "brightness_badges": {"original": b_orig, "underexposed": b_under,
                                           "severely_underexposed": b_sev_under,
                                           "overexposed": b_over, "severely_overexposed": b_sev_over},
                    "contrast_badges": {"original": c_orig, "low_contrast": c_low,
                                        "excessively_high_contrast": c_exc},
                    "image_dir": str(gen_dir / sid),
                })

            per_source.append({
                "source_id": sid, "engine": eng,
                "brightness_exposure_consistent": exp_ok,
                "brightness_over_beats_original": over_beats,
                "contrast_monotone_in_magnitude": con_mono,
                "contrast_excessive_ge_original": con_exc_ge,
            })

    n_evaluable = sum(1 for r in per_source for _ in [0])  # not used directly
    n_sources_eval = {eng: sum(1 for p in per_source if p["engine"] == eng) for eng in ENGINES}

    summary = {
        "brightness_exposure_consistent": bright_exposure_consistent,
        "brightness_over_beats_original": bright_over_beats_original,
        "brightness_severely_under_low_badge": bright_severe_under_low,
        "brightness_severely_over_low_badge": bright_severe_over_low,
        "contrast_monotone_in_magnitude": contrast_monotone_in_magnitude,
        "contrast_excessive_ge_original": contrast_excessive_ge_original,
        "n_sources_evaluable_per_engine": n_sources_eval,
    }

    payload = {
        "generated_at": now_iso(),
        "config": {
            "source_dir": str(args.source_dir),
            "n_sources": n_src,
            "variants": [{"name": n, "family": f, "gain": g} for n, f, g in VARIANTS],
            "engines": list(ENGINES),
            "expected_records": expected,
            "output_root": str(args.output),
        },
        "validation": validation,
        "distributions": dists,
        "mean_badge_by_variant": mean_badge,
        "raw_vs_objective_tracking": tracking,
        "direction_summary": summary,
        "inconsistent_cases": inconsistent_cases[:50],
        "n_inconsistent_cases": len(inconsistent_cases),
        "wall_seconds": round(wall, 2),
        "notes": [
            "Research-only diagnostic. No production code changed. No SPAQ-200 access. No retraining.",
            "Engines scored independently; no silent substitution. Error rows kept explicit.",
            "Controlled distortions are objective measurement behavior, NOT proof of perceptual accuracy. No human ground-truth labels invented.",
            "brightness_badge = _soft_score(_brightness_metric(raw_brightness)); contrast_badge = _soft_score(min(raw_contrast,1.0)) — imported from app.services.media_evaluator (exact production transform).",
            "luma_mean = mean(gray)/255 and gray_std = std(gray) are objective measurements of the variant, independent of engine.",
            "brightness_exposure_consistent = badge(original) >= badge(underexposed) and >= badge(overexposed) (original is a local max).",
            "contrast_monotone_in_magnitude = badge(low_contrast) <= badge(original) <= badge(excessively_high_contrast) (rises with std).",
        ],
    }

    # ---- write CSV ----
    csv_fields = ["source_id", "variant", "family", "gain", "engine", "luma_mean", "gray_std",
                  "error", "raw_brightness", "raw_contrast", "brightness_metric",
                  "contrast_transformed", "brightness_badge", "contrast_badge"]
    with (out_dir / "brightness_contrast_controlled.csv").open("w", newline="", encoding="utf-8") as h:
        w = csv.DictWriter(h, fieldnames=csv_fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(records)

    # ---- write JSON ----
    (out_dir / "brightness_contrast_controlled.json").write_text(
        json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")

    # ---- write MD report ----
    write_report(out_dir / "BRIGHTNESS_CONTRAST_CONTROLLED_REPORT.md", payload)

    print("[BC] ---- summary ----", flush=True)
    print(json.dumps({
        "records": len(records), "expected": expected, "records_ok": validation["records_ok"],
        "sources_ok": validation["sources_ok"], "n_failures": len(failures),
        "badge_1_reachable": {e: dists[e]["badge_1_reachable"] for e in ENGINES},
        "brightness_exposure_consistent": bright_exposure_consistent,
        "contrast_monotone_in_magnitude": contrast_monotone_in_magnitude,
        "n_inconsistent_cases": len(inconsistent_cases),
        "out": str(out_dir),
    }, indent=2, default=str), flush=True)
    print("BC_DONE", flush=True)
    return 0 if (validation["records_ok"] and validation["sources_ok"]) else 2


def write_report(path: Path, p: dict[str, Any]) -> None:
    v = p["validation"]
    cfg = p["config"]
    lines = [
        "# ACCESS VisionCheck — Brightness & Contrast controlled diagnostic",
        "",
        f"**Generated:** {p['generated_at']}",
        "",
        "Research-only. No production code/weights/API/thresholds changed. No SPAQ-200 access. No retraining. "
        "Controlled distortions are objective-measurement behavior, **not** proof of perceptual accuracy. "
        "No human ground-truth labels were invented. Engines were scored independently with no silent substitution.",
        "",
        "## Config",
        "",
        f"- Sources: **{cfg['n_sources']}** (KonIQ-10k local JPEGs)",
        f"- Variants: **{len(cfg['variants'])}** (gains declared a priori, see below)",
        f"- Engines: EfficientNet-B0 (primary) + OpenCV (fallback), scored independently",
        f"- Expected records: **{cfg['expected_records']}** (sources x variants x engines)",
        "",
        "| # | Variant | Family | Gain |",
        "|---|---|---|---|",
    ]
    for i, vr in enumerate(cfg["variants"], start=1):
        lines.append(f"| {i} | {vr['name']} | {vr['family']} | {vr['gain']} |")

    lines += ["", "## Validation", "",
              f"- expected_records={v['expected_records']} actual={v['actual_records']} "
              f"**records_ok={v['records_ok']}**",
              f"- sources expected={v['sources_expected']} seen={v['sources_seen']} "
              f"**sources_ok={v['sources_ok']}**",
              f"- variant x engine pairs expected={v['variant_engine_pairs_expected']} "
              f"seen={v['variant_engine_pairs_seen']}",
              f"- failures: **{v['n_failures']}**"]
    if v["failures"]:
        lines.append("")
        for f in v["failures"][:20]:
            lines.append(f"- `{f['source_id']}` `{f['variant']}` `{f['engine']}`: {f['error']}")
        if len(v["failures"]) > 20:
            lines.append(f"- ... ({len(v['failures'])} total)")
    lines += ["", "## Score distributions (n=280 per engine = 40 sources x 7 variants)", "",
              "| Engine | n_ok | Brightness badge 1-5 | Contrast badge 1-5 | badge_1_reachable | Brightness ceiling-5 | Contrast ceiling-5 |",
              "|---|---|---|---|---|---|---|"]
    for eng in ENGINES:
        d = p["distributions"][eng]
        lines.append(f"| {eng} | {d['n_ok']} | {d['brightness_badge_counts']} | "
                     f"{d['contrast_badge_counts']} | {d['badge_1_reachable']} | "
                     f"{d['brightness_ceiling_5']} | {d['contrast_ceiling_5']} |")

    lines += ["", "## Mean badge by variant (across 40 sources)", "",
              "| Engine | Variant | luma_mean | gray_std_mean | brightness_badge_mean | contrast_badge_mean |",
              "|---|---|---|---|---|---|"]
    for eng in ENGINES:
        for vr in cfg["variants"]:
            m = p["mean_badge_by_variant"][eng][vr["name"]]
            lines.append(f"| {eng} | {vr['name']} | {m['luma_mean']} | {m['gray_std_mean']} | "
                         f"{m['brightness_badge_mean']} | {m['contrast_badge_mean']} |")

    lines += ["", "## Raw-vs-objective tracking (does the engine raw follow the actual image?)", "",
              "luma_mean = mean(gray)/255 and gray_std = std(gray) are objective measurements of each variant.",
              "OpenCV raw brightness == luma and raw contrast == gray_std/72 by construction. ENET raw is a learned head.",
              "",
              "| Engine | n | Spearman(raw_brightness, luma_mean) | Spearman(raw_contrast, gray_std) |",
              "|---|---|---|---|"]
    for eng in ENGINES:
        t = p["raw_vs_objective_tracking"][eng]
        lines.append(f"| {eng} | {t['n']} | {t['spearman_raw_brightness_vs_luma']} | "
                     f"{t['spearman_raw_contrast_vs_gray_std']} |")

    s = p["direction_summary"]
    nse = s["n_sources_evaluable_per_engine"]
    lines += ["", "## Direction consistency (per source, count over 40)", "",
              f"brightness_exposure_consistent = badge(original) >= badge(underexposed) AND >= badge(overexposed) "
              f"(original is a local max vs the moderate distortions).",
              "contrast_monotone_in_magnitude = badge(low) <= badge(original) <= badge(excessive) "
              "(rises with std).",
              "",
              "| Flag | EfficientNet-B0 | OpenCV |",
              "|---|---|---|",
              f"| n sources evaluable | {nse['efficientnet-b0']} | {nse['opencv']} |",
              f"| brightness_exposure_consistent | {s['brightness_exposure_consistent']['efficientnet-b0']} | {s['brightness_exposure_consistent']['opencv']} |",
              f"| brightness_over_beats_original | {s['brightness_over_beats_original']['efficientnet-b0']} | {s['brightness_over_beats_original']['opencv']} |",
              f"| brightness_severely_underexposed_low(<=2) | {s['brightness_severely_under_low_badge']['efficientnet-b0']} | {s['brightness_severely_under_low_badge']['opencv']} |",
              f"| brightness_severely_overexposed_low(<=2) | {s['brightness_severely_over_low_badge']['efficientnet-b0']} | {s['brightness_severely_over_low_badge']['opencv']} |",
              f"| contrast_monotone_in_magnitude | {s['contrast_monotone_in_magnitude']['efficientnet-b0']} | {s['contrast_monotone_in_magnitude']['opencv']} |",
              f"| contrast_excessive >= original | {s['contrast_excessive_ge_original']['efficientnet-b0']} | {s['contrast_excessive_ge_original']['opencv']} |"]

    lines += ["", "## Inconsistent cases (rating direction conflicts with intended quality)", "",
              f"{p['n_inconsistent_cases']} cases flagged. Representative (first 20):", "",
              "| source_id | engine | flags | brightness (orig/under/sev_under/over/sev_over) | contrast (orig/low/exc) |",
              "|---|---|---|---|---|"]
    for c in p["inconsistent_cases"][:20]:
        b = c["brightness_badges"]
        cc = c["contrast_badges"]
        lines.append(f"| {c['source_id']} | {c['engine']} | {', '.join(c['flags'])} | "
                     f"{b['original']}/{b['underexposed']}/{b['severely_underexposed']}/{b['overexposed']}/{b['severely_overexposed']} | "
                     f"{cc['original']}/{cc['low_contrast']}/{cc['excessively_high_contrast']} |")
    lines += ["", "Representative images for visual review are under "
              "`workspace/datasets/brightness_contrast_controlled/generated/<source_id>/*.png` "
              "for the source_ids listed above.", "",
              "## Limitations",
              "",
              "- Controlled distortions measure objective score behavior, not perceptual accuracy.",
              "- No human ground-truth labels; variants are diagnostic, not validation.",
              "- KonIQ-10k source images are research-licensed; outputs are research-only and not deployed.",
              "- The `_soft_score` compression (badge 1 unreachable for [0,1] input) limits badge-1 reachability; "
              "this is structural and measured here, not a new finding.",
              "- ENET raw heads are learned on synthetic distortions; their tracking of real luma/std is reported above.",
              "",
              "No production code was changed. No deploy or integration. Stopped for review.",
              "",
              f"Artifacts: `{p['config']['output_root']}`",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
