#!/usr/bin/env python3
"""Experimental MUSIQ PaQ-2-PiQ benchmark on KonIQ Run 001 + 002.

Research-only. Does not import media_evaluator, EfficientNet production scoring,
PROBE, WaveRep, Gemini, Flutter, React, or PostgreSQL. Reads existing baseline
CSVs and JPEG files without modifying them.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import platform
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
DEFAULT_OUTPUT = _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "musiq_paq2piq_benchmark"
RUN_001_CSV = _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "metadata" / "output" / "run_001" / "per_image_results.csv"
RUN_002_CSV = _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "run_002" / "output" / "per_image_results.csv"
RUN_001_IMAGES = _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "images"
RUN_002_IMAGES = _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "run_002" / "images"
METRIC_ID = "musiq-paq2piq"
PROTECTED_OUTPUTS = (RUN_001_CSV.parent, RUN_002_CSV.parent)

LICENSE_SUMMARY = {
    "pyiqa_package": "PolyForm Noncommercial License 1.0.0 (current PyPI/pyproject.toml). Historical README/issue #294 also described CC BY-NC-SA 4.0. Treat as noncommercial research-only.",
    "pyiqa_weights": "pyiqa pretrained weights are typically CC BY-NC-SA 4.0 or otherwise noncommercial. Do not ship in ACCESS production.",
    "paq2piq_dataset_and_original_code": "PaQ-2-PiQ (baidut/PaQ-2-PiQ) is CC BY-NC-SA 4.0.",
    "musiq_paper_code": "Official MUSIQ (google-research) is a TensorFlow reimplementation source; pyiqa provides a PyTorch port of converted checkpoints.",
    "access_use": "Allowed for this isolated research benchmark. Not a production license. Do not install pyiqa into access_backend.",
}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def pearson_spearman(x: list[float], y: list[float]) -> dict[str, float | int | None | str]:
    if len(x) < 2 or len(x) != len(y):
        return {"pearson_r": None, "pearson_p": None, "spearman_r": None, "spearman_p": None, "n": len(x)}
    import numpy as np
    from scipy import stats

    xa = np.asarray(x, dtype=float)
    ya = np.asarray(y, dtype=float)
    if float(np.std(xa)) == 0.0 or float(np.std(ya)) == 0.0:
        return {
            "pearson_r": None,
            "pearson_p": None,
            "spearman_r": None,
            "spearman_p": None,
            "n": len(x),
            "note": "correlation undefined when a series has zero variance",
        }
    pr, pp = stats.pearsonr(xa, ya)
    sr, sp = stats.spearmanr(xa, ya)
    return {
        "pearson_r": float(pr),
        "pearson_p": float(pp),
        "spearman_r": float(sr),
        "spearman_p": float(sp),
        "n": int(len(x)),
    }


def mae_rmse(pred: list[float], target: list[float]) -> dict[str, float | int | None]:
    if len(pred) == 0 or len(pred) != len(target):
        return {"mae": None, "rmse": None, "n": len(pred)}
    import numpy as np

    d = np.asarray(pred, dtype=float) - np.asarray(target, dtype=float)
    return {
        "mae": float(np.mean(np.abs(d))),
        "rmse": float(np.sqrt(np.mean(d * d))),
        "n": int(len(pred)),
    }


def summarize(values: list[float]) -> dict[str, float | int | None]:
    if not values:
        return {"n": 0, "min": None, "max": None, "mean": None, "stdev": None}
    import statistics

    return {
        "n": len(values),
        "min": float(min(values)),
        "max": float(max(values)),
        "mean": float(statistics.fmean(values)),
        "stdev": float(statistics.stdev(values)) if len(values) > 1 else 0.0,
    }


def scores_on_comparable_1_5_scale(raw_values: list[float], declared_range: str | None) -> bool:
    """MAE/RMSE vs KonIQ MOS 1-5 is only valid if predictions live on ~1-5."""
    if not raw_values:
        return False
    lo, hi = min(raw_values), max(raw_values)
    declared = (declared_range or "").replace(" ", "").lower()
    looks_like_100 = "~0,~100" in declared or declared in {"0,100", "~0,~100"}
    if looks_like_100:
        return False
    if hi > 6.5 or lo < 0.4:
        return False
    return True


def load_baseline_csv(path: Path, run_id: str, images_dir: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for rec in reader:
            key = rec["source_media_key"]
            image_path = images_dir / key
            rows.append(
                {
                    "run_id": run_id,
                    "media_id": rec["media_id"],
                    "source_media_key": key,
                    "relative_path": rec.get("relative_path"),
                    "mos_quality_raw": float(rec["mos_quality_raw"]) if rec.get("mos_quality_raw") else None,
                    "mos_scale": rec.get("mos_scale"),
                    "overall_mapped_1_5": float(rec["overall_mapped_1_5"]) if rec.get("overall_mapped_1_5") else None,
                    "efficientnet_overall": float(rec["overall_score"]) if rec.get("overall_score") else None,
                    "efficientnet_status": rec.get("analysis_status"),
                    "efficientnet_engine": rec.get("quality_engine"),
                    "efficientnet_elapsed_ms": float(rec["elapsed_ms"]) if rec.get("elapsed_ms") else None,
                    "image_path": str(image_path),
                    "image_exists": image_path.is_file(),
                }
            )
    return rows


def collect_eval_set() -> tuple[list[dict[str, Any]], list[str]]:
    errors: list[str] = []
    rows = load_baseline_csv(RUN_001_CSV, "run_001", RUN_001_IMAGES) + load_baseline_csv(
        RUN_002_CSV, "run_002", RUN_002_IMAGES
    )
    if len(rows) != 140:
        errors.append(f"Expected 140 baseline rows, found {len(rows)}")
    keys = [r["source_media_key"] for r in rows]
    if len(set(keys)) != len(keys):
        errors.append("Duplicate source_media_key across Run 001/002")
    missing = [r["source_media_key"] for r in rows if not r["image_exists"]]
    if missing:
        errors.append(f"Missing JPEG files ({len(missing)}): {missing[:8]}")
    return rows, errors


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def probe_env() -> dict[str, Any]:
    usage = shutil.disk_usage(_TOOLKIT.anchor)
    info: dict[str, Any] = {
        "python_executable": sys.executable,
        "python_version": sys.version.replace("\n", " "),
        "platform": platform.platform(),
        "cwd": os.getcwd(),
        "disk_total_gb": round(usage.total / 1e9, 2),
        "disk_free_gb": round(usage.free / 1e9, 2),
        "torch": None,
        "torchvision": None,
        "timm": None,
        "pyiqa": None,
        "cuda_available": False,
        "cuda_version": None,
        "gpu_name": None,
    }
    try:
        import torch
        import torchvision

        info["torch"] = torch.__version__
        info["torchvision"] = torchvision.__version__
        info["cuda_available"] = bool(torch.cuda.is_available())
        info["cuda_version"] = getattr(torch.version, "cuda", None)
        if info["cuda_available"]:
            info["gpu_name"] = torch.cuda.get_device_name(0)
    except Exception as exc:  # pragma: no cover
        info["torch_error"] = str(exc)
    try:
        import timm

        info["timm"] = timm.__version__
    except Exception:
        info["timm"] = None
    try:
        import pyiqa

        info["pyiqa"] = getattr(pyiqa, "__version__", "installed_no_version")
        info["pyiqa_file"] = getattr(pyiqa, "__file__", None)
    except Exception:
        info["pyiqa"] = None
    return info


def collect_license_files() -> list[dict[str, str]]:
    try:
        import pyiqa
    except Exception:
        return []
    root = Path(pyiqa.__file__).resolve().parent
    candidates = [root / "LICENSE", root.parent / "LICENSE", root.parent / "LICENSE.md"]
    found: list[dict[str, str]] = []
    for path in candidates:
        if path.is_file():
            text = path.read_text(encoding="utf-8", errors="replace")
            found.append({"path": str(path), "head": text[:1200]})
    # pyproject / dist-info
    dist = root.parent
    for path in dist.glob("pyiqa-*.dist-info/METADATA"):
        text = path.read_text(encoding="utf-8", errors="replace")
        license_lines = [ln for ln in text.splitlines() if ln.lower().startswith("license")]
        found.append({"path": str(path), "head": "\n".join(license_lines[:20] + text.splitlines()[:30])})
    return found


def configure_cache(cache_dir: Path) -> dict[str, str]:
    cache_dir.mkdir(parents=True, exist_ok=True)
    torch_home = cache_dir / "torch"
    hf_home = cache_dir / "huggingface"
    torch_home.mkdir(parents=True, exist_ok=True)
    hf_home.mkdir(parents=True, exist_ok=True)
    os.environ["TORCH_HOME"] = str(torch_home)
    os.environ["HF_HOME"] = str(hf_home)
    os.environ["HUGGINGFACE_HUB_CACHE"] = str(hf_home / "hub")
    return {
        "TORCH_HOME": str(torch_home),
        "HF_HOME": str(hf_home),
        "cache_dir": str(cache_dir),
    }


def load_metric(device: str) -> tuple[Any, dict[str, Any]]:
    import pyiqa
    import torch

    t0 = time.perf_counter()
    metric = pyiqa.create_metric(METRIC_ID, device=device)
    load_s = time.perf_counter() - t0
    meta = {
        "metric_id": METRIC_ID,
        "device": device,
        "load_seconds": round(load_s, 3),
        "score_range": getattr(metric, "score_range", None),
        "lower_better": getattr(metric, "lower_better", None),
        "metric_mode": getattr(metric, "metric_mode", None),
        "pyiqa_version": getattr(pyiqa, "__version__", None),
        "net_class": type(getattr(metric, "net", metric)).__name__,
        "preprocess_note": (
            "pyiqa MUSIQ converts RGB tensors in [0,1] to [-1,1], then extracts multi-scale "
            "patches with longer_side_lengths=[224, 384] (native resolution retained as a scale). "
            "Do not resize to 224x224 the way EfficientNet-B0 production scoring does."
        ),
        "output_scale_note": (
            "pyiqa default_model_configs lists musiq-paq2piq score_range as '~0, ~100' "
            "(PaQ-2-PiQ / FLIVE MOS-like). This is not KonIQ ACR 1-5."
        ),
        "training_data_note": (
            "Checkpoint key pretrained='paq2piq' loads musiq_paq2piq_ckpt-364c0c84.pth. "
            "Trained on PaQ-2-PiQ/FLIVE, not KonIQ-10k. Default pyiqa id 'musiq' is KonIQ and was not used."
        ),
        "torch": torch.__version__,
        "cuda_available": bool(torch.cuda.is_available()),
    }
    net = getattr(metric, "net", None)
    if net is not None:
        opts = getattr(net, "data_preprocess_opts", None)
        if opts is not None:
            meta["data_preprocess_opts"] = opts
    return metric, meta


def find_checkpoint_files(cache_dir: Path) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    search_roots = [cache_dir, Path.home() / ".cache"]
    try:
        import pyiqa

        search_roots.append(Path(pyiqa.__file__).resolve().parent)
    except Exception:
        pass
    seen: set[Path] = set()
    for root in search_roots:
        if not root.exists():
            continue
        for path in root.rglob("*paq2piq*"):
            if not path.is_file():
                continue
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            hits.append(
                {
                    "path": str(resolved),
                    "size_bytes": resolved.stat().st_size,
                    "sha256": file_sha256(resolved),
                }
            )
        for path in root.rglob("*musiq_paq2piq*"):
            if not path.is_file():
                continue
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            hits.append(
                {
                    "path": str(resolved),
                    "size_bytes": resolved.stat().st_size,
                    "sha256": file_sha256(resolved),
                }
            )
    return hits


def score_image(metric: Any, image_path: Path) -> tuple[float | None, str | None]:
    try:
        out = metric(str(image_path))
        if hasattr(out, "detach"):
            value = float(out.detach().cpu().reshape(-1)[0].item())
        else:
            value = float(out)
        if not math.isfinite(value):
            return None, f"non_finite_score:{value}"
        return value, None
    except Exception as exc:
        return None, f"{type(exc).__name__}: {exc}"


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")


def assert_output_safe(output_dir: Path) -> None:
    resolved = output_dir.resolve()
    for protected in PROTECTED_OUTPUTS:
        if resolved == protected.resolve() or protected.resolve() in resolved.parents:
            raise SystemExit(f"Refusing to write inside protected baseline folder: {protected}")


def fmt(value: float | None, digits: int = 4) -> str:
    if value is None:
        return "N/A"
    return f"{value:.{digits}f}"


def build_markdown(report: dict[str, Any]) -> str:
    env = report["environment"]
    metric = report["metric"]
    musiq = report["musiq_vs_mos"]
    enet = report["efficientnet_vs_mos"]
    vs = report["musiq_vs_efficientnet"]
    dist = report["distributions"]
    overlap = report["overlap_and_limitations"]
    inf = report["inference"]
    return f"""# MUSIQ PaQ-2-PiQ experimental benchmark

Research-only comparison of pretrained **MUSIQ PaQ-2-PiQ** (`pyiqa` id `{METRIC_ID}`) against existing EfficientNet-B0 overall scores on the same 140 KonIQ-10k images from Run 001 (n=40) and Run 002 (n=100).

This is **not** a scientific validation of EfficientNet-B0, MUSIQ, or ACCESS VisionCheck. KonIQ MOS is an aggregate overall label. It is not the seven ACCESS technical criteria.

## Safeguards

- Production files were not modified (`media_evaluator.py`, `efficientnet_b0_scorer.py`, API, PostgreSQL, Flutter, React, PROBE, WaveRep, Gemini).
- Baseline CSVs and JPEGs were read-only.
- `pyiqa` was installed only in `tools/quality_validation/.venv_musiq_research`.
- No retraining, fine-tuning, or calibration fitted on these 140 images.
- Raw model outputs were saved before any error metric decision.

## Environment

| Item | Value |
|------|-------|
| Python | {env.get("python_version")} |
| Interpreter | `{env.get("python_executable")}` |
| Platform | {env.get("platform")} |
| torch | {env.get("torch")} |
| torchvision | {env.get("torchvision")} |
| timm | {env.get("timm") or "N/A"} |
| pyiqa | {env.get("pyiqa")} |
| CUDA | {env.get("cuda_available")} ({env.get("gpu_name") or "CPU-only"}) |
| Disk free at start | {env.get("disk_free_gb")} GB |

## Licensing (noncommercial)

- **pyiqa package:** {LICENSE_SUMMARY["pyiqa_package"]}
- **pyiqa weights:** {LICENSE_SUMMARY["pyiqa_weights"]}
- **PaQ-2-PiQ original:** {LICENSE_SUMMARY["paq2piq_dataset_and_original_code"]}
- **ACCESS implication:** {LICENSE_SUMMARY["access_use"]}

Installed license snippets are copied under the output folder (`license_files.json`).

## Model

| Item | Value |
|------|-------|
| Metric id | `{metric.get("metric_id")}` |
| Device | {metric.get("device")} |
| Load time | {metric.get("load_seconds")} s |
| Declared score_range | {metric.get("score_range")} |
| lower_better | {metric.get("lower_better")} |
| metric_mode | {metric.get("metric_mode")} |
| Checkpoint files | {json.dumps(report.get("checkpoints"), indent=2)} |

**Preprocessing:** {metric.get("preprocess_note")}

**Output scale:** {metric.get("output_scale_note")}

**Training overlap:** {metric.get("training_data_note")}

## Images

- Run 001: 40 files from `{RUN_001_IMAGES}` joined to `{RUN_001_CSV}`
- Run 002: 100 files from `{RUN_002_IMAGES}` joined to `{RUN_002_CSV}`
- Unique filenames: {report["n_requested"]}
- Successful MUSIQ scores: {inf.get("n_ok")}
- Failures: {inf.get("n_failed")} {inf.get("failures")}
- Mean inference time: {fmt(inf.get("mean_elapsed_ms"), 1)} ms
- Total inference time: {fmt(inf.get("total_elapsed_s"), 1)} s

## Score distributions

| Series | n | min | max | mean | stdev |
|--------|---|-----|-----|------|-------|
| KonIQ MOS (1-5) | {dist["mos"]["n"]} | {fmt(dist["mos"]["min"])} | {fmt(dist["mos"]["max"])} | {fmt(dist["mos"]["mean"])} | {fmt(dist["mos"]["stdev"])} |
| EfficientNet-B0 overall (1-5) | {dist["efficientnet"]["n"]} | {fmt(dist["efficientnet"]["min"])} | {fmt(dist["efficientnet"]["max"])} | {fmt(dist["efficientnet"]["mean"])} | {fmt(dist["efficientnet"]["stdev"])} |
| MUSIQ PaQ-2-PiQ raw | {dist["musiq_raw"]["n"]} | {fmt(dist["musiq_raw"]["min"])} | {fmt(dist["musiq_raw"]["max"])} | {fmt(dist["musiq_raw"]["mean"])} | {fmt(dist["musiq_raw"]["stdev"])} |

## Correlations (raw MUSIQ vs MOS)

Rank and linear association use **raw** MUSIQ outputs. No affine map was fitted on these images.

| Comparison | n | Pearson r | Pearson p | Spearman r | Spearman p | MAE | RMSE |
|------------|---|-----------|-----------|------------|------------|-----|------|
| MUSIQ raw vs KonIQ MOS | {musiq.get("n")} | {fmt(musiq.get("pearson_r"))} | {fmt(musiq.get("pearson_p"), 4)} | {fmt(musiq.get("spearman_r"))} | {fmt(musiq.get("spearman_p"), 4)} | {musiq.get("mae_display")} | {musiq.get("rmse_display")} |
| EfficientNet-B0 vs KonIQ MOS | {enet.get("n")} | {fmt(enet.get("pearson_r"))} | {fmt(enet.get("pearson_p"), 4)} | {fmt(enet.get("spearman_r"))} | {fmt(enet.get("spearman_p"), 4)} | {fmt(enet.get("mae"))} | {fmt(enet.get("rmse"))} |
| MUSIQ raw vs EfficientNet-B0 | {vs.get("n")} | {fmt(vs.get("pearson_r"))} | {fmt(vs.get("pearson_p"), 4)} | {fmt(vs.get("spearman_r"))} | {fmt(vs.get("spearman_p"), 4)} | {vs.get("mae_display")} | {vs.get("rmse_display")} |

MAE/RMSE vs MOS for MUSIQ: **{report["mae_rmse_policy"]}**

## By split

### Run 001 (n=40)

| Comparison | Pearson r | Spearman r | MAE | RMSE |
|------------|-----------|------------|-----|------|
| MUSIQ vs MOS | {fmt(report["by_run"]["run_001"]["musiq_vs_mos"].get("pearson_r"))} | {fmt(report["by_run"]["run_001"]["musiq_vs_mos"].get("spearman_r"))} | {report["by_run"]["run_001"]["musiq_vs_mos"].get("mae_display")} | {report["by_run"]["run_001"]["musiq_vs_mos"].get("rmse_display")} |
| EfficientNet vs MOS | {fmt(report["by_run"]["run_001"]["efficientnet_vs_mos"].get("pearson_r"))} | {fmt(report["by_run"]["run_001"]["efficientnet_vs_mos"].get("spearman_r"))} | {fmt(report["by_run"]["run_001"]["efficientnet_vs_mos"].get("mae"))} | {fmt(report["by_run"]["run_001"]["efficientnet_vs_mos"].get("rmse"))} |

### Run 002 (n=100)

| Comparison | Pearson r | Spearman r | MAE | RMSE |
|------------|-----------|------------|-----|------|
| MUSIQ vs MOS | {fmt(report["by_run"]["run_002"]["musiq_vs_mos"].get("pearson_r"))} | {fmt(report["by_run"]["run_002"]["musiq_vs_mos"].get("spearman_r"))} | {report["by_run"]["run_002"]["musiq_vs_mos"].get("mae_display")} | {report["by_run"]["run_002"]["musiq_vs_mos"].get("rmse_display")} |
| EfficientNet vs MOS | {fmt(report["by_run"]["run_002"]["efficientnet_vs_mos"].get("pearson_r"))} | {fmt(report["by_run"]["run_002"]["efficientnet_vs_mos"].get("spearman_r"))} | {fmt(report["by_run"]["run_002"]["efficientnet_vs_mos"].get("mae"))} | {fmt(report["by_run"]["run_002"]["efficientnet_vs_mos"].get("rmse"))} |

## Finding

{report["finding"]}

## Overlap and limitations

{overlap}

## Outputs

All new artifacts are under `{DEFAULT_OUTPUT}` and `tools/quality_validation/MUSIQ_EXPERIMENTAL_BENCHMARK.md`. Run 001/002 folders were not rewritten.

Generated at {report.get("generated_at")}.
"""


def pair_metrics(
    pred: list[float],
    target: list[float],
    *,
    comparable_for_error: bool,
) -> dict[str, Any]:
    corr = pearson_spearman(pred, target)
    out: dict[str, Any] = dict(corr)
    if comparable_for_error:
        err = mae_rmse(pred, target)
        out.update(err)
        out["mae_display"] = fmt(err["mae"])
        out["rmse_display"] = fmt(err["rmse"])
        out["error_metrics_computed"] = True
    else:
        out["mae"] = None
        out["rmse"] = None
        out["mae_display"] = "not comparable (scale)"
        out["rmse_display"] = "not comparable (scale)"
        out["error_metrics_computed"] = False
    return out


def run(*, output_dir: Path, device: str, limit: int | None = None) -> dict[str, Any]:
    assert_output_safe(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    cache_dir = output_dir / "cache"
    cache_env = configure_cache(cache_dir)
    env = probe_env()
    env["cache"] = cache_env
    write_json(output_dir / "environment.json", env)

    rows, errors = collect_eval_set()
    if limit is not None:
        rows = rows[:limit]
    if errors and limit is None:
        raise SystemExit("; ".join(errors))
    if env.get("pyiqa") is None:
        raise SystemExit("pyiqa is not importable in this interpreter. Use .venv_musiq_research.")

    license_files = collect_license_files()
    write_json(output_dir / "license_files.json", {"summary": LICENSE_SUMMARY, "files": license_files})

    metric, metric_meta = load_metric(device)
    write_json(output_dir / "metric_metadata.json", metric_meta)

    predictions: list[dict[str, Any]] = []
    failures: list[dict[str, str]] = []
    t_all = time.perf_counter()
    for row in rows:
        t0 = time.perf_counter()
        score, err = score_image(metric, Path(row["image_path"]))
        elapsed_ms = (time.perf_counter() - t0) * 1000
        rec = {
            **{k: row[k] for k in (
                "run_id",
                "media_id",
                "source_media_key",
                "image_path",
                "mos_quality_raw",
                "mos_scale",
                "overall_mapped_1_5",
                "efficientnet_overall",
                "efficientnet_status",
                "efficientnet_engine",
                "efficientnet_elapsed_ms",
            )},
            "musiq_metric_id": METRIC_ID,
            "musiq_raw_score": score,
            "musiq_status": "ok" if err is None else "failed",
            "musiq_error": err,
            "musiq_elapsed_ms": round(elapsed_ms, 3),
            "calibrated_1_5": None,
            "calibration_note": "none_fitted_on_eval_set",
        }
        predictions.append(rec)
        if err is not None:
            failures.append({"media_id": row["media_id"], "error": err})

    total_s = time.perf_counter() - t_all
    write_json(output_dir / "raw_predictions.json", {"results": predictions})
    write_csv(
        output_dir / "raw_predictions.csv",
        predictions,
        [
            "run_id",
            "media_id",
            "source_media_key",
            "mos_quality_raw",
            "overall_mapped_1_5",
            "efficientnet_overall",
            "musiq_raw_score",
            "musiq_status",
            "musiq_error",
            "musiq_elapsed_ms",
            "efficientnet_elapsed_ms",
            "calibrated_1_5",
            "image_path",
        ],
    )

    ok = [p for p in predictions if p["musiq_status"] == "ok" and p["musiq_raw_score"] is not None and p["mos_quality_raw"] is not None]
    musiq_raw = [float(p["musiq_raw_score"]) for p in ok]
    mos = [float(p["mos_quality_raw"]) for p in ok]
    enet = [float(p["efficientnet_overall"]) for p in ok if p["efficientnet_overall"] is not None]
    comparable = scores_on_comparable_1_5_scale(musiq_raw, str(metric_meta.get("score_range") or ""))
    mae_policy = (
        "computed against MOS 1-5 because raw predictions fell on a 1-5-like range"
        if comparable
        else "not computed: MUSIQ PaQ-2-PiQ raw scores are on a ~0-100 scale, not KonIQ MOS 1-5. No eval-set calibration was fitted."
    )

    musiq_vs_mos = pair_metrics(musiq_raw, mos, comparable_for_error=comparable)
    enet_ok = [p for p in ok if p["efficientnet_overall"] is not None]
    efficientnet_vs_mos = pair_metrics(
        [float(p["efficientnet_overall"]) for p in enet_ok],
        [float(p["mos_quality_raw"]) for p in enet_ok],
        comparable_for_error=True,
    )
    musiq_vs_enet = pair_metrics(
        [float(p["musiq_raw_score"]) for p in enet_ok],
        [float(p["efficientnet_overall"]) for p in enet_ok],
        comparable_for_error=False,
    )

    by_run: dict[str, Any] = {}
    for run_id in ("run_001", "run_002"):
        subset = [p for p in ok if p["run_id"] == run_id]
        by_run[run_id] = {
            "n": len(subset),
            "musiq_vs_mos": pair_metrics(
                [float(p["musiq_raw_score"]) for p in subset],
                [float(p["mos_quality_raw"]) for p in subset],
                comparable_for_error=comparable,
            ),
            "efficientnet_vs_mos": pair_metrics(
                [float(p["efficientnet_overall"]) for p in subset],
                [float(p["mos_quality_raw"]) for p in subset],
                comparable_for_error=True,
            ),
        }

    sr_m = musiq_vs_mos.get("spearman_r")
    sr_e = efficientnet_vs_mos.get("spearman_r")
    pr_m = musiq_vs_mos.get("pearson_r")
    pr_e = efficientnet_vs_mos.get("pearson_r")
    if sr_m is None or sr_e is None:
        finding = "Insufficient paired scores to compare rank correlation."
    elif sr_m > sr_e and (pr_m or 0) > (pr_e or 0):
        finding = (
            f"On this 140-image KonIQ subset, MUSIQ PaQ-2-PiQ raw scores track published MOS more closely "
            f"than EfficientNet-B0 overall (Spearman {sr_m:.3f} vs {sr_e:.3f}; Pearson {pr_m:.3f} vs {pr_e:.3f}). "
            "This is a cross-dataset NR-IQA check, not a production replacement, and not criterion-level accuracy."
        )
    elif sr_m <= sr_e:
        finding = (
            f"On this 140-image KonIQ subset, MUSIQ PaQ-2-PiQ did not beat EfficientNet-B0 on Spearman "
            f"({sr_m:.3f} vs {sr_e:.3f}). Pearson {pr_m} vs {pr_e}. "
            "Do not replace production scoring from this run."
        )
    else:
        finding = (
            f"Mixed: MUSIQ Spearman {sr_m:.3f} vs EfficientNet {sr_e:.3f}; "
            f"Pearson {pr_m} vs {pr_e}. Rank and linear agreement disagree. Do not replace production scoring."
        )

    checkpoints = find_checkpoint_files(cache_dir)
    inference = {
        "n_ok": len(ok),
        "n_failed": len(failures),
        "failures": failures,
        "mean_elapsed_ms": (sum(p["musiq_elapsed_ms"] for p in ok) / len(ok)) if ok else None,
        "total_elapsed_s": round(total_s, 3),
    }
    report = {
        "generated_at": _now_iso(),
        "disclaimer": "Not a scientific validation of EfficientNet-B0 or MUSIQ. KonIQ MOS is not ACCESS criterion ground truth.",
        "n_requested": len(rows),
        "environment": env,
        "metric": metric_meta,
        "checkpoints": checkpoints,
        "license": LICENSE_SUMMARY,
        "inference": inference,
        "distributions": {
            "mos": summarize(mos),
            "efficientnet": summarize(enet),
            "musiq_raw": summarize(musiq_raw),
        },
        "musiq_vs_mos": musiq_vs_mos,
        "efficientnet_vs_mos": efficientnet_vs_mos,
        "musiq_vs_efficientnet": musiq_vs_enet,
        "by_run": by_run,
        "mae_rmse_policy": mae_policy,
        "finding": finding,
        "overlap_and_limitations": (
            "The evaluated JPEGs are KonIQ-10k files. MUSIQ PaQ-2-PiQ was trained on PaQ-2-PiQ/FLIVE, not KonIQ, "
            "so this is a cross-dataset test (unlike default pyiqa `musiq`, which is KonIQ-trained and would leak). "
            "Flickr-source collision between FLIVE and KonIQ cannot be proven zero without a full ID join; it is not "
            "documented as a shared split. Run 001/002 were MOS-quintile samples, not the official KonIQ test split. "
            "EfficientNet overall is the mean of seven quantized 1-5 heads after `_soft_score`, not a MOS-trained head. "
            "n=140 is small. CPU-only inference. pyiqa is noncommercial."
        ),
        "errors_preflight": errors,
    }
    write_json(output_dir / "metrics.json", report)
    markdown = build_markdown(report)
    (output_dir / "MUSIQ_EXPERIMENTAL_BENCHMARK.md").write_text(markdown, encoding="utf-8")
    (_TOOLKIT / "MUSIQ_EXPERIMENTAL_BENCHMARK.md").write_text(markdown, encoding="utf-8")
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Experimental MUSIQ PaQ-2-PiQ benchmark (research only).")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--limit", type=int, default=None, help="Debug only: score the first N images.")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    result = run(output_dir=args.output_dir, device=args.device, limit=args.limit)
    print(json.dumps({"ok": result["inference"]["n_failed"] == 0, "n_ok": result["inference"]["n_ok"], "finding": result["finding"]}, indent=2))
