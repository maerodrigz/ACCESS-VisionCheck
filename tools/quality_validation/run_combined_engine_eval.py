#!/usr/bin/env python3
"""Evaluate experimental_classical_combined_v1 (research-only).

Efficiency:
  - Scores ONLY the combined engine (decode once per image).
  - Reuses cached production baseline + experimental v2 SPAQ/pilot CSVs.
  - Prints per-image progress and writes checkpoint CSVs incrementally.

Diagnostic only: SPAQ-200 and the frozen ACCESS pilot were not used to select
the combined composition. Do not treat correlations as unbiased final validation.

Does not modify production, prior engines, human CSVs, or previous outputs.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.experimental_quality_engine_combined_v1 import (  # noqa: E402
    CRITERIA,
    ENGINE_ID,
    analyze_image_bytes,
)
from tools.quality_validation.metrics import pearson_spearman  # noqa: E402

SPAQ_IMAGES = _TOOLKIT / "workspace" / "datasets" / "spaq" / "images"
SPAQ_HUMAN = _TOOLKIT / "workspace" / "datasets" / "spaq" / "metadata" / "human_ratings_200.csv"
V2_SPAQ_CACHE = (
    _TOOLKIT
    / "workspace"
    / "experimental_quality"
    / "output"
    / "exp_eval_v2_20261108T123035Z"
    / "spaq200_baseline_vs_experimental.csv"
)
V2_PILOT_CACHE = (
    _TOOLKIT
    / "workspace"
    / "experimental_quality"
    / "output"
    / "exp_eval_v2_20261108T123035Z"
    / "access_pilot_frozen_secondary.csv"
)
PILOT_CONSENSUS = (
    _TOOLKIT
    / "workspace"
    / "human_pilot"
    / "output"
    / "pilot_hvsm_20261108T114511Z"
    / "human_consensus_by_image.csv"
)
PILOT_ORIGINALS = _TOOLKIT / "workspace" / "human_pilot" / "facilitator" / "originals"
DEFAULT_OUT = _TOOLKIT / "workspace" / "experimental_quality" / "output"

CSV_COL = {
    "Sharpness": "sharpness",
    "Blur": "blur",
    "Noise": "noise",
    "Brightness": "brightness",
    "Contrast": "contrast",
    "Blocking Artifacts": "blocking_artifacts",
    "Ringing Artifacts": "ringing_artifacts",
}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _log(msg: str) -> None:
    print(msg, flush=True)


def load_csv_map(path: Path, key: str) -> dict[str, dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return {(row.get(key) or "").strip(): row for row in csv.DictReader(handle) if row.get(key)}


def _hist(values: list[int]) -> dict[str, int]:
    counts = Counter(int(v) for v in values)
    return {str(i): int(counts.get(i, 0)) for i in range(1, 6)}


def _corr(x: list[float], y: list[float]) -> dict[str, Any]:
    return pearson_spearman(x, y)


def _write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields: list[str] = []
    seen: set[str] = set()
    for row in rows:
        for key in row:
            if key not in seen:
                seen.add(key)
                fields.append(key)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def _append_checkpoint(path: Path, row: dict[str, Any], fields: list[str]) -> None:
    exists = path.is_file() and path.stat().st_size > 0
    with path.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        if not exists:
            writer.writeheader()
        writer.writerow(row)


def score_spaq_combined(
    out_dir: Path,
    *,
    limit: int | None = None,
    checkpoint_every: int = 10,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if not V2_SPAQ_CACHE.is_file():
        raise FileNotFoundError(f"Missing cached v2 SPAQ CSV: {V2_SPAQ_CACHE}")
    humans = load_csv_map(SPAQ_HUMAN, "media_id")
    cached = load_csv_map(V2_SPAQ_CACHE, "media_id")
    media_ids = sorted(humans.keys())
    if limit is not None:
        media_ids = media_ids[:limit]

    ckpt = out_dir / "spaq200_combined_checkpoint.csv"
    if ckpt.exists():
        ckpt.unlink()

    fields = [
        "media_id",
        "source_media_key",
        "status",
        "ms_combined",
        "combined_overall",
        "v2_overall",
        "baseline_overall",
        "mos_quality_raw",
        "attr_sharpness_raw",
        "attr_noisiness_raw",
        "attr_brightness_raw",
        "attr_contrast_raw",
    ]
    for name in CRITERIA:
        col = CSV_COL[name]
        fields.extend([f"combined_{col}", f"v2_{col}", f"baseline_{col}"])

    rows: list[dict[str, Any]] = []
    times: list[float] = []
    t0 = time.perf_counter()
    n = len(media_ids)
    _log(f"[SPAQ] scoring combined engine on {n} images (v2+production reused from cache)")

    for i, mid in enumerate(media_ids, start=1):
        hum = humans[mid]
        cache = cached.get(mid, {})
        key = hum.get("source_media_key") or cache.get("source_media_key") or ""
        path = SPAQ_IMAGES / key
        rec: dict[str, Any] = {
            "media_id": mid,
            "source_media_key": key,
            "mos_quality_raw": hum.get("mos_quality_raw", ""),
            "attr_sharpness_raw": hum.get("attr_sharpness_raw", ""),
            "attr_noisiness_raw": hum.get("attr_noisiness_raw", ""),
            "attr_brightness_raw": hum.get("attr_brightness_raw", ""),
            "attr_contrast_raw": hum.get("attr_contrast_raw", ""),
            "v2_overall": cache.get("experimental_overall", ""),
            "baseline_overall": cache.get("baseline_overall", ""),
        }
        for name in CRITERIA:
            col = CSV_COL[name]
            rec[f"v2_{col}"] = cache.get(f"experimental_{col}", "")
            rec[f"baseline_{col}"] = cache.get(f"baseline_{col}", "")

        if not path.is_file():
            rec["status"] = "missing"
            rows.append(rec)
            _append_checkpoint(ckpt, rec, fields)
            _log(f"[SPAQ] {i}/{n} {mid} MISSING")
            continue

        content = path.read_bytes()
        t1 = time.perf_counter()
        result = analyze_image_bytes(content)
        ms = (time.perf_counter() - t1) * 1000.0
        times.append(ms)
        if result is None:
            rec["status"] = "failed"
            rec["ms_combined"] = round(ms, 2)
            rows.append(rec)
            _append_checkpoint(ckpt, rec, fields)
            _log(f"[SPAQ] {i}/{n} {mid} FAILED ({ms:.0f} ms)")
            continue

        rec["status"] = "ok"
        rec["ms_combined"] = round(ms, 2)
        rec["combined_overall"] = result["overall_score"]
        for name in CRITERIA:
            col = CSV_COL[name]
            rec[f"combined_{col}"] = int(result["criterion_scores"][name])
        rows.append(rec)
        _append_checkpoint(ckpt, rec, fields)
        if i % checkpoint_every == 0 or i == n:
            _write_csv(out_dir / "spaq200_combined_vs_cached.csv", rows)
        _log(
            f"[SPAQ] {i}/{n} {mid} ok overall={rec['combined_overall']} "
            f"block={rec['combined_blocking_artifacts']} ring={rec['combined_ringing_artifacts']} "
            f"({ms:.0f} ms)"
        )

    ok = [r for r in rows if r.get("status") == "ok"]
    summary: dict[str, Any] = {
        "n_ok": len(ok),
        "n_requested": n,
        "wall_seconds": round(time.perf_counter() - t0, 3),
        "mean_ms_combined": float(np.mean(times)) if times else None,
        "badge_hist_combined": {
            name: _hist([int(r[f"combined_{CSV_COL[name]}"]) for r in ok]) for name in CRITERIA
        },
        "badge_hist_v2": {
            name: _hist([int(float(r[f"v2_{CSV_COL[name]}"])) for r in ok if str(r.get(f"v2_{CSV_COL[name]}")).strip()])
            for name in CRITERIA
        },
        "badge_hist_baseline": {
            name: _hist(
                [int(float(r[f"baseline_{CSV_COL[name]}"])) for r in ok if str(r.get(f"baseline_{CSV_COL[name]}")).strip()]
            )
            for name in CRITERIA
        },
        "correlations": {},
        "overall_vs_mos": {},
        "reused_v2_cache": str(V2_SPAQ_CACHE),
        "diagnostic_only": True,
    }

    # SPAQ attribute proxies (no Blur/Blocking/Ringing attrs).
    pairs = [
        ("Sharpness", "attr_sharpness_raw", "combined_sharpness", "v2_sharpness", "baseline_sharpness", False),
        ("Noise_cleanliness", "attr_noisiness_raw", "combined_noise", "v2_noise", "baseline_noise", True),
        ("Brightness", "attr_brightness_raw", "combined_brightness", "v2_brightness", "baseline_brightness", False),
        ("Contrast", "attr_contrast_raw", "combined_contrast", "v2_contrast", "baseline_contrast", False),
    ]
    for label, attr, c_key, v2_key, b_key, invert_attr in pairs:
        hx: list[float] = []
        cy: list[float] = []
        v2y: list[float] = []
        by: list[float] = []
        for r in ok:
            try:
                h = float(r[attr])
                if invert_attr:
                    h = 100.0 - h
                c = float(r[c_key])
                v2 = float(r[v2_key])
                b = float(r[b_key])
            except (TypeError, ValueError):
                continue
            hx.append(h)
            cy.append(c)
            v2y.append(v2)
            by.append(b)
        summary["correlations"][label] = {
            "combined_vs_human": _corr(hx, cy),
            "v2_vs_human": _corr(hx, v2y),
            "baseline_vs_human": _corr(hx, by),
        }

    mos_x: list[float] = []
    c_o: list[float] = []
    v2_o: list[float] = []
    b_o: list[float] = []
    for r in ok:
        try:
            mos_x.append(float(r["mos_quality_raw"]))
            c_o.append(float(r["combined_overall"]))
            v2_o.append(float(r["v2_overall"]))
            b_o.append(float(r["baseline_overall"]))
        except (TypeError, ValueError):
            continue
    summary["overall_vs_mos"] = {
        "note": "Exploratory only; overall is mean of seven badges, MOS is SPAQ overall.",
        "combined_vs_mos": _corr(mos_x, c_o),
        "v2_vs_mos": _corr(mos_x, v2_o),
        "baseline_vs_mos": _corr(mos_x, b_o),
        "mean_overall_combined": float(np.mean(c_o)) if c_o else None,
        "mean_overall_v2": float(np.mean(v2_o)) if v2_o else None,
        "mean_overall_baseline": float(np.mean(b_o)) if b_o else None,
    }
    _write_csv(out_dir / "spaq200_combined_vs_cached.csv", rows)
    return rows, summary


def score_pilot_combined(out_dir: Path) -> dict[str, Any]:
    if not PILOT_CONSENSUS.is_file():
        return {"available": False}
    if not V2_PILOT_CACHE.is_file():
        return {"available": False, "error": f"missing {V2_PILOT_CACHE}"}

    consensus = load_csv_map(PILOT_CONSENSUS, "media_id")
    cached = load_csv_map(V2_PILOT_CACHE, "media_id")
    rows: list[dict[str, Any]] = []
    times: list[float] = []
    ckpt = out_dir / "access_pilot_combined_checkpoint.csv"
    if ckpt.exists():
        ckpt.unlink()

    fields = ["media_id", "status", "ms_combined", "combined_overall", "v2_overall", "baseline_overall"]
    for name in CRITERIA:
        col = CSV_COL[name]
        fields.extend([f"human_{col}", f"combined_{col}", f"v2_{col}", f"baseline_{col}"])

    media_ids = sorted(consensus.keys())
    n = len(media_ids)
    _log(f"[PILOT] scoring combined engine on {n} frozen ACCESS images")
    t0 = time.perf_counter()

    for i, mid in enumerate(media_ids, start=1):
        path = PILOT_ORIGINALS / f"{mid}.jpg"
        cache = cached.get(mid, {})
        cons = consensus[mid]
        rec: dict[str, Any] = {
            "media_id": mid,
            "v2_overall": cache.get("experimental_overall", ""),
            "baseline_overall": cache.get("baseline_overall", ""),
        }
        for name in CRITERIA:
            col = CSV_COL[name]
            rec[f"human_{col}"] = cons.get(f"{col}_median", "")
            rec[f"v2_{col}"] = cache.get(f"experimental_{col}", "")
            rec[f"baseline_{col}"] = cache.get(f"baseline_{col}", "")

        if not path.is_file():
            rec["status"] = "missing"
            rows.append(rec)
            _append_checkpoint(ckpt, rec, fields)
            _log(f"[PILOT] {i}/{n} {mid} MISSING")
            continue

        t1 = time.perf_counter()
        result = analyze_image_bytes(path.read_bytes())
        ms = (time.perf_counter() - t1) * 1000.0
        times.append(ms)
        if result is None:
            rec["status"] = "failed"
            rec["ms_combined"] = round(ms, 2)
            rows.append(rec)
            _append_checkpoint(ckpt, rec, fields)
            _log(f"[PILOT] {i}/{n} {mid} FAILED")
            continue

        rec["status"] = "ok"
        rec["ms_combined"] = round(ms, 2)
        rec["combined_overall"] = result["overall_score"]
        for name in CRITERIA:
            col = CSV_COL[name]
            rec[f"combined_{col}"] = int(result["criterion_scores"][name])
        rows.append(rec)
        _append_checkpoint(ckpt, rec, fields)
        _write_csv(out_dir / "access_pilot_combined_vs_cached.csv", rows)
        _log(
            f"[PILOT] {i}/{n} {mid} ok overall={rec['combined_overall']} "
            f"block={rec['combined_blocking_artifacts']} ring={rec['combined_ringing_artifacts']} "
            f"({ms:.0f} ms)"
        )

    ok = [r for r in rows if r.get("status") == "ok"]
    corrs: dict[str, Any] = {}
    for name in CRITERIA:
        col = CSV_COL[name]
        hx: list[float] = []
        cy: list[float] = []
        v2y: list[float] = []
        by: list[float] = []
        for r in ok:
            try:
                hx.append(float(r[f"human_{col}"]))
                cy.append(float(r[f"combined_{col}"]))
                v2y.append(float(r[f"v2_{col}"]))
                by.append(float(r[f"baseline_{col}"]))
            except (TypeError, ValueError):
                continue
        corrs[name] = {
            "combined_vs_human": _corr(hx, cy),
            "v2_vs_human": _corr(hx, v2y),
            "baseline_vs_human": _corr(hx, by),
        }

    # Overall vs human overall median if present in consensus via joined cache fields.
    # Consensus CSV uses overall_visual_quality_median.
    overall_h: list[float] = []
    overall_c: list[float] = []
    overall_v2: list[float] = []
    overall_b: list[float] = []
    for r in ok:
        mid = r["media_id"]
        try:
            overall_h.append(float(consensus[mid]["overall_visual_quality_median"]))
            overall_c.append(float(r["combined_overall"]))
            overall_v2.append(float(r["v2_overall"]))
            overall_b.append(float(r["baseline_overall"]))
        except (TypeError, ValueError, KeyError):
            continue

    # Skill-classification risk: how often overall mean is pulled by single harsh heads.
    harsh_pull: list[dict[str, Any]] = []
    for r in ok:
        badges = [int(r[f"combined_{CSV_COL[name]}"]) for name in CRITERIA]
        overall = float(r["combined_overall"])
        mn = min(badges)
        if mn <= 2 and overall <= 3.5:
            harsh_pull.append(
                {
                    "media_id": r["media_id"],
                    "overall": overall,
                    "min_badge": mn,
                    "badges": {name: int(r[f"combined_{CSV_COL[name]}"]) for name in CRITERIA},
                }
            )

    summary = {
        "available": True,
        "role": "frozen_secondary_check_not_for_tuning",
        "n": len(ok),
        "wall_seconds": round(time.perf_counter() - t0, 3),
        "mean_ms_combined": float(np.mean(times)) if times else None,
        "correlations": corrs,
        "overall_vs_human": {
            "combined": _corr(overall_h, overall_c),
            "v2": _corr(overall_h, overall_v2),
            "baseline": _corr(overall_h, overall_b),
        },
        "badge_hist_combined": {
            name: _hist([int(r[f"combined_{CSV_COL[name]}"]) for r in ok]) for name in CRITERIA
        },
        "mean_overall_combined": float(np.mean(overall_c)) if overall_c else None,
        "mean_overall_v2": float(np.mean(overall_v2)) if overall_v2 else None,
        "mean_overall_baseline": float(np.mean(overall_b)) if overall_b else None,
        "misleading_feedback_flags": {
            "n_images_with_min_badge_le_2_and_overall_le_3_5": len(harsh_pull),
            "examples": harsh_pull[:8],
            "note": (
                "Mean-of-seven overall can look mediocre when one defect head (e.g. Blocking/Ringing) "
                "is harsh while humans rate the photo as generally good. Risk for member feedback / "
                "skill-adjacent messaging if overall is shown as a single grade."
            ),
        },
        "reused_v2_cache": str(V2_PILOT_CACHE),
        "disclaimer": "ACCESS pilot was not used to choose the combined composition.",
    }
    _write_csv(out_dir / "access_pilot_combined_vs_cached.csv", rows)
    return summary


def build_recommendation(spaq: dict[str, Any], pilot: dict[str, Any]) -> dict[str, Any]:
    improvements: list[str] = []
    regressions: list[str] = []
    unresolved: list[str] = []

    # SPAQ: Sharpness/Brightness/Contrast/Noise should match v2 (same estimators).
    for label in ("Sharpness", "Brightness", "Contrast", "Noise_cleanliness"):
        block = (spaq.get("correlations") or {}).get(label) or {}
        c = (block.get("combined_vs_human") or {}).get("spearman_r")
        v = (block.get("v2_vs_human") or {}).get("spearman_r")
        if c is not None and v is not None and abs(c - v) > 0.03:
            regressions.append(f"SPAQ {label}: combined ρ={c:.3f} drifted from v2 ρ={v:.3f}")

    if pilot.get("available"):
        for name in CRITERIA:
            block = (pilot.get("correlations") or {}).get(name) or {}
            c = (block.get("combined_vs_human") or {}).get("spearman_r")
            v = (block.get("v2_vs_human") or {}).get("spearman_r")
            b = (block.get("baseline_vs_human") or {}).get("spearman_r")
            if name in ("Blocking Artifacts", "Ringing Artifacts"):
                if c is not None and v is not None and c > v + 0.05:
                    improvements.append(f"Pilot {name}: combined ρ={c:.3f} > v2 ρ={v:.3f}")
                elif c is not None and c < 0:
                    unresolved.append(f"Pilot {name}: still non-positive vs humans (ρ={c:.3f})")
                elif c is not None and v is not None and c < v - 0.05:
                    regressions.append(f"Pilot {name}: combined ρ={c:.3f} < v2 ρ={v:.3f}")
            else:
                if c is not None and v is not None and abs(c - v) > 0.02:
                    regressions.append(f"Pilot {name}: unexpected drift combined ρ={c:.3f} vs v2 ρ={v:.3f}")
            if name == "Noise" and c is not None and c < 0:
                unresolved.append(f"Pilot Noise remains wrong-signed/inconclusive (ρ={c:.3f}); Noise v3 not promoted")

    flags = (pilot.get("misleading_feedback_flags") or {}) if pilot.get("available") else {}
    n_harsh = flags.get("n_images_with_min_badge_le_2_and_overall_le_3_5", 0)

    if not regressions and any("Blocking" in s or "Ringing" in s for s in improvements):
        rec = (
            "Keep combined_v1 as the active research candidate for further diagnostic work. "
            "Do not ship to production: Blocking/Ringing human alignment remains provisional, "
            "Noise is unresolved, and mean-of-seven overall can mislead member feedback."
        )
        verdict = "RESEARCH_CANDIDATE"
    elif unresolved or regressions:
        rec = (
            "combined_v1 is a useful integration checkpoint but is not ready for production. "
            "Keep v2 as the parent baseline; treat Blocking/Ringing v3 as research modules; "
            "do not use overall mean for skill classification."
        )
        verdict = "HOLD"
    else:
        rec = (
            "combined_v1 integrates cleanly. Still research-only pending a disjoint ACCESS-rubric "
            "holdout and an explicit overall aggregation policy."
        )
        verdict = "RESEARCH_CANDIDATE"

    return {
        "verdict": verdict,
        "recommendation": rec,
        "improvements": improvements,
        "regressions": regressions,
        "unresolved": unresolved,
        "overall_feedback_risk": {
            "pilot_harsh_pull_count": n_harsh,
            "guidance": (
                "Do not map mean-of-seven overall directly to member skill tiers. "
                "Prefer per-criterion feedback; if an overall is shown, disclose it is an unweighted "
                "mean of proxies and can be dragged by a single defect head."
            ),
        },
        "limitations": [
            "SPAQ has no Blur/Blocking/Ringing attribute labels.",
            "ACCESS pilot n=30 is frozen secondary evidence, not tuning or final validation.",
            "Composition selected from prior research modules; these eval correlations are diagnostic only.",
            "Noise v3 not promoted (SPAQ/pilot tradeoffs unresolved).",
            "Combined computes v2's five retained heads only; Blocking/Ringing use v3 estimators (Blocking center-crops to ANALYSIS_CAP).",
        ],
    }


def write_report(path: Path, payload: dict[str, Any]) -> None:
    spaq = payload["spaq_summary"]
    pilot = payload["access_pilot"]
    rec = payload["integration_recommendation"]
    lines = [
        "# Combined experimental engine evaluation",
        "",
        f"Generated (UTC): {payload['generated_at']}",
        f"Engine: `{payload['engine_id']}`",
        f"Verdict: **{rec['verdict']}**",
        "",
        "## Composition",
        "- Sharpness / Blur / Noise / Brightness / Contrast: `experimental_classical_v2`",
        "- Blocking Artifacts: `experimental_blocking_v3`",
        "- Ringing Artifacts: `experimental_ringing_v3`",
        "- Noise v3: alternate, not promoted",
        "",
        "## Safety",
        "- Production / Flutter / API / DB / human CSVs unchanged.",
        "- Prior engine sources unchanged.",
        "- SPAQ + pilot used diagnostically only (not for selecting thresholds).",
        "",
        "## SPAQ-200 (diagnostic)",
        f"- n_ok: {spaq.get('n_ok')}",
        f"- mean ms/image combined: {spaq.get('mean_ms_combined')}",
        f"- wall seconds: {spaq.get('wall_seconds')}",
        f"- reused v2 cache: `{spaq.get('reused_v2_cache')}`",
        "",
    ]
    for label, block in (spaq.get("correlations") or {}).items():
        c = (block.get("combined_vs_human") or {}).get("spearman_r")
        v = (block.get("v2_vs_human") or {}).get("spearman_r")
        b = (block.get("baseline_vs_human") or {}).get("spearman_r")
        lines.append(f"- {label}: combined ρ={c} | v2 ρ={v} | production ρ={b}")
    ov = spaq.get("overall_vs_mos") or {}
    lines.extend(
        [
            "",
            f"- Overall vs MOS: combined ρ={(ov.get('combined_vs_mos') or {}).get('spearman_r')} | "
            f"v2 ρ={(ov.get('v2_vs_mos') or {}).get('spearman_r')} | "
            f"production ρ={(ov.get('baseline_vs_mos') or {}).get('spearman_r')}",
            "",
            "## ACCESS pilot (frozen secondary)",
        ]
    )
    if pilot.get("available"):
        lines.append(f"- n: {pilot.get('n')} | mean ms: {pilot.get('mean_ms_combined')}")
        for name, block in (pilot.get("correlations") or {}).items():
            c = (block.get("combined_vs_human") or {}).get("spearman_r")
            v = (block.get("v2_vs_human") or {}).get("spearman_r")
            b = (block.get("baseline_vs_human") or {}).get("spearman_r")
            lines.append(f"- {name}: combined ρ={c} | v2 ρ={v} | production ρ={b}")
        oh = pilot.get("overall_vs_human") or {}
        lines.append(
            f"- Overall vs human: combined ρ={(oh.get('combined') or {}).get('spearman_r')} | "
            f"v2 ρ={(oh.get('v2') or {}).get('spearman_r')} | "
            f"production ρ={(oh.get('baseline') or {}).get('spearman_r')}"
        )
        flags = pilot.get("misleading_feedback_flags") or {}
        lines.append(
            f"- Overall feedback risk flags (min≤2 & overall≤3.5): {flags.get('n_images_with_min_badge_le_2_and_overall_le_3_5')}"
        )
    else:
        lines.append("- Pilot unavailable.")

    lines.extend(["", "## Improvements"])
    lines.extend([f"- {x}" for x in rec["improvements"]] or ["- (none clear)"])
    lines.extend(["", "## Regressions"])
    lines.extend([f"- {x}" for x in rec["regressions"]] or ["- (none clear)"])
    lines.extend(["", "## Unresolved"])
    lines.extend([f"- {x}" for x in rec["unresolved"]] or ["- (none listed)"])
    lines.extend(["", "## Limitations"])
    lines.extend([f"- {x}" for x in rec["limitations"]])
    lines.extend(
        [
            "",
            "## Overall / skill-classification guidance",
            rec["overall_feedback_risk"]["guidance"],
            "",
            "## Recommendation",
            rec["recommendation"],
            "",
            "Do not integrate into production without approval.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--limit", type=int, default=None, help="Optional SPAQ image limit")
    parser.add_argument("--skip-spaq", action="store_true")
    parser.add_argument("--skip-pilot", action="store_true")
    parser.add_argument("--checkpoint-every", type=int, default=10)
    args = parser.parse_args(argv)

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = args.output_root / f"combined_v1_eval_{stamp}"
    out_dir.mkdir(parents=True, exist_ok=False)
    _log(f"[START] combined engine eval → {out_dir}")
    _log(f"[ENGINE] {ENGINE_ID}")
    _log("[NOTE] Progress is printed per image; SPAQ/pilot are diagnostic only.")

    spaq_summary: dict[str, Any] = {"skipped": True}
    if not args.skip_spaq:
        _, spaq_summary = score_spaq_combined(
            out_dir, limit=args.limit, checkpoint_every=args.checkpoint_every
        )
        (out_dir / "spaq_summary.json").write_text(
            json.dumps(spaq_summary, indent=2, default=str), encoding="utf-8"
        )

    pilot: dict[str, Any] = {"available": False, "skipped": True}
    if not args.skip_pilot:
        pilot = score_pilot_combined(out_dir)
        (out_dir / "pilot_summary.json").write_text(
            json.dumps({k: v for k, v in pilot.items()}, indent=2, default=str),
            encoding="utf-8",
        )

    recommendation = build_recommendation(
        spaq_summary if not spaq_summary.get("skipped") else {},
        pilot if pilot.get("available") else {},
    )
    payload = {
        "generated_at": _now(),
        "engine_id": ENGINE_ID,
        "output_dir": str(out_dir),
        "spaq_summary": spaq_summary,
        "access_pilot": {k: v for k, v in pilot.items()},
        "integration_recommendation": recommendation,
        "production_modified": False,
        "prior_engines_modified": False,
        "fitted_on_spaq": False,
        "fitted_on_access_pilot": False,
    }
    (out_dir / "combined_v1_eval.json").write_text(
        json.dumps(payload, indent=2, default=str), encoding="utf-8"
    )
    write_report(out_dir / "COMBINED_V1_EVAL_REPORT.md", payload)
    _log(
        json.dumps(
            {
                "status": "ok",
                "output_dir": str(out_dir),
                "verdict": recommendation["verdict"],
                "recommendation": recommendation["recommendation"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
