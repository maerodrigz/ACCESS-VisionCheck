#!/usr/bin/env python3
"""Independent MUSIQ PaQ-2-PiQ evaluation on LIVE Challenge test images.

Research-only. Does not import production scoring, PROBE, WaveRep, Gemini, or DB.
Does not train, fine-tune, or fit calibration on LIVEC.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image
from scipy.io import loadmat

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
if str(_REPO) not in sys.path:
    sys.path.insert(0, str(_REPO))

from tools.quality_validation.musiq_paq2piq_benchmark import (  # noqa: E402
    LICENSE_SUMMARY,
    METRIC_ID,
    configure_cache,
    file_sha256,
    find_checkpoint_files,
    fmt,
    load_metric,
    mae_rmse,
    pair_metrics,
    pearson_spearman,
    probe_env,
    score_image,
    scores_on_comparable_1_5_scale,
    summarize,
    write_csv,
    write_json,
    _now_iso,
)

LIVEC_ROOT_CANDIDATES = (
    _TOOLKIT / "workspace" / "datasets" / "livec" / "ChallengeDB_release",
    _TOOLKIT / "workspace" / "datasets" / "livec",
    _TOOLKIT / "workspace" / "datasets" / "live_vqc" / "ChallengeDB_release",
)
EXISTING_CKPT = (
    _TOOLKIT
    / "workspace"
    / "datasets"
    / "koniq10k"
    / "musiq_paq2piq_benchmark"
    / "cache"
    / "torch"
    / "hub"
    / "pyiqa"
    / "musiq_paq2piq_ckpt-364c0c84.pth"
)
DEFAULT_OUTPUT = _TOOLKIT / "workspace" / "datasets" / "livec" / "output" / "run_livec_001"
EXPECTED_TEST_N = 1162
EXPECTED_TRAIN_N = 7


def find_livec_root() -> Path:
    for cand in LIVEC_ROOT_CANDIDATES:
        if (cand / "Data" / "AllMOS_release.mat").is_file() and (cand / "Images").is_dir():
            return cand
        nested = cand / "ChallengeDB_release"
        if (nested / "Data" / "AllMOS_release.mat").is_file():
            return nested
    raise SystemExit("LIVE Challenge release not found. Expected ChallengeDB_release with Data/ and Images/.")


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


def load_official_rows(root: Path) -> list[dict[str, Any]]:
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
                "mos_quality_raw": float(score),
                "split": split,
                "image_path": str(path) if path else None,
            }
        )
    return rows


def integrity_check(root: Path, rows: list[dict[str, Any]]) -> dict[str, Any]:
    test = [r for r in rows if r["split"] == "test"]
    train = [r for r in rows if r["split"] == "subject_training"]
    images_dir = root / "Images"
    disk_test = [
        p
        for p in images_dir.iterdir()
        if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".bmp", ".png"}
    ]
    missing = [r["source_media_key"] for r in rows if not r["image_path"]]
    unreadable: list[dict[str, str]] = []
    for rec in rows:
        path = Path(rec["image_path"]) if rec["image_path"] else None
        if path is None:
            continue
        try:
            with Image.open(path) as im:
                im.verify()
        except Exception as exc:
            unreadable.append({"name": rec["source_media_key"], "error": str(exc)})
    mos_vals = np.array([r["mos_quality_raw"] for r in test], dtype=float)
    mapped_names = {Path(r["source_media_key"]).name.lower() for r in test}
    extra = [p.name for p in disk_test if p.name.lower() not in mapped_names]
    readme = root / "README.txt"
    errors: list[str] = []
    if len(test) != EXPECTED_TEST_N:
        errors.append(f"test count {len(test)} != {EXPECTED_TEST_N}")
    if len(train) != EXPECTED_TRAIN_N:
        errors.append(f"training count {len(train)} != {EXPECTED_TRAIN_N}")
    if missing:
        errors.append(f"missing files: {missing[:8]}")
    if unreadable:
        errors.append(f"unreadable: {unreadable[:4]}")
    if extra:
        errors.append(f"extra disk files: {extra[:8]}")
    if not np.isfinite(mos_vals).all():
        errors.append("non-finite MOS")
    return {
        "root": str(root),
        "readme": str(readme) if readme.is_file() else None,
        "n_mat": len(rows),
        "n_test": len(test),
        "n_subject_training": len(train),
        "n_disk_test": len(disk_test),
        "missing_files": missing,
        "unreadable": unreadable,
        "extra_on_disk": extra,
        "train_names": [r["source_media_key"] for r in train],
        "mos_test": summarize(list(mos_vals)),
        "copyright_notice_present": bool(readme.is_file() and "COPYRIGHT NOTICE" in readme.read_text(encoding="utf-8", errors="replace")),
        "errors": errors,
        "ok": not errors,
    }


def scales_comparable_0_100(pred: list[float], mos: list[float], declared_range: str | None) -> bool:
    if not pred or not mos:
        return False
    declared = (declared_range or "").replace(" ", "").lower()
    if scores_on_comparable_1_5_scale(pred, declared_range):
        return False
    if min(pred) < -1 or max(pred) > 101 or min(mos) < -1 or max(mos) > 101:
        return False
    if "~0,~100" not in declared and declared not in {"0,100", "~0,~100"}:
        if not (0 <= min(pred) and max(pred) <= 100):
            return False
    pred_span = max(pred) - min(pred)
    mos_span = max(mos) - min(mos)
    if mos_span > 0 and pred_span < 0.4 * mos_span:
        return False
    return True


def copy_checkpoint_into_cache(cache_dir: Path) -> None:
    dest_dir = cache_dir / "torch" / "hub" / "pyiqa"
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / EXISTING_CKPT.name
    if EXISTING_CKPT.is_file() and not dest.is_file():
        dest.write_bytes(EXISTING_CKPT.read_bytes())


def koniq_overlap(test_rows: list[dict[str, Any]]) -> dict[str, Any]:
    csvs = [
        _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "metadata" / "output" / "run_001" / "per_image_results.csv",
        _TOOLKIT / "workspace" / "datasets" / "koniq10k" / "run_002" / "output" / "per_image_results.csv",
    ]
    names: set[str] = set()
    hashes: dict[str, str] = {}
    import csv as csvmod

    for path in csvs:
        if not path.is_file():
            continue
        with path.open(newline="", encoding="utf-8") as handle:
            for rec in csvmod.DictReader(handle):
                names.add(rec["source_media_key"].lower())
                if rec.get("file_sha256"):
                    hashes[rec["file_sha256"]] = rec["source_media_key"]
    name_hits = [r["source_media_key"] for r in test_rows if r["source_media_key"].lower() in names]
    hash_hits = []
    for rec in test_rows:
        p = rec.get("image_path")
        if not p:
            continue
        digest = file_sha256(Path(p))
        rec["file_sha256"] = digest
        if digest in hashes:
            hash_hits.append({"livec": rec["source_media_key"], "koniq": hashes[digest]})
    return {
        "koniq_filename_overlap": name_hits,
        "koniq_sha256_overlap": hash_hits,
        "flive_join": "FLIVE/PaQ-2-PiQ training IDs are not on disk; filename/hash join against FLIVE was not possible.",
    }


def run(*, output_dir: Path, device: str, limit: int | None = None) -> dict[str, Any]:
    root = find_livec_root()
    output_dir.mkdir(parents=True, exist_ok=True)
    rows = load_official_rows(root)
    integrity = integrity_check(root, rows)
    write_json(output_dir / "integrity.json", integrity)
    readme_src = root / "README.txt"
    if readme_src.is_file():
        (output_dir / "LIVE_CHALLENGE_README.copied.txt").write_bytes(readme_src.read_bytes())
        meta_dir = _TOOLKIT / "workspace" / "datasets" / "livec" / "metadata"
        meta_dir.mkdir(parents=True, exist_ok=True)
        dest_readme = meta_dir / "README.txt"
        if not dest_readme.exists():
            dest_readme.write_bytes(readme_src.read_bytes())
    if not integrity["ok"]:
        raise SystemExit("Integrity failed: " + "; ".join(integrity["errors"]))

    test_rows = [r for r in rows if r["split"] == "test"]
    overlap = koniq_overlap(test_rows)
    write_json(output_dir / "overlap.json", overlap)
    if limit is not None:
        test_rows = test_rows[:limit]

    env = probe_env()
    if env.get("pyiqa") is None:
        raise SystemExit("pyiqa missing. Use tools/quality_validation/.venv_musiq_research.")
    cache_dir = output_dir / "cache"
    cache_env = configure_cache(cache_dir)
    copy_checkpoint_into_cache(cache_dir)
    env["cache"] = cache_env
    write_json(output_dir / "environment.json", env)

    metric, metric_meta = load_metric(device)
    metric_meta["training_data_note"] = (
        "pretrained='paq2piq' / musiq_paq2piq_ckpt-364c0c84.pth trained on PaQ-2-PiQ/FLIVE. "
        "LIVEC is a cross-dataset holdout, not listed as MUSIQ training data."
    )
    write_json(output_dir / "metric_metadata.json", metric_meta)

    predictions: list[dict[str, Any]] = []
    failures: list[dict[str, str]] = []
    t_all = time.perf_counter()
    for rec in test_rows:
        t0 = time.perf_counter()
        score, err = score_image(metric, Path(rec["image_path"]))
        elapsed_ms = (time.perf_counter() - t0) * 1000
        row = {
            "media_id": f"LIVEC-{rec['index']:04d}",
            "source_media_key": rec["source_media_key"],
            "split": "test",
            "mos_quality_raw": rec["mos_quality_raw"],
            "mos_scale_observed": "continuous_approx_0_100",
            "musiq_metric_id": METRIC_ID,
            "musiq_raw_score": score,
            "musiq_status": "ok" if err is None else "failed",
            "musiq_error": err,
            "musiq_elapsed_ms": round(elapsed_ms, 3),
            "calibrated_1_5": None,
            "calibration_note": "none_fitted_on_livec",
            "image_path": rec["image_path"],
            "file_sha256": rec.get("file_sha256"),
        }
        predictions.append(row)
        if err is not None:
            failures.append({"media_id": row["media_id"], "error": err})
    total_s = time.perf_counter() - t_all

    write_json(output_dir / "raw_predictions.json", {"results": predictions})
    write_csv(
        output_dir / "raw_predictions.csv",
        predictions,
        [
            "media_id",
            "source_media_key",
            "mos_quality_raw",
            "musiq_raw_score",
            "musiq_status",
            "musiq_error",
            "musiq_elapsed_ms",
            "calibrated_1_5",
            "image_path",
        ],
    )

    ok = [p for p in predictions if p["musiq_status"] == "ok" and p["musiq_raw_score"] is not None]
    musiq_raw = [float(p["musiq_raw_score"]) for p in ok]
    mos = [float(p["mos_quality_raw"]) for p in ok]
    comparable_1_5 = scores_on_comparable_1_5_scale(musiq_raw, str(metric_meta.get("score_range") or ""))
    comparable_0_100 = (not comparable_1_5) and scales_comparable_0_100(
        musiq_raw, mos, str(metric_meta.get("score_range") or "")
    )
    musiq_vs_mos = pair_metrics(musiq_raw, mos, comparable_for_error=comparable_0_100)
    if comparable_0_100:
        mae_policy = (
            "MAE/RMSE computed on raw scores because both LIVEC MOS and MUSIQ PaQ-2-PiQ are 0-100-like, "
            "higher-is-better, with comparable spans. No mapping was fitted on LIVEC. Absolute error is still "
            "uncalibrated cross-dataset error, not an ACCESS 1-5 product metric."
        )
    else:
        mae_policy = (
            "MAE/RMSE not computed: raw MUSIQ and LIVEC MOS are not on a justified common scale "
            "(or MUSIQ span is too compressed). No LIVEC calibration was fitted."
        )
        musiq_vs_mos["mae_display"] = "not comparable (scale)"
        musiq_vs_mos["rmse_display"] = "not comparable (scale)"

    ckpts = [c for c in find_checkpoint_files(cache_dir) if str(c["path"]).endswith(".pth")]
    report = {
        "generated_at": _now_iso(),
        "disclaimer": "Not a scientific validation of EfficientNet-B0 or ACCESS criteria. LIVEC MOS is overall-only.",
        "dataset_root": str(root),
        "n_requested": len(test_rows),
        "integrity": integrity,
        "overlap": overlap,
        "environment": env,
        "metric": metric_meta,
        "checkpoints": ckpts,
        "license": LICENSE_SUMMARY,
        "inference": {
            "n_ok": len(ok),
            "n_failed": len(failures),
            "failures": failures,
            "mean_elapsed_ms": (sum(p["musiq_elapsed_ms"] for p in ok) / len(ok)) if ok else None,
            "total_elapsed_s": round(total_s, 3),
            "device": device,
        },
        "distributions": {"mos": summarize(mos), "musiq_raw": summarize(musiq_raw)},
        "musiq_vs_mos": musiq_vs_mos,
        "mae_rmse_policy": mae_policy,
        "koniq_phase2_reference": {
            "n": 140,
            "musiq_pearson_r": 0.8199676454679334,
            "musiq_spearman_r": 0.8213120902017359,
            "efficientnet_pearson_r": 0.14174349699639105,
            "efficientnet_spearman_r": 0.10854887348425696,
            "note": "KonIQ exploratory benchmark. Not LIVEC labels.",
        },
    }
    write_json(output_dir / "metrics.json", report)
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="LIVEC independent MUSIQ PaQ-2-PiQ benchmark.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--limit", type=int, default=None)
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    result = run(output_dir=args.output_dir, device=args.device, limit=args.limit)
    print(
        json.dumps(
            {
                "ok": result["inference"]["n_failed"] == 0 and result["integrity"]["ok"],
                "n_ok": result["inference"]["n_ok"],
                "pearson_r": result["musiq_vs_mos"].get("pearson_r"),
                "spearman_r": result["musiq_vs_mos"].get("spearman_r"),
            },
            indent=2,
        )
    )
