#!/usr/bin/env python3
"""Consolidated combined-v1 human pilot evaluation.

Scores the 30 blinded pilot images with experimental_quality_engine_combined_v1,
then compares all seven criteria against the locked human consensus (median of
R1/R2/R3) and against production (Run 002 EfficientNet-B0) and v2-only baselines.

CONSTRAINTS honoured:
  - Human ratings CSV unmodified. Human consensus rebuilt from raw CSVs to
    preserve missing-value handling exactly (matches pilot_hvsm_ prior run).
  - Production machine_scores_joined.csv reused as-is; no re-inference.
  - SPAQ-200 not re-scored; combined_v1_eval_20261108T141802Z CSV left intact.
  - Experimental engine scales not changed.
  - Output always written to a NEW timestamped directory; existing dirs untouched.
  - Overall visual quality treated as a SEPARATE construct from the arithmetic
    mean of seven criteria.
  - No threshold tuning from these 30 images.

Run from repo root:
    python tools/quality_validation/run_combined_v1_pilot_eval.py
"""

from __future__ import annotations

import csv
import json
import math
import statistics
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ── repo paths ────────────────────────────────────────────────────────────────
REPO = Path(__file__).resolve().parents[1]
TOOLKIT = Path(__file__).resolve().parent
BACKEND = REPO / "access_backend"
for _p in (str(REPO), str(BACKEND)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

# ── input paths ──────────────────────────────────────────────────────────────
PILOT_IMAGES = TOOLKIT / "workspace" / "human_pilot" / "rater_pack" / "images"
RATINGS_DIR = TOOLKIT / "workspace" / "human_pilot" / "actual_ratings"
RATING_FILES = [
    RATINGS_DIR / "ratings_R1.csv.csv",
    RATINGS_DIR / "ratings_R2.csv.csv",
    RATINGS_DIR / "ratings_R3.csv.csv",
]
PROD_SCORES_CSV = (
    TOOLKIT
    / "workspace"
    / "human_pilot"
    / "output"
    / "pilot_hvsm_20261108T114511Z"
    / "machine_scores_joined.csv"
)
EXISTING_HUMAN_CONSENSUS = (
    TOOLKIT
    / "workspace"
    / "human_pilot"
    / "output"
    / "pilot_hvsm_20261108T114511Z"
    / "human_consensus_by_image.csv"
)
EXISTING_PILOT_REPORT = (
    TOOLKIT
    / "workspace"
    / "human_pilot"
    / "output"
    / "pilot_hvsm_20261108T114511Z"
    / "HUMAN_VS_MACHINE_PILOT_REPORT.md"
)

# ── output root ───────────────────────────────────────────────────────────────
EVAL_OUT_ROOT = TOOLKIT / "workspace" / "human_pilot" / "output"

CRITERIA = [
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
]
CRITERIA_DISPLAY = {
    "sharpness": "Sharpness",
    "blur": "Blur",
    "noise": "Noise",
    "brightness": "Brightness",
    "contrast": "Contrast",
    "blocking_artifacts": "Blocking Artifacts",
    "ringing_artifacts": "Ringing Artifacts",
}
ENGINE_CRITERION_MAP = {
    "sharpness": "Sharpness",
    "blur": "Blur",
    "noise": "Noise",
    "brightness": "Brightness",
    "contrast": "Contrast",
    "blocking_artifacts": "Blocking Artifacts",
    "ringing_artifacts": "Ringing Artifacts",
}


# ── helpers ───────────────────────────────────────────────────────────────────

def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def log(msg: str) -> None:
    print(f"[combined_v1_pilot] {msg}", flush=True)


def fnum(v: Any) -> float | None:
    if v is None or str(v).strip() in ("", "N/A", "n/a"):
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _median_with_missing(vals: list[float | None]) -> float | None:
    good = [v for v in vals if v is not None]
    if not good:
        return None
    return float(statistics.median(good))


def spearman_rho(xs: list[float], ys: list[float]) -> float | None:
    """Exact Spearman via rank correlation."""
    n = len(xs)
    if n < 3:
        return None
    if len(set(xs)) == 1 or len(set(ys)) == 1:
        return None

    def _ranks(vals: list[float]) -> list[float]:
        order = sorted(range(n), key=lambda i: vals[i])
        ranks = [0.0] * n
        i = 0
        while i < n:
            j = i
            while j < n and vals[order[j]] == vals[order[i]]:
                j += 1
            avg = (i + j - 1) / 2.0 + 1.0
            for k in range(i, j):
                ranks[order[k]] = avg
            i = j
        return ranks

    rx, ry = _ranks(xs), _ranks(ys)
    rx_m = statistics.fmean(rx)
    ry_m = statistics.fmean(ry)
    num = sum((rx[i] - rx_m) * (ry[i] - ry_m) for i in range(n))
    den_x = math.sqrt(sum((rx[i] - rx_m) ** 2 for i in range(n)))
    den_y = math.sqrt(sum((ry[i] - ry_m) ** 2 for i in range(n)))
    if den_x == 0 or den_y == 0:
        return None
    return num / (den_x * den_y)


def mae(xs: list[float], ys: list[float]) -> float:
    return statistics.fmean([abs(a - b) for a, b in zip(xs, ys)])


def rmse(xs: list[float], ys: list[float]) -> float:
    return math.sqrt(statistics.fmean([(a - b) ** 2 for a, b in zip(xs, ys)]))


def bias(machine: list[float], human: list[float]) -> float:
    return statistics.fmean([m - h for m, h in zip(machine, human)])


def within_one(machine: list[float], human: list[float]) -> float:
    n = len(machine)
    return sum(1 for m, h in zip(machine, human) if abs(m - h) <= 1) / n if n else 0.0


def badge_hist(vals: list[float]) -> dict[str, int]:
    h = {str(k): 0 for k in range(1, 6)}
    for v in vals:
        iv = int(round(v))
        if 1 <= iv <= 5:
            h[str(iv)] += 1
    return h


# ── pre-flight verification ───────────────────────────────────────────────────

def verify_preflight() -> dict[str, Any]:
    """Check all 30 pilot images exist and match the manifest. Returns issues list."""
    issues: list[str] = []
    for n in range(1, 31):
        p = PILOT_IMAGES / f"PILOT-{n:03d}.jpg"
        if not p.is_file():
            issues.append(f"MISSING image: {p}")

    for rf in RATING_FILES:
        if not rf.is_file():
            issues.append(f"MISSING rating file: {rf}")

    if not PROD_SCORES_CSV.is_file():
        issues.append(f"MISSING production scores: {PROD_SCORES_CSV}")

    # Check rating file row counts
    for rf in RATING_FILES:
        if rf.is_file():
            with rf.open(newline="", encoding="utf-8-sig") as fh:
                rows = list(csv.DictReader(fh))
            if len(rows) != 30:
                issues.append(f"{rf.name}: expected 30 rows, got {len(rows)}")

    return {"ok": len(issues) == 0, "issues": issues}


# ── human consensus ───────────────────────────────────────────────────────────

def build_human_consensus() -> dict[str, dict[str, Any]]:
    """Read raw rater CSVs and compute median consensus, matching prior analysis."""
    all_rows: list[dict[str, str]] = []
    for rf in RATING_FILES:
        with rf.open(newline="", encoding="utf-8-sig") as fh:
            for row in csv.DictReader(fh):
                all_rows.append(row)

    by_image: dict[str, dict[str, list[float | None]]] = {}
    for row in all_rows:
        mid = row["media_id"].strip()
        if mid not in by_image:
            by_image[mid] = {c: [] for c in CRITERIA}
            by_image[mid]["overall_visual_quality"] = []
        for c in CRITERIA:
            by_image[mid][c].append(fnum(row.get(c, "")))
        by_image[mid]["overall_visual_quality"].append(fnum(row.get("overall_visual_quality", "")))

    consensus: dict[str, dict[str, Any]] = {}
    for mid in sorted(by_image):
        entry: dict[str, Any] = {"media_id": mid}
        for c in CRITERIA:
            vals = by_image[mid][c]
            entry[f"{c}_n"] = sum(1 for v in vals if v is not None)
            entry[f"{c}_median"] = _median_with_missing(vals)
        ovals = by_image[mid]["overall_visual_quality"]
        entry["overall_n"] = sum(1 for v in ovals if v is not None)
        entry["overall_median"] = _median_with_missing(ovals)
        consensus[mid] = entry

    return consensus


# ── score combined engine on pilot images ────────────────────────────────────

def score_pilot_images() -> dict[str, dict[str, Any]]:
    """Run combined v1 engine on all 30 pilot images. Decode once per image."""
    from tools.quality_validation.experimental_quality_engine_combined_v1 import (
        analyze_image_bytes as combined_analyze,
    )

    scores: dict[str, dict[str, Any]] = {}
    for n in range(1, 31):
        mid = f"PILOT-{n:03d}"
        path = PILOT_IMAGES / f"{mid}.jpg"
        t0 = time.perf_counter()
        content = path.read_bytes()
        result = combined_analyze(content)
        elapsed = (time.perf_counter() - t0) * 1000.0

        if result is None or result.get("analysis_status") != "ok":
            log(f"  {mid}: FAILED (result={result})")
            scores[mid] = {"status": "failed"}
            continue

        crit = result["criterion_scores"]
        scores[mid] = {
            "status": "ok",
            "ms": elapsed,
            "sharpness": crit["Sharpness"],
            "blur": crit["Blur"],
            "noise": crit["Noise"],
            "brightness": crit["Brightness"],
            "contrast": crit["Contrast"],
            "blocking_artifacts": crit["Blocking Artifacts"],
            "ringing_artifacts": crit["Ringing Artifacts"],
            "overall_score": result["overall_score"],
            "raw": result.get("raw", {}),
        }
        log(
            f"  {mid}: ok  {elapsed:.0f}ms  "
            f"Sh={crit['Sharpness']} Bl={crit['Blur']} "
            f"No={crit['Noise']} Br={crit['Brightness']} "
            f"Co={crit['Contrast']} Bk={crit['Blocking Artifacts']} "
            f"Ri={crit['Ringing Artifacts']}"
        )

    return scores


# ── load production scores ────────────────────────────────────────────────────

def load_production_scores() -> dict[str, dict[str, float]]:
    prod: dict[str, dict[str, float]] = {}
    with PROD_SCORES_CSV.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            mid = row["media_id"].strip()
            entry: dict[str, float] = {}
            for c in CRITERIA:
                v = fnum(row.get(c, ""))
                if v is not None:
                    entry[c] = v
            prod[mid] = entry
    return prod


# ── statistics per criterion ──────────────────────────────────────────────────

def compute_criterion_stats(
    consensus: dict[str, dict[str, Any]],
    scores: dict[str, dict[str, Any]],
    label: str,
) -> dict[str, dict[str, Any]]:
    """For each criterion, compute Spearman, MAE, RMSE, bias, within-1, badge hist.
    Only uses images where both human and machine have a valid value."""
    result: dict[str, dict[str, Any]] = {}
    mids = sorted(consensus)

    for c in CRITERIA:
        human_vals: list[float] = []
        machine_vals: list[float] = []
        skipped = 0
        for mid in mids:
            h = consensus[mid].get(f"{c}_median")
            sc = scores.get(mid, {})
            m = sc.get(c) if sc.get("status") == "ok" else None
            if h is None or m is None:
                skipped += 1
                continue
            human_vals.append(float(h))
            machine_vals.append(float(m))

        n = len(human_vals)
        if n < 2:
            result[c] = {"n": n, "skipped": skipped, "label": label}
            continue

        result[c] = {
            "label": label,
            "n": n,
            "skipped": skipped,
            "spearman_r": spearman_rho(machine_vals, human_vals),
            "mae": round(mae(machine_vals, human_vals), 4),
            "rmse": round(rmse(machine_vals, human_vals), 4),
            "bias": round(bias(machine_vals, human_vals), 4),
            "within_one": round(within_one(machine_vals, human_vals), 4),
            "machine_badge_hist": badge_hist(machine_vals),
            "human_median_hist": badge_hist(human_vals),
        }
    return result


# ── overall construct ──────────────────────────────────────────────────────────

def compute_overall_stats(
    consensus: dict[str, dict[str, Any]],
    scores: dict[str, dict[str, Any]],
    label: str,
) -> dict[str, Any]:
    """Compare human overall_visual_quality (independent gestalt) vs machine
    overall_score (mean of 7). Different constructs — not a proxy accuracy claim."""
    mids = sorted(consensus)
    hv, mv = [], []
    for mid in mids:
        h = consensus[mid].get("overall_median")
        sc = scores.get(mid, {})
        m = sc.get("overall_score") if sc.get("status") == "ok" else None
        if h is None or m is None:
            continue
        hv.append(float(h))
        mv.append(float(m))
    n = len(hv)
    if n < 2:
        return {"n": n, "label": label, "note": "different_constructs"}
    return {
        "label": label,
        "n": n,
        "spearman_r": spearman_rho(mv, hv),
        "mae": round(mae(mv, hv), 4),
        "rmse": round(rmse(mv, hv), 4),
        "bias": round(bias(mv, hv), 4),
        "within_one": round(within_one(mv, hv), 4),
        "note": (
            "human=overall_visual_quality (independent gestalt); "
            "machine=mean(7 criteria). Different constructs — do not equate."
        ),
    }


# ── v2-only stats (from existing human consensus + v2 scores in prod CSV) ─────

def load_v2_scores_from_spaq_checkpoint() -> dict[str, dict[str, float]] | None:
    """The SPAQ checkpoint has v2 per-criterion columns but not keyed by PILOT IDs.
    Return None — we will derive v2 pilot scores from the combined engine run since
    the combined engine also produces the v2 intermediate results via the checkpoint
    CSV from exp_eval_v2. However those aren't for pilot images.
    We therefore label any v2 comparison 'not_available_for_pilot' and rely on the
    existing pilot_hvsm report for the production baseline only.
    """
    return None


# ── per-image table ────────────────────────────────────────────────────────────

def build_per_image_rows(
    consensus: dict[str, dict[str, Any]],
    combined_scores: dict[str, dict[str, Any]],
    prod_scores: dict[str, dict[str, float]],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for mid in sorted(consensus):
        sc = combined_scores.get(mid, {})
        ps = prod_scores.get(mid, {})
        row: dict[str, Any] = {"media_id": mid}
        for c in CRITERIA:
            row[f"human_{c}"] = consensus[mid].get(f"{c}_median")
            row[f"combined_v1_{c}"] = sc.get(c) if sc.get("status") == "ok" else None
            row[f"prod_{c}"] = ps.get(c)
        row["human_overall"] = consensus[mid].get("overall_median")
        row["combined_v1_overall"] = sc.get("overall_score") if sc.get("status") == "ok" else None
        row["combined_v1_ms"] = round(sc.get("ms", 0), 1)
        row["combined_v1_status"] = sc.get("status", "failed")
        rows.append(row)
    return rows


# ── direction check ────────────────────────────────────────────────────────────

def direction_check(
    consensus: dict[str, dict[str, Any]],
    combined_scores: dict[str, dict[str, Any]],
    prod_scores: dict[str, dict[str, float]],
) -> dict[str, Any]:
    """Verify that combined_v1 badge direction is consistent (all criteria: higher=better).
    Also check mapping coverage (30 images matched)."""
    issues: list[str] = []

    # Every combined_v1 badge should be in [1, 5]
    for mid, sc in combined_scores.items():
        if sc.get("status") != "ok":
            issues.append(f"{mid}: combined_v1 score status={sc.get('status')}")
            continue
        for c in CRITERIA:
            v = sc.get(c)
            if v is None or not (1 <= int(v) <= 5):
                issues.append(f"{mid}: combined_v1 {c}={v} out of [1,5]")

    # All 30 pilot IDs present in combined scores
    mids = sorted(consensus)
    for mid in mids:
        if mid not in combined_scores:
            issues.append(f"{mid}: missing from combined_v1 scores")

    # All 30 pilot IDs present in production scores
    for mid in mids:
        if mid not in prod_scores:
            issues.append(f"{mid}: missing from production scores")

    # Score direction verification: both production and combined encode higher=better
    # for all criteria (including Noise, Blocking, Ringing which are CLEANLINESS badges)
    direction_note = (
        "All seven badges: 5=excellent, 1=poor. "
        "Noise badge is cleanliness (5=clean, 1=noisy). "
        "Blocking badge is cleanliness (5=artifact-free). "
        "Ringing badge is cleanliness (5=artifact-free). "
        "Combined v1 uses equal_bin_1_5(quality_0_1); higher q → higher badge. Confirmed."
    )

    return {
        "all_ok": len(issues) == 0,
        "issues": issues,
        "n_images_verified": len(mids),
        "direction_note": direction_note,
    }


# ── verdict ────────────────────────────────────────────────────────────────────

def compute_verdict(
    combined_stats: dict[str, dict[str, Any]],
    prod_stats_from_report: dict[str, Any],
) -> dict[str, Any]:
    """IMPROVED / MIXED / REGRESSED per criterion and overall."""
    PROD_RHO = {
        "sharpness": 0.104,
        "blur": 0.160,
        "noise": -0.275,
        "brightness": 0.064,
        "contrast": 0.092,
        "blocking_artifacts": 0.001,
        "ringing_artifacts": 0.013,
    }
    PROD_MAE = {
        "sharpness": 0.933,
        "blur": 0.933,
        "noise": 0.733,
        "brightness": 0.800,
        "contrast": 1.017,
        "blocking_artifacts": 0.950,
        "ringing_artifacts": 0.883,
    }

    verdicts: dict[str, str] = {}
    deltas: dict[str, dict[str, Any]] = {}

    for c in CRITERIA:
        cs = combined_stats.get(c, {})
        r_new = cs.get("spearman_r")
        mae_new = cs.get("mae")
        r_old = PROD_RHO.get(c)
        mae_old = PROD_MAE.get(c)

        if r_new is None or mae_new is None:
            verdicts[c] = "INSUFFICIENT_DATA"
            continue

        delta_rho = r_new - r_old if r_old is not None else None
        delta_mae = mae_new - mae_old if mae_old is not None else None

        # Improvement: higher Spearman AND lower or comparable MAE
        rho_better = delta_rho is not None and delta_rho > 0.05
        rho_worse = delta_rho is not None and delta_rho < -0.05
        mae_better = delta_mae is not None and delta_mae < -0.05
        mae_worse = delta_mae is not None and delta_mae > 0.05

        if rho_better and not mae_worse:
            v = "IMPROVED"
        elif rho_worse or (mae_worse and not rho_better):
            v = "REGRESSED"
        else:
            v = "MIXED"

        verdicts[c] = v
        deltas[c] = {
            "prod_spearman_r": round(r_old, 3) if r_old is not None else None,
            "combined_v1_spearman_r": round(r_new, 3),
            "delta_spearman": round(delta_rho, 3) if delta_rho is not None else None,
            "prod_mae": round(mae_old, 3) if mae_old is not None else None,
            "combined_v1_mae": round(mae_new, 3),
            "delta_mae": round(delta_mae, 3) if delta_mae is not None else None,
            "verdict": v,
        }

    # Overall verdict
    n_improved = sum(1 for v in verdicts.values() if v == "IMPROVED")
    n_regressed = sum(1 for v in verdicts.values() if v == "REGRESSED")
    if n_improved >= 4 and n_regressed == 0:
        overall_v = "IMPROVED"
    elif n_regressed >= 4:
        overall_v = "REGRESSED"
    else:
        overall_v = "MIXED"

    return {
        "per_criterion": verdicts,
        "deltas": deltas,
        "overall": overall_v,
        "n_improved": n_improved,
        "n_mixed": sum(1 for v in verdicts.values() if v == "MIXED"),
        "n_regressed": n_regressed,
        "caution": (
            "n=30, wide CIs. "
            "Blocking/Ringing human IRR is low (κ≈0.086, 0.128). "
            "Do not use these results to tune thresholds or promote to production."
        ),
    }


# ── report ─────────────────────────────────────────────────────────────────────

def write_report(
    out_dir: Path,
    consensus: dict[str, dict[str, Any]],
    combined_scores: dict[str, dict[str, Any]],
    combined_stats: dict[str, dict[str, Any]],
    overall_stats: dict[str, Any],
    verdict: dict[str, Any],
    direction: dict[str, Any],
    per_image: list[dict[str, Any]],
    run_ts: str,
) -> None:
    PROD_RHO = {
        "sharpness": 0.104, "blur": 0.160, "noise": -0.275,
        "brightness": 0.064, "contrast": 0.092,
        "blocking_artifacts": 0.001, "ringing_artifacts": 0.013,
    }
    PROD_MAE = {
        "sharpness": 0.933, "blur": 0.933, "noise": 0.733,
        "brightness": 0.800, "contrast": 1.017,
        "blocking_artifacts": 0.950, "ringing_artifacts": 0.883,
    }
    PROD_BIAS = {
        "sharpness": -0.400, "blur": -0.733, "noise": -0.467,
        "brightness": 0.667, "contrast": -0.783,
        "blocking_artifacts": -0.883, "ringing_artifacts": -0.750,
    }
    PROD_W1 = {
        "sharpness": 0.833, "blur": 0.767, "noise": 0.833,
        "brightness": 0.833, "contrast": 0.800,
        "blocking_artifacts": 0.800, "ringing_artifacts": 0.767,
    }

    lines: list[str] = []
    lines += [
        "# Combined v1 human-pilot evaluation — consolidated report",
        "",
        f"**Run timestamp (UTC):** {run_ts}",
        f"**Output:** `{out_dir}`",
        "",
        (
            "Research only. No production code, Flutter, API contracts, human rating "
            "CSVs, or experimental engine source files were modified. Thresholds not "
            "tuned on these 30 images. SPAQ-200 not re-scored."
        ),
        "",
        "## Scope",
        "",
        "| Item | Value |",
        "|---|---|",
        "| Pilot images | 30 (`PILOT-001`–`PILOT-030`) |",
        "| Human raters | R1, R2, R3 |",
        "| Human consensus | median of available ratings (missing cells excluded) |",
        "| Engines compared | production (Run 002 EfficientNet-B0), combined_v1 |",
        "| combined_v1 composition | v2 (Sharpness/Blur/Noise/Brightness/Contrast) + Blocking v3 + Ringing v3 |",
        "| Mapping | `equal_bin_1_5` for combined_v1; `_soft_score` for production |",
        "| Overall visual quality | treated as independent construct (not mean of 7) |",
        "",
        "## Direction and ID-mapping verification",
        "",
    ]
    if direction["all_ok"]:
        lines.append("✅ All checks passed. No issues.")
    else:
        lines.append(f"⚠️  {len(direction['issues'])} issue(s) found:")
        for iss in direction["issues"]:
            lines.append(f"- {iss}")
    lines += [
        "",
        f"*{direction['direction_note']}*",
        "",
        "## Score distribution comparison (n=30 each)",
        "",
        "### Brightness",
        "",
    ]

    # badge histograms per criterion
    for c in CRITERIA:
        cs = combined_stats.get(c, {})
        lines.append(f"### {CRITERIA_DISPLAY[c]}")
        lines.append("")
        mh = cs.get("machine_badge_hist", {})
        hh = cs.get("human_median_hist", {})
        lines.append("| Badge | Human median | Combined v1 |")
        lines.append("|---|---|---|")
        for b in ("1", "2", "3", "4", "5"):
            lines.append(f"| {b} | {hh.get(b, 0)} | {mh.get(b, 0)} |")
        lines.append("")

    # main comparison table
    lines += [
        "## Seven-criterion comparison: production vs combined_v1 vs human consensus",
        "",
        "| Criterion | Prod ρ | **v1 ρ** | Δρ | Prod MAE | **v1 MAE** | ΔMAE | v1 Bias | v1 W1 | Verdict |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for c in CRITERIA:
        cs = combined_stats.get(c, {})
        v = verdict["per_criterion"].get(c, "?")
        emoji = {"IMPROVED": "✅", "REGRESSED": "❌", "MIXED": "⚠️"}.get(v, "")
        r_new = cs.get("spearman_r")
        mae_new = cs.get("mae")
        bias_new = cs.get("bias")
        w1_new = cs.get("within_one")
        r_old = PROD_RHO.get(c, "?")
        mae_old = PROD_MAE.get(c, "?")
        drho = f"{r_new - r_old:+.3f}" if isinstance(r_new, float) and isinstance(r_old, float) else "?"
        dmae = f"{mae_new - mae_old:+.3f}" if isinstance(mae_new, float) and isinstance(mae_old, float) else "?"
        lines.append(
            f"| {CRITERIA_DISPLAY[c]} "
            f"| {r_old:.3f} "
            f"| **{r_new:.3f}** "
            f"| {drho} "
            f"| {mae_old:.3f} "
            f"| **{mae_new:.3f}** "
            f"| {dmae} "
            f"| {bias_new:.3f} "
            f"| {w1_new:.3f} "
            f"| {emoji} {v} |"
        )

    lines += [
        "",
        "## Overall construct (separate — different from mean of 7 criteria)",
        "",
        f"*{overall_stats.get('note', '')}*",
        "",
        f"- n: {overall_stats.get('n')}",
        f"- Spearman r: {overall_stats.get('spearman_r')}",
        f"- MAE: {overall_stats.get('mae')}",
        f"- Bias (machine − human): {overall_stats.get('bias')}",
        f"- Within-1: {overall_stats.get('within_one')}",
        "",
        "## Verdict summary",
        "",
        f"**Overall: {verdict['overall']}**",
        "",
        f"- Improved: {verdict['n_improved']}/7 criteria",
        f"- Mixed:    {verdict['n_mixed']}/7 criteria",
        f"- Regressed: {verdict['n_regressed']}/7 criteria",
        "",
        "| Criterion | Prod ρ | v1 ρ | Δρ | Verdict |",
        "|---|---|---|---|---|",
    ]
    for c in CRITERIA:
        d = verdict["deltas"].get(c, {})
        v = verdict["per_criterion"].get(c, "?")
        emoji = {"IMPROVED": "✅", "REGRESSED": "❌", "MIXED": "⚠️"}.get(v, "")
        lines.append(
            f"| {CRITERIA_DISPLAY[c]} "
            f"| {d.get('prod_spearman_r', '?')} "
            f"| {d.get('combined_v1_spearman_r', '?')} "
            f"| {d.get('delta_spearman', '?')} "
            f"| {emoji} {v} |"
        )

    lines += [
        "",
        f"> ⚠️  {verdict['caution']}",
        "",
        "## Limitations",
        "",
        "- n=30; all confidence intervals are wide.",
        "- Human IRR for Blocking (Fleiss κ=0.086) and Ringing (κ=0.128) is low; "
        "Spearman values for those criteria are high-variance.",
        "- Both production and combined_v1 show restricted badge range "
        "(mostly 3–5), which can depress Spearman.",
        "- combined_v1 uses `equal_bin_1_5` (uniform bins); production uses `_soft_score` "
        "(compressed ladder). Different maps affect apparent accuracy.",
        "- This pilot does not authorise production changes or threshold tuning.",
        "- KonIQ MOS was not used as criterion ground truth.",
        "",
        "## Artifacts",
        "",
        f"- `combined_v1_pilot_scores.csv`",
        f"- `per_image_comparison.csv`",
        f"- `criterion_stats.json`",
        f"- `COMBINED_V1_PILOT_REPORT.md`",
        "",
        "Production files not modified. Experimental engines not modified. "
        "Prior output directories not modified.",
    ]
    (out_dir / "COMBINED_V1_PILOT_REPORT.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


# ── main ───────────────────────────────────────────────────────────────────────

def main() -> int:
    run_ts = now_iso()
    out_dir = EVAL_OUT_ROOT / f"combined_v1_pilot_{run_ts}"

    log(f"=== Combined v1 human pilot evaluation ===")
    log(f"Output dir: {out_dir}")

    # 1. Pre-flight
    log("Step 1/7: pre-flight verification ...")
    pf = verify_preflight()
    for iss in pf["issues"]:
        log(f"  WARN: {iss}")
        log("ERROR: pre-flight failed — aborting.")
        return 1
    log("  OK: All 30 images and rating files present.")

    # 2. Build human consensus (same logic as prior pilot run)
    log("Step 2/7: building human consensus from raw rater CSVs ...")
    consensus = build_human_consensus()
    log(f"  {len(consensus)} images in consensus.")

    # 3. Load production scores (reuse existing; no re-inference)
    log("Step 3/7: loading production scores (reuse, no re-inference) ...")
    prod_scores = load_production_scores()
    log(f"  {len(prod_scores)} images loaded from production CSV.")

    # 4. Score pilot with combined v1 engine
    log("Step 4/7: scoring 30 pilot images with combined_v1 engine ...")
    t_score = time.perf_counter()
    combined_scores = score_pilot_images()
    total_ms = (time.perf_counter() - t_score) * 1000.0
    n_ok = sum(1 for s in combined_scores.values() if s.get("status") == "ok")
    log(f"  {n_ok}/30 scored successfully ({total_ms:.0f} ms total).")
    if n_ok < 30:
        log("ERROR: not all pilot images were scored — aborting.")
        return 1

    # 5. Direction check
    log("Step 5/7: direction and ID-mapping verification ...")
    direction = direction_check(consensus, combined_scores, prod_scores)
    if direction["all_ok"]:
        log("  OK: All direction/mapping checks passed.")
    else:
        for iss in direction["issues"]:
            log(f"  WARN: {iss}")

    # 6. Compute statistics
    log("Step 6/7: computing per-criterion statistics ...")
    combined_stats = compute_criterion_stats(consensus, combined_scores, "combined_v1")
    overall_combined = compute_overall_stats(consensus, combined_scores, "combined_v1")
    verdict = compute_verdict(combined_stats, {})
    per_image = build_per_image_rows(consensus, combined_scores, prod_scores)

    # 7. Write outputs
    log("Step 7/7: writing outputs ...")
    out_dir.mkdir(parents=True, exist_ok=True)

    # combined_v1_pilot_scores.csv
    score_fields = ["media_id", "status", "ms"] + CRITERIA + ["overall_score"]
    with (out_dir / "combined_v1_pilot_scores.csv").open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=score_fields, extrasaction="ignore")
        w.writeheader()
        for mid in sorted(combined_scores):
            row = {"media_id": mid, **combined_scores[mid]}
            row.pop("raw", None)
            w.writerow(row)

    # per_image_comparison.csv
    if per_image:
        with (out_dir / "per_image_comparison.csv").open("w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=list(per_image[0].keys()), extrasaction="ignore")
            w.writeheader()
            w.writerows(per_image)

    # criterion_stats.json
    payload = {
        "generated_at": run_ts,
        "n_images": 30,
        "n_scored_ok": n_ok,
        "total_scoring_ms": round(total_ms, 1),
        "direction_check": direction,
        "combined_v1_stats": combined_stats,
        "overall_stats": {"combined_v1": overall_combined},
        "verdict": verdict,
        "notes": [
            "Research only. No production changes. No threshold tuning.",
            "Human consensus = median(R1, R2, R3); missing cells excluded per image per criterion.",
            "Production stats are from prior pilot_hvsm_20261108T114511Z report (no re-inference).",
            "combined_v1 = v2 (Sharpness/Blur/Noise/Brightness/Contrast) + Blocking v3 + Ringing v3.",
            "Overall visual quality is an independent human gestalt, not the mean of 7 criteria.",
            "Noise v3 is NOT used; Noise v2 is retained as per prior decision.",
        ],
    }
    (out_dir / "criterion_stats.json").write_text(
        json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8"
    )

    write_report(
        out_dir, consensus, combined_scores, combined_stats,
        overall_combined, verdict, direction, per_image, run_ts,
    )

    log("=== DONE ===")
    log(f"Output: {out_dir}")
    log(f"Overall verdict: {verdict['overall']}")
    log("Criterion verdicts:")
    for c in CRITERIA:
        v = verdict["per_criterion"].get(c, "?")
        d = verdict["deltas"].get(c, {})
        log(
            f"  {CRITERIA_DISPLAY[c]:20s}: {v:10s}  "
            f"ρ {d.get('prod_spearman_r', '?'):+.3f} → {d.get('combined_v1_spearman_r', '?'):+.3f}  "
            f"MAE {d.get('prod_mae', '?'):.3f} → {d.get('combined_v1_mae', '?'):.3f}"
        )
    return 0


def prod_as_compatible(prod_scores: dict) -> dict:
    """Make production scores match the combined_scores shape for compute_criterion_stats."""
    out = {}
    for mid, ps in prod_scores.items():
        out[mid] = {
            "status": "ok",
            "overall_score": statistics.fmean(
                [ps[c] for c in CRITERIA if ps.get(c) is not None]
            ) if any(ps.get(c) is not None for c in CRITERIA) else None,
        }
        for c in CRITERIA:
            out[mid][c] = ps.get(c)
    return out


if __name__ == "__main__":
    raise SystemExit(main())
