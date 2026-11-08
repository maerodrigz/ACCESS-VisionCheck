#!/usr/bin/env python3
"""Controlled-distortion evaluation of ACCESS technical criteria.

Research-only. Does not write production code, DB, or authenticity detectors.
Source JPEGs are read-only. Distorted copies go under workspace/datasets/controlled_distortion/.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import random
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

import numpy as np

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
if str(_REPO) not in sys.path:
    sys.path.insert(0, str(_REPO))
_BACKEND = _REPO / "access_backend"
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

from tools.quality_validation.classical_quality_metrics import analyze_image_bytes as classical_analyze  # noqa: E402
from tools.quality_validation.engines import ENGINE_EFFICIENTNET, ENGINE_OPENCV, analyze_image_metrics  # noqa: E402
from tools.quality_validation.evaluate import evaluate_bytes_validation  # noqa: E402
from tools.quality_validation.metrics import pearson_spearman  # noqa: E402

try:
    import cv2
except ImportError as exc:  # pragma: no cover
    raise SystemExit("OpenCV required") from exc

SEED = "20261107_phase8"
DEFAULT_N = 10
KONIQ_RUN001 = _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "images"
WORKSPACE = _TOOLKIT / "workspace" / "datasets" / "controlled_distortion"
CRITERION_NAMES = (
    "Sharpness",
    "Blur",
    "Noise",
    "Brightness",
    "Contrast",
    "Blocking Artifacts",
    "Ringing Artifacts",
)
RAW_KEYS = (
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
)

# Primary ACCESS badge expected to fall as severity rises (except high_contrast: rubric vs RMS).
FAMILY_PRIMARY = {
    "gaussian_blur": "Blur",
    "awgn": "Noise",
    "underexposure": "Brightness",
    "overexposure": "Brightness",
    "low_contrast": "Contrast",
    "high_contrast": "Contrast",
    "jpeg": "Blocking Artifacts",
    "ringing": "Ringing Artifacts",
}

# severity is a comparable numeric within a family (higher = stronger distortion).
LADDERS: dict[str, list[dict[str, Any]]] = {
    "gaussian_blur": [{"severity": s, "sigma": s} for s in (0.5, 1.0, 2.0, 4.0, 8.0)],
    "awgn": [{"severity": s, "std": s} for s in (5.0, 10.0, 20.0, 35.0, 50.0)],
    "underexposure": [{"severity": round(1.0 - g, 3), "gain": g} for g in (0.70, 0.50, 0.35, 0.20)],
    "overexposure": [{"severity": round(g - 1.0, 3), "gain": g} for g in (1.30, 1.60, 2.00, 2.50)],
    "low_contrast": [{"severity": round(1.0 - g, 3), "gain": g} for g in (0.70, 0.50, 0.35, 0.20)],
    "high_contrast": [{"severity": round(g - 1.0, 3), "gain": g} for g in (1.40, 1.80, 2.40, 3.20)],
    "jpeg": [{"severity": 100 - q, "quality": q} for q in (70, 40, 25, 15, 8)],
    "ringing": [{"severity": a, "amount": a} for a in (1.4, 1.8, 2.2, 2.8, 3.5)],
}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _noise_seed(media_id: str, std: float) -> int:
    h = hashlib.sha256(f"{SEED}:{media_id}:awgn:{std}".encode("utf-8")).hexdigest()
    return int(h[:16], 16) % (2**32)


def decode_bgr(content: bytes) -> np.ndarray:
    arr = np.frombuffer(content, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if bgr is None:
        raise RuntimeError("decode failed")
    return bgr


def encode_png(bgr: np.ndarray) -> bytes:
    ok, buf = cv2.imencode(".png", bgr)
    if not ok:
        raise RuntimeError("png encode failed")
    return bytes(buf)


def encode_jpeg(bgr: np.ndarray, quality: int) -> bytes:
    ok, buf = cv2.imencode(".jpg", bgr, [int(cv2.IMWRITE_JPEG_QUALITY), int(quality)])
    if not ok:
        raise RuntimeError("jpeg encode failed")
    return bytes(buf)


def apply_gaussian_blur(bgr: np.ndarray, *, sigma: float, **_: Any) -> bytes:
    k = max(3, int(round(sigma * 4)) | 1)
    out = cv2.GaussianBlur(bgr, (k, k), sigma)
    return encode_png(out)


def apply_awgn(bgr: np.ndarray, *, std: float, media_id: str, **_: Any) -> bytes:
    rng = np.random.default_rng(_noise_seed(media_id, float(std)))
    noise = rng.normal(0.0, float(std), bgr.shape)
    out = np.clip(bgr.astype(np.float64) + noise, 0, 255).astype(np.uint8)
    return encode_png(out)


def apply_exposure(bgr: np.ndarray, *, gain: float, **_: Any) -> bytes:
    out = np.clip(bgr.astype(np.float64) * float(gain), 0, 255).astype(np.uint8)
    return encode_png(out)


def apply_contrast(bgr: np.ndarray, *, gain: float, **_: Any) -> bytes:
    x = bgr.astype(np.float64)
    out = np.clip((x - 127.5) * float(gain) + 127.5, 0, 255).astype(np.uint8)
    return encode_png(out)


def apply_jpeg(bgr: np.ndarray, *, quality: int, **_: Any) -> bytes:
    return encode_jpeg(bgr, int(quality))


def apply_ringing(bgr: np.ndarray, *, amount: float, **_: Any) -> bytes:
    blurred = cv2.GaussianBlur(bgr, (0, 0), 1.0)
    out = cv2.addWeighted(bgr, float(amount), blurred, 1.0 - float(amount), 0)
    out = np.clip(out, 0, 255).astype(np.uint8)
    return encode_png(out)


APPLIERS: dict[str, Callable[..., bytes]] = {
    "gaussian_blur": apply_gaussian_blur,
    "awgn": apply_awgn,
    "underexposure": apply_exposure,
    "overexposure": apply_exposure,
    "low_contrast": apply_contrast,
    "high_contrast": apply_contrast,
    "jpeg": apply_jpeg,
    "ringing": apply_ringing,
}


def select_originals(folder: Path, n: int, seed: str) -> list[Path]:
    files = sorted(p for p in folder.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png"} and p.is_file())
    if not files:
        raise SystemExit(f"no photographs in {folder}")
    rng = random.Random(seed)
    if n >= len(files):
        return files
    return sorted(rng.sample(files, n), key=lambda p: p.name)


def criteria_map(result: dict[str, Any]) -> dict[str, int]:
    out: dict[str, int] = {}
    scores = result.get("criterion_scores")
    if isinstance(scores, dict):
        for name, score in scores.items():
            try:
                out[str(name)] = int(score)
            except (TypeError, ValueError):
                continue
        return out
    rows = result.get("criteria")
    if not isinstance(rows, list):
        return out
    for row in rows:
        if isinstance(row, dict) and row.get("name"):
            try:
                out[str(row["name"])] = int(row["score"])
            except (TypeError, ValueError):
                continue
    return out


def flatten_record(
    *,
    media_id: str,
    source_media_key: str,
    family: str,
    severity: float,
    params: dict[str, Any],
    is_original: bool,
    path: Path,
    enet: dict[str, Any] | None,
    enet_err: str | None,
    enet_int: dict[str, int],
    opencv_raw: dict[str, Any] | None,
    opencv_int: dict[str, int],
    classical: dict[str, float] | None,
    elapsed_ms: float,
) -> dict[str, Any]:
    rec: dict[str, Any] = {
        "media_id": media_id,
        "source_media_key": source_media_key,
        "family": family,
        "severity": severity,
        "params_json": json.dumps(params, sort_keys=True),
        "is_original": int(is_original),
        "image_path": str(path),
        "seed": SEED,
        "enet_error": enet_err or "",
        "elapsed_ms": elapsed_ms,
    }
    raw = enet or {}
    for key in RAW_KEYS:
        rec[f"enet_raw_{key}"] = raw.get(key)
    for name in CRITERION_NAMES:
        slug = name.lower().replace(" ", "_")
        rec[f"enet_int_{slug}"] = enet_int.get(name)
        rec[f"opencv_int_{slug}"] = opencv_int.get(name)
    oc = opencv_raw or {}
    for key in RAW_KEYS:
        rec[f"opencv_raw_{key}"] = oc.get(key)
    cl = classical or {}
    for key, val in cl.items():
        rec[f"classic_{key}"] = val
    rec["enet_overall"] = None
    if enet_int and len(enet_int) >= 7:
        rec["enet_overall"] = sum(enet_int[n] for n in CRITERION_NAMES) / 7.0
    rec["opencv_overall"] = None
    if opencv_int and len(opencv_int) >= 7:
        rec["opencv_overall"] = sum(opencv_int.get(n, 0) for n in CRITERION_NAMES) / 7.0
    return rec


def score_bytes(content: bytes, file_name: str) -> tuple[dict[str, Any] | None, str | None, dict[str, int], dict[str, Any] | None, dict[str, int], dict[str, float] | None]:
    enet_result = evaluate_bytes_validation(content, file_name=file_name, engine=ENGINE_EFFICIENTNET)
    enet_ok = str(enet_result.get("analysis_status") or "") == "ok"
    enet_err = None if enet_ok else str(enet_result.get("error_code") or "enet_failed")
    enet_raw = enet_result.get("raw_metrics") if isinstance(enet_result.get("raw_metrics"), dict) else None
    enet_int = criteria_map(enet_result)
    oc_raw, oc_err = analyze_image_metrics(content, ENGINE_OPENCV)
    oc_result = evaluate_bytes_validation(content, file_name=file_name, engine=ENGINE_OPENCV)
    oc_int = criteria_map(oc_result)
    classic = classical_analyze(content)
    if oc_err and oc_raw is None:
        oc_int = {}
    if enet_err:
        enet_raw = None
        enet_int = {}
    return enet_raw, enet_err, enet_int, oc_raw, oc_int, classic


def monotonicity_rows(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Spearman of score vs severity within each (media_id, family). Originals attached as severity 0."""
    originals = {r["media_id"]: r for r in records if r["is_original"]}
    by: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for rec in records:
        if rec["is_original"]:
            continue
        by.setdefault((rec["media_id"], rec["family"]), []).append(rec)
    out: list[dict[str, Any]] = []
    score_cols = [
        *[f"enet_int_{n.lower().replace(' ', '_')}" for n in CRITERION_NAMES],
        *[f"enet_raw_{k}" for k in RAW_KEYS],
        *[f"opencv_int_{n.lower().replace(' ', '_')}" for n in CRITERION_NAMES],
        "classic_sharpness_laplacian_var",
        "classic_sharpness_tenengrad",
        "classic_blur_inv_laplacian",
        "classic_noise_immerkaer",
        "classic_noise_residual_std",
        "classic_brightness_mean",
        "classic_exposure_clip_frac",
        "classic_exposure_triangle_048",
        "classic_contrast_rms",
        "classic_contrast_michelson",
        "classic_blocking_boundary_ratio",
        "classic_blocking_flat_frac",
        "classic_ringing_edge_lap",
        "enet_overall",
        "opencv_overall",
    ]
    for (media_id, family), rows in sorted(by.items()):
        orig = originals.get(media_id)
        series = ([orig] if orig else []) + sorted(rows, key=lambda r: float(r["severity"]))
        sev = [0.0 if r["is_original"] else float(r["severity"]) for r in series]
        for col in score_cols:
            ys: list[float] = []
            ok = True
            for r in series:
                v = r.get(col)
                if v is None or v == "":
                    ok = False
                    break
                ys.append(float(v))
            if not ok or len(ys) < 3:
                corr: dict[str, Any] = {"spearman_r": None, "pearson_r": None, "n": len(ys)}
            else:
                corr = pearson_spearman(sev, ys)
            primary = FAMILY_PRIMARY.get(family)
            slug = primary.lower().replace(" ", "_") if primary else ""
            out.append(
                {
                    "media_id": media_id,
                    "family": family,
                    "column": col,
                    "is_primary": int(bool(primary) and (col.endswith(slug) or col == f"enet_int_{slug}")),
                    "n": corr.get("n"),
                    "spearman_r": corr.get("spearman_r"),
                    "pearson_r": corr.get("pearson_r"),
                    "expected_sign": -1 if family != "high_contrast" or "contrast" not in col else -1,
                    "note": (
                        "high_contrast: ACCESS rubric wants quality down; RMS-style metrics may rise"
                        if family == "high_contrast" and "contrast" in col
                        else ""
                    ),
                }
            )
    return out


def summarize_monotonicity(mono: list[dict[str, Any]]) -> dict[str, Any]:
    """Median Spearman across images for primary enet integer vs severity (expect negative)."""
    summary: dict[str, Any] = {}
    for family, primary in FAMILY_PRIMARY.items():
        slug = primary.lower().replace(" ", "_")
        col = f"enet_int_{slug}"
        vals = [
            float(r["spearman_r"])
            for r in mono
            if r["family"] == family and r["column"] == col and r.get("spearman_r") is not None
        ]
        classic_col = {
            "gaussian_blur": "classic_blur_inv_laplacian",
            "awgn": "classic_noise_immerkaer",
            "underexposure": "classic_exposure_triangle_048",
            "overexposure": "classic_exposure_clip_frac",
            "low_contrast": "classic_contrast_rms",
            "high_contrast": "classic_contrast_rms",
            "jpeg": "classic_blocking_boundary_ratio",
            "ringing": "classic_ringing_edge_lap",
        }[family]
        cvals = [
            float(r["spearman_r"])
            for r in mono
            if r["family"] == family and r["column"] == classic_col and r.get("spearman_r") is not None
        ]
        def _med(xs: list[float]) -> float | None:
            if not xs:
                return None
            xs = sorted(xs)
            return xs[len(xs) // 2]

        summary[family] = {
            "primary_criterion": primary,
            "enet_int_median_spearman_vs_severity": _med(vals),
            "enet_int_n_images": len(vals),
            "classic_column": classic_col,
            "classic_median_spearman_vs_severity": _med(cvals),
            "enet_responds_as_worse": (_med(vals) is not None and _med(vals) < -0.5),
            "classic_tracks_amount": (
                _med(cvals) is not None
                and (
                    _med(cvals) > 0.5
                    if classic_col
                    in {
                        "classic_noise_immerkaer",
                        "classic_exposure_clip_frac",
                        "classic_blocking_boundary_ratio",
                        "classic_ringing_edge_lap",
                        "classic_blur_inv_laplacian",
                    }
                    else _med(cvals) < -0.5
                )
            ),
        }
        if family in {"underexposure"}:
            # triangle should fall as underexposure severity rises
            summary[family]["classic_tracks_amount"] = _med(cvals) is not None and _med(cvals) < -0.5
        if family == "low_contrast":
            summary[family]["classic_tracks_amount"] = _med(cvals) is not None and _med(cvals) < -0.5
        if family == "high_contrast":
            summary[family]["classic_tracks_amount"] = _med(cvals) is not None and _med(cvals) > 0.5
            summary[family]["note"] = "RMS contrast is expected to rise with gain; ACCESS rubric would want quality down."
    return summary


def sharpness_blur_duplication(records: list[dict[str, Any]]) -> dict[str, Any]:
    blur_family = [r for r in records if r["family"] == "gaussian_blur" or r["is_original"]]
    # unique rows: originals + blur ladder
    seen: set[tuple[str, str, float]] = set()
    rows: list[dict[str, Any]] = []
    for r in records:
        if not r["is_original"] and r["family"] != "gaussian_blur":
            continue
        key = (r["media_id"], r["family"], float(r["severity"]))
        if key in seen:
            continue
        seen.add(key)
        rows.append(r)
    enet_s = [float(r["enet_raw_sharpness"]) for r in rows if r.get("enet_raw_sharpness") is not None]
    enet_b = [float(r["enet_raw_blur"]) for r in rows if r.get("enet_raw_blur") is not None]
    n = min(len(enet_s), len(enet_b))
    enet_s, enet_b = enet_s[:n], enet_b[:n]
    ints_s = [float(r["enet_int_sharpness"]) for r in rows if r.get("enet_int_sharpness") is not None]
    ints_b = [float(r["enet_int_blur"]) for r in rows if r.get("enet_int_blur") is not None]
    oc_s = [float(r["opencv_raw_sharpness"]) for r in rows if r.get("opencv_raw_sharpness") is not None]
    oc_b = [float(r["opencv_raw_blur"]) for r in rows if r.get("opencv_raw_blur") is not None]
    m = min(len(oc_s), len(oc_b))
    return {
        "n_enet": n,
        "enet_raw_sharpness_vs_blur": pearson_spearman(enet_s, enet_b),
        "enet_int_sharpness_vs_blur": pearson_spearman(ints_s[: min(len(ints_s), len(ints_b))], ints_b[: min(len(ints_s), len(ints_b))]),
        "opencv_raw_sharpness_vs_blur": pearson_spearman(oc_s[:m], oc_b[:m]),
        "opencv_identity_mean_abs_s_plus_b_minus_1": (
            float(np.mean(np.abs(np.array(oc_s[:m]) + np.array(oc_b[:m]) - 1.0))) if m else None
        ),
    }


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields: list[str] = []
    for row in rows:
        for k in row:
            if k not in fields:
                fields.append(k)
    with path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)


def run(*, n: int, seed: str, output_dir: Path, source_dir: Path) -> dict[str, Any]:
    originals = select_originals(source_dir, n, seed)
    gen_dir = WORKSPACE / "generated"
    gen_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    manifest = []
    records: list[dict[str, Any]] = []
    t_all = time.perf_counter()

    for idx, src in enumerate(originals, start=1):
        media_id = f"CTRL-{idx:03d}"
        key = src.name
        content = src.read_bytes()
        bgr = decode_bgr(content)
        manifest.append(
            {
                "media_id": media_id,
                "source_media_key": key,
                "source_path": str(src.resolve()),
                "width": int(bgr.shape[1]),
                "height": int(bgr.shape[0]),
            }
        )
        t0 = time.perf_counter()
        enet_raw, enet_err, enet_int, oc_raw, oc_int, classic = score_bytes(content, key)
        rec = flatten_record(
            media_id=media_id,
            source_media_key=key,
            family="original",
            severity=0.0,
            params={},
            is_original=True,
            path=src,
            enet=enet_raw,
            enet_err=enet_err,
            enet_int=enet_int,
            opencv_raw=oc_raw,
            opencv_int=oc_int,
            classical=classic,
            elapsed_ms=(time.perf_counter() - t0) * 1000.0,
        )
        records.append(rec)
        print(f"{media_id} original {key} enet={enet_err or 'ok'}", flush=True)

        for family, steps in LADDERS.items():
            fn = APPLIERS[family]
            for step in steps:
                params = {k: v for k, v in step.items() if k != "severity"}
                distorted = fn(bgr, media_id=media_id, **params)
                suffix = "jpg" if family == "jpeg" else "png"
                out_path = gen_dir / media_id / f"{family}_s{step['severity']}.{suffix}"
                out_path.parent.mkdir(parents=True, exist_ok=True)
                out_path.write_bytes(distorted)
                t1 = time.perf_counter()
                er, ee, ei, ocr, oci, cl = score_bytes(distorted, out_path.name)
                records.append(
                    flatten_record(
                        media_id=media_id,
                        source_media_key=key,
                        family=family,
                        severity=float(step["severity"]),
                        params=params,
                        is_original=False,
                        path=out_path,
                        enet=er,
                        enet_err=ee,
                        enet_int=ei,
                        opencv_raw=ocr,
                        opencv_int=oci,
                        classical=cl,
                        elapsed_ms=(time.perf_counter() - t1) * 1000.0,
                    )
                )
            print(f"  {family} done", flush=True)

    mono = monotonicity_rows(records)
    summary = summarize_monotonicity(mono)
    dup = sharpness_blur_duplication(records)

    # Integer 1 usage
    ones = {name: 0 for name in CRITERION_NAMES}
    for r in records:
        for name in CRITERION_NAMES:
            slug = name.lower().replace(" ", "_")
            if r.get(f"enet_int_{slug}") == 1:
                ones[name] += 1

    payload = {
        "generated_at": _now_iso(),
        "seed": seed,
        "n_originals": len(originals),
        "n_records": len(records),
        "source_dir": str(source_dir),
        "elapsed_s": time.perf_counter() - t_all,
        "ladders": LADDERS,
        "family_primary": FAMILY_PRIMARY,
        "monotonicity_summary": summary,
        "sharpness_blur": dup,
        "enet_integer_1_counts": ones,
        "disclaimer": "Not human criterion accuracy. Not MUSIQ. Production unmodified.",
    }
    write_csv(output_dir / "originals_manifest.csv", manifest)
    write_csv(output_dir / "raw_predictions.csv", records)
    write_csv(output_dir / "monotonicity.csv", mono)
    (output_dir / "metrics.json").write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    return payload


def fmt(v: Any, digits: int = 3) -> str:
    if v is None:
        return "N/A"
    if isinstance(v, bool):
        return "yes" if v else "no"
    if isinstance(v, float):
        return f"{v:.{digits}f}"
    return str(v)


def write_report(path: Path, payload: dict[str, Any]) -> None:
    s = payload["monotonicity_summary"]
    dup = payload["sharpness_blur"]
    lines = [
        "# Controlled distortion results (Phase 8)",
        "",
        "**Status: complete.** Research-only ladders on existing KonIQ JPEGs. Source files were not modified. Production scoring was not changed. No human criterion labels were invented. MUSIQ was not run.",
        "",
        f"Generated: {payload['generated_at']}",
        f"Seed: `{payload['seed']}`",
        f"Originals: **{payload['n_originals']}**  Records: **{payload['n_records']}**  Wall time: {fmt(payload.get('elapsed_s'), 1)} s",
        "",
        "Spearman is **score vs distortion severity** (higher severity = stronger distortion). For displayed ACCESS quality (high = better), **negative** Spearman means the badge gets worse as the distortion grows, which is the expected direction.",
        "",
        "## 1. Ladders (deterministic)",
        "",
        "| Family | Parameters | Primary badge |",
        "|--------|------------|---------------|",
    ]
    for fam, steps in LADDERS.items():
        lines.append(f"| `{fam}` | `{steps}` | {FAMILY_PRIMARY[fam]} |")
    lines += [
        "",
        "AWGN uses `sha256(seed:media_id:awgn:std)` as numpy RNG seed.",
        "",
        "## 2. EfficientNet displayed integers vs severity (median Spearman across originals)",
        "",
        "| Family | Primary | Median Spearman | Responds as worse (&lt; −0.5)? |",
        "|--------|---------|----------------:|:-------------------------------:|",
    ]
    for fam, row in s.items():
        lines.append(
            f"| {fam} | {row['primary_criterion']} | {fmt(row['enet_int_median_spearman_vs_severity'])} | {fmt(row['enet_responds_as_worse'])} |"
        )
    lines += [
        "",
        "## 3. Classical research metrics vs severity (median Spearman)",
        "",
        "| Family | Metric | Median Spearman | Tracks amount? |",
        "|--------|--------|----------------:|:--------------:|",
    ]
    for fam, row in s.items():
        lines.append(
            f"| {fam} | `{row['classic_column']}` | {fmt(row['classic_median_spearman_vs_severity'])} | {fmt(row['classic_tracks_amount'])} |"
        )
        if row.get("note"):
            lines.append(f"| | | | {row['note']} |")
    enet_sb = dup.get("enet_raw_sharpness_vs_blur") or {}
    int_sb = dup.get("enet_int_sharpness_vs_blur") or {}
    oc_sb = dup.get("opencv_raw_sharpness_vs_blur") or {}
    lines += [
        "",
        "## 4. Sharpness vs Blur duplication (originals + Gaussian ladder)",
        "",
        f"- n (EfficientNet raw pairs): {dup.get('n_enet')}",
        f"- EfficientNet raw sharpness vs raw blur: Pearson {fmt(enet_sb.get('pearson_r'))}, Spearman {fmt(enet_sb.get('spearman_r'))}",
        f"- EfficientNet **integers** Sharpness vs Blur (both high=better): Pearson {fmt(int_sb.get('pearson_r'))}, Spearman {fmt(int_sb.get('spearman_r'))}",
        f"- OpenCV raw sharpness vs blur: Pearson {fmt(oc_sb.get('pearson_r'))}, Spearman {fmt(oc_sb.get('spearman_r'))}",
        f"- OpenCV mean |sharpness + blur − 1|: {fmt(dup.get('opencv_identity_mean_abs_s_plus_b_minus_1'))}",
        "",
        "If OpenCV |s+b−1| ≈ 0 they are exact inverses. If EfficientNet raw Spearman is near −1, the heads are duplicate signals on this ladder.",
        "",
        "## 5. Unreachable 1",
        "",
        f"Counts of displayed integer **1** across all scored files: {payload.get('enet_integer_1_counts')}",
        "",
        "## 6. How to read this",
        "",
        "- This is **construct sensitivity**, not human accuracy.",
        "- Classical metrics are compared on the same ladders; they are **not** assumed better until humans exist.",
        "- JPEG family encodes at the listed quality. Other families are PNG so JPEG is not mixed in.",
        "",
        "## 7. Production",
        "",
        "FastAPI, EfficientNet weights, `_soft_score`, overall_score, XP, Flutter, React, PROBE, WaveRep, Gemini, MUSIQ: unchanged.",
        "",
        "Stopped for review.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--n", type=int, default=DEFAULT_N)
    parser.add_argument("--seed", type=str, default=SEED)
    parser.add_argument("--source-dir", type=Path, default=KONIQ_RUN001)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=WORKSPACE / "output" / "run_001",
    )
    args = parser.parse_args()
    if not args.source_dir.is_dir():
        print(f"STOP: missing source photographs: {args.source_dir}", file=sys.stderr)
        return 2
    payload = run(n=args.n, seed=args.seed, output_dir=args.output_dir.resolve(), source_dir=args.source_dir.resolve())
    write_report(args.output_dir / "CONTROLLED_DISTORTION_RESULTS.md", payload)
    toolkit = _TOOLKIT / "CONTROLLED_DISTORTION_RESULTS.md"
    toolkit.write_text((args.output_dir / "CONTROLLED_DISTORTION_RESULTS.md").read_text(encoding="utf-8"), encoding="utf-8")
    print(json.dumps({k: payload[k] for k in ("n_originals", "n_records", "monotonicity_summary", "sharpness_blur", "enet_integer_1_counts")}, indent=2, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
