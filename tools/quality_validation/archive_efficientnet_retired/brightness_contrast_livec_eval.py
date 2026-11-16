#!/usr/bin/env python3
"""ACCESS VisionCheck — research-only LIVEC Brightness/Contrast diagnostic.

Declared BEFORE scoring:
  SELECTION_SEED = 20261108
  N = 200 LIVEC test images, 40 per MOS quintile (cuts from the 1162 test MOS).
  Training images t1–t7 excluded. SPAQ-200 is not accessed.
  Candidate PARAMS/ANCHORS are unchanged a-priori placeholders. No fitting.
  No winner is selected. LIVEC MOS is overall quality only, not Brightness/Contrast GT.

Writes only under workspace/datasets/livec/output/run_bc_livec_001/.
Aborts if those artifacts already exist. Does not modify production files.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
import statistics
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for _p in (str(_BACKEND), str(_REPO), str(_TOOLKIT)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from brightness_contrast_candidates import ANCHORS, ANCHORS_NOTE, candidates_for_image  # noqa: E402
from research_datasets import STRATUM_LABELS, assign_mos_quintile, koniq_quintile_cuts  # noqa: E402

try:
    import cv2
    import numpy as np
    from scipy.io import loadmat
except ImportError as exc:  # pragma: no cover
    cv2 = None  # type: ignore
    np = None  # type: ignore
    loadmat = None  # type: ignore
    _IMPORT_ERR = str(exc)
else:
    _IMPORT_ERR = ""

LIVEC_ROOT = _TOOLKIT / "workspace" / "datasets" / "livec" / "ChallengeDB_release"
CONTROLLED_GENERATED = (
    _TOOLKIT / "workspace" / "datasets" / "brightness_contrast_controlled" / "generated"
)
DEFAULT_OUT = _TOOLKIT / "workspace" / "datasets" / "livec" / "output" / "run_bc_livec_001"

# Documented before scoring. Do not change after looking at LIVEC correlations.
SELECTION_SEED = 20261108
N_SELECT = 200
N_PER_QUINTILE = 40
EXPECTED_TEST_N = 1162
EXPECTED_TRAIN_N = 7
ARTIFACTS = (
    "brightness_contrast_livec.csv",
    "brightness_contrast_livec.json",
    "BRIGHTNESS_CONTRAST_LIVEC_REPORT.md",
)

# Heuristics copied from the controlled-candidate report (diagnostic only).
HIGH_KEY = 0.65
LOW_KEY = 0.25
FLAT_STD = 0.10
HARSH_EXTREMES = 0.20
SPIKE_EPS = 0.05


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def mean_safe(values: list[Any]) -> float | None:
    vals = [float(v) for v in values if isinstance(v, (int, float))]
    return round(statistics.fmean(vals), 4) if vals else None


def spearman(xs: list[float], ys: list[float]) -> float | None:
    try:
        from scipy import stats

        if len(xs) < 5 or len(xs) != len(ys):
            return None
        if len(set(xs)) < 2 or len(set(ys)) < 2:
            return None
        return float(stats.spearmanr(xs, ys).correlation)
    except Exception:  # noqa: BLE001
        return None


def badge_hist(values: list[Any]) -> dict[str, int]:
    out = {str(k): 0 for k in range(1, 6)}
    for v in values:
        if isinstance(v, (int, float)) and 1 <= int(v) <= 5:
            out[str(int(v))] += 1
    return out


def controlled_source_ids() -> set[str]:
    if not CONTROLLED_GENERATED.is_dir():
        return set()
    return {p.name for p in CONTROLLED_GENERATED.iterdir() if p.is_dir()}


def resolve_image(name: str, images_dir: Path, train_dir: Path) -> Path | None:
    lowered = name.lower()
    for folder in (train_dir, images_dir):
        if not folder.is_dir():
            continue
        direct = folder / name
        if direct.is_file():
            return direct
        hits = [p for p in folder.iterdir() if p.is_file() and p.name.lower() == lowered]
        if len(hits) == 1:
            return hits[0]
    return None


def load_livec_rows(root: Path) -> list[dict[str, Any]]:
    if loadmat is None or np is None:
        raise SystemExit(f"ABORT: numpy/scipy required ({_IMPORT_ERR})")
    images_dir = root / "Images"
    train_dir = images_dir / "trainingImages"
    names = np.asarray(
        loadmat(str(root / "Data" / "AllImages_release.mat"), squeeze_me=True)["AllImages_release"]
    ).ravel()
    mos = np.asarray(
        loadmat(str(root / "Data" / "AllMOS_release.mat"), squeeze_me=True)["AllMOS_release"],
        dtype=float,
    ).ravel()
    if names.shape[0] != mos.shape[0]:
        raise SystemExit(f"MAT length mismatch: names={names.shape[0]} mos={mos.shape[0]}")
    rows: list[dict[str, Any]] = []
    for i, (name, score) in enumerate(zip((str(n) for n in names), mos, strict=True)):
        split = "subject_training" if i < EXPECTED_TRAIN_N else "test"
        path = resolve_image(name, images_dir, train_dir)
        rows.append(
            {
                "index": i,
                "source_media_key": name,
                "stem": Path(name).stem,
                "mos_quality_raw": float(score),
                "split": split,
                "image_path": str(path) if path else None,
            }
        )
    return rows


def assign_strata(test_rows: list[dict[str, Any]]) -> tuple[float, ...]:
    cuts = koniq_quintile_cuts([r["mos_quality_raw"] for r in test_rows])
    for rec in test_rows:
        q = assign_mos_quintile(rec["mos_quality_raw"], cuts)
        rec["stratum_id"] = q
        rec["stratum_label"] = STRATUM_LABELS[q]
    return cuts


def select_livec200(
    test_rows: list[dict[str, Any]],
    *,
    seed: int = SELECTION_SEED,
    n_per: int = N_PER_QUINTILE,
    exclude_stems: set[str] | None = None,
) -> list[dict[str, Any]]:
    """MOS-quintile sample. Call only after strata are assigned. Seed is fixed a priori."""
    exclude_stems = exclude_stems or set()
    seen: set[str] = set()
    pool: list[dict[str, Any]] = []
    for rec in test_rows:
        key = rec["source_media_key"]
        stem = rec.get("stem") or Path(key).stem
        if rec.get("split") == "subject_training":
            continue
        if key in seen or stem in exclude_stems:
            continue
        seen.add(key)
        pool.append(rec)
    rng = random.Random(seed)
    selected: list[dict[str, Any]] = []
    for q in range(1, 6):
        band = [r for r in pool if r.get("stratum_id") == q]
        band.sort(key=lambda r: (r["source_media_key"], r["index"]))
        if len(band) < n_per:
            raise SystemExit(f"quintile {q} has {len(band)} images, need {n_per}")
        selected.extend(rng.sample(band, n_per))
    selected.sort(key=lambda r: (r["stratum_id"], r["source_media_key"]))
    if len(selected) != n_per * 5:
        raise SystemExit(f"expected {n_per * 5}, got {len(selected)}")
    keys = [r["source_media_key"] for r in selected]
    if len(keys) != len(set(keys)):
        raise SystemExit("duplicate source_media_key in selection")
    return selected


def abort_if_existing(out_dir: Path) -> None:
    existing = [name for name in ARTIFACTS if (out_dir / name).exists()]
    if existing:
        raise SystemExit(
            "ABORT: output already exists, refusing to overwrite: "
            + ", ".join(existing)
            + f" in {out_dir}"
        )


def import_production_scorers() -> dict[str, Any]:
    """Read-only inference helpers. Do not open DB sessions or write files."""
    from app.services.efficientnet_b0_scorer import (
        analyze_image_bytes as enet_analyze,
        efficientnet_available,
        ensure_weights,
    )
    from app.services.media_evaluator import _brightness_metric, _soft_score
    from app.services.opencv_quality import analyze_image_bytes as opencv_analyze
    from app.services.opencv_quality import opencv_available

    enet_ok = bool(efficientnet_available() and ensure_weights())
    return {
        "enet_analyze": enet_analyze,
        "opencv_analyze": opencv_analyze,
        "brightness_metric": _brightness_metric,
        "soft_score": _soft_score,
        "enet_ok": enet_ok,
        "opencv_ok": bool(opencv_available()),
    }


def score_engine(content: bytes, engine: str, rt: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {"engine": engine, "error": None}
    raw = None
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
    out.update(
        {
            "raw_brightness": rb,
            "raw_contrast": rc,
            "brightness_metric": bm,
            "contrast_transformed": ct,
            "brightness_badge": bb,
            "contrast_badge": cb,
        }
    )
    return out


def decode_bgr(content: bytes):
    if cv2 is None or np is None:
        return None
    arr = np.frombuffer(content, dtype=np.uint8)
    return cv2.imdecode(arr, cv2.IMREAD_COLOR)


def evaluate_one(rec: dict[str, Any], rt: dict[str, Any]) -> dict[str, Any]:
    row: dict[str, Any] = {
        "source_media_key": rec["source_media_key"],
        "livec_index": rec["index"],
        "mos_quality_raw": rec["mos_quality_raw"],
        "mos_is_overall_not_brightness_or_contrast": True,
        "stratum_id": rec["stratum_id"],
        "stratum_label": rec["stratum_label"],
        "image_path": rec.get("image_path"),
        "status": "ok",
        "error": "",
    }
    path = Path(rec["image_path"]) if rec.get("image_path") else None
    if path is None or not path.is_file():
        row["status"] = "missing_file"
        row["error"] = "missing_file"
        return row
    content = path.read_bytes()
    bgr = decode_bgr(content)
    if bgr is None:
        row["status"] = "decode_failed"
        row["error"] = "decode_failed"
        return row
    try:
        cand = candidates_for_image(bgr)
    except Exception as exc:  # noqa: BLE001
        row["status"] = "candidate_failed"
        row["error"] = f"{type(exc).__name__}: {exc}"
        return row
    feat = cand["features"]
    row.update(
        {
            "width": feat.get("width"),
            "height": feat.get("height"),
            "luma_mean": feat["luma_mean"],
            "luma_std": feat["luma_std"],
            "local_std": feat["local_std"],
            "mid_cov": feat["mid_cov"],
            "clip_lo": feat["clip_lo"],
            "clip_hi": feat["clip_hi"],
            "band_lo": feat["band_lo"],
            "band_hi": feat["band_hi"],
            "extremes": feat["extremes"],
            "detail_mid_raw": feat["detail_mid_raw"],
            "Q_B1": cand["Q_B1"],
            "Q_B2": cand["Q_B2"],
            "Q_C1": cand["Q_C1"],
            "Q_C2": cand["Q_C2"],
            "label_B1": cand["label_B1"],
            "label_B2": cand["label_B2"],
            "label_C1": cand["label_C1"],
            "label_C2": cand["label_C2"],
        }
    )
    errors: list[str] = []
    enet = score_engine(content, "efficientnet-b0", rt)
    ocv = score_engine(content, "opencv", rt)
    if enet.get("error"):
        errors.append(f"enet:{enet['error']}")
    if ocv.get("error"):
        errors.append(f"opencv:{ocv['error']}")
    row.update(
        {
            "enet_raw_brightness": enet.get("raw_brightness"),
            "enet_raw_contrast": enet.get("raw_contrast"),
            "enet_brightness_badge": enet.get("brightness_badge"),
            "enet_contrast_badge": enet.get("contrast_badge"),
            "opencv_raw_brightness": ocv.get("raw_brightness"),
            "opencv_raw_contrast": ocv.get("raw_contrast"),
            "opencv_brightness_badge": ocv.get("brightness_badge"),
            "opencv_contrast_badge": ocv.get("contrast_badge"),
        }
    )
    if errors:
        row["status"] = "partial"
        row["error"] = "; ".join(errors)
    return row


def disagree_count(a: list[Any], b: list[Any], *, min_gap: int = 2) -> int:
    n = 0
    for x, y in zip(a, b, strict=True):
        if isinstance(x, (int, float)) and isinstance(y, (int, float)):
            if abs(int(x) - int(y)) >= min_gap:
                n += 1
    return n


def write_report(path: Path, payload: dict[str, Any]) -> None:
    d = payload["distributions"]
    lines = [
        "# ACCESS VisionCheck — LIVEC Brightness/Contrast automated diagnostic (research only)",
        "",
        f"**Generated:** {payload['generated_at']}",
        f"**Selection seed (declared before scoring):** `{payload['selection']['seed']}`",
        f"**Sample:** {payload['selection']['n_selected']} LIVEC test images, "
        f"{payload['selection']['n_per_quintile']} per MOS quintile.",
        "",
        "Research-only. Production scoring, APIs, Flutter, weights, and thresholds were not changed. "
        "SPAQ-200 was not accessed. Candidate parameters were not fit on this sample. "
        "No winner is selected.",
        "",
        "LIVEC MOS is **overall** perceptual quality from the LIVE Challenge study. "
        "It is **not** human ground truth for ACCESS Brightness or Contrast. "
        "Spearman vs MOS below is supplementary context only.",
        "",
        "Diagnostic 1-5 labels use temporary anchors "
        f"`{payload['anchors']}` ({payload['anchors_note']}).",
        "",
        "## Validation",
        "",
        f"- selected={payload['selection']['n_selected']} unique keys="
        f"{payload['selection']['n_unique_keys']} ok={payload['validation']['n_ok']} "
        f"partial={payload['validation']['n_partial']} failed={payload['validation']['n_failed']}",
        f"- excluded_training={payload['selection']['n_training_excluded']} "
        f"excluded_controlled_stems={payload['selection']['n_controlled_excluded']}",
        f"- wall_s={payload['runtime']['wall_s']} mean_ms={payload['runtime']['ms_mean']}",
        "",
        "## Rating histograms (diagnostic 1-5 or production badges)",
        "",
        "| Method | Kind | n | 1 | 2 | 3 | 4 | 5 | mean | floor% (1) | ceiling% (5) |",
        "|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for name, block in d.items():
        h = block["hist"]
        n = block["n"]
        lines.append(
            f"| {name} | {block['kind']} | {n} | {h.get('1', 0)} | {h.get('2', 0)} | "
            f"{h.get('3', 0)} | {h.get('4', 0)} | {h.get('5', 0)} | {block['mean']} | "
            f"{block['floor_pct']} | {block['ceiling_pct']} |"
        )
    lines += [
        "",
        "## Method disagreement (absolute integer gap >= 2, n scored both)",
        "",
        "| Pair | n | n_gap>=2 |",
        "|---|---|---|",
    ]
    for pair, block in payload["disagreement"].items():
        lines.append(f"| {pair} | {block['n']} | {block['n_gap_ge_2']} |")
    lines += [
        "",
        "## Supplementary Spearman vs LIVEC overall MOS (not attribute GT)",
        "",
        "| Series | Spearman vs MOS | n |",
        "|---|---|---|",
    ]
    for name, block in payload["mos_context"].items():
        lines.append(f"| {name} | {block['spearman']} | {block['n']} |")
    fp = payload["false_positive_flags"]
    lines += [
        "",
        "## Potential false-positive / construct-mismatch flags (heuristic, not human labels)",
        "",
        f"- high-key originals (luma_mean>{HIGH_KEY}): {fp['n_high_key']}",
        f"- low-key originals (luma_mean<{LOW_KEY}): {fp['n_low_key']}",
        f"- naturally flat (luma_std<{FLAT_STD}): {fp['n_flat']}",
        f"- high extremes fraction (extremes>{HARSH_EXTREMES}): {fp['n_harsh']}",
        f"- high-key, clip_hi<{SPIKE_EPS}, B2 label<=2: {len(fp['high_key_no_spike_low_b2'])}",
        f"- low-key, clip_lo<{SPIKE_EPS}, B2 label<=2: {len(fp['low_key_no_spike_low_b2'])}",
        f"- flat, C2 label<=2: {len(fp['flat_low_c2'])}",
        f"- harsh extremes, C1 label>=4 (C1 may reward punch): {len(fp['harsh_high_c1'])}",
        "",
        "Example source_media_key values (up to 8):",
        f"- high_key_no_spike_low_b2: {fp['high_key_no_spike_low_b2'][:8]}",
        f"- low_key_no_spike_low_b2: {fp['low_key_no_spike_low_b2'][:8]}",
        f"- flat_low_c2: {fp['flat_low_c2'][:8]}",
        f"- harsh_high_c1: {fp['harsh_high_c1'][:8]}",
        "",
        "## Limitations",
        "",
        "- Automated diagnostics on real-world LIVEC photos. Not perceptual accuracy for Brightness or Contrast.",
        "- No independent ACCESS 1-5 human ratings were collected.",
        "- Temporary diagnostic anchors are unvalidated.",
        "- Production `_soft_score` still cannot emit badge 1 for q in [0,1].",
        "- Video is out of scope.",
        "- Do not deploy from this file.",
        "",
        "No production code changed. No candidate integrated.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def build_payload(rows: list[dict[str, Any]], meta: dict[str, Any]) -> dict[str, Any]:
    ok_rows = [r for r in rows if r.get("status") in {"ok", "partial"}]
    series = {
        "B1": ("label_B1", "candidate"),
        "B2": ("label_B2", "candidate"),
        "C1": ("label_C1", "candidate"),
        "C2": ("label_C2", "candidate"),
        "enet_brightness": ("enet_brightness_badge", "production_badge"),
        "enet_contrast": ("enet_contrast_badge", "production_badge"),
        "opencv_brightness": ("opencv_brightness_badge", "production_badge"),
        "opencv_contrast": ("opencv_contrast_badge", "production_badge"),
    }
    distributions: dict[str, Any] = {}
    for name, (col, kind) in series.items():
        vals = [r[col] for r in ok_rows if isinstance(r.get(col), (int, float))]
        hist = badge_hist(vals)
        n = len(vals)
        distributions[name] = {
            "kind": kind,
            "n": n,
            "hist": hist,
            "mean": mean_safe(vals),
            "floor_pct": round(100.0 * hist["1"] / n, 2) if n else None,
            "ceiling_pct": round(100.0 * hist["5"] / n, 2) if n else None,
        }

    def col(name: str) -> list[Any]:
        return [r.get(name) for r in ok_rows]

    pairs = [
        ("B1_vs_enet_brightness", "label_B1", "enet_brightness_badge"),
        ("B2_vs_enet_brightness", "label_B2", "enet_brightness_badge"),
        ("B1_vs_opencv_brightness", "label_B1", "opencv_brightness_badge"),
        ("B2_vs_opencv_brightness", "label_B2", "opencv_brightness_badge"),
        ("C1_vs_enet_contrast", "label_C1", "enet_contrast_badge"),
        ("C2_vs_enet_contrast", "label_C2", "enet_contrast_badge"),
        ("C1_vs_opencv_contrast", "label_C1", "opencv_contrast_badge"),
        ("C2_vs_opencv_contrast", "label_C2", "opencv_contrast_badge"),
        ("B1_vs_B2", "label_B1", "label_B2"),
        ("C1_vs_C2", "label_C1", "label_C2"),
        ("enet_vs_opencv_brightness", "enet_brightness_badge", "opencv_brightness_badge"),
        ("enet_vs_opencv_contrast", "enet_contrast_badge", "opencv_contrast_badge"),
    ]
    disagreement: dict[str, Any] = {}
    for pname, a, b in pairs:
        aa, bb = [], []
        for r in ok_rows:
            if isinstance(r.get(a), (int, float)) and isinstance(r.get(b), (int, float)):
                aa.append(r[a])
                bb.append(r[b])
        disagreement[pname] = {"n": len(aa), "n_gap_ge_2": disagree_count(aa, bb)}

    mos_pairs = [
        ("mos_vs_B1", "label_B1"),
        ("mos_vs_B2", "label_B2"),
        ("mos_vs_C1", "label_C1"),
        ("mos_vs_C2", "label_C2"),
        ("mos_vs_enet_brightness", "enet_brightness_badge"),
        ("mos_vs_enet_contrast", "enet_contrast_badge"),
        ("mos_vs_opencv_brightness", "opencv_brightness_badge"),
        ("mos_vs_opencv_contrast", "opencv_contrast_badge"),
        ("mos_vs_Q_B1", "Q_B1"),
        ("mos_vs_Q_B2", "Q_B2"),
        ("mos_vs_Q_C1", "Q_C1"),
        ("mos_vs_Q_C2", "Q_C2"),
    ]
    mos_context: dict[str, Any] = {}
    for pname, coln in mos_pairs:
        xs, ys = [], []
        for r in ok_rows:
            if isinstance(r.get("mos_quality_raw"), (int, float)) and isinstance(
                r.get(coln), (int, float)
            ):
                xs.append(float(r["mos_quality_raw"]))
                ys.append(float(r[coln]))
        mos_context[pname] = {
            "spearman": None if spearman(xs, ys) is None else round(spearman(xs, ys), 4),
            "n": len(xs),
            "note": "overall MOS, not Brightness/Contrast human GT",
        }

    high_key = [r for r in ok_rows if isinstance(r.get("luma_mean"), float) and r["luma_mean"] > HIGH_KEY]
    low_key = [r for r in ok_rows if isinstance(r.get("luma_mean"), float) and r["luma_mean"] < LOW_KEY]
    flat = [r for r in ok_rows if isinstance(r.get("luma_std"), float) and r["luma_std"] < FLAT_STD]
    harsh = [r for r in ok_rows if isinstance(r.get("extremes"), float) and r["extremes"] > HARSH_EXTREMES]
    fp = {
        "n_high_key": len(high_key),
        "n_low_key": len(low_key),
        "n_flat": len(flat),
        "n_harsh": len(harsh),
        "high_key_no_spike_low_b2": [
            r["source_media_key"]
            for r in high_key
            if r.get("clip_hi", 1) < SPIKE_EPS and isinstance(r.get("label_B2"), int) and r["label_B2"] <= 2
        ],
        "low_key_no_spike_low_b2": [
            r["source_media_key"]
            for r in low_key
            if r.get("clip_lo", 1) < SPIKE_EPS and isinstance(r.get("label_B2"), int) and r["label_B2"] <= 2
        ],
        "flat_low_c2": [
            r["source_media_key"]
            for r in flat
            if isinstance(r.get("label_C2"), int) and r["label_C2"] <= 2
        ],
        "harsh_high_c1": [
            r["source_media_key"]
            for r in harsh
            if isinstance(r.get("label_C1"), int) and r["label_C1"] >= 4
        ],
    }
    return {
        **meta,
        "anchors": ANCHORS,
        "anchors_note": ANCHORS_NOTE,
        "distributions": distributions,
        "disagreement": disagreement,
        "mos_context": mos_context,
        "false_positive_flags": fp,
        "recommendation": (
            "Keep production frozen. Next research: human Brightness/Contrast ratings on a "
            "subset of these 200, or inspect flagged low-key B2 cases. Do not fit on this sample."
        ),
    }


CSV_FIELDS = [
    "source_media_key",
    "livec_index",
    "mos_quality_raw",
    "mos_is_overall_not_brightness_or_contrast",
    "stratum_id",
    "stratum_label",
    "status",
    "error",
    "width",
    "height",
    "luma_mean",
    "luma_std",
    "local_std",
    "mid_cov",
    "clip_lo",
    "clip_hi",
    "band_lo",
    "band_hi",
    "extremes",
    "detail_mid_raw",
    "Q_B1",
    "Q_B2",
    "Q_C1",
    "Q_C2",
    "label_B1",
    "label_B2",
    "label_C1",
    "label_C2",
    "enet_raw_brightness",
    "enet_raw_contrast",
    "enet_brightness_badge",
    "enet_contrast_badge",
    "opencv_raw_brightness",
    "opencv_raw_contrast",
    "opencv_brightness_badge",
    "opencv_contrast_badge",
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--livec-root", type=Path, default=LIVEC_ROOT)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    if cv2 is None:
        raise SystemExit(f"ABORT: OpenCV required ({_IMPORT_ERR})")

    out_dir = args.output_dir
    abort_if_existing(out_dir)

    print(
        f"[BC-LIVEC] seed={SELECTION_SEED} n={N_SELECT} n_per_quintile={N_PER_QUINTILE} "
        "(declared before scoring)",
        flush=True,
    )
    rows_all = load_livec_rows(args.livec_root)
    train = [r for r in rows_all if r["split"] == "subject_training"]
    test = [r for r in rows_all if r["split"] == "test"]
    if len(test) != EXPECTED_TEST_N or len(train) != EXPECTED_TRAIN_N:
        raise SystemExit(f"unexpected LIVEC counts test={len(test)} train={len(train)}")
    cuts = assign_strata(test)
    exclude = controlled_source_ids()
    n_before = len(test)
    selected = select_livec200(test, seed=SELECTION_SEED, n_per=N_PER_QUINTILE, exclude_stems=exclude)
    skipped_controlled = n_before - len(
        {r["source_media_key"] for r in test if Path(r["source_media_key"]).stem not in exclude}
    )

    rt = import_production_scorers()
    print(f"[BC-LIVEC] enet_ok={rt['enet_ok']} opencv_ok={rt['opencv_ok']}", flush=True)

    scored: list[dict[str, Any]] = []
    t0 = time.perf_counter()
    times: list[float] = []
    for i, rec in enumerate(selected, start=1):
        print(f"[BC-LIVEC {i}/{len(selected)}] {rec['source_media_key']}", flush=True)
        t1 = time.perf_counter()
        scored.append(evaluate_one(rec, rt))
        times.append((time.perf_counter() - t1) * 1000.0)
    wall = time.perf_counter() - t0

    n_ok = sum(1 for r in scored if r["status"] == "ok")
    n_partial = sum(1 for r in scored if r["status"] == "partial")
    n_failed = sum(1 for r in scored if r["status"] not in {"ok", "partial"})
    counts = Counter(r["stratum_id"] for r in selected)
    meta = {
        "generated_at": now_iso(),
        "phase": "livec_brightness_contrast_research",
        "fitted_on_livec": False,
        "winner_selected": False,
        "spaq200_accessed": False,
        "production_untouched": True,
        "selection": {
            "seed": SELECTION_SEED,
            "n_selected": len(selected),
            "n_per_quintile": N_PER_QUINTILE,
            "n_unique_keys": len({r["source_media_key"] for r in selected}),
            "n_training_excluded": len(train),
            "train_names": [r["source_media_key"] for r in train],
            "n_controlled_excluded": skipped_controlled,
            "controlled_stems_on_disk": sorted(exclude),
            "quintile_cuts": list(cuts),
            "stratum_counts": {str(k): counts[k] for k in range(1, 6)},
            "selected_keys": [r["source_media_key"] for r in selected],
        },
        "validation": {
            "n_ok": n_ok,
            "n_partial": n_partial,
            "n_failed": n_failed,
            "failures": [
                {"source_media_key": r["source_media_key"], "status": r["status"], "error": r["error"]}
                for r in scored
                if r["status"] != "ok"
            ],
        },
        "runtime": {
            "wall_s": wall,
            "ms_mean": (sum(times) / len(times)) if times else None,
        },
        "notes": [
            "LIVEC MOS is overall quality, not Brightness or Contrast human ground truth.",
            "Candidate PARAMS were not updated from this run.",
        ],
    }
    payload = build_payload(scored, meta)
    out_dir.mkdir(parents=True, exist_ok=True)
    abort_if_existing(out_dir)
    csv_path = out_dir / ARTIFACTS[0]
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(scored)
    (out_dir / ARTIFACTS[1]).write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
    write_report(out_dir / ARTIFACTS[2], payload)
    print(
        json.dumps(
            {
                "n_selected": len(selected),
                "n_ok": n_ok,
                "n_partial": n_partial,
                "n_failed": n_failed,
                "wall_s": wall,
                "out": str(out_dir),
            },
            indent=2,
        ),
        flush=True,
    )
    return 0 if n_failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
