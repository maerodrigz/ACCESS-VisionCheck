#!/usr/bin/env python3
"""Phase 5B–5D: live Docker MUSIQ + OpenCV criterion validation on the 30-image pilot.

Reads PATHS from PHASE5_CRITERION_VALIDATION_AUDIT.md (canonical assets).
Does NOT modify production code, QUALITY_ENGINE, PROBE, WaveRep, or Flutter.
Does NOT overwrite Phase 1–4 output folders.
Does NOT invent ratings or substitute cached MUSIQ when the worker is down.
Does NOT recalibrate thresholds on these 30 images.

Usage:
  access_backend/venv312/Scripts/python.exe run_phase5_criterion_validation.py

Auth: MUSIQ_WORKER_TOKEN from env, else musiq_worker/.env, else compose default.
Token is never printed or written to research outputs.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx

_TOOLKIT = Path(__file__).resolve().parent
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from metrics import mae_rmse, pearson_spearman  # noqa: E402

PILOT_ROOT = _TOOLKIT / "workspace" / "human_pilot"
PILOT_IMAGES = PILOT_ROOT / "rater_pack" / "images"
PILOT_LOCKED = PILOT_ROOT / "output" / "pilot_hvsm_20261108T114511Z"
HUMAN_CONSENSUS = PILOT_LOCKED / "human_consensus_by_image.csv"
ENET_JOINED = PILOT_LOCKED / "machine_scores_joined.csv"
PHASE1_HYBRID = PILOT_ROOT / "output" / "phase1_hybrid_nr_iqa_20261113" / "hybrid_per_image.csv"
ENET_CRIT_SUMMARY = PILOT_LOCKED / "criterion_comparison_summary.csv"
ENET_OVERALL_SUMMARY = PILOT_LOCKED / "overall_construct_comparison.csv"
WORKER_ENV_FILE = _TOOLKIT.parents[1] / "musiq_worker" / ".env"

OPENCV_CRITERIA = (
    "sharpness",
    "blur",
    "brightness",
    "contrast",
    "blocking_artifacts",
)

# Documented blank human cells (audit §2.3); medians still present.
KNOWN_BLANK_CELLS = (
    {"rater": "R1", "media_id": "PILOT-020", "criterion": "blocking_artifacts"},
    {"rater": "R2", "media_id": "PILOT-012", "criterion": "contrast"},
    {"rater": "R3", "media_id": "PILOT-012", "criterion": "brightness"},
    {"rater": "R3", "media_id": "PILOT-013", "criterion": "ringing_artifacts"},
)

EQUAL_BIN_NOTE = (
    "Equal-bin badge mapping is experimental and uncalibrated on this pilot. "
    "Maps were declared a priori (Phase 9 / hybrid CLASSICAL_MAP_VERSION); "
    "not fitted or retuned on these 30 images."
)


def _now_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def _write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str] | None = None) -> None:
    if not rows and not fieldnames:
        path.write_text("", encoding="utf-8")
        return
    cols = fieldnames or list(rows[0].keys())
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k) for k in cols})


def _parse_dotenv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#") or "=" not in s:
            continue
        k, v = s.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def _load_token() -> tuple[str, str]:
    """Return (token, source_label). Never log the token value."""
    env_tok = (os.environ.get("MUSIQ_WORKER_TOKEN") or "").strip()
    if env_tok:
        return env_tok, "env:MUSIQ_WORKER_TOKEN"
    dotenv = _parse_dotenv(WORKER_ENV_FILE)
    file_tok = (dotenv.get("MUSIQ_WORKER_TOKEN") or "").strip()
    if file_tok:
        return file_tok, "musiq_worker/.env"
    return "dev-local-musiq-token", "docker-compose-default"


def _float_or_none(v: Any) -> float | None:
    if v is None:
        return None
    s = str(v).strip()
    if s == "" or s.lower() in {"nan", "none", "null", "n/a"}:
        return None
    try:
        x = float(s)
    except (TypeError, ValueError):
        return None
    if x != x:  # NaN
        return None
    return x


def _pairs(xs: list[float | None], ys: list[float | None]) -> tuple[list[float], list[float]]:
    a: list[float] = []
    b: list[float] = []
    for x, y in zip(xs, ys, strict=True):
        if x is None or y is None:
            continue
        a.append(float(x))
        b.append(float(y))
    return a, b


def _corr_block(xs: list[float | None], ys: list[float | None], *, mae_ok: bool) -> dict[str, Any]:
    a, b = _pairs(xs, ys)
    base = pearson_spearman(a, b)
    out: dict[str, Any] = {
        "n_valid_pairs": len(a),
        "spearman_r": base.get("spearman_r"),
        "spearman_p": base.get("spearman_p"),
        "pearson_r": base.get("pearson_r"),
        "pearson_p": base.get("pearson_p"),
        "corr_note": base.get("note"),
    }
    if mae_ok and len(a) > 0:
        err = mae_rmse(a, b)
        out["mae"] = err.get("mae")
        out["rmse"] = err.get("rmse")
        out["mae_applicable"] = True
        out["mae_note"] = (
            "Both series on comparable 1–5 higher-is-better scale "
            f"({EQUAL_BIN_NOTE})"
        )
    else:
        out["mae"] = None
        out["rmse"] = None
        out["mae_applicable"] = False
        out["mae_note"] = (
            "MAE withheld: MUSIQ ~0–100 vs human 1–5 (no frozen calibration), "
            "or continuous q vs discrete human without a priori 1–5 map for MAE"
        )
    if len(a) >= 2:
        import numpy as np

        if float(np.std(a)) == 0.0 or float(np.std(b)) == 0.0:
            out["warning"] = "constant_or_zero_variance_series"
    if len(a) < 3:
        out["warning"] = (out.get("warning") or "") + ";insufficient_n" if out.get("warning") else "insufficient_n"
    return out


def _assert_pilot_images() -> list[Path]:
    imgs = sorted(PILOT_IMAGES.glob("PILOT-*.jpg"))
    ids = [p.stem for p in imgs]
    expected = [f"PILOT-{i:03d}" for i in range(1, 31)]
    if ids != expected:
        missing = sorted(set(expected) - set(ids))
        extra = sorted(set(ids) - set(expected))
        raise SystemExit(
            f"ERROR: pilot image ID mismatch. missing={missing} extra={extra} count={len(ids)}"
        )
    if len(set(ids)) != 30:
        raise SystemExit("ERROR: duplicate PILOT image stems")
    return imgs


def _check_ready(base_url: str, timeout: float) -> dict[str, Any]:
    url = f"{base_url.rstrip('/')}/ready"
    try:
        with httpx.Client(timeout=timeout) as client:
            resp = client.get(url)
    except Exception as exc:  # noqa: BLE001
        raise SystemExit(
            f"ERROR: Docker MUSIQ worker unavailable at {url}: {exc}. "
            "Stop: do not substitute Phase 1 cached MUSIQ scores."
        ) from exc
    if resp.status_code != 200:
        raise SystemExit(
            f"ERROR: worker /ready returned HTTP {resp.status_code}: {(resp.text or '')[:300]}. "
            "Stop: do not substitute cached MUSIQ scores."
        )
    body = resp.json()
    if not body.get("musiq_ready"):
        raise SystemExit(
            f"ERROR: worker not musiq_ready: {body}. "
            "Stop: do not substitute cached MUSIQ scores."
        )
    return body


def _evaluate_one(
    client: httpx.Client,
    base_url: str,
    token: str,
    path: Path,
) -> dict[str, Any]:
    t0 = time.perf_counter()
    headers = {"Authorization": f"Bearer {token}"}
    files = {"file": (path.name, path.read_bytes(), "image/jpeg")}
    data = {"media_type": "photo", "file_ext": ".jpg"}
    rec: dict[str, Any] = {
        "media_id": path.stem,
        "filename": path.name,
        "path": str(path),
        "http_status": None,
        "client_error": None,
        "wall_ms": None,
        "raw": None,
    }
    try:
        resp = client.post(
            f"{base_url.rstrip('/')}/v1/evaluate",
            headers=headers,
            files=files,
            data=data,
        )
        rec["http_status"] = resp.status_code
        rec["wall_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
        if resp.status_code >= 400:
            rec["client_error"] = f"http_{resp.status_code}:{(resp.text or '')[:200]}"
            rec["raw"] = {
                "status": "error",
                "error": rec["client_error"],
                "musiq": None,
                "criteria_raw": None,
                "criteria_q": None,
                "criteria_badge_equal_bin": None,
            }
            return rec
        body = resp.json()
        if not isinstance(body, dict):
            rec["client_error"] = "invalid_json"
            rec["raw"] = {"status": "error", "error": "invalid_json"}
            return rec
        rec["raw"] = body
        return rec
    except Exception as exc:  # noqa: BLE001
        rec["wall_ms"] = round((time.perf_counter() - t0) * 1000.0, 3)
        rec["client_error"] = f"request_failed:{type(exc).__name__}"
        rec["raw"] = {
            "status": "error",
            "error": rec["client_error"],
            "musiq": None,
            "criteria_raw": None,
            "criteria_q": None,
            "criteria_badge_equal_bin": None,
        }
        return rec


def _flatten_eval(rec: dict[str, Any]) -> dict[str, Any]:
    raw = rec.get("raw") or {}
    musiq = raw.get("musiq") if isinstance(raw.get("musiq"), dict) else {}
    q = raw.get("criteria_q") if isinstance(raw.get("criteria_q"), dict) else {}
    badge = (
        raw.get("criteria_badge_equal_bin")
        if isinstance(raw.get("criteria_badge_equal_bin"), dict)
        else {}
    )
    crit_raw = raw.get("criteria_raw") if isinstance(raw.get("criteria_raw"), dict) else {}
    row: dict[str, Any] = {
        "media_id": rec["media_id"],
        "filename": rec["filename"],
        "http_status": rec.get("http_status"),
        "client_error": rec.get("client_error"),
        "wall_ms": rec.get("wall_ms"),
        "worker_status": raw.get("status"),
        "worker_error": raw.get("error"),
        "worker_version": raw.get("worker_version"),
        "classical_map_version": raw.get("classical_map_version"),
        "duration_ms": raw.get("duration_ms"),
        "musiq_status": musiq.get("status"),
        "musiq_opq_raw": musiq.get("musiq_opq_raw"),
        "musiq_scale": musiq.get("musiq_scale"),
        "musiq_model_id": musiq.get("model_id"),
        "musiq_model_version": musiq.get("model_version"),
        "musiq_engine_handle": musiq.get("engine_handle"),
        "musiq_error": musiq.get("error"),
        "soft_score_applied_to_musiq": raw.get("soft_score_applied_to_musiq"),
        "production_payload_mutated": raw.get("production_payload_mutated"),
    }
    for c in OPENCV_CRITERIA:
        row[f"q_{c}"] = q.get(c)
        row[f"badge_{c}"] = badge.get(c)
    for k, v in crit_raw.items():
        row[f"raw_{k}"] = v
    return row


def _build_joined(
    live_rows: list[dict[str, Any]],
    consensus: list[dict[str, str]],
    enet: list[dict[str, str]],
    phase1: list[dict[str, str]],
) -> list[dict[str, Any]]:
    cons_by = {r["media_id"]: r for r in consensus}
    enet_by = {r["media_id"]: r for r in enet}
    p1_by = {r["media_id"]: r for r in phase1}
    joined: list[dict[str, Any]] = []
    for live in live_rows:
        mid = live["media_id"]
        h = cons_by.get(mid, {})
        e = enet_by.get(mid, {})
        p1 = p1_by.get(mid, {})
        row: dict[str, Any] = {
            "media_id": mid,
            "source_media_key": h.get("source_media_key") or e.get("source_media_key"),
            "stratum_label": h.get("stratum_label"),
            "human_overall_visual_quality_median": _float_or_none(
                h.get("overall_visual_quality_median")
            ),
            "human_overall_n": _float_or_none(h.get("overall_visual_quality_n")),
            "live_musiq_opq_raw": _float_or_none(live.get("musiq_opq_raw")),
            "live_musiq_status": live.get("musiq_status"),
            "live_worker_status": live.get("worker_status"),
            "live_client_error": live.get("client_error"),
            "phase1_musiq_opq_raw": _float_or_none(p1.get("musiq_opq_raw")),
            "enet_overall_score": _float_or_none(e.get("overall_score")),
        }
        for c in OPENCV_CRITERIA:
            row[f"human_{c}_median"] = _float_or_none(h.get(f"{c}_median"))
            row[f"human_{c}_n"] = _float_or_none(h.get(f"{c}_n"))
            row[f"live_badge_{c}"] = _float_or_none(live.get(f"badge_{c}"))
            row[f"live_q_{c}"] = _float_or_none(live.get(f"q_{c}"))
            row[f"enet_{c}"] = _float_or_none(e.get(c))
            row[f"phase1_badge_{c}"] = _float_or_none(p1.get(f"badge_{c}"))
        # Preserve ringing/noise human medians for missing-data inventory only
        for c in ("noise", "ringing_artifacts"):
            row[f"human_{c}_median"] = _float_or_none(h.get(f"{c}_median"))
            row[f"human_{c}_n"] = _float_or_none(h.get(f"{c}_n"))
            row[f"enet_{c}"] = _float_or_none(e.get(c))
        joined.append(row)
    return joined


def _criterion_stats(joined: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for c in OPENCV_CRITERIA:
        hum = [r.get(f"human_{c}_median") for r in joined]
        badge = [r.get(f"live_badge_{c}") for r in joined]
        q = [r.get(f"live_q_{c}") for r in joined]
        enet = [r.get(f"enet_{c}") for r in joined]
        badge_block = _corr_block(hum, badge, mae_ok=True)
        q_block = _corr_block(hum, q, mae_ok=False)
        enet_block = _corr_block(hum, enet, mae_ok=True)
        rows.append(
            {
                "criterion": c,
                "machine": "live_opencv_badge_equal_bin",
                "human_column": f"{c}_median",
                "n_valid_pairs": badge_block["n_valid_pairs"],
                "spearman_r": badge_block["spearman_r"],
                "spearman_p": badge_block["spearman_p"],
                "mae": badge_block["mae"],
                "rmse": badge_block["rmse"],
                "mae_applicable": badge_block["mae_applicable"],
                "mae_note": badge_block["mae_note"],
                "warning": badge_block.get("warning") or badge_block.get("corr_note"),
                "mapping_label": "experimental_uncalibrated_equal_bin",
            }
        )
        rows.append(
            {
                "criterion": c,
                "machine": "live_opencv_q_continuous",
                "human_column": f"{c}_median",
                "n_valid_pairs": q_block["n_valid_pairs"],
                "spearman_r": q_block["spearman_r"],
                "spearman_p": q_block["spearman_p"],
                "mae": None,
                "rmse": None,
                "mae_applicable": False,
                "mae_note": q_block["mae_note"],
                "warning": q_block.get("warning") or q_block.get("corr_note"),
                "mapping_label": "continuous_q_spearman_only",
            }
        )
        rows.append(
            {
                "criterion": c,
                "machine": "locked_enet_badge_retrospective",
                "human_column": f"{c}_median",
                "n_valid_pairs": enet_block["n_valid_pairs"],
                "spearman_r": enet_block["spearman_r"],
                "spearman_p": enet_block["spearman_p"],
                "mae": enet_block["mae"],
                "rmse": enet_block["rmse"],
                "mae_applicable": True,
                "mae_note": (
                    "Retrospective ENET vs human on the same pilot already used for "
                    "ENET H-vs-M evaluation. Not an independent holdout."
                ),
                "warning": enet_block.get("warning") or enet_block.get("corr_note"),
                "mapping_label": "locked_enet_run002",
            }
        )
    # Overall: MUSIQ Spearman only
    hum_ov = [r.get("human_overall_visual_quality_median") for r in joined]
    musiq = [r.get("live_musiq_opq_raw") for r in joined]
    enet_ov = [r.get("enet_overall_score") for r in joined]
    p1_m = [r.get("phase1_musiq_opq_raw") for r in joined]
    musiq_block = _corr_block(hum_ov, musiq, mae_ok=False)
    enet_ov_block = _corr_block(hum_ov, enet_ov, mae_ok=True)
    live_vs_p1 = _corr_block(musiq, p1_m, mae_ok=False)
    rows.append(
        {
            "criterion": "overall_visual_quality",
            "machine": "live_musiq_opq_paq2piq",
            "human_column": "overall_visual_quality_median",
            "n_valid_pairs": musiq_block["n_valid_pairs"],
            "spearman_r": musiq_block["spearman_r"],
            "spearman_p": musiq_block["spearman_p"],
            "mae": None,
            "rmse": None,
            "mae_applicable": False,
            "mae_note": (
                "MAE not calculated: MUSIQ ~0–100 vs human 1–5; no frozen calibration map."
            ),
            "warning": musiq_block.get("warning") or musiq_block.get("corr_note"),
            "mapping_label": "musiq_overall_only_not_criterion_predictor",
        }
    )
    rows.append(
        {
            "criterion": "overall_visual_quality",
            "machine": "locked_enet_overall_mean_retrospective",
            "human_column": "overall_visual_quality_median",
            "n_valid_pairs": enet_ov_block["n_valid_pairs"],
            "spearman_r": enet_ov_block["spearman_r"],
            "spearman_p": enet_ov_block["spearman_p"],
            "mae": enet_ov_block["mae"],
            "rmse": enet_ov_block["rmse"],
            "mae_applicable": True,
            "mae_note": (
                "ENET overall_score is mean of seven technical badges (different construct "
                "from human gestalt overall). Retrospective only."
            ),
            "warning": enet_ov_block.get("warning") or enet_ov_block.get("corr_note"),
            "mapping_label": "locked_enet_overall",
        }
    )
    rows.append(
        {
            "criterion": "musiq_live_vs_phase1_csv",
            "machine": "live_vs_prior_benchmark_csv",
            "human_column": "n/a",
            "n_valid_pairs": live_vs_p1["n_valid_pairs"],
            "spearman_r": live_vs_p1["spearman_r"],
            "spearman_p": live_vs_p1["spearman_p"],
            "mae": None,
            "rmse": None,
            "mae_applicable": False,
            "mae_note": "Machine-vs-machine provenance check only; not a human correlation.",
            "warning": live_vs_p1.get("warning") or live_vs_p1.get("corr_note"),
            "mapping_label": "provenance",
        }
    )
    return rows


def _fmt(v: Any, nd: int = 4) -> str:
    if v is None:
        return "N/A"
    if isinstance(v, float):
        return f"{v:.{nd}f}"
    return str(v)


def _write_report(
    path: Path,
    *,
    out_dir: Path,
    ready: dict[str, Any],
    meta: dict[str, Any],
    stats_rows: list[dict[str, Any]],
    live_rows: list[dict[str, Any]],
    joined: list[dict[str, Any]],
) -> None:
    ok_n = sum(
        1
        for r in live_rows
        if r.get("worker_status") in ("ok", "partial") and not r.get("client_error")
    )
    musiq_ok = sum(1 for r in live_rows if r.get("musiq_status") == "ok")
    fail_n = len(live_rows) - ok_n
    badge_rows = [
        r
        for r in stats_rows
        if r["machine"] == "live_opencv_badge_equal_bin"
        or r["machine"] == "live_musiq_opq_paq2piq"
    ]
    enet_rows = [r for r in stats_rows if "enet" in str(r["machine"])]

    lines: list[str] = []
    lines.append("# Phase 5B–5D: Live MUSIQ + OpenCV Criterion Validation")
    lines.append("")
    lines.append(f"**Output folder:** `{out_dir}`")
    lines.append(f"**UTC stamp:** {meta['timestamp_utc']}")
    lines.append(f"**Worker ready:** `{json.dumps(ready)}`")
    lines.append(
        f"**Successful evaluations:** {ok_n}/30 "
        f"(MUSIQ ok: {musiq_ok}/30; failed/errored requests recorded: {fail_n})"
    )
    lines.append("")
    lines.append("## Constraints honored")
    lines.append("")
    lines.append("- No production / Flutter / PROBE / WaveRep changes.")
    lines.append("- `QUALITY_ENGINE=enet` remains production default.")
    lines.append("- No threshold recalibration on these 30 pilot images.")
    lines.append("- Equal-bin OpenCV badges labeled **experimental / uncalibrated**.")
    lines.append("- MUSIQ used as **overall** perceptual quality only (not criterion-specific).")
    lines.append("- MAE omitted for MUSIQ ~0–100 vs human 1–5.")
    lines.append("- Token never written to research outputs.")
    lines.append("")
    lines.append("## Methodology")
    lines.append("")
    lines.append("1. Verified `GET /ready` on the local Docker MUSIQ worker.")
    lines.append(
        "2. Authenticated `POST /v1/evaluate` for each `PILOT-001`…`030` JPG "
        "(live OpenCV classical + live MUSIQ PaQ-2-PiQ)."
    )
    lines.append(
        "3. Joined on `media_id` to locked human consensus medians "
        f"(`{HUMAN_CONSENSUS.name}`) and locked ENET badges "
        f"(`{ENET_JOINED.name}`)."
    )
    lines.append(
        "4. Spearman ρ per criterion; MAE only for 1–5 vs 1–5 OpenCV equal-bin badges "
        "(and retrospective ENET)."
    )
    lines.append(
        f"5. Classical map version from worker: "
        f"`{meta.get('classical_map_version_observed')}`."
    )
    lines.append("")
    lines.append("## Missing data")
    lines.append("")
    lines.append(
        "Four individual rater cells were blank (audit §2.3). Consensus medians "
        "exclude blanks per cell; all 30 images retain medians for Phase 5 criteria:"
    )
    lines.append("")
    for b in KNOWN_BLANK_CELLS:
        lines.append(
            f"- {b['rater']} / {b['media_id']} / `{b['criterion']}`"
        )
    lines.append("")
    miss_human = []
    for c in list(OPENCV_CRITERIA) + ["overall_visual_quality"]:
        key = (
            "human_overall_visual_quality_median"
            if c == "overall_visual_quality"
            else f"human_{c}_median"
        )
        n_miss = sum(1 for r in joined if r.get(key) is None)
        if n_miss:
            miss_human.append(f"{c}: {n_miss} missing medians")
    if miss_human:
        lines.append("Missing consensus medians in joined table: " + "; ".join(miss_human))
    else:
        lines.append(
            "Joined table: **0** missing human medians for sharpness, blur, "
            "brightness, contrast, blocking, overall."
        )
    lines.append("")
    live_miss_badge = []
    for c in OPENCV_CRITERIA:
        n_miss = sum(1 for r in joined if r.get(f"live_badge_{c}") is None)
        if n_miss:
            live_miss_badge.append(f"{c}={n_miss}")
    musiq_miss = sum(1 for r in joined if r.get("live_musiq_opq_raw") is None)
    lines.append(
        f"Live machine missing: badges {{{', '.join(live_miss_badge) or 'none'}}}; "
        f"MUSIQ OPQ missing={musiq_miss}."
    )
    lines.append("")
    lines.append("## Per-criterion results (primary)")
    lines.append("")
    lines.append(
        "| Criterion | Machine | n | Spearman ρ | Spearman p | MAE | Notes |"
    )
    lines.append("|---|---|---:|---:|---:|---:|---|")
    for r in badge_rows:
        lines.append(
            f"| {r['criterion']} | {r['machine']} | {r['n_valid_pairs']} | "
            f"{_fmt(r['spearman_r'])} | {_fmt(r['spearman_p'])} | "
            f"{_fmt(r['mae']) if r['mae_applicable'] else 'omitted'} | "
            f"{(r.get('warning') or r.get('mapping_label') or '').replace('|', '/')} |"
        )
    lines.append("")
    lines.append("### OpenCV continuous q (Spearman only)")
    lines.append("")
    lines.append("| Criterion | n | Spearman ρ | Spearman p |")
    lines.append("|---|---:|---:|---:|")
    for r in stats_rows:
        if r["machine"] != "live_opencv_q_continuous":
            continue
        lines.append(
            f"| {r['criterion']} | {r['n_valid_pairs']} | "
            f"{_fmt(r['spearman_r'])} | {_fmt(r['spearman_p'])} |"
        )
    lines.append("")
    lines.append("## Descriptive comparison vs locked EfficientNet-B0")
    lines.append("")
    lines.append(
        "ENET numbers are **retrospective** on a pilot already used for ENET "
        "human-vs-machine evaluation. No claim of statistically significant "
        "improvement is made without a formal paired test pre-registered on an "
        "independent holdout (Phase 4A humans still empty)."
    )
    lines.append("")
    lines.append("| Criterion | Live OpenCV badge ρ | Locked ENET badge ρ | Live MAE | ENET MAE |")
    lines.append("|---|---:|---:|---:|---:|")
    for c in OPENCV_CRITERIA:
        live = next(
            r
            for r in stats_rows
            if r["criterion"] == c and r["machine"] == "live_opencv_badge_equal_bin"
        )
        en = next(
            r
            for r in stats_rows
            if r["criterion"] == c and r["machine"] == "locked_enet_badge_retrospective"
        )
        lines.append(
            f"| {c} | {_fmt(live['spearman_r'])} | {_fmt(en['spearman_r'])} | "
            f"{_fmt(live['mae'])} | {_fmt(en['mae'])} |"
        )
    live_ov = next(
        r for r in stats_rows if r["machine"] == "live_musiq_opq_paq2piq"
    )
    en_ov = next(
        r for r in stats_rows if r["machine"] == "locked_enet_overall_mean_retrospective"
    )
    lines.append(
        f"| overall (MUSIQ vs ENET mean) | {_fmt(live_ov['spearman_r'])} | "
        f"{_fmt(en_ov['spearman_r'])} | omitted | {_fmt(en_ov['mae'])} |"
    )
    lines.append("")
    p1_row = next(r for r in stats_rows if r["criterion"] == "musiq_live_vs_phase1_csv")
    lines.append(
        f"Live MUSIQ vs Phase 1 CSV-joined MUSIQ (machine provenance): "
        f"n={p1_row['n_valid_pairs']}, Spearman ρ={_fmt(p1_row['spearman_r'])}."
    )
    lines.append("")
    lines.append("## Reproducibility")
    lines.append("")
    lines.append(f"- Worker URL: `{meta['worker_url']}`")
    lines.append(f"- Token source (not value): `{meta['token_source']}`")
    lines.append(f"- Worker model: `{ready.get('model_id')}` / `{ready.get('model_version')}`")
    lines.append(f"- Observed worker_version: `{meta.get('worker_version_observed')}`")
    lines.append(f"- Classical map: `{meta.get('classical_map_version_observed')}`")
    lines.append(f"- Image root: `{PILOT_IMAGES}`")
    lines.append(f"- Human consensus: `{HUMAN_CONSENSUS}`")
    lines.append("- Artifacts: `live_evaluations.jsonl`, `live_scores.csv`, "
                 "`comparison_joined.csv`, `criterion_stats.csv`, `run_meta.json`")
    lines.append("")
    lines.append("## Limitations")
    lines.append("")
    lines.append("- n=30; correlations are unstable and exploratory.")
    lines.append("- Sharpness and blur share the Laplacian axis (dependent measures).")
    lines.append("- Equal-bin badges are experimental; do not present as validated member feedback.")
    lines.append("- Pilot already used for ENET evaluation; not an independent ENET holdout.")
    lines.append("- No human GT for color; noise/ringing lack live OpenCV badges in worker q set.")
    lines.append("- Phase 4A (n=100) remains the intended independent set once humans rate it.")
    lines.append("")
    lines.append("## Conclusion: readiness for further validation")
    lines.append("")
    lines.append(
        "Live Docker MUSIQ + OpenCV scoring of the locked 30-image pilot **completed** "
        "with versioned research outputs. Criterion-level Spearman/MAE tables are "
        "available for research review. This does **not** authorize switching "
        "`QUALITY_ENGINE`, publishing experimental badges to members, or claiming "
        "criterion validation. Next appropriate step: independent human ratings on "
        "Phase 4A (or a new sealed set), then pre-registered analysis without "
        "retuning on that holdout."
    )
    lines.append("")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--worker-url",
        default=os.environ.get("MUSIQ_WORKER_URL", "http://127.0.0.1:8080"),
    )
    ap.add_argument("--timeout-sec", type=float, default=float(os.environ.get("MUSIQ_WORKER_TIMEOUT_SEC", "120")))
    args = ap.parse_args()

    print("Phase 5B–5D: preflight…")
    imgs = _assert_pilot_images()
    print(f"  images OK: {len(imgs)} PILOT-001..030")
    for p in (HUMAN_CONSENSUS, ENET_JOINED, PHASE1_HYBRID):
        if not p.is_file():
            raise SystemExit(f"ERROR: required asset missing: {p}")
    print("  locked CSVs present")

    ready = _check_ready(args.worker_url, args.timeout_sec)
    print(f"  worker ready: model_id={ready.get('model_id')} version={ready.get('model_version')}")

    token, token_source = _load_token()
    print(f"  token source: {token_source} (value not printed)")

    stamp = _now_stamp()
    out_dir = PILOT_ROOT / "output" / f"phase5_criterion_validation_{stamp}"
    out_dir.mkdir(parents=True, exist_ok=False)
    print(f"  output: {out_dir}")

    consensus = _read_csv(HUMAN_CONSENSUS)
    enet = _read_csv(ENET_JOINED)
    phase1 = _read_csv(PHASE1_HYBRID)
    cons_ids = {r["media_id"] for r in consensus}
    if cons_ids != {p.stem for p in imgs}:
        raise SystemExit("ERROR: consensus media_id set != image set")

    live_recs: list[dict[str, Any]] = []
    live_rows: list[dict[str, Any]] = []
    jsonl_path = out_dir / "live_evaluations.jsonl"

    with httpx.Client(timeout=args.timeout_sec) as client, jsonl_path.open(
        "w", encoding="utf-8"
    ) as jf:
        for i, path in enumerate(imgs, start=1):
            print(f"  evaluate {i}/30 {path.name}…", flush=True)
            rec = _evaluate_one(client, args.worker_url, token, path)
            # Strip any accidental auth material; store raw worker JSON only
            safe_rec = {
                "media_id": rec["media_id"],
                "filename": rec["filename"],
                "path": rec["path"],
                "http_status": rec["http_status"],
                "client_error": rec["client_error"],
                "wall_ms": rec["wall_ms"],
                "raw": rec["raw"],
            }
            jf.write(json.dumps(safe_rec, ensure_ascii=False) + "\n")
            flat = _flatten_eval(rec)
            live_recs.append(rec)
            live_rows.append(flat)
            status = flat.get("worker_status") or "error"
            print(
                f"    status={status} musiq={flat.get('musiq_status')} "
                f"opq={flat.get('musiq_opq_raw')} wall_ms={flat.get('wall_ms')}"
            )

    _write_csv(out_dir / "live_scores.csv", live_rows)

    joined = _build_joined(live_rows, consensus, enet, phase1)
    _write_csv(out_dir / "comparison_joined.csv", joined)

    stats_rows = _criterion_stats(joined)
    _write_csv(out_dir / "criterion_stats.csv", stats_rows)

    worker_versions = {
        str(r.get("worker_version"))
        for r in live_rows
        if r.get("worker_version")
    }
    map_versions = {
        str(r.get("classical_map_version"))
        for r in live_rows
        if r.get("classical_map_version")
    }
    ok_n = sum(
        1
        for r in live_rows
        if r.get("worker_status") in ("ok", "partial") and not r.get("client_error")
    )
    musiq_ok = sum(1 for r in live_rows if r.get("musiq_status") == "ok")
    failed = [
        {
            "media_id": r["media_id"],
            "http_status": r.get("http_status"),
            "client_error": r.get("client_error"),
            "worker_status": r.get("worker_status"),
            "worker_error": r.get("worker_error"),
            "musiq_status": r.get("musiq_status"),
            "musiq_error": r.get("musiq_error"),
        }
        for r in live_rows
        if r.get("client_error")
        or r.get("worker_status") not in ("ok", "partial")
        or r.get("musiq_status") != "ok"
    ]
    _write_csv(
        out_dir / "failed_or_partial.csv",
        failed
        or [
            {
                "media_id": "",
                "note": "no_failed_or_partial_rows",
            }
        ],
    )

    meta = {
        "timestamp_utc": stamp,
        "phase": "5B-5D",
        "worker_url": args.worker_url,
        "token_source": token_source,
        "ready": ready,
        "n_images": 30,
        "n_eval_ok": ok_n,
        "n_musiq_ok": musiq_ok,
        "worker_version_observed": sorted(worker_versions),
        "classical_map_version_observed": sorted(map_versions),
        "human_consensus": str(HUMAN_CONSENSUS),
        "enet_joined": str(ENET_JOINED),
        "phase1_hybrid": str(PHASE1_HYBRID),
        "equal_bin_note": EQUAL_BIN_NOTE,
        "known_blank_human_cells": list(KNOWN_BLANK_CELLS),
        "production_mutations": False,
        "quality_engine_unchanged": "enet",
        "cached_musiq_substitution": False,
        "audit_doc": str(_TOOLKIT / "PHASE5_CRITERION_VALIDATION_AUDIT.md"),
    }
    (out_dir / "run_meta.json").write_text(
        json.dumps(meta, indent=2) + "\n", encoding="utf-8"
    )

    # Copy ENET historical summaries for side-by-side reading (read-only reference)
    if ENET_CRIT_SUMMARY.is_file():
        (out_dir / "reference_enet_criterion_comparison_summary.csv").write_bytes(
            ENET_CRIT_SUMMARY.read_bytes()
        )
    if ENET_OVERALL_SUMMARY.is_file():
        (out_dir / "reference_enet_overall_construct_comparison.csv").write_bytes(
            ENET_OVERALL_SUMMARY.read_bytes()
        )

    report_path = out_dir / "PHASE5_CRITERION_VALIDATION_REPORT.md"
    _write_report(
        report_path,
        out_dir=out_dir,
        ready=ready,
        meta=meta,
        stats_rows=stats_rows,
        live_rows=live_rows,
        joined=joined,
    )

    print("")
    print("=== Phase 5 complete ===")
    print(f"output: {out_dir}")
    print(f"successful: {ok_n}/30  musiq_ok: {musiq_ok}/30")
    print("primary Spearman / MAE:")
    for r in stats_rows:
        if r["machine"] not in (
            "live_opencv_badge_equal_bin",
            "live_musiq_opq_paq2piq",
        ):
            continue
        mae_s = _fmt(r["mae"]) if r["mae_applicable"] else "omitted"
        print(
            f"  {r['criterion']}: n={r['n_valid_pairs']} "
            f"rho={_fmt(r['spearman_r'])} mae={mae_s}"
        )
    print(f"report: {report_path}")
    return 0 if ok_n == 30 and musiq_ok == 30 else 2


if __name__ == "__main__":
    raise SystemExit(main())
