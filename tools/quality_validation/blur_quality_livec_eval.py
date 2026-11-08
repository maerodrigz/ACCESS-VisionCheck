#!/usr/bin/env python3
"""ACCESS VisionCheck — Wave B: research-only LIVEC Blur/Sharpness diagnostic.

Declared BEFORE scoring:
  SELECTION_SEED = 20261108 (same as Brightness/Contrast LIVEC 200)
  N = 200 LIVEC test images, 40 per MOS quintile.
  Training images t1–t7 excluded. SPAQ-200 is not accessed.
  LIVEC MOS is overall quality only, not Blur ground truth.
  No winner is selected. No production scoring change.

Writes only under workspace/datasets/livec/output/run_blur_livec_001/.
Aborts if those artifacts already exist.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
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

from blur_quality_audit import run_wave_a  # noqa: E402
from brightness_contrast_livec_eval import (  # noqa: E402
    EXPECTED_TEST_N,
    EXPECTED_TRAIN_N,
    LIVEC_ROOT,
    N_PER_QUINTILE,
    N_SELECT,
    SELECTION_SEED,
    assign_strata,
    controlled_source_ids,
    decode_bgr,
    load_livec_rows,
    select_livec200,
)
from classical_quality_metrics import analyze_image_bytes as classical_analyze  # noqa: E402

try:
    import cv2
    import numpy as np
except ImportError as exc:  # pragma: no cover
    cv2 = None  # type: ignore
    np = None  # type: ignore
    _IMPORT_ERR = str(exc)
else:
    _IMPORT_ERR = ""

DEFAULT_OUT = _TOOLKIT / "workspace" / "datasets" / "livec" / "output" / "run_blur_livec_001"
BC_KEYS_JSON = (
    _TOOLKIT / "workspace" / "datasets" / "livec" / "output" / "run_bc_livec_001" / "brightness_contrast_livec.json"
)
ARTIFACTS = (
    "blur_quality_livec.csv",
    "blur_quality_livec.json",
    "BLUR_QUALITY_LIVEC_REPORT.md",
)
LOW_LUMA = 0.25
HIGH_BLUR_AMOUNT = 0.85
OPENCV_SOFT_CEILING = 0.95

SCORER_PATHS = [
    _BACKEND / "app" / "services" / "efficientnet_b0_scorer.py",
    _BACKEND / "app" / "services" / "opencv_quality.py",
    _BACKEND / "app" / "services" / "media_evaluator.py",
    _BACKEND / "ml" / "efficientnet_b0_heads.pt",
]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def hash_paths(paths: list[Path]) -> dict[str, str]:
    out: dict[str, str] = {}
    for path in paths:
        key = str(path)
        if not path.is_file():
            out[key] = "MISSING"
            continue
        out[key] = sha256_file(path)
    return out


def abort_if_existing(out_dir: Path) -> None:
    existing = [name for name in ARTIFACTS if (out_dir / name).exists()]
    if existing:
        raise SystemExit(
            "ABORT: output already exists, refusing to overwrite: "
            + ", ".join(existing)
            + f" in {out_dir}"
        )


def load_bc_selected_keys(path: Path) -> list[str]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    selection = payload.get("selection") or {}
    seed = selection.get("seed")
    if seed != SELECTION_SEED:
        raise SystemExit(f"ABORT: B/C JSON seed {seed} != {SELECTION_SEED}")
    keys = list(selection.get("selected_keys") or [])
    if len(keys) != N_SELECT:
        raise SystemExit(f"ABORT: B/C JSON has {len(keys)} keys, expected {N_SELECT}")
    return keys


def import_production_scorers() -> dict[str, Any]:
    """Read-only inference helpers. Do not open DB sessions or write files."""
    from app.services.efficientnet_b0_scorer import (
        analyze_image_bytes as enet_analyze,
        efficientnet_available,
        ensure_weights,
    )
    from app.services.media_evaluator import _soft_score
    from app.services.opencv_quality import analyze_image_bytes as opencv_analyze
    from app.services.opencv_quality import opencv_available

    enet_ok = bool(efficientnet_available() and ensure_weights())
    return {
        "enet_analyze": enet_analyze,
        "opencv_analyze": opencv_analyze,
        "soft_score": _soft_score,
        "enet_ok": enet_ok,
        "opencv_ok": bool(opencv_available()),
    }


def _engine_pack(raw: dict[str, Any] | None, error: str | None, soft_score) -> dict[str, Any]:
    out: dict[str, Any] = {"error": error}
    if raw is None:
        return out
    rb = raw.get("blur")
    rs = raw.get("sharpness")
    q_blur = (1.0 - float(rb)) if isinstance(rb, (int, float)) else None
    q_sharp = float(rs) if isinstance(rs, (int, float)) else None
    out.update(
        {
            "raw_blur": rb,
            "raw_sharpness": rs,
            "q_blur": q_blur,
            "blur_badge": soft_score(q_blur) if q_blur is not None else None,
            "sharpness_badge": soft_score(q_sharp) if q_sharp is not None else None,
            "raw_noise": raw.get("noise"),
            "raw_brightness": raw.get("brightness"),
            "raw_contrast": raw.get("contrast"),
            "raw_blocking": raw.get("blocking_artifacts"),
            "raw_ringing": raw.get("ringing_artifacts"),
        }
    )
    return out


def score_engine(content: bytes, engine: str, rt: dict[str, Any]) -> dict[str, Any]:
    raw = None
    error = None
    try:
        if engine == "efficientnet-b0":
            raw = rt["enet_analyze"](content)
            if raw is None:
                error = "enet_returned_none"
        else:
            raw = rt["opencv_analyze"](content)
            if raw is None:
                error = "opencv_returned_none"
    except Exception as exc:  # noqa: BLE001
        error = f"{type(exc).__name__}: {exc}"
        raw = None
    return _engine_pack(raw, error, rt["soft_score"])


def luma_mean(bgr) -> float | None:
    if cv2 is None or bgr is None:
        return None
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    return float(gray.mean() / 255.0)


def evaluate_one(rec: dict[str, Any], rt: dict[str, Any]) -> dict[str, Any]:
    row: dict[str, Any] = {
        "source_media_key": rec["source_media_key"],
        "livec_index": rec["index"],
        "mos_quality_raw": rec["mos_quality_raw"],
        "mos_is_overall_not_blur": True,
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
    row["width"] = int(bgr.shape[1])
    row["height"] = int(bgr.shape[0])
    row["luma_mean"] = luma_mean(bgr)
    errors: list[str] = []
    enet = score_engine(content, "efficientnet-b0", rt)
    ocv = score_engine(content, "opencv", rt)
    classic = None
    try:
        classic = classical_analyze(content)
    except Exception as exc:  # noqa: BLE001
        errors.append(f"classic:{type(exc).__name__}: {exc}")
    if enet.get("error"):
        errors.append(f"enet:{enet['error']}")
    if ocv.get("error"):
        errors.append(f"opencv:{ocv['error']}")
    oc_s = ocv.get("raw_sharpness")
    oc_b = ocv.get("raw_blur")
    identity = None
    if isinstance(oc_s, (int, float)) and isinstance(oc_b, (int, float)):
        identity = abs(float(oc_s) + float(oc_b) - 1.0)
    row.update(
        {
            "enet_raw_blur": enet.get("raw_blur"),
            "enet_raw_sharpness": enet.get("raw_sharpness"),
            "enet_q_blur": enet.get("q_blur"),
            "enet_blur_badge": enet.get("blur_badge"),
            "enet_sharpness_badge": enet.get("sharpness_badge"),
            "enet_raw_noise": enet.get("raw_noise"),
            "enet_raw_brightness": enet.get("raw_brightness"),
            "enet_raw_contrast": enet.get("raw_contrast"),
            "enet_raw_blocking": enet.get("raw_blocking"),
            "enet_raw_ringing": enet.get("raw_ringing"),
            "opencv_raw_blur": ocv.get("raw_blur"),
            "opencv_raw_sharpness": ocv.get("raw_sharpness"),
            "opencv_q_blur": ocv.get("q_blur"),
            "opencv_blur_badge": ocv.get("blur_badge"),
            "opencv_sharpness_badge": ocv.get("sharpness_badge"),
            "opencv_identity_abs": identity,
            "classic_laplacian_var": None if classic is None else classic.get("sharpness_laplacian_var"),
            "classic_blur_inv_laplacian": None if classic is None else classic.get("blur_inv_laplacian"),
            "classic_tenengrad": None if classic is None else classic.get("sharpness_tenengrad"),
            "flag_low_luma": bool(
                isinstance(row.get("luma_mean"), float) and row["luma_mean"] < LOW_LUMA
            ),
            "flag_high_enet_blur_amount": bool(
                isinstance(enet.get("raw_blur"), (int, float)) and float(enet["raw_blur"]) >= HIGH_BLUR_AMOUNT
            ),
            "flag_opencv_blur_ceiling": bool(
                isinstance(ocv.get("raw_blur"), (int, float)) and float(ocv["raw_blur"]) >= OPENCV_SOFT_CEILING
            ),
        }
    )
    if isinstance(enet.get("blur_badge"), int) and isinstance(ocv.get("blur_badge"), int):
        row["enet_opencv_blur_badge_gap"] = abs(int(enet["blur_badge"]) - int(ocv["blur_badge"]))
    else:
        row["enet_opencv_blur_badge_gap"] = None
    if errors:
        row["status"] = "partial" if row.get("enet_blur_badge") is not None or row.get("opencv_blur_badge") is not None else "failed"
        row["error"] = "; ".join(errors)
    return row


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


def pearson(xs: list[float], ys: list[float]) -> float | None:
    try:
        from scipy import stats

        if len(xs) < 5 or len(xs) != len(ys):
            return None
        if len(set(xs)) < 2 or len(set(ys)) < 2:
            return None
        return float(stats.pearsonr(xs, ys).correlation)
    except Exception:  # noqa: BLE001
        return None


def badge_hist(values: list[Any]) -> dict[str, int]:
    out = {str(k): 0 for k in range(1, 6)}
    for v in values:
        if isinstance(v, (int, float)) and 1 <= int(v) <= 5:
            out[str(int(v))] += 1
    return out


def disagree_count(a: list[Any], b: list[Any], *, min_gap: int = 2) -> int:
    n = 0
    for x, y in zip(a, b, strict=True):
        if isinstance(x, (int, float)) and isinstance(y, (int, float)):
            if abs(int(x) - int(y)) >= min_gap:
                n += 1
    return n


def _corr_block(xs: list[float], ys: list[float], note: str) -> dict[str, Any]:
    return {
        "n": len(xs),
        "pearson": None if pearson(xs, ys) is None else round(pearson(xs, ys), 4),
        "spearman": None if spearman(xs, ys) is None else round(spearman(xs, ys), 4),
        "note": note,
    }


def build_payload(rows: list[dict[str, Any]], meta: dict[str, Any]) -> dict[str, Any]:
    ok_rows = [r for r in rows if r.get("status") in {"ok", "partial"}]
    series = {
        "enet_blur": ("enet_blur_badge", "production_badge"),
        "enet_sharpness": ("enet_sharpness_badge", "production_badge"),
        "opencv_blur": ("opencv_blur_badge", "production_badge"),
        "opencv_sharpness": ("opencv_sharpness_badge", "production_badge"),
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
            "n_unique": len({int(v) for v in vals}),
            "floor_pct": round(100.0 * hist["1"] / n, 2) if n else None,
            "ceiling_pct": round(100.0 * hist["5"] / n, 2) if n else None,
        }

    def paired(a: str, b: str) -> tuple[list[float], list[float]]:
        xs, ys = [], []
        for r in ok_rows:
            if isinstance(r.get(a), (int, float)) and isinstance(r.get(b), (int, float)):
                xs.append(float(r[a]))
                ys.append(float(r[b]))
        return xs, ys

    redundancy = {
        "enet_raw_sharpness_vs_blur": _corr_block(
            *paired("enet_raw_sharpness", "enet_raw_blur"),
            "amount heads; expected negative if duplicate axis",
        ),
        "enet_badge_sharpness_vs_blur": _corr_block(
            *paired("enet_sharpness_badge", "enet_blur_badge"),
            "both high=better; positive if they co-move",
        ),
        "opencv_raw_sharpness_vs_blur": _corr_block(
            *paired("opencv_raw_sharpness", "opencv_raw_blur"),
            "should be exact inverse",
        ),
        "opencv_badge_sharpness_vs_blur": _corr_block(
            *paired("opencv_sharpness_badge", "opencv_blur_badge"),
            "OpenCV badges should match if identity holds",
        ),
        "classic_lap_vs_inv_lap": _corr_block(
            *paired("classic_laplacian_var", "classic_blur_inv_laplacian"),
            "same Laplacian axis",
        ),
        "enet_vs_opencv_blur_raw": _corr_block(
            *paired("enet_raw_blur", "opencv_raw_blur"),
            "not human GT",
        ),
        "enet_vs_opencv_blur_badge": _corr_block(
            *paired("enet_blur_badge", "opencv_blur_badge"),
            "not human GT",
        ),
        "opencv_identity_mean_abs": mean_safe(
            [r.get("opencv_identity_abs") for r in ok_rows]
        ),
        "opencv_identity_max_abs": (
            max(float(r["opencv_identity_abs"]) for r in ok_rows if isinstance(r.get("opencv_identity_abs"), float))
            if any(isinstance(r.get("opencv_identity_abs"), float) for r in ok_rows)
            else None
        ),
    }

    aa, bb = paired("enet_blur_badge", "opencv_blur_badge")
    disagreement = {
        "enet_vs_opencv_blur_badge": {
            "n": len(aa),
            "n_gap_ge_2": disagree_count(aa, bb),
        }
    }
    sa, sb = paired("enet_sharpness_badge", "opencv_sharpness_badge")
    disagreement["enet_vs_opencv_sharpness_badge"] = {
        "n": len(sa),
        "n_gap_ge_2": disagree_count(sa, sb),
    }

    mos_context = {}
    for name, coln in (
        ("mos_vs_enet_blur_badge", "enet_blur_badge"),
        ("mos_vs_opencv_blur_badge", "opencv_blur_badge"),
        ("mos_vs_enet_raw_blur", "enet_raw_blur"),
        ("mos_vs_opencv_raw_blur", "opencv_raw_blur"),
        ("mos_vs_enet_sharpness_badge", "enet_sharpness_badge"),
    ):
        xs, ys = [], []
        for r in ok_rows:
            if isinstance(r.get("mos_quality_raw"), (int, float)) and isinstance(r.get(coln), (int, float)):
                xs.append(float(r["mos_quality_raw"]))
                ys.append(float(r[coln]))
        mos_context[name] = {
            "spearman": None if spearman(xs, ys) is None else round(spearman(xs, ys), 4),
            "n": len(xs),
            "note": "overall MOS, not Blur human GT",
        }

    def keys_where(pred) -> list[str]:
        return [r["source_media_key"] for r in ok_rows if pred(r)]

    review = {
        "n_low_luma": sum(1 for r in ok_rows if r.get("flag_low_luma")),
        "n_high_enet_blur_amount": sum(1 for r in ok_rows if r.get("flag_high_enet_blur_amount")),
        "n_opencv_blur_ceiling": sum(1 for r in ok_rows if r.get("flag_opencv_blur_ceiling")),
        "enet_opencv_blur_gap_ge_2": keys_where(
            lambda r: isinstance(r.get("enet_opencv_blur_badge_gap"), int) and r["enet_opencv_blur_badge_gap"] >= 2
        ),
        "low_luma_and_high_enet_blur": keys_where(
            lambda r: r.get("flag_low_luma") and r.get("flag_high_enet_blur_amount")
        ),
        "opencv_ceiling_enet_badge_ge_4": keys_where(
            lambda r: r.get("flag_opencv_blur_ceiling")
            and isinstance(r.get("enet_blur_badge"), int)
            and r["enet_blur_badge"] >= 4
        ),
        "enet_blur_badge_gt_sharpness_by_2": keys_where(
            lambda r: isinstance(r.get("enet_blur_badge"), int)
            and isinstance(r.get("enet_sharpness_badge"), int)
            and r["enet_blur_badge"] - r["enet_sharpness_badge"] >= 2
        ),
        "note": (
            "Heuristic flags only. Not bokeh, motion-smear, or defocus labels. "
            "Do not treat as human ratings."
        ),
    }

    return {
        **meta,
        "distributions": distributions,
        "redundancy": redundancy,
        "disagreement": disagreement,
        "mos_context": mos_context,
        "human_review_candidates": review,
        "winner_selected": False,
        "recommendation": (
            "Keep production frozen. Wave C (BID/LIVE blur subsets) and human Blur "
            "ratings remain blocked until approved. Do not integrate a Blur candidate."
        ),
    }


def write_report(path: Path, payload: dict[str, Any]) -> None:
    wave_a = payload.get("wave_a") or {}
    p8 = wave_a.get("phase8") or {}
    d = payload["distributions"]
    lines = [
        "# ACCESS VisionCheck — Blur Quality Wave A + Wave B (research only)",
        "",
        f"**Generated:** {payload['generated_at']}",
        f"**Selection seed (declared before scoring):** `{payload['selection']['seed']}`",
        f"**Sample:** {payload['selection']['n_selected']} LIVEC test images, "
        f"{payload['selection']['n_per_quintile']} per MOS quintile (same keys as Brightness/Contrast).",
        "",
        "Research-only. Production scoring, APIs, Flutter, weights, and thresholds were not changed. "
        "SPAQ-200 images were not opened. Frozen Sharpness and exploratory Noise were not modified. "
        "No Blur candidate is integrated. No winner is selected.",
        "",
        "LIVEC MOS is **overall** perceptual quality. It is **not** human ground truth for ACCESS Blur.",
        "",
        "## Production scorer hashes",
        "",
        f"- hashes_match_before_after: `{payload['hashes']['match']}`",
        "",
    ]
    for name, digest in (payload["hashes"].get("before") or {}).items():
        after = (payload["hashes"].get("after") or {}).get(name)
        lines.append(f"- `{Path(name).name}`: before `{digest}` after `{after}`")
    lines += [
        "",
        "## Wave A — saved Phase 8 / 11 / 12 evidence (no rerun)",
        "",
        f"- Phase 8 records used (originals + Gaussian): {p8.get('n_records_used')} "
        f"(originals={p8.get('n_originals')}, gaussian={p8.get('n_gaussian_variants')}, σ=8={p8.get('n_sigma8')})",
        f"- SPAQ-200 images opened: `{wave_a.get('spaq200_images_opened')}`",
        f"- Inference rerun in Wave A: `{wave_a.get('inference_rerun')}`",
        "",
        "### Gaussian severity (median Spearman vs σ, per original)",
        "",
        "| Series | n_images defined | median Spearman |",
        "|---|---|---|",
    ]
    for name, block in (p8.get("gaussian_severity_sensitivity") or {}).items():
        lines.append(
            f"| {name} | {block.get('n_images_defined')}/{block.get('n_images')} | "
            f"{block.get('median_spearman_vs_severity')} |"
        )
    p8r = p8.get("redundancy") or {}
    lines += [
        "",
        "### Phase 8 Sharpness–Blur redundancy",
        "",
        f"- ENET raw sharpness vs blur: {p8r.get('enet_raw_sharpness_vs_blur')}",
        f"- ENET integer Sharpness vs Blur: {p8r.get('enet_int_sharpness_vs_blur')}",
        f"- OpenCV raw sharpness vs blur: {p8r.get('opencv_raw_sharpness_vs_blur')}",
        f"- OpenCV mean |s+b−1|: {p8r.get('opencv_mean_abs_s_plus_b_minus_1')}",
        "",
        "Phase 11 (unlabeled Blur on SPAQ-200 ENET summaries): badges pile at 3 "
        f"(`{(wave_a.get('phase11') or {}).get('blur_badge_hist')}`). "
        "Badge 1 is unreachable for q in [0,1]. SPAQ has no Blur label.",
        "",
        f"Phase 12 unlabeled distributions: `{(wave_a.get('phase12') or {}).get('unlabeled_distributions')}`.",
        "",
        "## Wave B — LIVEC 200",
        "",
        f"- selected={payload['selection']['n_selected']} unique keys="
        f"{payload['selection']['n_unique_keys']} matched_bc_keys="
        f"{payload['selection']['matched_bc_keys']}",
        f"- ok={payload['validation']['n_ok']} partial={payload['validation']['n_partial']} "
        f"failed={payload['validation']['n_failed']}",
        f"- wall_s={payload['runtime']['wall_s']} mean_ms={payload['runtime']['ms_mean']}",
        "",
        "## Rating histograms (member-facing 1-5)",
        "",
        "| Method | n | 1 | 2 | 3 | 4 | 5 | mean | floor% | ceiling% |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for name, block in d.items():
        h = block["hist"]
        lines.append(
            f"| {name} | {block['n']} | {h.get('1', 0)} | {h.get('2', 0)} | "
            f"{h.get('3', 0)} | {h.get('4', 0)} | {h.get('5', 0)} | {block['mean']} | "
            f"{block['floor_pct']} | {block['ceiling_pct']} |"
        )
    red = payload["redundancy"]
    lines += [
        "",
        "## Sharpness–Blur redundancy (LIVEC 200)",
        "",
        "| Pair | n | Pearson | Spearman |",
        "|---|---|---|---|",
    ]
    for name, block in red.items():
        if not isinstance(block, dict) or "n" not in block:
            continue
        lines.append(f"| {name} | {block['n']} | {block.get('pearson')} | {block.get('spearman')} |")
    lines += [
        "",
        f"- OpenCV mean |sharpness + blur − 1|: {red.get('opencv_identity_mean_abs')} "
        f"(max {red.get('opencv_identity_max_abs')})",
        "",
        "## ENET versus OpenCV disagreement (integer gap >= 2)",
        "",
    ]
    for pair, block in payload["disagreement"].items():
        lines.append(f"- {pair}: n={block['n']} n_gap>=2={block['n_gap_ge_2']}")
    lines += [
        "",
        "## Supplementary Spearman vs LIVEC overall MOS (not Blur GT)",
        "",
        "| Series | Spearman vs MOS | n |",
        "|---|---|---|",
    ]
    for name, block in payload["mos_context"].items():
        lines.append(f"| {name} | {block['spearman']} | {block['n']} |")
    rv = payload["human_review_candidates"]
    lines += [
        "",
        "## Diagnostic flags (not scene labels)",
        "",
        f"- low luma (mean gray/255 < {LOW_LUMA}): {rv['n_low_luma']}",
        f"- high ENET blur amount (>= {HIGH_BLUR_AMOUNT}): {rv['n_high_enet_blur_amount']}",
        f"- OpenCV blur amount ceiling (>= {OPENCV_SOFT_CEILING}): {rv['n_opencv_blur_ceiling']}",
        f"- ENET vs OpenCV Blur badge gap >= 2 (up to 12): {rv['enet_opencv_blur_gap_ge_2'][:12]}",
        f"- low luma and high ENET blur amount: {rv['low_luma_and_high_enet_blur'][:12]}",
        f"- OpenCV ceiling but ENET Blur badge >= 4: {rv['opencv_ceiling_enet_badge_ge_4'][:12]}",
        f"- ENET Blur badge exceeds Sharpness by >= 2: {rv['enet_blur_badge_gt_sharpness_by_2'][:12]}",
        "",
        rv["note"],
        "",
        "## Limitations",
        "",
        "- Automated diagnostics. Not perceptual accuracy for ACCESS 1-5 Blur.",
        "- No independent ACCESS Blur human ratings.",
        "- Scoring does not distinguish bokeh, motion smear, and unwanted defocus.",
        "- OpenCV Blur is identically 1 − Sharpness, so overall_score double-counts that axis.",
        "- Production `_soft_score` cannot emit badge 1 for q in [0,1].",
        "- Video motion stability is out of scope.",
        "- Wave C (BID / LIVE blur subsets) was not run.",
        "",
        "No production code changed. No candidate integrated.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


CSV_FIELDS = [
    "source_media_key",
    "livec_index",
    "mos_quality_raw",
    "mos_is_overall_not_blur",
    "stratum_id",
    "stratum_label",
    "status",
    "error",
    "width",
    "height",
    "luma_mean",
    "enet_raw_blur",
    "enet_raw_sharpness",
    "enet_q_blur",
    "enet_blur_badge",
    "enet_sharpness_badge",
    "opencv_raw_blur",
    "opencv_raw_sharpness",
    "opencv_q_blur",
    "opencv_blur_badge",
    "opencv_sharpness_badge",
    "opencv_identity_abs",
    "classic_laplacian_var",
    "classic_blur_inv_laplacian",
    "classic_tenengrad",
    "enet_opencv_blur_badge_gap",
    "flag_low_luma",
    "flag_high_enet_blur_amount",
    "flag_opencv_blur_ceiling",
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--livec-root", type=Path, default=LIVEC_ROOT)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--bc-json", type=Path, default=BC_KEYS_JSON)
    args = parser.parse_args()
    if cv2 is None:
        raise SystemExit(f"ABORT: OpenCV required ({_IMPORT_ERR})")

    out_dir = args.output_dir
    abort_if_existing(out_dir)

    hashes_before = hash_paths(SCORER_PATHS)
    wave_a = run_wave_a()
    bc_keys = load_bc_selected_keys(args.bc_json)

    print(
        f"[BLUR-LIVEC] seed={SELECTION_SEED} n={N_SELECT} n_per_quintile={N_PER_QUINTILE} "
        "(declared before scoring; same as B/C)",
        flush=True,
    )
    rows_all = load_livec_rows(args.livec_root)
    train = [r for r in rows_all if r["split"] == "subject_training"]
    test = [r for r in rows_all if r["split"] == "test"]
    if len(test) != EXPECTED_TEST_N or len(train) != EXPECTED_TRAIN_N:
        raise SystemExit(f"unexpected LIVEC counts test={len(test)} train={len(train)}")
    cuts = assign_strata(test)
    exclude = controlled_source_ids()
    selected = select_livec200(test, seed=SELECTION_SEED, n_per=N_PER_QUINTILE, exclude_stems=exclude)
    selected_keys = [r["source_media_key"] for r in selected]
    if selected_keys != bc_keys:
        raise SystemExit(
            "ABORT: selected LIVEC keys do not match Brightness/Contrast run_bc_livec_001 keys"
        )

    rt = import_production_scorers()
    print(f"[BLUR-LIVEC] enet_ok={rt['enet_ok']} opencv_ok={rt['opencv_ok']}", flush=True)

    scored: list[dict[str, Any]] = []
    t0 = time.perf_counter()
    times: list[float] = []
    for i, rec in enumerate(selected, start=1):
        print(f"[BLUR-LIVEC {i}/{len(selected)}] {rec['source_media_key']}", flush=True)
        t1 = time.perf_counter()
        scored.append(evaluate_one(rec, rt))
        times.append((time.perf_counter() - t1) * 1000.0)
    wall = time.perf_counter() - t0

    n_ok = sum(1 for r in scored if r["status"] == "ok")
    n_partial = sum(1 for r in scored if r["status"] == "partial")
    n_failed = sum(1 for r in scored if r["status"] not in {"ok", "partial"})
    counts = Counter(r["stratum_id"] for r in selected)
    hashes_after = hash_paths(SCORER_PATHS)
    meta = {
        "generated_at": now_iso(),
        "phase": "livec_blur_quality_research",
        "fitted_on_livec": False,
        "winner_selected": False,
        "spaq200_accessed": False,
        "production_untouched": True,
        "wave_a": wave_a,
        "hashes": {
            "before": hashes_before,
            "after": hashes_after,
            "match": hashes_before == hashes_after,
        },
        "selection": {
            "seed": SELECTION_SEED,
            "n_selected": len(selected),
            "n_per_quintile": N_PER_QUINTILE,
            "n_unique_keys": len(set(selected_keys)),
            "matched_bc_keys": True,
            "n_training_excluded": len(train),
            "quintile_cuts": list(cuts),
            "stratum_counts": {str(k): counts[k] for k in range(1, 6)},
            "selected_keys": selected_keys,
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
            "LIVEC MOS is overall quality, not Blur human ground truth.",
            "OpenCV blur = 1 - sharpness by construction.",
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
    hashes_written = hash_paths(SCORER_PATHS)
    if hashes_written != hashes_before:
        raise SystemExit("ABORT: production scorer hashes changed during evaluation")
    print(
        json.dumps(
            {
                "n_selected": len(selected),
                "n_ok": n_ok,
                "n_partial": n_partial,
                "n_failed": n_failed,
                "wall_s": wall,
                "hashes_match": True,
                "out": str(out_dir),
            },
            indent=2,
        ),
        flush=True,
    )
    return 0 if n_failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
