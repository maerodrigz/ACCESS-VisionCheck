#!/usr/bin/env python3
"""ACCESS VisionCheck — eval the B1/B2/C1/C2 candidates on the EXISTING
controlled-diagnostic variants (no regeneration) and compare against the prior
EfficientNet-B0 and OpenCV results.

Research-only diagnostic. Does NOT fit candidate parameters or select a winner
from controlled distortions. Does NOT modify production, retrain, or access
SPAQ-200. Detail/gradient metrics are recorded for diagnostics only.

Reuses: workspace/datasets/brightness_contrast_controlled/generated/<src>/*.png
        workspace/datasets/brightness_contrast_controlled/output/*.csv (ENET/OpenCV)
Writes: workspace/datasets/brightness_contrast_candidates/{csv,json,md}
"""

from __future__ import annotations

import csv
import json
import statistics
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
sys.path.insert(0, str(_TOOLKIT))

from brightness_contrast_candidates import candidates_for_image  # noqa: E402

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore

BC_ROOT = _TOOLKIT / "workspace" / "datasets" / "brightness_contrast_controlled"
GENERATED = BC_ROOT / "generated"
PRIOR_CSV = BC_ROOT / "output" / "brightness_contrast_controlled.csv"
OUT_ROOT = _TOOLKIT / "workspace" / "datasets" / "brightness_contrast_candidates"

VARIANTS = [
    ("original", "none", None, "original.png"),
    ("underexposed", "exposure", 0.55, "underexposed.png"),
    ("severely_underexposed", "exposure", 0.25, "severely_underexposed.png"),
    ("overexposed", "exposure", 1.6, "overexposed.png"),
    ("severely_overexposed", "exposure", 2.8, "severely_overexposed.png"),
    ("low_contrast", "contrast", 0.4, "low_contrast.png"),
    ("excessively_high_contrast", "contrast", 2.2, "excessively_high_contrast.png"),
]
CANDS = ("B1", "B2", "C1", "C2")
ENGINES = ("efficientnet-b0", "opencv")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def decode_png(path: Path):
    arr = __import__("numpy").frombuffer(path.read_bytes(), dtype=__import__("numpy").uint8)
    return cv2.imdecode(arr, cv2.IMREAD_COLOR)


def load_prior() -> dict[tuple[str, str], dict[str, dict[str, Any]]]:
    """{(source_id, variant): {engine: {raw_brightness, raw_contrast, brightness_badge, contrast_badge}}}"""
    out: dict[tuple[str, str], dict[str, dict[str, Any]]] = {}
    if not PRIOR_CSV.is_file():
        return out
    with PRIOR_CSV.open(newline="", encoding="utf-8") as h:
        for r in csv.DictReader(h):
            key = (r["source_id"], r["variant"])
            out.setdefault(key, {})[r["engine"]] = {
                "raw_brightness": _f(r.get("raw_brightness")),
                "raw_contrast": _f(r.get("raw_contrast")),
                "brightness_badge": _i(r.get("brightness_badge")),
                "contrast_badge": _i(r.get("contrast_badge")),
            }
    return out


def _f(v) -> float | None:
    try:
        return float(v) if v not in (None, "") else None
    except (TypeError, ValueError):
        return None


def _i(v) -> int | None:
    try:
        return int(float(v)) if v not in (None, "") else None
    except (TypeError, ValueError):
        return None


def mean_safe(values) -> float | None:
    vals = [v for v in values if isinstance(v, (int, float))]
    return round(statistics.fmean(vals), 4) if vals else None


def main() -> int:
    if cv2 is None:
        sys.exit("ABORT: OpenCV required (use venv312)")
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    prior = load_prior()
    print(f"[BCCE] prior records loaded: {len(prior)} (source,variant) keys", flush=True)

    src_dirs = sorted([p for p in GENERATED.iterdir() if p.is_dir()])
    print(f"[BCCE] source dirs: {len(src_dirs)}", flush=True)

    records: list[dict[str, Any]] = []
    failures: list[dict[str, Any]] = []
    for sd in src_dirs:
        sid = sd.name
        for vname, family, gain, fname in VARIANTS:
            p = sd / fname
            if not p.is_file():
                failures.append({"source_id": sid, "variant": vname, "error": "missing_variant_file"})
                continue
            bgr = decode_png(p)
            if bgr is None:
                failures.append({"source_id": sid, "variant": vname, "error": "decode_failed"})
                continue
            c = candidates_for_image(bgr)
            f = c["features"]
            enet = prior.get((sid, vname), {}).get("efficientnet-b0", {})
            opencv = prior.get((sid, vname), {}).get("opencv", {})
            rec = {
                "source_id": sid, "variant": vname, "family": family, "gain": gain,
                "luma_mean": f["luma_mean"], "luma_std": f["luma_std"], "local_std": f["local_std"],
                "mid_cov": f["mid_cov"], "clip_lo": f["clip_lo"], "clip_hi": f["clip_hi"],
                "band_lo": f["band_lo"], "band_hi": f["band_hi"], "extremes": f["extremes"],
                "detail_mid_raw": f["detail_mid_raw"],
                "Q_B1": c["Q_B1"], "Q_B2": c["Q_B2"], "Q_C1": c["Q_C1"], "Q_C2": c["Q_C2"],
                "label_B1": c["label_B1"], "label_B2": c["label_B2"],
                "label_C1": c["label_C1"], "label_C2": c["label_C2"],
                "enet_raw_brightness": enet.get("raw_brightness"),
                "enet_raw_contrast": enet.get("raw_contrast"),
                "enet_brightness_badge": enet.get("brightness_badge"),
                "enet_contrast_badge": enet.get("contrast_badge"),
                "opencv_raw_brightness": opencv.get("raw_brightness"),
                "opencv_raw_contrast": opencv.get("raw_contrast"),
                "opencv_brightness_badge": opencv.get("brightness_badge"),
                "opencv_contrast_badge": opencv.get("contrast_badge"),
            }
            records.append(rec)
        print(f"[BCCE] {sid} done", flush=True)

    n_src = len(src_dirs)
    expected = n_src * len(VARIANTS)
    validation = {
        "expected_records": expected, "actual_records": len(records),
        "records_ok": len(records) == expected,
        "n_sources": n_src, "n_variants": len(VARIANTS), "failures": failures, "n_failures": len(failures),
    }

    # ---- mean Q / label by variant (per candidate) ----
    mean_by_variant: dict[str, dict[str, Any]] = {}
    for vname, _, _, _ in VARIANTS:
        rows = [r for r in records if r["variant"] == vname]
        mean_by_variant[vname] = {
            "luma_mean": mean_safe([r["luma_mean"] for r in rows]),
            "luma_std": mean_safe([r["luma_std"] for r in rows]),
            **{f"Q_{c}": mean_safe([r[f"Q_{c}"] for r in rows]) for c in CANDS},
            **{f"label_{c}": mean_safe([r[f"label_{c}"] for r in rows]) for c in CANDS},
            "enet_brightness_badge": mean_safe([r["enet_brightness_badge"] for r in rows]),
            "opencv_brightness_badge": mean_safe([r["opencv_brightness_badge"] for r in rows]),
            "enet_contrast_badge": mean_safe([r["enet_contrast_badge"] for r in rows]),
            "opencv_contrast_badge": mean_safe([r["opencv_contrast_badge"] for r in rows]),
        }

    # ---- within-source direction checks ----
    def label_of(rows, vname, key):
        for r in rows:
            if r["variant"] == vname:
                return r.get(key)
        return None

    # brightness series + contrast series per candidate AND per engine
    bright_keys = [("B1", "label_B1"), ("B2", "label_B2"),
                   ("enet", "enet_brightness_badge"), ("opencv", "opencv_brightness_badge")]
    contrast_keys = [("C1", "label_C1"), ("C2", "label_C2"),
                     ("enet", "enet_contrast_badge"), ("opencv", "opencv_contrast_badge")]
    direction = {f"brightness_{k}": {"drops_both": 0, "severe_under_low": 0, "severe_over_low": 0, "n": 0}
                 for k, _ in bright_keys}
    direction.update({f"contrast_{k}": {"monotone_in_magnitude": 0, "drops_at_excessive": 0, "n": 0}
                      for k, _ in contrast_keys})

    def ok(v):
        return isinstance(v, (int, float))

    for sid in [sd.name for sd in src_dirs]:
        rows = [r for r in records if r["source_id"] == sid]
        if len(rows) != len(VARIANTS):
            continue
        for key, col in bright_keys:
            o = label_of(rows, "original", col)
            u = label_of(rows, "underexposed", col)
            su = label_of(rows, "severely_underexposed", col)
            ov = label_of(rows, "overexposed", col)
            so = label_of(rows, "severely_overexposed", col)
            if not all(ok(x) for x in (o, u, su, ov, so)):
                continue
            d = direction[f"brightness_{key}"]
            d["n"] += 1
            if o >= u and o >= ov:
                d["drops_both"] += 1
            if su <= 2:
                d["severe_under_low"] += 1
            if so <= 2:
                d["severe_over_low"] += 1
        for key, col in contrast_keys:
            lo = label_of(rows, "low_contrast", col)
            o = label_of(rows, "original", col)
            exc = label_of(rows, "excessively_high_contrast", col)
            if not all(ok(x) for x in (lo, o, exc)):
                continue
            d = direction[f"contrast_{key}"]
            d["n"] += 1
            if lo <= o <= exc:
                d["monotone_in_magnitude"] += 1
            if exc < o:
                d["drops_at_excessive"] += 1

    # ---- false-positive risk flags (based on ORIGINAL features) ----
    orig_rows = [r for r in records if r["variant"] == "original"]
    fp = {"high_key": [], "low_key": [], "low_contrast_natural": []}
    for r in orig_rows:
        sid = r["source_id"]
        if r["luma_mean"] > 0.65:
            fp["high_key"].append({"source_id": sid, "luma_mean": r["luma_mean"],
                                   "label_B1": r["label_B1"], "label_B2": r["label_B2"],
                                   "clip_hi": r["clip_hi"]})
        elif r["luma_mean"] < 0.25:
            fp["low_key"].append({"source_id": sid, "luma_mean": r["luma_mean"],
                                  "label_B1": r["label_B1"], "label_B2": r["label_B2"],
                                  "clip_lo": r["clip_lo"]})
        if r["luma_std"] < 0.10:
            fp["low_contrast_natural"].append({"source_id": sid, "luma_std": r["luma_std"],
                                               "label_C1": r["label_C1"], "label_C2": r["label_C2"]})
    fp_summary = {k: len(v) for k, v in fp.items()}
    # potential false-positive: high/low key with NO clipped spike but B2 label <= 2
    fp_risk = {
        "high_key_no_spike_low_badge": [x for x in fp["high_key"] if x["clip_hi"] < 0.05 and x["label_B2"] <= 2],
        "low_key_no_spike_low_badge": [x for x in fp["low_key"] if x["clip_lo"] < 0.05 and x["label_B2"] <= 2],
    }

    payload = {
        "generated_at": now_iso(),
        "validation": validation,
        "mean_by_variant": mean_by_variant,
        "direction": direction,
        "false_positive_flags": fp,
        "false_positive_summary": fp_summary,
        "false_positive_risk": fp_risk,
        "candidates": list(CANDS),
        "anchors_note": "1-5 anchors [0.20,0.40,0.62,0.82] are TEMPORARY DIAGNOSTIC labels, unvalidated, not for production.",
        "notes": [
            "Research-only diagnostic. No production code changed. No SPAQ-200 access. No retraining.",
            "Parameters are a-priori placeholders, NOT fit on these distortions. No winner selected.",
            "Controlled distortions measure objective behavior, NOT perceptual accuracy. No human labels invented.",
            "B2 distinguishes clipped spike (at 0/255) from ordinary tonal extremes (band); penalties bounded.",
            "C2 uses one combined bounded extremes fraction (no double-count); output in [0,1].",
            "detail_mid_raw is DIAGNOSTIC ONLY and is NOT used in B/C quality formulas.",
            "Video aggregation NOT implemented. Future research alternatives: per-frame median(Q), lower-percentile(Q) for worst-frame sensitivity, and poor-frame-fraction (fraction of frames below a Q threshold).",
        ],
    }

    # ---- write CSV ----
    csv_fields = ["source_id", "variant", "family", "gain", "luma_mean", "luma_std", "local_std",
                  "mid_cov", "clip_lo", "clip_hi", "band_lo", "band_hi", "extremes", "detail_mid_raw",
                  "Q_B1", "Q_B2", "Q_C1", "Q_C2", "label_B1", "label_B2", "label_C1", "label_C2",
                  "enet_raw_brightness", "enet_raw_contrast", "enet_brightness_badge", "enet_contrast_badge",
                  "opencv_raw_brightness", "opencv_raw_contrast", "opencv_brightness_badge", "opencv_contrast_badge"]
    with (OUT_ROOT / "brightness_contrast_candidates.csv").open("w", newline="", encoding="utf-8") as h:
        w = csv.DictWriter(h, fieldnames=csv_fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(records)
    (OUT_ROOT / "brightness_contrast_candidates.json").write_text(
        json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
    write_report(OUT_ROOT / "BRIGHTNESS_CONTRAST_CANDIDATES_REPORT.md", payload)

    print("[BCCE] ---- summary ----", flush=True)
    print(json.dumps({
        "records": len(records), "expected": expected, "records_ok": validation["records_ok"],
        "failures": len(failures),
        "direction_brightness_B2_drops_both": direction["brightness_B2"]["drops_both"],
        "direction_brightness_B2_severe_under_low": direction["brightness_B2"]["severe_under_low"],
        "direction_contrast_C2_drops_at_excessive": direction["contrast_C2"]["drops_at_excessive"],
        "direction_contrast_C1_monotone": direction["contrast_C1"]["monotone_in_magnitude"],
        "false_positive_summary": fp_summary,
        "out": str(OUT_ROOT),
    }, indent=2, default=str), flush=True)
    print("BCCE_DONE", flush=True)
    return 0 if validation["records_ok"] else 2


def write_report(path: Path, p: dict[str, Any]) -> None:
    v = p["validation"]
    mb = p["mean_by_variant"]
    d = p["direction"]
    lines = [
        "# ACCESS VisionCheck — Brightness/Contrast candidate diagnostic (research only)",
        "",
        f"**Generated:** {p['generated_at']}",
        "",
        "Research-only diagnostic. No production code/weights/thresholds changed. No SPAQ-200 access. No retraining. "
        "Candidate parameters are a-priori placeholders, **not** fit on these distortions; no winner is selected. "
        "Controlled distortions measure objective behavior, **not** perceptual accuracy. ",
        p["anchors_note"],
        "",
        f"## Validation",
        "",
        f"- records: {v['actual_records']}/{v['expected_records']} **ok={v['records_ok']}**; sources={v['n_sources']}; variants={v['n_variants']}; failures={v['n_failures']}",
        "",
        "## Mean by variant (across sources)",
        "",
        "| Variant | luma_mean | luma_std | Q_B1 | Q_B2 | Q_C1 | Q_C2 | lbl_B1 | lbl_B2 | lbl_C1 | lbl_C2 | enet_B | opencv_B | enet_C | opencv_C |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for vn in [x[0] for x in VARIANTS]:
        m = mb[vn]
        lines.append(f"| {vn} | {m['luma_mean']} | {m['luma_std']} | {m['Q_B1']} | {m['Q_B2']} | "
                     f"{m['Q_C1']} | {m['Q_C2']} | {m['label_B1']} | {m['label_B2']} | {m['label_C1']} | "
                     f"{m['label_C2']} | {m['enet_brightness_badge']} | {m['opencv_brightness_badge']} | "
                     f"{m['enet_contrast_badge']} | {m['opencv_contrast_badge']} |")

    lines += ["", "## Within-source direction (counts over evaluable sources)", "",
              "brightness: drops_both = label(original) >= label(under) AND >= label(over); severe_*_low = <=2.",
              "contrast: monotone = label(low) <= label(orig) <= label(excessive); drops_at_excessive = label(excessive) < label(orig).",
              "",
              "| Series | n | drops_both / monotone | severe_under_low | severe_over_low | drops_at_excessive |",
              "|---|---|---|---|---|---|"]
    for k in ("B1", "B2", "enet", "opencv"):
        b = d[f"brightness_{k}"]
        lines.append(f"| brightness {k} | {b['n']} | {b['drops_both']} | {b['severe_under_low']} | {b['severe_over_low']} | - |")
    for k in ("C1", "C2", "enet", "opencv"):
        c = d[f"contrast_{k}"]
        lines.append(f"| contrast {k} | {c['n']} | {c['monotone_in_magnitude']} | - | - | {c['drops_at_excessive']} |")

    fp = p["false_positive_summary"]
    fpr = p["false_positive_risk"]
    lines += ["", "## False-positive risk (based on ORIGINAL images)", "",
              f"- high_key originals (luma_mean>0.65): {fp['high_key']}",
              f"- low_key originals (luma_mean<0.25): {fp['low_key']}",
              f"- naturally low-contrast originals (luma_std<0.10): {fp['low_contrast_natural']}",
              "",
              "Potential false-positives (high/low key with NO clipped spike but B2 diagnostic label <= 2):",
              f"- high_key: {len(fpr['high_key_no_spike_low_badge'])} sources",
              f"- low_key: {len(fpr['low_key_no_spike_low_badge'])} sources",
              "",
              "Note: intentionally high-key/low-key or flat scenes may receive low diagnostic labels. "
              "This is a known limitation of clipping/exposure heuristics; final tolerances require independent human-rated validation.",
              "",
              "## Limitations",
              "",
              "- Controlled distortions are diagnostic, not perceptual accuracy. No human ground-truth invented.",
              "- Parameters are placeholders; do not deploy. No winner selected from these data.",
              "- detail_mid_raw is diagnostic only and is NOT used in B/C quality.",
              "- B2/C2 clipping heuristics can false-positive on intentional high-key/low-key or flat scenes.",
              "- Video aggregation is NOT implemented. Future research alternatives: per-frame median(Q), "
              "lower-percentile(Q) for worst-frame sensitivity, and poor-frame-fraction (fraction of frames below a Q threshold).",
              "",
              "No production code changed. No deploy or integration. Stopped for review.",
              "",
              f"Artifacts: `{OUT_ROOT}`",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
