#!/usr/bin/env python3
"""Phase 12A: a priori OpenCV + classical metrics on locked SPAQ-200.

Does not fit thresholds. Does not change production. Does not rewrite Phase 10/11.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.classical_quality_metrics import analyze_image_bytes as classical_analyze  # noqa: E402
from tools.quality_validation.engines import ENGINE_OPENCV, analyze_image_metrics  # noqa: E402
from tools.quality_validation.metrics import correlation_bootstrap, pearson_spearman  # noqa: E402
from tools.quality_validation.scale_mapping import parse_optional_float  # noqa: E402
from tools.quality_validation.scoring_candidates import clip01, production_brightness_q  # noqa: E402

SPAQ_ROOT = _TOOLKIT / "workspace" / "datasets" / "spaq"
ENET_CSV = SPAQ_ROOT / "output" / "run_001" / "spaq_200_machine_scores.csv"
DEFAULT_OUT = SPAQ_ROOT / "output" / "phase12_run_001"
SEED = 20261107

# Declared before scoring. Higher machine value meaning is in "machine_high".
# human_high documents the SPAQ column direction. invert_human applies 100-x.
PAIRS = (
    {"key": "sharp_enet_raw", "human": "attr_sharpness_raw", "invert_human": False, "machine": "enet_raw_sharpness", "machine_high": "sharper", "family": "sharpness", "baseline": True},
    {"key": "sharp_enet_badge", "human": "attr_sharpness_raw", "invert_human": False, "machine": "criterion_Sharpness", "machine_high": "sharper", "family": "sharpness", "baseline": True},
    {"key": "sharp_opencv", "human": "attr_sharpness_raw", "invert_human": False, "machine": "opencv_sharpness", "machine_high": "sharper", "family": "sharpness", "baseline": False},
    {"key": "sharp_lap", "human": "attr_sharpness_raw", "invert_human": False, "machine": "classic_sharpness_laplacian_var", "machine_high": "more_detail", "family": "sharpness", "baseline": False},
    {"key": "sharp_tenengrad", "human": "attr_sharpness_raw", "invert_human": False, "machine": "classic_sharpness_tenengrad", "machine_high": "more_detail", "family": "sharpness", "baseline": False},
    {"key": "noise_enet_raw_amount", "human": "attr_noisiness_raw", "invert_human": False, "machine": "enet_raw_noise", "machine_high": "more_noise", "family": "noise_amount", "baseline": True},
    {"key": "noise_enet_badge_quality", "human": "attr_noisiness_raw", "invert_human": True, "machine": "criterion_Noise", "machine_high": "cleaner", "family": "noise_quality", "baseline": True},
    {"key": "noise_opencv_amount", "human": "attr_noisiness_raw", "invert_human": False, "machine": "opencv_noise", "machine_high": "more_noise", "family": "noise_amount", "baseline": False},
    {"key": "noise_immerkaer_amount", "human": "attr_noisiness_raw", "invert_human": False, "machine": "classic_noise_immerkaer", "machine_high": "more_noise", "family": "noise_amount", "baseline": False},
    {"key": "noise_residual_amount", "human": "attr_noisiness_raw", "invert_human": False, "machine": "classic_noise_residual_std", "machine_high": "more_noise", "family": "noise_amount", "baseline": False},
    {"key": "bright_enet_badge", "human": "attr_brightness_raw", "invert_human": False, "machine": "criterion_Brightness", "machine_high": "better_exposure", "family": "brightness", "baseline": True},
    {"key": "bright_enet_raw_luma", "human": "attr_brightness_raw", "invert_human": False, "machine": "enet_raw_brightness", "machine_high": "higher_luma", "family": "brightness_amount", "baseline": True},
    {"key": "bright_mean_luma", "human": "attr_brightness_raw", "invert_human": False, "machine": "classic_brightness_mean", "machine_high": "higher_luma", "family": "brightness_amount", "baseline": False},
    {"key": "bright_triangle", "human": "attr_brightness_raw", "invert_human": False, "machine": "classic_exposure_triangle_048", "machine_high": "near_mid_gray", "family": "brightness", "baseline": False},
    {"key": "bright_opencv_luma", "human": "attr_brightness_raw", "invert_human": False, "machine": "opencv_brightness", "machine_high": "higher_luma", "family": "brightness_amount", "baseline": False},
    {"key": "contrast_enet_badge", "human": "attr_contrast_raw", "invert_human": False, "machine": "criterion_Contrast", "machine_high": "more_contrast", "family": "contrast", "baseline": True},
    {"key": "contrast_enet_raw", "human": "attr_contrast_raw", "invert_human": False, "machine": "enet_raw_contrast", "machine_high": "more_contrast", "family": "contrast", "baseline": True},
    {"key": "contrast_opencv", "human": "attr_contrast_raw", "invert_human": False, "machine": "opencv_contrast", "machine_high": "more_contrast", "family": "contrast", "baseline": False},
    {"key": "contrast_rms", "human": "attr_contrast_raw", "invert_human": False, "machine": "classic_contrast_rms", "machine_high": "more_contrast", "family": "contrast", "baseline": False},
    {"key": "contrast_michelson", "human": "attr_contrast_raw", "invert_human": False, "machine": "classic_contrast_michelson", "machine_high": "more_range", "family": "contrast", "baseline": False},
    {"key": "mos_enet_overall", "human": "mos_quality_raw", "invert_human": False, "machine": "overall_score", "machine_high": "better", "family": "overall", "baseline": True},
)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_enet(path: Path) -> dict[str, dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return {row["source_media_key"]: row for row in csv.DictReader(handle)}


def corr_pack(hs: list[float], ms: list[float]) -> dict[str, Any]:
    if len(hs) < 5:
        return {"n": len(hs), "pearson_r": None, "spearman_r": None, "note": "insufficient_n"}
    base = pearson_spearman(ms, hs)
    boot = correlation_bootstrap(ms, hs, seed=SEED, n_boot=400)
    return {
        "n": len(hs),
        "pearson_r": base.get("pearson_r"),
        "pearson_p": base.get("pearson_p"),
        "pearson_ci_low": boot.get("pearson_ci_low"),
        "pearson_ci_high": boot.get("pearson_ci_high"),
        "spearman_r": base.get("spearman_r"),
        "spearman_p": base.get("spearman_p"),
        "spearman_ci_low": boot.get("spearman_ci_low"),
        "spearman_ci_high": boot.get("spearman_ci_high"),
        "note": base.get("note"),
        "machine_n_unique": len(set(ms)),
        "machine_min": min(ms),
        "machine_max": max(ms),
        "machine_mean": sum(ms) / len(ms),
    }


def human_val(row: dict[str, Any], spec: dict[str, Any]) -> float | None:
    raw = parse_optional_float(row.get(spec["human"]))
    if raw is None:
        return None
    return 100.0 - raw if spec["invert_human"] else raw


def run(images_dir: Path, enet_csv: Path, out_dir: Path) -> dict[str, Any]:
    enet = load_enet(enet_csv)
    keys = list(enet.keys())
    if len(keys) != 200:
        raise SystemExit(f"expected 200 ENET rows, got {len(keys)}")
    rows: list[dict[str, Any]] = []
    opencv_ms: list[float] = []
    classic_ms: list[float] = []
    failures: list[dict[str, Any]] = []
    t0 = time.perf_counter()
    for i, key in enumerate(keys, start=1):
        rec = dict(enet[key])
        path = images_dir / key
        rec["relative_path"] = f"images/{key}"
        print(f"[12A {i}/200] {key}", flush=True)
        if not path.is_file():
            rec["opencv_error"] = "missing_file"
            rec["classic_error"] = "missing_file"
            failures.append({"key": key, "error": "missing_file"})
            rows.append(rec)
            continue
        content = path.read_bytes()
        t1 = time.perf_counter()
        ocv, oerr = analyze_image_metrics(content, ENGINE_OPENCV)
        opencv_ms.append((time.perf_counter() - t1) * 1000.0)
        if ocv is None:
            rec["opencv_error"] = oerr or "opencv_failed"
            failures.append({"key": key, "error": rec["opencv_error"]})
        else:
            rec["opencv_error"] = ""
            for k, v in ocv.items():
                rec[f"opencv_{k}"] = v
            rec["opencv_noise_quality"] = clip01(1.0 - min(float(ocv["noise"]), 0.85))
            rec["opencv_exposure_q"] = production_brightness_q(float(ocv["brightness"]))
        t2 = time.perf_counter()
        classic = classical_analyze(content)
        classic_ms.append((time.perf_counter() - t2) * 1000.0)
        if classic is None:
            rec["classic_error"] = "classic_failed"
        else:
            rec["classic_error"] = ""
            for k, v in classic.items():
                rec[f"classic_{k}"] = v
        rec["enet_raw_sharpness"] = rec.get("raw_sharpness")
        rec["enet_raw_noise"] = rec.get("raw_noise")
        rec["enet_raw_brightness"] = rec.get("raw_brightness")
        rec["enet_raw_contrast"] = rec.get("raw_contrast")
        rec["enet_raw_blur"] = rec.get("raw_blur")
        rec["enet_raw_blocking"] = rec.get("raw_blocking_artifacts")
        rec["enet_raw_ringing"] = rec.get("raw_ringing_artifacts")
        rows.append(rec)
    elapsed = time.perf_counter() - t0

    comparisons: dict[str, Any] = {}
    for spec in PAIRS:
        hs: list[float] = []
        ms: list[float] = []
        for rec in rows:
            h = human_val(rec, spec)
            m = parse_optional_float(rec.get(spec["machine"]))
            if h is None or m is None:
                continue
            hs.append(h)
            ms.append(m)
        comparisons[spec["key"]] = {**spec, **corr_pack(hs, ms)}

    unlabeled = {}
    for name, cols in (
        ("Blur", ("opencv_blur", "classic_blur_inv_laplacian", "criterion_Blur", "enet_raw_blur")),
        ("Blocking", ("opencv_blocking_artifacts", "classic_blocking_boundary_ratio", "criterion_Blocking_Artifacts")),
        ("Ringing", ("opencv_ringing_artifacts", "classic_ringing_edge_lap", "criterion_Ringing_Artifacts")),
    ):
        unlabeled[name] = {"human_labels": False, "correlation_computed": False, "columns": {}}
        for col in cols:
            vals = [v for v in (parse_optional_float(r.get(col)) for r in rows) if v is not None]
            if not vals:
                continue
            unlabeled[name]["columns"][col] = {
                "n": len(vals),
                "min": min(vals),
                "max": max(vals),
                "mean": sum(vals) / len(vals),
                "n_unique": len(set(vals)),
            }

    payload = {
        "generated_at": _now(),
        "phase": "12A",
        "n": len(rows),
        "n_opencv_ok": sum(1 for r in rows if not r.get("opencv_error")),
        "n_classic_ok": sum(1 for r in rows if not r.get("classic_error")),
        "failures": failures,
        "wall_s": elapsed,
        "opencv_ms_mean": sum(opencv_ms) / len(opencv_ms) if opencv_ms else None,
        "classic_ms_mean": sum(classic_ms) / len(classic_ms) if classic_ms else None,
        "comparisons": comparisons,
        "unlabeled": unlabeled,
        "pairs_declared_before_scoring": True,
        "fitted_on_spaq200": False,
        "production_untouched": True,
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    fieldnames: list[str] = []
    for rec in rows:
        for k in rec:
            if k not in fieldnames:
                fieldnames.append(k)
    with (out_dir / "phase12a_scores.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    (out_dir / "phase12a_metrics.json").write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--images", type=Path, default=SPAQ_ROOT / "images")
    parser.add_argument("--enet-csv", type=Path, default=ENET_CSV)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    payload = run(args.images.resolve(), args.enet_csv.resolve(), args.output_dir.resolve())
    print(json.dumps({"n": payload["n"], "opencv_ms": payload["opencv_ms_mean"], "classic_ms": payload["classic_ms_mean"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
