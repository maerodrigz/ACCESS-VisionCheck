#!/usr/bin/env python3
"""Compare official Google MUSIQ PaQ-2-PiQ (TF Hub) vs saved pyiqa raw scores.

Research-only. Does not import production media_evaluator, EfficientNet, PROBE,
WaveRep, Gemini, Flutter, React, or PostgreSQL. Does not write those trees.

Numerical-equivalence tolerances are declared in EQUIVALENCE_TOLERANCE *before*
scores are judged.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import platform
import random
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
DEFAULT_PYIQA_CSV = (
    _TOOLKIT
    / "workspace"
    / "datasets"
    / "koniq10k"
    / "musiq_paq2piq_benchmark"
    / "raw_predictions.csv"
)
DEFAULT_OUTPUT = (
    _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "official_musiq_engine_verification"
)

SAMPLE_N = 24
SAMPLE_SEED = "20261107_engine"
TFHUB_PAQ2PIQ = "https://tfhub.dev/google/musiq/paq2piq/1"
KAGGLE_PAQ2PIQ = "https://www.kaggle.com/models/google/musiq/TensorFlow2/paq2piq/1"
GCS_NPZ = "https://storage.googleapis.com/gresearch/musiq/paq2piq_ckpt.npz"

# Declared before any comparison. Scores are ~0-100 MOS-like.
EQUIVALENCE_TOLERANCE = {
    "pearson_min": 0.999,
    "spearman_min": 0.999,
    "mean_abs_diff_max": 0.50,
    "max_abs_diff_max": 2.0,
    "strict_max_abs_diff": 0.05,
    "required_success_rate": 1.0,
    "note": (
        "Primary: Pearson and Spearman vs pyiqa raw on the same files, plus mean/max "
        "absolute difference on the 0-100-like scale. Strict: float-noise only. "
        "Fail primary => engines are not interchangeable. Pass primary but fail strict "
        "=> same ranking, residual numeric offset (framework conversion)."
    ),
}

LICENSE_FINDINGS = {
    "google_research_source": (
        "google-research/google-research source files: Apache License 2.0 "
        "(repo LICENSE). musiq/*.py headers are Apache 2.0."
    ),
    "google_research_datasets_in_repo": (
        "Datasets *in that GitHub repo* are CC BY 4.0. MUSIQ training sets "
        "(PaQ-2-PiQ/FLIVE, KonIQ, SPAQ, AVA) are not those in-repo datasets."
    ),
    "gcs_npz": (
        "gs://gresearch/musiq/paq2piq_ckpt.npz (and siblings) have no LICENSE or NOTICE "
        "object in the bucket listing. Code Apache 2.0 does **not** automatically cover "
        "these weights. Production use of the npz is **not established**."
    ),
    "tfhub_paq2piq": (
        "TensorFlow Hub / Kaggle model google/musiq TensorFlow2/paq2piq/1 lists "
        "License: Apache 2.0. Output declared [0, 100]. This is the weights artifact "
        "used for this verification (SavedModel export of the paper checkpoint)."
    ),
    "paq2piq_training_data": (
        "baidut/PaQ-2-PiQ dataset/code is CC BY-NC-SA 4.0. That is a separate "
        "training-data term; it does not rewrite the TF Hub Apache label, but counsel "
        "should still review commercial use of a model trained on NC-SA data."
    ),
    "pyiqa": (
        "pyiqa 0.1.16 is PolyForm-Noncommercial; converted .pth weights treated as "
        "noncommercial. Not used as the official engine."
    ),
    "access": (
        "Research download/inference of the TF Hub Apache SavedModel is in scope. "
        "Do not copy the model into access_backend or ship it from this phase."
    ),
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


def abs_diff_stats(a: list[float], b: list[float]) -> dict[str, float | int | None]:
    if not a or len(a) != len(b):
        return {"n": len(a), "mean_abs_diff": None, "max_abs_diff": None, "rmse": None}
    diffs = [abs(x - y) for x, y in zip(a, b)]
    mse = sum((x - y) ** 2 for x, y in zip(a, b)) / len(a)
    return {
        "n": len(a),
        "mean_abs_diff": sum(diffs) / len(diffs),
        "max_abs_diff": max(diffs),
        "rmse": math.sqrt(mse),
    }


def judge_equivalence(corr: dict[str, Any], diffs: dict[str, Any], success_rate: float) -> dict[str, Any]:
    tol = EQUIVALENCE_TOLERANCE
    pr = corr.get("pearson_r")
    sr = corr.get("spearman_r")
    mad = diffs.get("mean_abs_diff")
    mx = diffs.get("max_abs_diff")
    primary = (
        success_rate >= tol["required_success_rate"]
        and pr is not None
        and sr is not None
        and mad is not None
        and mx is not None
        and float(pr) >= float(tol["pearson_min"])
        and float(sr) >= float(tol["spearman_min"])
        and float(mad) <= float(tol["mean_abs_diff_max"])
        and float(mx) <= float(tol["max_abs_diff_max"])
    )
    strict = primary and float(mx) <= float(tol["strict_max_abs_diff"])
    return {
        "primary_equivalent": bool(primary),
        "strict_float_equivalent": bool(strict),
        "tolerance": tol,
    }


def load_pyiqa_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    ok = []
    for row in rows:
        if str(row.get("musiq_status", "")).lower() != "ok":
            continue
        if not row.get("musiq_raw_score") or not row.get("image_path"):
            continue
        ok.append(row)
    return ok


def select_sample(rows: list[dict[str, str]], n: int, seed: str) -> list[dict[str, str]]:
    """Deterministic quintile sample of pyiqa raw scores."""
    scored = sorted(rows, key=lambda r: float(r["musiq_raw_score"]))
    if len(scored) <= n:
        return scored
    rng = random.Random(seed)
    bins: list[list[dict[str, str]]] = [[] for _ in range(5)]
    for i, row in enumerate(scored):
        bins[min(4, (i * 5) // len(scored))].append(row)
    per = n // 5
    extra = n - per * 5
    chosen: list[dict[str, str]] = []
    for i, bucket in enumerate(bins):
        take = per + (1 if i < extra else 0)
        take = min(take, len(bucket))
        chosen.extend(rng.sample(bucket, take))
    chosen.sort(key=lambda r: (r.get("run_id", ""), r.get("media_id", "")))
    return chosen


def probe_flax_npz_path() -> dict[str, Any]:
    """Record whether GitHub flax 0.3.3 run_predict_image can even import here."""
    out: dict[str, Any] = {
        "target": "google-research musiq/run_predict_image.py + paq2piq_ckpt.npz",
        "pinned_requirements": "flax==0.3.3, jax>=0.1.55, tensorflow (TF1 compat), ml-collections==0.1.0",
        "python": sys.version,
        "platform": platform.platform(),
    }
    try:
        import importlib.metadata as md

        out["installed"] = {
            "tensorflow": _pkg_version("tensorflow") or _pkg_version("tensorflow-cpu"),
            "jax": _pkg_version("jax"),
            "jaxlib": _pkg_version("jaxlib"),
            "flax": _pkg_version("flax"),
        }
        flax_ver = out["installed"].get("flax")
        out["flax_0_3_3_present"] = flax_ver == "0.3.3"
        if flax_ver and flax_ver != "0.3.3":
            out["compat"] = (
                "Modern Flax is installed or missing 0.3.3. Official run_predict_image "
                "uses flax.linen-pre Model.partial (Flax 0.3 nn API) and is not a drop-in "
                "on current Flax."
            )
        elif not flax_ver:
            out["compat"] = (
                "Flax not installed in this venv. Official npz runner was not executed. "
                "TF Hub SavedModel is the CPU path under test."
            )
        else:
            out["compat"] = "flax==0.3.3 present; npz runner still not invoked in this script."
    except Exception as exc:  # noqa: BLE001
        out["compat"] = f"probe failed: {exc}"
    out["windows_note"] = (
        "Historical jaxlib CPU wheels for flax 0.3.3 target old CPython. This host is "
        f"Python {platform.python_version()} on {platform.system()}."
    )
    return out


def _pkg_version(name: str) -> str | None:
    try:
        import importlib.metadata as md

        return md.version(name)
    except Exception:
        return None


def _scalar_from_hub(prediction: Any) -> float:
    if isinstance(prediction, dict):
        if "output_0" in prediction:
            tensor = prediction["output_0"]
        elif len(prediction) == 1:
            tensor = next(iter(prediction.values()))
        else:
            for key in ("mos", "predictions", "output", "outputs"):
                if key in prediction:
                    tensor = prediction[key]
                    break
            else:
                tensor = prediction[sorted(prediction.keys())[0]]
    else:
        tensor = prediction
    numpy = tensor.numpy() if hasattr(tensor, "numpy") else tensor
    import numpy as np

    arr = np.asarray(numpy, dtype=float).reshape(-1)
    if arr.size == 0:
        raise RuntimeError("empty official prediction")
    return float(arr[0])


def load_official_predict_fn() -> tuple[Any, str]:
    os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")
    import tensorflow as tf
    import tensorflow_hub as hub

    tf.config.set_visible_devices([], "GPU")
    last_err: Exception | None = None
    for handle in (TFHUB_PAQ2PIQ, KAGGLE_PAQ2PIQ):
        try:
            model = hub.load(handle)
            predict_fn = model.signatures["serving_default"]
            return predict_fn, handle
        except Exception as exc:  # noqa: BLE001
            last_err = exc
    raise RuntimeError(f"Could not load official MUSIQ PaQ-2-PiQ SavedModel: {last_err}")


def score_jpeg(predict_fn: Any, image_path: Path) -> float:
    import tensorflow as tf

    raw = image_path.read_bytes()
    if not raw:
        raise RuntimeError(f"empty file: {image_path}")
    prediction = predict_fn(tf.constant(raw))
    return _scalar_from_hub(prediction)


def write_report_md(path: Path, payload: dict[str, Any]) -> None:
    eq = payload["equivalence"]
    corr = payload["correlations"]
    diffs = payload["differences"]
    inf = payload["inference"]
    env = payload["environment"]
    lines = [
        "# Official MUSIQ engine verification",
        "",
        "**Status:** research comparison of official Google MUSIQ PaQ-2-PiQ vs saved pyiqa raw scores.",
        "This is **not** production integration, not EfficientNet validation, and not criterion accuracy.",
        "",
        f"Generated: {payload['generated_at']}",
        f"Artifacts: `{payload['output_dir']}`",
        "",
        "## 1. Licensing (weights vs code)",
        "",
    ]
    for key, text in LICENSE_FINDINGS.items():
        lines.append(f"- **{key}:** {text}")
    lines += [
        "",
        "Production FastAPI was not modified. The TF Hub model was not copied into `access_backend/`.",
        "",
        "## 2. Official engine under test",
        "",
        f"- Handle: `{payload.get('model_handle', '')}`",
        f"- GitHub flax+npz runner: {payload['flax_probe'].get('compat', '')}",
        f"- Preprocess: TF Hub SavedModel takes **raw JPEG/PNG bytes** (no extra resize in this script).",
        "- pyiqa research path: RGB [0,1] → [-1,1], patches 32, longer sides [224, 384], native res.",
        "",
        "## 3. Sample",
        "",
        f"- Source CSV (read-only): `{payload['pyiqa_csv']}`",
        f"- n = {payload['sample']['n']}, seed = `{payload['sample']['seed']}`",
        "- Images: existing KonIQ JPEGs from Phase 2 (not LIVEC).",
        "",
        "## 4. Declared tolerance (before judging)",
        "",
        f"- Pearson ≥ {EQUIVALENCE_TOLERANCE['pearson_min']}",
        f"- Spearman ≥ {EQUIVALENCE_TOLERANCE['spearman_min']}",
        f"- mean |diff| ≤ {EQUIVALENCE_TOLERANCE['mean_abs_diff_max']}",
        f"- max |diff| ≤ {EQUIVALENCE_TOLERANCE['max_abs_diff_max']}",
        f"- strict max |diff| ≤ {EQUIVALENCE_TOLERANCE['strict_max_abs_diff']}",
        f"- success rate ≥ {EQUIVALENCE_TOLERANCE['required_success_rate']}",
        "",
        "## 5. Environment",
        "",
        f"- Python: {env.get('python')}",
        f"- tensorflow: {env.get('tensorflow')}",
        f"- tensorflow-hub: {env.get('tensorflow_hub')}",
        f"- Device: {env.get('device')}",
        f"- Platform: {env.get('platform')}",
        "",
        "## 6. Inference",
        "",
        f"- Official ok: **{inf['official_ok']} / {inf['n']}**",
        f"- Failures: **{inf['failures']}**",
        f"- Mean CPU time: **{inf.get('mean_ms_per_image')}** ms/image",
        "",
        "## 7. Distributions",
        "",
        "| Series | n | min | max | mean |",
        "|--------|--:|----:|----:|-----:|",
        f"| pyiqa raw | {payload['dist']['pyiqa']['n']} | {payload['dist']['pyiqa']['min']:.4f} | {payload['dist']['pyiqa']['max']:.4f} | {payload['dist']['pyiqa']['mean']:.4f} |",
        f"| official raw | {payload['dist']['official']['n']} | {payload['dist']['official']['min']:.4f} | {payload['dist']['official']['max']:.4f} | {payload['dist']['official']['mean']:.4f} |",
        "",
        "## 8. Equivalence vs pyiqa",
        "",
        f"- Pearson: **{corr.get('pearson_r')}**",
        f"- Spearman: **{corr.get('spearman_r')}**",
        f"- mean |diff|: **{diffs.get('mean_abs_diff')}**",
        f"- max |diff|: **{diffs.get('max_abs_diff')}**",
        f"- RMSE: **{diffs.get('rmse')}**",
        f"- Primary equivalent: **{eq['primary_equivalent']}**",
        f"- Strict float equivalent: **{eq['strict_float_equivalent']}**",
        "",
        "## 9. Production",
        "",
        "- FastAPI, EfficientNet-B0, seven criteria, overall_score, XP, Flutter, React, PROBE, WaveRep, Gemini: unchanged.",
        "- Official engine was **not** deployed.",
        "",
        "Stopped for review.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pyiqa-csv", type=Path, default=DEFAULT_PYIQA_CSV)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--n", type=int, default=SAMPLE_N)
    parser.add_argument("--seed", type=str, default=SAMPLE_SEED)
    parser.add_argument("--limit", type=int, default=0, help="optional cap after sampling (tests)")
    args = parser.parse_args()

    out_dir = args.output_dir.resolve()
    cache_dir = out_dir / "cache" / "tfhub"
    cache_dir.mkdir(parents=True, exist_ok=True)
    os.environ["TFHUB_CACHE_DIR"] = str(cache_dir)

    pyiqa_csv = args.pyiqa_csv.resolve()
    if not pyiqa_csv.is_file():
        print(f"STOP: missing pyiqa predictions: {pyiqa_csv}", file=sys.stderr)
        return 2

    rows = load_pyiqa_rows(pyiqa_csv)
    sample = select_sample(rows, args.n, args.seed)
    if args.limit:
        sample = sample[: args.limit]
    if not sample:
        print("STOP: empty sample", file=sys.stderr)
        return 2

    flax_probe = probe_flax_npz_path()
    load_t0 = time.perf_counter()
    predict_fn, handle = load_official_predict_fn()
    load_ms = (time.perf_counter() - load_t0) * 1000.0

    predictions: list[dict[str, Any]] = []
    official_ok = 0
    times: list[float] = []
    for row in sample:
        image_path = Path(row["image_path"])
        rec: dict[str, Any] = {
            "run_id": row.get("run_id"),
            "media_id": row.get("media_id"),
            "source_media_key": row.get("source_media_key"),
            "image_path": str(image_path),
            "pyiqa_raw": float(row["musiq_raw_score"]),
            "official_raw": None,
            "abs_diff": None,
            "status": "error",
            "error": None,
            "elapsed_ms": None,
        }
        t0 = time.perf_counter()
        try:
            if not image_path.is_file():
                raise FileNotFoundError(str(image_path))
            score = score_jpeg(predict_fn, image_path)
            rec["official_raw"] = score
            rec["abs_diff"] = abs(score - rec["pyiqa_raw"])
            rec["status"] = "ok"
            official_ok += 1
        except Exception as exc:  # noqa: BLE001
            rec["error"] = f"{type(exc).__name__}: {exc}"
        rec["elapsed_ms"] = (time.perf_counter() - t0) * 1000.0
        times.append(float(rec["elapsed_ms"]))
        predictions.append(rec)
        print(
            f"{rec['media_id']} pyiqa={rec['pyiqa_raw']:.4f} official={rec['official_raw']} "
            f"status={rec['status']} {rec['elapsed_ms']:.0f}ms",
            flush=True,
        )

    paired = [p for p in predictions if p["status"] == "ok" and p["official_raw"] is not None]
    py = [float(p["pyiqa_raw"]) for p in paired]
    of = [float(p["official_raw"]) for p in paired]
    corr = pearson_spearman(py, of)
    diffs = abs_diff_stats(py, of)
    success_rate = official_ok / len(predictions) if predictions else 0.0
    equivalence = judge_equivalence(corr, diffs, success_rate)

    def _dist(xs: list[float]) -> dict[str, float | int]:
        return {
            "n": len(xs),
            "min": min(xs) if xs else float("nan"),
            "max": max(xs) if xs else float("nan"),
            "mean": (sum(xs) / len(xs)) if xs else float("nan"),
        }

    payload = {
        "generated_at": _now_iso(),
        "output_dir": str(out_dir),
        "pyiqa_csv": str(pyiqa_csv),
        "model_handle": handle,
        "gcs_npz_not_used": GCS_NPZ,
        "license": LICENSE_FINDINGS,
        "flax_probe": flax_probe,
        "sample": {"n": len(sample), "seed": args.seed, "pool": len(rows)},
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
            "mean_ms_per_image": (sum(times) / len(times)) if times else None,
        },
        "dist": {"pyiqa": _dist(py), "official": _dist(of)},
        "correlations": corr,
        "differences": diffs,
        "equivalence": equivalence,
        "predictions": predictions,
    }

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "metrics.json").write_text(json.dumps({k: payload[k] for k in payload if k != "predictions"}, indent=2, default=str), encoding="utf-8")
    (out_dir / "raw_predictions.json").write_text(json.dumps(predictions, indent=2), encoding="utf-8")
    with (out_dir / "raw_predictions.csv").open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(
            fh,
            fieldnames=[
                "run_id",
                "media_id",
                "source_media_key",
                "image_path",
                "pyiqa_raw",
                "official_raw",
                "abs_diff",
                "status",
                "error",
                "elapsed_ms",
            ],
        )
        w.writeheader()
        w.writerows(predictions)
    (out_dir / "equivalence_tolerance.json").write_text(json.dumps(EQUIVALENCE_TOLERANCE, indent=2), encoding="utf-8")
    write_report_md(out_dir / "OFFICIAL_MUSIQ_ENGINE_VERIFICATION.md", payload)
    toolkit_report = _TOOLKIT / "OFFICIAL_MUSIQ_ENGINE_VERIFICATION.md"
    toolkit_report.write_text((out_dir / "OFFICIAL_MUSIQ_ENGINE_VERIFICATION.md").read_text(encoding="utf-8"), encoding="utf-8")
    print(json.dumps({"primary_equivalent": equivalence["primary_equivalent"], "n": official_ok, "handle": handle}, indent=2))
    return 0 if official_ok == len(predictions) else 1


if __name__ == "__main__":
    raise SystemExit(main())
