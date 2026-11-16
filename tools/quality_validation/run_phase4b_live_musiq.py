#!/usr/bin/env python3
"""Phase 4B live MUSIQ-only scoring on the frozen independent holdout.

Research-only. Uses the official TF Hub PaQ-2-PiQ SavedModel via musiq_opq.
Does not overwrite machine_scores.csv, human packs, or the freeze manifest.
Does not substitute historical MUSIQ CSV scores. Does not touch production.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
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
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, str(_TOOLKIT), str(_REPO)):
    p = str(path)
    if p not in sys.path:
        sys.path.insert(0, p)

DEFAULT_MANIFEST = _TOOLKIT / "workspace" / "phase4a_indval" / "holdout_manifest.csv"
DEFAULT_CACHE = (
    _TOOLKIT
    / "workspace"
    / "datasets"
    / "koniq10k"
    / "official_musiq_engine_verification"
    / "cache"
    / "tfhub"
)
FREEZE = _TOOLKIT / "phase4a_freeze_manifest.json"
MODEL_DIR_NAME = "a5e1c51ceccb5074aa6e1ed774b7ba4f4c79bbee"
EXPECTED_HANDLE = "https://tfhub.dev/google/musiq/paq2piq/1"


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    keys: list[str] = []
    for row in rows:
        for k in row:
            if k not in keys:
                keys.append(k)
    with path.open("w", newline="", encoding="utf-8") as handle:
        w = csv.DictWriter(handle, fieldnames=keys)
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k, "") for k in keys})


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _artifact_inventory(cache_dir: Path) -> dict[str, Any]:
    model_dir = cache_dir / MODEL_DIR_NAME
    files: dict[str, Any] = {}
    if model_dir.is_dir():
        for path in sorted(model_dir.rglob("*")):
            if path.is_file():
                rel = str(path.relative_to(cache_dir)).replace("\\", "/")
                files[rel] = {
                    "bytes": path.stat().st_size,
                    "sha256": _sha256_file(path),
                }
    descriptor = cache_dir / f"{MODEL_DIR_NAME}.descriptor.txt"
    return {
        "tfhub_cache_dir": str(cache_dir),
        "model_dir_present": model_dir.is_dir(),
        "descriptor": descriptor.read_text(encoding="utf-8", errors="replace")
        if descriptor.is_file()
        else None,
        "files": files,
    }


def _env_probe() -> dict[str, Any]:
    import importlib.util

    info: dict[str, Any] = {
        "python": sys.version,
        "executable": sys.executable,
        "platform": platform.platform(),
        "tensorflow_spec": bool(importlib.util.find_spec("tensorflow")),
        "tensorflow_hub_spec": bool(importlib.util.find_spec("tensorflow_hub")),
    }
    try:
        import numpy as np

        info["numpy"] = np.__version__
    except Exception as exc:  # noqa: BLE001
        info["numpy_error"] = str(exc)
    try:
        import tensorflow as tf

        info["tensorflow"] = tf.__version__
    except Exception as exc:  # noqa: BLE001
        info["tensorflow_error"] = str(exc)
    try:
        import tensorflow_hub as hub

        info["tensorflow_hub"] = hub.__version__
    except Exception as exc:  # noqa: BLE001
        info["tensorflow_hub_error"] = str(exc)
    return info


def _score_one(content: bytes, cache_dir: Path) -> dict[str, Any]:
    from app.services.quality_shadow.musiq_opq import score_image_bytes_musiq

    return score_image_bytes_musiq(content, tfhub_cache_dir=str(cache_dir))


def _smoke(rows: list[dict[str, str]], cache_dir: Path, out_dir: Path) -> dict[str, Any]:
    from app.services.quality_shadow.musiq_opq import reset_musiq_loader_for_tests

    reset_musiq_loader_for_tests()
    sample = rows[:3]
    results: list[dict[str, Any]] = []
    for row in sample:
        path = Path(row["path"])
        content = path.read_bytes()
        t0 = time.perf_counter()
        first = _score_one(content, cache_dir)
        t1 = time.perf_counter()
        second = _score_one(content, cache_dir)
        t2 = time.perf_counter()
        s1 = first.get("musiq_opq_raw")
        s2 = second.get("musiq_opq_raw")
        finite = (
            isinstance(s1, (int, float))
            and isinstance(s2, (int, float))
            and math.isfinite(float(s1))
            and math.isfinite(float(s2))
        )
        # Scalar MOS-like output: treat as shape () / length-1
        shape_ok = first.get("status") == "ok" and finite
        deterministic = shape_ok and float(s1) == float(s2)
        rec = {
            "indval_id": row["indval_id"],
            "source_media_key": row.get("source_media_key"),
            "path": str(path),
            "pass1": first,
            "pass2": second,
            "pass1_ms": round((t1 - t0) * 1000.0, 3),
            "pass2_ms": round((t2 - t1) * 1000.0, 3),
            "finite": finite,
            "shape_ok_scalar": shape_ok,
            "deterministic_repeat": deterministic,
            "smoke_pass": bool(
                first.get("status") == "ok"
                and second.get("status") == "ok"
                and finite
                and deterministic
                and first.get("engine_handle") == EXPECTED_HANDLE
            ),
        }
        results.append(rec)
        print(
            f"[SMOKE] {row['indval_id']} status={first.get('status')} "
            f"s1={s1} s2={s2} det={deterministic}",
            flush=True,
        )

    summary = {
        "n": len(results),
        "all_pass": all(r["smoke_pass"] for r in results),
        "results": results,
    }
    (out_dir / "smoke_test_3.json").write_text(
        json.dumps(summary, indent=2, default=str), encoding="utf-8"
    )
    return summary


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    ap.add_argument(
        "--output-root",
        type=Path,
        default=_TOOLKIT / "workspace" / "phase4a_indval" / "machine_output",
    )
    ap.add_argument("--tfhub-cache", type=Path, default=DEFAULT_CACHE)
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--smoke-only", action="store_true")
    ap.add_argument(
        "--run-tag",
        type=str,
        default=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
    )
    args = ap.parse_args()

    if not args.manifest.is_file():
        raise SystemExit(f"Missing holdout manifest: {args.manifest}")

    freeze = json.loads(FREEZE.read_text(encoding="utf-8")) if FREEZE.is_file() else {}
    freeze_id = freeze.get("freeze_id")
    out_dir = args.output_root / f"musiq_live_{args.run_tag}"
    out_dir.mkdir(parents=True, exist_ok=True)

    os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")
    os.environ["TFHUB_CACHE_DIR"] = str(args.tfhub_cache)

    env = _env_probe()
    artifacts = _artifact_inventory(args.tfhub_cache)
    meta: dict[str, Any] = {
        "started_at_utc": datetime.now(timezone.utc).isoformat(),
        "freeze_id": freeze_id,
        "protocol": "phase4b_live_musiq_restore",
        "manifest": str(args.manifest),
        "output_dir": str(out_dir),
        "preserves_machine_scores_csv": True,
        "cached_musiq_csv_used": False,
        "model_handle_expected": EXPECTED_HANDLE,
        "model_id": "tfhub:google/musiq/paq2piq/1",
        "environment": env,
        "local_model_artifact": artifacts,
        "license_notes": {
            "tfhub_paq2piq": (
                "TensorFlow Hub / Kaggle model google/musiq TensorFlow2/paq2piq/1 "
                "lists License: Apache 2.0. Output declared [0, 100]."
            ),
            "paq2piq_training_data": (
                "baidut/PaQ-2-PiQ dataset/code is CC BY-NC-SA 4.0 (training-data term; "
                "counsel should review commercial use)."
            ),
            "access": (
                "Research inference of the TF Hub Apache SavedModel only. "
                "Do not ship weights into production."
            ),
        },
        "quality_shadow_enabled_unchanged": True,
        "note": "Live MUSIQ only. Human ratings not generated. Validation not complete.",
    }
    (out_dir / "env_and_artifact_probe.json").write_text(
        json.dumps({"environment": env, "local_model_artifact": artifacts}, indent=2),
        encoding="utf-8",
    )

    if not env.get("tensorflow_spec") or not env.get("tensorflow_hub_spec"):
        meta["blocker"] = (
            "MUSIQ runtime unavailable: tensorflow / tensorflow_hub not installed "
            "in this environment"
        )
        meta["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
        (out_dir / "run_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
        print(meta["blocker"], flush=True)
        return 2

    rows = _read_csv(args.manifest)
    if args.limit is not None:
        rows = rows[: args.limit]

    smoke = _smoke(rows, args.tfhub_cache, out_dir)
    meta["smoke"] = {
        "n": smoke["n"],
        "all_pass": smoke["all_pass"],
        "scores": [
            {
                "indval_id": r["indval_id"],
                "musiq_opq_raw": (r["pass1"] or {}).get("musiq_opq_raw"),
                "smoke_pass": r["smoke_pass"],
            }
            for r in smoke["results"]
        ],
    }
    if not smoke["all_pass"]:
        meta["blocker"] = "Three-image smoke test failed; refusing full holdout run"
        meta["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
        (out_dir / "run_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
        print(meta["blocker"], flush=True)
        return 3

    if args.smoke_only:
        meta["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
        meta["n_musiq_ok"] = sum(1 for r in smoke["results"] if r["smoke_pass"])
        (out_dir / "run_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
        print(f"[MUSIQ] smoke-only complete -> {out_dir}", flush=True)
        return 0

    per_image: list[dict[str, Any]] = []
    for row in rows:
        indval = row["indval_id"]
        path = Path(row["path"])
        print(f"[MUSIQ] {indval} {path.name}", flush=True)
        t0 = time.perf_counter()
        rec: dict[str, Any] = {
            "indval_id": indval,
            "source_media_key": row.get("source_media_key"),
            "pool": row.get("pool"),
            "file_sha256": row.get("file_sha256"),
            "path": str(path),
            "freeze_id": freeze_id,
            "cached_musiq_csv_used": False,
        }
        if not path.is_file():
            rec["musiq_status"] = "error"
            rec["musiq_error"] = "image_not_found"
            per_image.append(rec)
            continue
        content = path.read_bytes()
        try:
            result = _score_one(content, args.tfhub_cache)
            rec["musiq_status"] = result.get("status")
            rec["musiq_opq_raw"] = result.get("musiq_opq_raw")
            rec["musiq_scale"] = result.get("musiq_scale")
            rec["musiq_model_id"] = result.get("model_id")
            rec["musiq_engine_handle"] = result.get("engine_handle")
            rec["musiq_error"] = result.get("error")
            score = result.get("musiq_opq_raw")
            rec["musiq_finite"] = (
                isinstance(score, (int, float)) and math.isfinite(float(score))
            )
        except Exception as exc:  # noqa: BLE001
            rec["musiq_status"] = "error"
            rec["musiq_error"] = str(exc)
        rec["elapsed_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
        per_image.append(rec)

    _write_csv(out_dir / "musiq_live_scores.csv", per_image)
    meta["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
    meta["n_target"] = len(rows)
    meta["n_scored"] = len(per_image)
    meta["n_musiq_ok"] = sum(1 for r in per_image if r.get("musiq_status") == "ok")
    meta["n_musiq_unavailable"] = sum(
        1 for r in per_image if r.get("musiq_status") == "unavailable"
    )
    meta["n_musiq_error"] = sum(1 for r in per_image if r.get("musiq_status") == "error")
    (out_dir / "run_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(
        f"[MUSIQ] live scores -> {out_dir} ok={meta['n_musiq_ok']}/{meta['n_scored']}",
        flush=True,
    )
    return 0 if meta["n_musiq_ok"] == meta["n_scored"] else 4


if __name__ == "__main__":
    raise SystemExit(main())
