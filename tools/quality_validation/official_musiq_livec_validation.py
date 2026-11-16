#!/usr/bin/env python3
"""Official TF Hub MUSIQ PaQ-2-PiQ vs LIVEC MOS and vs saved pyiqa raw scores.

Research-only. No production imports. No calibration on LIVEC. Does not change
Phase 5 EQUIVALENCE_TOLERANCE.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import math
import os
import platform
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from official_musiq_engine_verification import (  # noqa: E402
    EQUIVALENCE_TOLERANCE,
    KAGGLE_PAQ2PIQ,
    LICENSE_FINDINGS,
    TFHUB_PAQ2PIQ,
    abs_diff_stats,
    judge_equivalence,
    load_official_predict_fn,
    pearson_spearman,
    _pkg_version,
    _scalar_from_hub,
)

DEFAULT_PYIQA_CSV = (
    _TOOLKIT / "workspace" / "datasets" / "livec" / "output" / "run_livec_001" / "raw_predictions.csv"
)
DEFAULT_OUTPUT = _TOOLKIT / "workspace" / "datasets" / "livec" / "output" / "run_official_livec_001"
PHASE5_CACHE = (
    _TOOLKIT
    / "workspace"
    / "datasets"
    / "koniq10k"
    / "official_musiq_engine_verification"
    / "cache"
    / "tfhub"
)
EXPECTED_N = 1162
PHASE5_RESULT = {
    "n": 24,
    "pearson_r": 0.9997477772016965,
    "spearman_r": 0.9921739130434782,
    "mean_abs_diff": 0.07349046071370442,
    "max_abs_diff": 0.26296234130859375,
    "primary_equivalent": False,
    "reason": "Spearman 0.99217 < predeclared 0.999. Thresholds were not changed.",
}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_pyiqa_livec(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    if len(rows) != EXPECTED_N:
        raise SystemExit(f"expected {EXPECTED_N} pyiqa LIVEC rows, got {len(rows)}")
    return rows


def png_bytes_from_path(image_path: Path) -> bytes:
    from PIL import Image

    with Image.open(image_path) as im:
        rgb = im.convert("RGB")
        buf = io.BytesIO()
        rgb.save(buf, format="PNG")
        return buf.getvalue()


def score_file(predict_fn: Any, image_path: Path) -> tuple[float, str]:
    """Return (score, encoding). encoding is original suffix or png_fallback."""
    import tensorflow as tf

    raw = image_path.read_bytes()
    if not raw:
        raise RuntimeError(f"empty file: {image_path}")
    try:
        score = _scalar_from_hub(predict_fn(tf.constant(raw)))
        return score, image_path.suffix.lower().lstrip(".") or "raw"
    except Exception:
        png = png_bytes_from_path(image_path)
        score = _scalar_from_hub(predict_fn(tf.constant(png)))
        return score, "png_fallback"


def ranking_disagreements(pyiqa: list[float], official: list[float], keys: list[str]) -> dict[str, Any]:
    """Count adjacent-rank swaps after sorting each engine descending."""
    order_p = sorted(range(len(pyiqa)), key=lambda i: (-pyiqa[i], keys[i]))
    order_o = sorted(range(len(official)), key=lambda i: (-official[i], keys[i]))
    rank_p = {i: r + 1 for r, i in enumerate(order_p)}
    rank_o = {i: r + 1 for r, i in enumerate(order_o)}
    swapped = 0
    examples: list[dict[str, Any]] = []
    for i in range(len(pyiqa)):
        if rank_p[i] != rank_o[i]:
            swapped += 1
            if len(examples) < 8:
                examples.append(
                    {
                        "key": keys[i],
                        "pyiqa_rank": rank_p[i],
                        "official_rank": rank_o[i],
                        "rank_delta": abs(rank_p[i] - rank_o[i]),
                        "pyiqa": pyiqa[i],
                        "official": official[i],
                    }
                )
    deltas = [abs(rank_p[i] - rank_o[i]) for i in range(len(pyiqa))]
    return {
        "n_rank_changed": swapped,
        "max_abs_rank_delta": max(deltas) if deltas else 0,
        "mean_abs_rank_delta": (sum(deltas) / len(deltas)) if deltas else 0.0,
        "examples": examples,
    }


def dist(xs: list[float]) -> dict[str, float | int]:
    if not xs:
        return {"n": 0, "min": float("nan"), "max": float("nan"), "mean": float("nan"), "stdev": float("nan")}
    mean = sum(xs) / len(xs)
    var = sum((x - mean) ** 2 for x in xs) / len(xs)
    return {"n": len(xs), "min": min(xs), "max": max(xs), "mean": mean, "stdev": math.sqrt(var)}


def write_report(path: Path, p: dict[str, Any]) -> None:
    inf = p["inference"]
    mos_c = p["vs_mos"]
    eng = p["vs_pyiqa"]
    lines = [
        "# Official MUSIQ LIVE Challenge validation (Phase 6)",
        "",
        "**Status: complete.** Official TensorFlow Hub MUSIQ PaQ-2-PiQ scored the same 1,162 LIVEC test images used in Phase 3. No calibration, no retraining, no production changes.",
        "",
        "LIVEC MOS is overall perceptual quality only. This is **not** validation of EfficientNet-B0 or of the seven ACCESS technical criteria.",
        "",
        f"Generated: {p['generated_at']}",
        f"Artifacts: `{p['output_dir']}`",
        "",
        "## Phase 5 gate (unchanged)",
        "",
        "Phase 5 KonIQ engine comparison **failed** the predeclared Spearman ≥ 0.999 gate "
        f"(Spearman {PHASE5_RESULT['spearman_r']:.5f}, Pearson {PHASE5_RESULT['pearson_r']:.5f}, "
        f"n={PHASE5_RESULT['n']}). Those thresholds were **not** edited. Phase 6 does not reopen that verdict.",
        "",
        "## 1. Engine",
        "",
        f"- Handle: `{p['model_handle']}`",
        f"- tensorflow: {p['environment'].get('tensorflow')}",
        f"- Device: CPU",
        f"- Cache: `{p['environment'].get('tfhub_cache')}`",
        "",
        "## 2. Dataset",
        "",
        f"- pyiqa CSV (read-only): `{p['pyiqa_csv']}`",
        f"- n = {inf['n']} official test images (subject-training t1–t7 excluded, same as Phase 3)",
        "",
        "## 3. Inference",
        "",
        f"- Official ok: **{inf['official_ok']} / {inf['n']}**",
        f"- Failures: **{inf['failures']}**",
        f"- png_fallback (BMP or Hub-rejected bytes): **{inf['png_fallback']}**",
        f"- Mean CPU time: **{inf.get('mean_ms_per_image')}** ms/image",
        f"- First-image time: **{inf.get('first_ms')}** ms",
        "",
        "## 4. Official vs published LIVEC MOS",
        "",
        f"- Pearson: **{mos_c.get('pearson_r')}**",
        f"- Spearman: **{mos_c.get('spearman_r')}**",
        f"- n: {mos_c.get('n')}",
        "",
        "## 5. Distributions",
        "",
        "| Series | n | min | max | mean | stdev |",
        "|--------|--:|----:|----:|-----:|------:|",
        f"| LIVEC MOS | {p['dist']['mos']['n']} | {p['dist']['mos']['min']:.4f} | {p['dist']['mos']['max']:.4f} | {p['dist']['mos']['mean']:.4f} | {p['dist']['mos']['stdev']:.4f} |",
        f"| official raw | {p['dist']['official']['n']} | {p['dist']['official']['min']:.4f} | {p['dist']['official']['max']:.4f} | {p['dist']['official']['mean']:.4f} | {p['dist']['official']['stdev']:.4f} |",
        f"| pyiqa raw | {p['dist']['pyiqa']['n']} | {p['dist']['pyiqa']['min']:.4f} | {p['dist']['pyiqa']['max']:.4f} | {p['dist']['pyiqa']['mean']:.4f} | {p['dist']['pyiqa']['stdev']:.4f} |",
        "",
        "## 6. Official vs pyiqa (same 1,162 files)",
        "",
        f"- Pearson: **{eng['correlations'].get('pearson_r')}**",
        f"- Spearman: **{eng['correlations'].get('spearman_r')}**",
        f"- mean |diff|: **{eng['differences'].get('mean_abs_diff')}**",
        f"- max |diff|: **{eng['differences'].get('max_abs_diff')}**",
        f"- RMSE: **{eng['differences'].get('rmse')}**",
        f"- ranks changed: **{eng['ranks'].get('n_rank_changed')}** / {eng['correlations'].get('n')}",
        f"- max |rank delta|: **{eng['ranks'].get('max_abs_rank_delta')}**",
        f"- Phase 6 vs pyiqa primary_equivalent (Phase 5 thresholds, not a new gate): **{eng['equivalence'].get('primary_equivalent')}**",
        "",
        "## 7. Independent overall-quality reading",
        "",
        p["independent_assessment"],
        "",
        "## 8. Licensing / deployment limits",
        "",
    ]
    for key, text in LICENSE_FINDINGS.items():
        lines.append(f"- **{key}:** {text}")
    lines += [
        "",
        "- Do not deploy. Do not average into the seven criteria. TF Hub Apache label does not close NC-SA training-data review.",
        "- GCS `paq2piq_ckpt.npz` still has no LICENSE object.",
        "",
        "## 9. Production",
        "",
        "FastAPI, EfficientNet-B0, seven criteria, overall_score, XP, Flutter, React, PROBE, WaveRep, Gemini: unchanged.",
        "",
        "Stopped for review.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def independent_assessment(*, official_mos: dict[str, Any], pyiqa_mos: dict[str, Any] | None) -> str:
    pr = official_mos.get("pearson_r")
    sr = official_mos.get("spearman_r")
    if pr is None or sr is None:
        return "Insufficient paired scores to assess official vs MOS."
    pr_f, sr_f = float(pr), float(sr)
    # Predeclared qualitative bar for "useful overall NR-IQA" on this holdout (not a production gate).
    useful = pr_f >= 0.70 and sr_f >= 0.70
    py_note = ""
    if pyiqa_mos and pyiqa_mos.get("pearson_r") is not None:
        py_note = (
            f" Phase 3 pyiqa vs the same MOS was Pearson {pyiqa_mos['pearson_r']:.3f}, "
            f"Spearman {pyiqa_mos['spearman_r']:.3f}."
        )
    if useful:
        return (
            f"Official TF Hub MUSIQ vs LIVEC MOS: Pearson {pr_f:.3f}, Spearman {sr_f:.3f}. "
            "That is independent evidence of useful overall NR-IQA on authentic photos "
            "(both coefficients ≥ 0.70, no LIVEC fit). It does not validate ACCESS badges "
            f"and does not authorize deployment.{py_note}"
        )
    return (
        f"Official TF Hub MUSIQ vs LIVEC MOS: Pearson {pr_f:.3f}, Spearman {sr_f:.3f}. "
        "Below the descriptive 0.70/0.70 bar used in this report for useful overall rank "
        f"agreement on this holdout.{py_note}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pyiqa-csv", type=Path, default=DEFAULT_PYIQA_CSV)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--cache-dir", type=Path, default=PHASE5_CACHE)
    args = parser.parse_args()

    out_dir = args.output_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    cache_dir = args.cache_dir.resolve()
    cache_dir.mkdir(parents=True, exist_ok=True)
    os.environ["TFHUB_CACHE_DIR"] = str(cache_dir)
    os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")

    pyiqa_csv = args.pyiqa_csv.resolve()
    if not pyiqa_csv.is_file():
        print(f"STOP: missing pyiqa LIVEC CSV: {pyiqa_csv}", file=sys.stderr)
        return 2
    rows = load_pyiqa_livec(pyiqa_csv)
    if args.limit:
        rows = rows[: args.limit]

    load_t0 = time.perf_counter()
    predict_fn, handle = load_official_predict_fn()
    load_ms = (time.perf_counter() - load_t0) * 1000.0

    predictions: list[dict[str, Any]] = []
    official_ok = 0
    png_fallback = 0
    times: list[float] = []
    for i, row in enumerate(rows):
        image_path = Path(row["image_path"])
        rec: dict[str, Any] = {
            "media_id": row.get("media_id"),
            "source_media_key": row.get("source_media_key"),
            "image_path": str(image_path),
            "mos_quality_raw": float(row["mos_quality_raw"]),
            "pyiqa_raw": float(row["musiq_raw_score"]) if row.get("musiq_raw_score") else None,
            "official_raw": None,
            "abs_diff_vs_pyiqa": None,
            "encoding": None,
            "status": "error",
            "error": None,
            "elapsed_ms": None,
        }
        t0 = time.perf_counter()
        try:
            if not image_path.is_file():
                raise FileNotFoundError(str(image_path))
            score, encoding = score_file(predict_fn, image_path)
            rec["official_raw"] = score
            rec["encoding"] = encoding
            if encoding == "png_fallback":
                png_fallback += 1
            if rec["pyiqa_raw"] is not None:
                rec["abs_diff_vs_pyiqa"] = abs(score - rec["pyiqa_raw"])
            rec["status"] = "ok"
            official_ok += 1
        except Exception as exc:  # noqa: BLE001
            rec["error"] = f"{type(exc).__name__}: {exc}"
        rec["elapsed_ms"] = (time.perf_counter() - t0) * 1000.0
        times.append(float(rec["elapsed_ms"]))
        predictions.append(rec)
        if i == 0 or (i + 1) % 25 == 0 or i + 1 == len(rows):
            print(
                f"[{i + 1}/{len(rows)}] {rec['source_media_key']} status={rec['status']} "
                f"official={rec['official_raw']} enc={rec['encoding']} {rec['elapsed_ms']:.0f}ms",
                flush=True,
            )

    ok = [p for p in predictions if p["status"] == "ok" and p["official_raw"] is not None]
    mos = [float(p["mos_quality_raw"]) for p in ok]
    of = [float(p["official_raw"]) for p in ok]
    py = [float(p["pyiqa_raw"]) for p in ok if p["pyiqa_raw"] is not None]
    of_py = [float(p["official_raw"]) for p in ok if p["pyiqa_raw"] is not None]
    keys = [str(p["source_media_key"]) for p in ok if p["pyiqa_raw"] is not None]

    vs_mos = pearson_spearman(of, mos)
    vs_py_corr = pearson_spearman(of_py, py)
    vs_py_diff = abs_diff_stats(of_py, py)
    ranks = ranking_disagreements(py, of_py, keys)
    success_rate = official_ok / len(predictions) if predictions else 0.0
    vs_py_eq = judge_equivalence(vs_py_corr, vs_py_diff, success_rate if not args.limit else (1.0 if official_ok == len(predictions) else 0.0))

    # Phase 3 published numbers for the independent-assessment note.
    pyiqa_mos_ref = {"pearson_r": 0.8014, "spearman_r": 0.7672}

    payload = {
        "generated_at": _now_iso(),
        "output_dir": str(out_dir),
        "pyiqa_csv": str(pyiqa_csv),
        "model_handle": handle,
        "phase5_preserved": PHASE5_RESULT,
        "phase5_tolerance_unchanged": EQUIVALENCE_TOLERANCE,
        "license": LICENSE_FINDINGS,
        "environment": {
            "python": sys.version.split()[0],
            "tensorflow": _pkg_version("tensorflow") or _pkg_version("tensorflow-cpu"),
            "tensorflow_hub": _pkg_version("tensorflow-hub"),
            "device": "CPU",
            "platform": platform.platform(),
            "tfhub_cache": str(cache_dir),
            "model_load_ms": load_ms,
        },
        "inference": {
            "n": len(predictions),
            "official_ok": official_ok,
            "failures": len(predictions) - official_ok,
            "png_fallback": png_fallback,
            "mean_ms_per_image": (sum(times) / len(times)) if times else None,
            "first_ms": times[0] if times else None,
        },
        "dist": {
            "mos": dist(mos),
            "official": dist(of),
            "pyiqa": dist(py),
        },
        "vs_mos": vs_mos,
        "vs_pyiqa": {
            "correlations": vs_py_corr,
            "differences": vs_py_diff,
            "ranks": ranks,
            "equivalence": vs_py_eq,
        },
        "independent_assessment": independent_assessment(official_mos=vs_mos, pyiqa_mos=pyiqa_mos_ref),
        "predictions": predictions,
    }

    (out_dir / "metrics.json").write_text(
        json.dumps({k: payload[k] for k in payload if k != "predictions"}, indent=2, default=str),
        encoding="utf-8",
    )
    (out_dir / "raw_predictions.json").write_text(json.dumps(predictions, indent=2), encoding="utf-8")
    fieldnames = [
        "media_id",
        "source_media_key",
        "image_path",
        "mos_quality_raw",
        "pyiqa_raw",
        "official_raw",
        "abs_diff_vs_pyiqa",
        "encoding",
        "status",
        "error",
        "elapsed_ms",
    ]
    with (out_dir / "raw_predictions.csv").open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(predictions)
    write_report(out_dir / "OFFICIAL_MUSIQ_LIVEC_VALIDATION.md", payload)
    (_TOOLKIT / "OFFICIAL_MUSIQ_LIVEC_VALIDATION.md").write_text(
        (out_dir / "OFFICIAL_MUSIQ_LIVEC_VALIDATION.md").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "official_ok": official_ok,
                "vs_mos_pearson": vs_mos.get("pearson_r"),
                "vs_mos_spearman": vs_mos.get("spearman_r"),
                "vs_pyiqa_pearson": vs_py_corr.get("pearson_r"),
                "png_fallback": png_fallback,
            },
            indent=2,
        )
    )
    return 0 if official_ok == len(predictions) else 1


if __name__ == "__main__":
    raise SystemExit(main())
