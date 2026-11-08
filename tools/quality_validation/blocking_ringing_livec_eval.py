#!/usr/bin/env python3
"""ACCESS VisionCheck — Wave B: LIVEC Blocking/Ringing diagnostic (research only).

Declared BEFORE scoring:
  SELECTION_SEED = 20261108 (same LIVEC 200 as Brightness/Contrast and Blur)
  N = 200 test images, 40 per MOS quintile.
  SPAQ-200 is not accessed. LIVEC MOS is overall quality, not artifact GT.
  No winner. No production change.

Writes only under workspace/datasets/livec/output/run_block_ring_livec_001/.
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

from blocking_ringing_audit import run_wave_a  # noqa: E402
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
except ImportError as exc:  # pragma: no cover
    cv2 = None  # type: ignore
    _IMPORT_ERR = str(exc)
else:
    _IMPORT_ERR = ""

DEFAULT_OUT = _TOOLKIT / "workspace" / "datasets" / "livec" / "output" / "run_block_ring_livec_001"
BC_KEYS_JSON = (
    _TOOLKIT / "workspace" / "datasets" / "livec" / "output" / "run_bc_livec_001" / "brightness_contrast_livec.json"
)
BLUR_KEYS_JSON = (
    _TOOLKIT / "workspace" / "datasets" / "livec" / "output" / "run_blur_livec_001" / "blur_quality_livec.json"
)
ARTIFACTS = (
    "blocking_ringing_livec.csv",
    "blocking_ringing_livec.json",
    "BLOCKING_RINGING_LIVEC_REPORT.md",
)
HIGH_FLAT = 0.50
HIGH_BOUNDARY = 1.30
HIGH_EDGE_LAP = 40.0
HIGH_ENET_BLOCK = 0.80
HIGH_ENET_RING = 0.75

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
        out[key] = sha256_file(path) if path.is_file() else "MISSING"
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
        raise SystemExit(f"ABORT: locked JSON seed {seed} != {SELECTION_SEED}")
    keys = list(selection.get("selected_keys") or [])
    if len(keys) != N_SELECT:
        raise SystemExit(f"ABORT: locked JSON has {len(keys)} keys, expected {N_SELECT}")
    return keys


def import_production_scorers() -> dict[str, Any]:
    from app.services.efficientnet_b0_scorer import (
        analyze_image_bytes as enet_analyze,
        efficientnet_available,
        ensure_weights,
    )
    from app.services.media_evaluator import _brightness_metric, _soft_score
    from app.services.opencv_quality import analyze_image_bytes as opencv_analyze
    from app.services.opencv_quality import opencv_available

    return {
        "enet_analyze": enet_analyze,
        "opencv_analyze": opencv_analyze,
        "soft_score": _soft_score,
        "brightness_metric": _brightness_metric,
        "enet_ok": bool(efficientnet_available() and ensure_weights()),
        "opencv_ok": bool(opencv_available()),
    }


def _q_block_ring(raw: dict[str, Any], soft_score, brightness_metric) -> dict[str, Any]:
    def num(key: str) -> float | None:
        val = raw.get(key)
        return float(val) if isinstance(val, (int, float)) else None

    blocking = num("blocking_artifacts")
    ringing = num("ringing_artifacts")
    sharpness = num("sharpness")
    blur = num("blur")
    noise = num("noise")
    brightness = num("brightness")
    contrast = num("contrast")
    q_block = None if blocking is None else 1.0 - blocking
    q_ring = None if ringing is None else 1.0 - ringing
    q_noise = None if noise is None else 1.0 - min(noise, 0.85)
    q_bright = None if brightness is None else brightness_metric(brightness)
    q_contrast = None if contrast is None else min(contrast, 1.0)
    badges = {
        "blocking": None if q_block is None else soft_score(q_block),
        "ringing": None if q_ring is None else soft_score(q_ring),
        "sharpness": None if sharpness is None else soft_score(sharpness),
        "blur": None if blur is None else soft_score(1.0 - blur),
        "noise": None if q_noise is None else soft_score(q_noise),
        "brightness": None if q_bright is None else soft_score(q_bright),
        "contrast": None if q_contrast is None else soft_score(q_contrast),
    }
    seven = [badges[k] for k in badges if isinstance(badges[k], int)]
    five = [
        badges[k]
        for k in ("sharpness", "blur", "noise", "brightness", "contrast")
        if isinstance(badges[k], int)
    ]
    return {
        "raw_blocking": blocking,
        "raw_ringing": ringing,
        "raw_sharpness": sharpness,
        "raw_blur": blur,
        "raw_noise": noise,
        "q_blocking": q_block,
        "q_ringing": q_ring,
        "blocking_badge": badges["blocking"],
        "ringing_badge": badges["ringing"],
        "sharpness_badge": badges["sharpness"],
        "blur_badge": badges["blur"],
        "noise_badge": badges["noise"],
        "overall_7": round(sum(seven) / len(seven), 4) if len(seven) == 7 else None,
        "overall_5_no_block_ring": round(sum(five) / len(five), 4) if len(five) == 5 else None,
    }


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
    out = {"error": error}
    if raw is not None:
        out.update(_q_block_ring(raw, rt["soft_score"], rt["brightness_metric"]))
    return out


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
        "mos_is_overall_not_blocking_or_ringing": True,
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
    classic = classic or {}
    row.update(
        {
            "enet_raw_blocking": enet.get("raw_blocking"),
            "enet_raw_ringing": enet.get("raw_ringing"),
            "enet_q_blocking": enet.get("q_blocking"),
            "enet_q_ringing": enet.get("q_ringing"),
            "enet_blocking_badge": enet.get("blocking_badge"),
            "enet_ringing_badge": enet.get("ringing_badge"),
            "enet_sharpness_badge": enet.get("sharpness_badge"),
            "enet_blur_badge": enet.get("blur_badge"),
            "enet_noise_badge": enet.get("noise_badge"),
            "enet_raw_sharpness": enet.get("raw_sharpness"),
            "enet_raw_blur": enet.get("raw_blur"),
            "enet_raw_noise": enet.get("raw_noise"),
            "enet_overall_7": enet.get("overall_7"),
            "enet_overall_5_no_block_ring": enet.get("overall_5_no_block_ring"),
            "opencv_raw_blocking": ocv.get("raw_blocking"),
            "opencv_raw_ringing": ocv.get("raw_ringing"),
            "opencv_q_blocking": ocv.get("q_blocking"),
            "opencv_q_ringing": ocv.get("q_ringing"),
            "opencv_blocking_badge": ocv.get("blocking_badge"),
            "opencv_ringing_badge": ocv.get("ringing_badge"),
            "opencv_sharpness_badge": ocv.get("sharpness_badge"),
            "opencv_noise_badge": ocv.get("noise_badge"),
            "classic_blocking_boundary_ratio": classic.get("blocking_boundary_ratio"),
            "classic_blocking_flat_frac": classic.get("blocking_flat_frac"),
            "classic_ringing_edge_lap": classic.get("ringing_edge_lap"),
            "classic_tenengrad": classic.get("sharpness_tenengrad"),
        }
    )
    if isinstance(enet.get("overall_7"), float) and isinstance(enet.get("overall_5_no_block_ring"), float):
        row["enet_overall_block_ring_delta"] = round(
            float(enet["overall_7"]) - float(enet["overall_5_no_block_ring"]), 4
        )
    else:
        row["enet_overall_block_ring_delta"] = None
    if isinstance(enet.get("blocking_badge"), int) and isinstance(ocv.get("blocking_badge"), int):
        row["enet_opencv_blocking_gap"] = abs(int(enet["blocking_badge"]) - int(ocv["blocking_badge"]))
    else:
        row["enet_opencv_blocking_gap"] = None
    if isinstance(enet.get("ringing_badge"), int) and isinstance(ocv.get("ringing_badge"), int):
        row["enet_opencv_ringing_gap"] = abs(int(enet["ringing_badge"]) - int(ocv["ringing_badge"]))
    else:
        row["enet_opencv_ringing_gap"] = None
    row["flag_high_flat_frac"] = bool(
        isinstance(row.get("classic_blocking_flat_frac"), float)
        and row["classic_blocking_flat_frac"] >= HIGH_FLAT
    )
    row["flag_high_boundary"] = bool(
        isinstance(row.get("classic_blocking_boundary_ratio"), float)
        and row["classic_blocking_boundary_ratio"] >= HIGH_BOUNDARY
    )
    row["flag_high_edge_lap"] = bool(
        isinstance(row.get("classic_ringing_edge_lap"), float)
        and row["classic_ringing_edge_lap"] >= HIGH_EDGE_LAP
    )
    row["flag_high_enet_blocking"] = bool(
        isinstance(enet.get("raw_blocking"), (int, float)) and float(enet["raw_blocking"]) >= HIGH_ENET_BLOCK
    )
    row["flag_high_enet_ringing"] = bool(
        isinstance(enet.get("raw_ringing"), (int, float)) and float(enet["raw_ringing"]) >= HIGH_ENET_RING
    )
    if errors:
        scored = row.get("enet_blocking_badge") is not None or row.get("opencv_blocking_badge") is not None
        row["status"] = "partial" if scored else "failed"
        row["error"] = "; ".join(errors)
    return row


def mean_safe(values: list[Any]) -> float | None:
    vals = [float(v) for v in values if isinstance(v, (int, float))]
    return round(statistics.fmean(vals), 4) if vals else None


def spearman(xs: list[float], ys: list[float]) -> float | None:
    try:
        from scipy import stats

        if len(xs) < 5 or len(xs) != len(ys) or len(set(xs)) < 2 or len(set(ys)) < 2:
            return None
        return float(stats.spearmanr(xs, ys).correlation)
    except Exception:  # noqa: BLE001
        return None


def pearson(xs: list[float], ys: list[float]) -> float | None:
    try:
        from scipy import stats

        if len(xs) < 5 or len(xs) != len(ys) or len(set(xs)) < 2 or len(set(ys)) < 2:
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
        if isinstance(x, (int, float)) and isinstance(y, (int, float)) and abs(int(x) - int(y)) >= min_gap:
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
        "enet_blocking": "enet_blocking_badge",
        "enet_ringing": "enet_ringing_badge",
        "opencv_blocking": "opencv_blocking_badge",
        "opencv_ringing": "opencv_ringing_badge",
    }
    distributions: dict[str, Any] = {}
    for name, col in series.items():
        vals = [r[col] for r in ok_rows if isinstance(r.get(col), (int, float))]
        hist = badge_hist(vals)
        n = len(vals)
        distributions[name] = {
            "kind": "production_badge",
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
        "enet_raw_blocking_vs_opencv": _corr_block(
            *paired("enet_raw_blocking", "opencv_raw_blocking"), "OpenCV is flat-frac, not 8x8"
        ),
        "enet_raw_blocking_vs_classic_boundary": _corr_block(
            *paired("enet_raw_blocking", "classic_blocking_boundary_ratio"), "classical 8x8 ratio"
        ),
        "opencv_blocking_vs_classic_flat": _corr_block(
            *paired("opencv_raw_blocking", "classic_blocking_flat_frac"), "should agree: both flat-frac"
        ),
        "opencv_blocking_vs_classic_boundary": _corr_block(
            *paired("opencv_raw_blocking", "classic_blocking_boundary_ratio"), "construct mismatch if weak"
        ),
        "enet_raw_ringing_vs_opencv": _corr_block(
            *paired("enet_raw_ringing", "opencv_raw_ringing"), "not human GT"
        ),
        "enet_raw_ringing_vs_classic_edge_lap": _corr_block(
            *paired("enet_raw_ringing", "classic_ringing_edge_lap"), "not human GT"
        ),
        "enet_raw_ringing_vs_sharpness": _corr_block(
            *paired("enet_raw_ringing", "enet_raw_sharpness"), "halo vs micro-contrast overlap"
        ),
        "enet_raw_ringing_vs_noise": _corr_block(
            *paired("enet_raw_ringing", "enet_raw_noise"), "oscillation vs grain"
        ),
        "enet_raw_blocking_vs_noise": _corr_block(
            *paired("enet_raw_blocking", "enet_raw_noise"), "blocks vs grain"
        ),
        "enet_raw_blocking_vs_blur": _corr_block(
            *paired("enet_raw_blocking", "enet_raw_blur"), "JPEG mixes blur"
        ),
        "enet_badge_blocking_vs_opencv": _corr_block(
            *paired("enet_blocking_badge", "opencv_blocking_badge"), "not human GT"
        ),
        "enet_badge_ringing_vs_opencv": _corr_block(
            *paired("enet_ringing_badge", "opencv_ringing_badge"), "not human GT"
        ),
        "enet_overall7_vs_overall5": _corr_block(
            *paired("enet_overall_7", "enet_overall_5_no_block_ring"),
            "how much block+ring move overall",
        ),
        "mean_abs_overall_delta": mean_safe([r.get("enet_overall_block_ring_delta") for r in ok_rows]),
    }

    disagreement = {}
    for pname, a, b in (
        ("enet_vs_opencv_blocking_badge", "enet_blocking_badge", "opencv_blocking_badge"),
        ("enet_vs_opencv_ringing_badge", "enet_ringing_badge", "opencv_ringing_badge"),
    ):
        aa, bb = paired(a, b)
        disagreement[pname] = {"n": len(aa), "n_gap_ge_2": disagree_count(aa, bb)}

    mos_context = {}
    for name, coln in (
        ("mos_vs_enet_blocking_badge", "enet_blocking_badge"),
        ("mos_vs_opencv_blocking_badge", "opencv_blocking_badge"),
        ("mos_vs_enet_ringing_badge", "enet_ringing_badge"),
        ("mos_vs_opencv_ringing_badge", "opencv_ringing_badge"),
        ("mos_vs_classic_boundary", "classic_blocking_boundary_ratio"),
        ("mos_vs_classic_edge_lap", "classic_ringing_edge_lap"),
    ):
        xs, ys = paired("mos_quality_raw", coln)
        mos_context[name] = {
            "spearman": None if spearman(xs, ys) is None else round(spearman(xs, ys), 4),
            "n": len(xs),
            "note": "overall MOS, not Blocking/Ringing human GT; not a winner rule",
        }

    def keys_where(pred) -> list[str]:
        return [r["source_media_key"] for r in ok_rows if pred(r)]

    review = {
        "n_high_flat_frac": sum(1 for r in ok_rows if r.get("flag_high_flat_frac")),
        "n_high_boundary": sum(1 for r in ok_rows if r.get("flag_high_boundary")),
        "n_high_edge_lap": sum(1 for r in ok_rows if r.get("flag_high_edge_lap")),
        "n_high_enet_blocking": sum(1 for r in ok_rows if r.get("flag_high_enet_blocking")),
        "n_high_enet_ringing": sum(1 for r in ok_rows if r.get("flag_high_enet_ringing")),
        "enet_opencv_blocking_gap_ge_2": keys_where(
            lambda r: isinstance(r.get("enet_opencv_blocking_gap"), int) and r["enet_opencv_blocking_gap"] >= 2
        ),
        "enet_opencv_ringing_gap_ge_2": keys_where(
            lambda r: isinstance(r.get("enet_opencv_ringing_gap"), int) and r["enet_opencv_ringing_gap"] >= 2
        ),
        "flat_and_enet_blocking_badge_ge_4": keys_where(
            lambda r: r.get("flag_high_flat_frac")
            and isinstance(r.get("enet_blocking_badge"), int)
            and r["enet_blocking_badge"] >= 4
        ),
        "high_edge_lap_and_enet_ringing_badge_ge_4": keys_where(
            lambda r: r.get("flag_high_edge_lap")
            and isinstance(r.get("enet_ringing_badge"), int)
            and r["enet_ringing_badge"] >= 4
        ),
        "high_boundary_and_opencv_blocking_badge_ge_4": keys_where(
            lambda r: r.get("flag_high_boundary")
            and isinstance(r.get("opencv_blocking_badge"), int)
            and r["opencv_blocking_badge"] >= 4
        ),
        "note": (
            "Heuristic flags only. Not JPEG-block or halo labels. "
            "OpenCV blocking is 8x8 flatness, not DCT grid energy."
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
            "Keep production frozen. Wave C (LIVE/TID JPEG/JP2K) remains blocked. "
            "Do not integrate a Blocking or Ringing candidate."
        ),
    }


def write_report(path: Path, payload: dict[str, Any]) -> None:
    wave_a = payload.get("wave_a") or {}
    p8 = wave_a.get("phase8") or {}
    jpeg = p8.get("jpeg") or {}
    ringing = p8.get("ringing") or {}
    d = payload["distributions"]
    lines = [
        "# ACCESS VisionCheck — Blocking and Ringing Wave A + Wave B (research only)",
        "",
        f"**Generated:** {payload['generated_at']}",
        f"**Selection seed (declared before scoring):** `{payload['selection']['seed']}`",
        f"**Sample:** {payload['selection']['n_selected']} LIVEC test images "
        f"(same keys as Brightness/Contrast and Blur).",
        "",
        "Research-only. Production scoring, APIs, Flutter, weights, and thresholds were not changed. "
        "SPAQ-200 images were not opened. Frozen Sharpness, Noise, Brightness, Contrast, and Blur "
        "research were not modified. No candidate is integrated. No winner is selected.",
        "",
        "LIVEC MOS is **overall** quality. It is **not** Blocking or Ringing ground truth. "
        "Do not treat MOS Spearman as perceptual superiority.",
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
        "## Wave A — saved Phase 8 / 11 / 12 (no rerun)",
        "",
        f"- JPEG ladder records: {jpeg.get('n_records_used')} "
        f"(originals={jpeg.get('n_originals')}, variants={jpeg.get('n_variants')}, worst={jpeg.get('n_worst')})",
        f"- Ringing ladder records: {ringing.get('n_records_used')} "
        f"(variants={ringing.get('n_variants')}, worst amount={ringing.get('worst_severity')})",
        f"- SPAQ-200 images opened: `{wave_a.get('spaq200_images_opened')}`",
        "",
        "### JPEG severity (median Spearman vs 100-Q)",
        "",
        "| Series | n defined | median Spearman |",
        "|---|---|---|",
    ]
    for name, block in (jpeg.get("severity_sensitivity") or {}).items():
        lines.append(
            f"| {name} | {block.get('n_images_defined')}/{block.get('n_images')} | "
            f"{block.get('median_spearman_vs_severity')} |"
        )
    lines += [
        "",
        "### Unsharp/ringing severity (median Spearman vs amount)",
        "",
        "| Series | n defined | median Spearman |",
        "|---|---|---|",
    ]
    for name, block in (ringing.get("severity_sensitivity") or {}).items():
        lines.append(
            f"| {name} | {block.get('n_images_defined')}/{block.get('n_images')} | "
            f"{block.get('median_spearman_vs_severity')} |"
        )
    lines += [
        "",
        f"- JPEG overlap: `{jpeg.get('overlap')}`",
        f"- Ringing overlap: `{ringing.get('overlap')}`",
        "",
        "Phase 11 ENET badges (no SPAQ Blocking/Ringing labels): "
        f"blocking `{(wave_a.get('phase11') or {}).get('blocking_badge_hist')}`, "
        f"ringing `{(wave_a.get('phase11') or {}).get('ringing_badge_hist')}`. "
        "Badge 1 is unreachable for q in [0,1].",
        "",
        f"Phase 12 unlabeled: `{(wave_a.get('phase12') or {}).get('unlabeled_distributions')}`.",
        "",
        "## Wave B — LIVEC 200",
        "",
        f"- selected={payload['selection']['n_selected']} unique="
        f"{payload['selection']['n_unique_keys']} matched_bc="
        f"{payload['selection']['matched_bc_keys']} matched_blur="
        f"{payload['selection'].get('matched_blur_keys')}",
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
        "## Correlations and possible redundancy (not accuracy)",
        "",
        "| Pair | n | Pearson | Spearman |",
        "|---|---|---|---|",
    ]
    for name, block in red.items():
        if not isinstance(block, dict) or "n" not in block:
            continue
        lines.append(f"| {name} | {block['n']} | {block.get('pearson')} | {block.get('spearman')} |")
    lines.append(f"- mean |overall_7 - overall_5|: {red.get('mean_abs_overall_delta')}")
    lines += ["", "## ENET versus OpenCV disagreement (integer gap >= 2)", ""]
    for pair, block in payload["disagreement"].items():
        lines.append(f"- {pair}: n={block['n']} n_gap>=2={block['n_gap_ge_2']}")
    lines += [
        "",
        "## Supplementary Spearman vs LIVEC overall MOS (not artifact GT, not a winner rule)",
        "",
        "| Series | Spearman vs MOS | n |",
        "|---|---|---|",
    ]
    for name, block in payload["mos_context"].items():
        lines.append(f"| {name} | {block['spearman']} | {block['n']} |")
    rv = payload["human_review_candidates"]
    lines += [
        "",
        "## Diagnostic flags (not artifact labels)",
        "",
        f"- high classic flat-frac (>= {HIGH_FLAT}): {rv['n_high_flat_frac']}",
        f"- high classic 8x8 boundary (>= {HIGH_BOUNDARY}): {rv['n_high_boundary']}",
        f"- high classic edge-Laplacian (>= {HIGH_EDGE_LAP}): {rv['n_high_edge_lap']}",
        f"- high ENET blocking amount (>= {HIGH_ENET_BLOCK}): {rv['n_high_enet_blocking']}",
        f"- high ENET ringing amount (>= {HIGH_ENET_RING}): {rv['n_high_enet_ringing']}",
        f"- ENET vs OpenCV Blocking gap >= 2 (up to 12): {rv['enet_opencv_blocking_gap_ge_2'][:12]}",
        f"- ENET vs OpenCV Ringing gap >= 2 (up to 12): {rv['enet_opencv_ringing_gap_ge_2'][:12]}",
        f"- high flat-frac and ENET Blocking badge >= 4: {rv['flat_and_enet_blocking_badge_ge_4'][:12]}",
        f"- high edge-Lap and ENET Ringing badge >= 4: {rv['high_edge_lap_and_enet_ringing_badge_ge_4'][:12]}",
        f"- high 8x8 boundary and OpenCV Blocking badge >= 4: {rv['high_boundary_and_opencv_blocking_badge_ge_4'][:12]}",
        "",
        rv["note"],
        "",
        "## Limitations",
        "",
        "- Automated diagnostics. Not ACCESS 1-5 Blocking or Ringing accuracy.",
        "- No independent ACCESS human ratings for these criteria.",
        "- SPAQ has no Blocking/Ringing labels. LIVEC MOS is overall only.",
        "- OpenCV Blocking measures 8x8 patch flatness, not DCT block boundaries.",
        "- OpenCV Ringing counts sign flips near Canny edges.",
        "- ENET is 224x224, which smears an 8x8 JPEG grid.",
        "- JPEG mixes blocking, blur, and ringing. Unsharp is not JPEG2000 ringing.",
        "- Production `_soft_score` cannot emit badge 1 for q in [0,1].",
        "- Wave C (LIVE/TID JPEG/JP2K) was not run.",
        "",
        "No production code changed. No candidate integrated.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


CSV_FIELDS = [
    "source_media_key",
    "livec_index",
    "mos_quality_raw",
    "mos_is_overall_not_blocking_or_ringing",
    "stratum_id",
    "stratum_label",
    "status",
    "error",
    "width",
    "height",
    "luma_mean",
    "enet_raw_blocking",
    "enet_raw_ringing",
    "enet_q_blocking",
    "enet_q_ringing",
    "enet_blocking_badge",
    "enet_ringing_badge",
    "enet_sharpness_badge",
    "enet_blur_badge",
    "enet_noise_badge",
    "enet_raw_sharpness",
    "enet_raw_blur",
    "enet_raw_noise",
    "enet_overall_7",
    "enet_overall_5_no_block_ring",
    "enet_overall_block_ring_delta",
    "opencv_raw_blocking",
    "opencv_raw_ringing",
    "opencv_blocking_badge",
    "opencv_ringing_badge",
    "classic_blocking_boundary_ratio",
    "classic_blocking_flat_frac",
    "classic_ringing_edge_lap",
    "enet_opencv_blocking_gap",
    "enet_opencv_ringing_gap",
    "flag_high_flat_frac",
    "flag_high_boundary",
    "flag_high_edge_lap",
    "flag_high_enet_blocking",
    "flag_high_enet_ringing",
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--livec-root", type=Path, default=LIVEC_ROOT)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--bc-json", type=Path, default=BC_KEYS_JSON)
    parser.add_argument("--blur-json", type=Path, default=BLUR_KEYS_JSON)
    args = parser.parse_args()
    if cv2 is None:
        raise SystemExit(f"ABORT: OpenCV required ({_IMPORT_ERR})")

    out_dir = args.output_dir
    abort_if_existing(out_dir)
    hashes_before = hash_paths(SCORER_PATHS)
    wave_a = run_wave_a()
    bc_keys = load_bc_selected_keys(args.bc_json)
    blur_keys = load_bc_selected_keys(args.blur_json) if args.blur_json.is_file() else None

    print(
        f"[BR-LIVEC] seed={SELECTION_SEED} n={N_SELECT} n_per_quintile={N_PER_QUINTILE} "
        "(same as B/C and Blur)",
        flush=True,
    )
    rows_all = load_livec_rows(args.livec_root)
    train = [r for r in rows_all if r["split"] == "subject_training"]
    test = [r for r in rows_all if r["split"] == "test"]
    if len(test) != EXPECTED_TEST_N or len(train) != EXPECTED_TRAIN_N:
        raise SystemExit(f"unexpected LIVEC counts test={len(test)} train={len(train)}")
    cuts = assign_strata(test)
    selected = select_livec200(
        test, seed=SELECTION_SEED, n_per=N_PER_QUINTILE, exclude_stems=controlled_source_ids()
    )
    selected_keys = [r["source_media_key"] for r in selected]
    if selected_keys != bc_keys:
        raise SystemExit("ABORT: selected keys do not match run_bc_livec_001")
    matched_blur = blur_keys is None or selected_keys == blur_keys
    if blur_keys is not None and not matched_blur:
        raise SystemExit("ABORT: selected keys do not match run_blur_livec_001")

    rt = import_production_scorers()
    print(f"[BR-LIVEC] enet_ok={rt['enet_ok']} opencv_ok={rt['opencv_ok']}", flush=True)
    scored: list[dict[str, Any]] = []
    t0 = time.perf_counter()
    times: list[float] = []
    for i, rec in enumerate(selected, start=1):
        print(f"[BR-LIVEC {i}/{len(selected)}] {rec['source_media_key']}", flush=True)
        t1 = time.perf_counter()
        scored.append(evaluate_one(rec, rt))
        times.append((time.perf_counter() - t1) * 1000.0)
    wall = time.perf_counter() - t0
    n_ok = sum(1 for r in scored if r["status"] == "ok")
    n_partial = sum(1 for r in scored if r["status"] == "partial")
    n_failed = sum(1 for r in scored if r["status"] not in {"ok", "partial"})
    hashes_after = hash_paths(SCORER_PATHS)
    counts = Counter(r["stratum_id"] for r in selected)
    meta = {
        "generated_at": now_iso(),
        "phase": "livec_blocking_ringing_research",
        "fitted_on_livec": False,
        "winner_selected": False,
        "spaq200_accessed": False,
        "production_untouched": True,
        "wave_a": wave_a,
        "hashes": {"before": hashes_before, "after": hashes_after, "match": hashes_before == hashes_after},
        "selection": {
            "seed": SELECTION_SEED,
            "n_selected": len(selected),
            "n_per_quintile": N_PER_QUINTILE,
            "n_unique_keys": len(set(selected_keys)),
            "matched_bc_keys": True,
            "matched_blur_keys": matched_blur,
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
        "runtime": {"wall_s": wall, "ms_mean": (sum(times) / len(times)) if times else None},
        "notes": [
            "LIVEC MOS is overall quality, not Blocking or Ringing GT.",
            "OpenCV blocking is 8x8 patch flatness, not DCT grid energy.",
        ],
    }
    payload = build_payload(scored, meta)
    out_dir.mkdir(parents=True, exist_ok=True)
    abort_if_existing(out_dir)
    with (out_dir / ARTIFACTS[0]).open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(scored)
    (out_dir / ARTIFACTS[1]).write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
    write_report(out_dir / ARTIFACTS[2], payload)
    if hash_paths(SCORER_PATHS) != hashes_before:
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
