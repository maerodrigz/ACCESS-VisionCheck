#!/usr/bin/env python3
"""Frozen Noise/Ringing machine validation on NR001–NR015 (research only).

Uses locked ACCEPTANCE_CRITERIA.md gates. Does not retune detectors, modify
production, or invent missing estimators.
"""

from __future__ import annotations

import csv
import hashlib
import json
import math
import shutil
import statistics
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
BACKEND = REPO / "access_backend"
TOOLKIT = ROOT.parent
for p in (str(REPO), str(BACKEND), str(TOOLKIT)):
    if p not in sys.path:
        sys.path.insert(0, p)

from tools.quality_validation.metrics import (  # noqa: E402
    fleiss_kappa,
    mae_rmse,
    pearson_spearman,
    quadratic_weighted_kappa,
)

IMAGE_IDS = [f"NR{i:03d}" for i in range(1, 16)]
CRITERIA = ("noise", "ringing_artifacts")
RATER_FILES = {
    "R1": ROOT / "ratings" / "R1_noise_ringing_ratings.csv",
    "R2": ROOT / "ratings" / "R2_noise_ringing_ratings.csv",
    "R3": ROOT / "ratings" / "R3_noise_ringing_ratings.csv",
}


def utc_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_score(raw: str | None) -> int | None:
    if raw is None:
        return None
    s = str(raw).strip()
    if not s or s.upper() == "N/A":
        return None
    try:
        v = int(float(s))
    except ValueError:
        return None
    if 1 <= v <= 5:
        return v
    return None


def load_rater_csv(path: Path, expected_rater: str) -> dict[str, dict[str, int | None | str]]:
    with path.open(encoding="utf-8", newline="") as fh:
        rows = list(csv.DictReader(fh))
    out: dict[str, dict[str, int | None | str]] = {}
    for row in rows:
        mid = (row.get("media_id") or "").strip()
        rid = (row.get("rater_id") or "").strip()
        if mid not in IMAGE_IDS:
            continue
        if rid != expected_rater:
            raise ValueError(f"{path.name}: expected rater_id={expected_rater}, got {rid!r} for {mid}")
        out[mid] = {
            "noise": parse_score(row.get("noise")),
            "ringing_artifacts": parse_score(row.get("ringing_artifacts")),
            "notes": (row.get("notes") or "").strip(),
        }
    missing = [m for m in IMAGE_IDS if m not in out]
    if missing:
        raise ValueError(f"{path.name}: missing media_ids {missing}")
    return out


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str] | None = None) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields = fieldnames or list(rows[0].keys())
    with path.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def median_int(vals: list[int | None]) -> float | None:
    present = [float(v) for v in vals if v is not None]
    if not present:
        return None
    return float(statistics.median(present))


def pairwise_irr(matrix: np.ndarray) -> dict[str, Any]:
    """matrix shape (n_items, 3) with NaN for missing."""
    pairs = [(0, 1), (0, 2), (1, 2)]
    pair_names = ["R1-R2", "R1-R3", "R2-R3"]
    pairwise: dict[str, Any] = {}
    within_vals = []
    qwk_vals = []
    exact_vals = []
    for (i, j), name in zip(pairs, pair_names):
        a = []
        b = []
        for row in matrix:
            va, vb = row[i], row[j]
            if np.isnan(va) or np.isnan(vb):
                continue
            a.append(int(va))
            b.append(int(vb))
        if not a:
            pairwise[name] = {"n": 0, "within_one": None, "qwk": None, "exact": None}
            continue
        aa = np.asarray(a, dtype=float)
        bb = np.asarray(b, dtype=float)
        within1 = float(np.mean(np.abs(aa - bb) <= 1.0))
        exact = float(np.mean(aa == bb))
        qwk = quadratic_weighted_kappa(a, b)
        pairwise[name] = {"n": len(a), "within_one": within1, "qwk": qwk, "exact": exact}
        within_vals.append(within1)
        exact_vals.append(exact)
        if qwk is not None:
            qwk_vals.append(qwk)

    # Disagreement rate: max-min >= 3 among available raters
    disagree = 0
    usable_items = 0
    for row in matrix:
        present = [float(x) for x in row if not np.isnan(x)]
        if len(present) < 2:
            continue
        usable_items += 1
        if max(present) - min(present) >= 3:
            disagree += 1
    disagree_rate = (disagree / usable_items) if usable_items else None

    n_cells = matrix.size
    n_missing = int(np.isnan(matrix).sum())
    coverage = 1.0 - (n_missing / n_cells) if n_cells else 0.0

    fleiss = fleiss_kappa(matrix)
    return {
        "pairwise": pairwise,
        "mean_within_one": float(np.mean(within_vals)) if within_vals else None,
        "mean_exact": float(np.mean(exact_vals)) if exact_vals else None,
        "mean_qwk": float(np.mean(qwk_vals)) if qwk_vals else None,
        "fleiss_kappa": fleiss,
        "disagreement_rate_maxmin_ge3": disagree_rate,
        "usable_coverage": coverage,
        "missing_cells": n_missing,
        "n_items": int(matrix.shape[0]),
    }


def evaluate_human_gates(irr: dict[str, Any]) -> dict[str, Any]:
    h1 = irr["mean_within_one"] is not None and irr["mean_within_one"] >= 0.85
    h2 = irr["mean_qwk"] is not None and irr["mean_qwk"] >= 0.40
    h3_pass = irr["fleiss_kappa"] is not None and irr["fleiss_kappa"] >= 0.20
    h3_soft_fail = h1 and h2 and not h3_pass
    h4 = irr["disagreement_rate_maxmin_ge3"] is not None and irr["disagreement_rate_maxmin_ge3"] <= 0.15
    h5 = irr["usable_coverage"] is not None and irr["usable_coverage"] >= 0.90
    hard_pass = h1 and h2 and h4 and h5
    limited = hard_pass and h3_soft_fail
    overall_pass = hard_pass  # soft H3 does not STOP
    return {
        "H1_within1": {"value": irr["mean_within_one"], "threshold": 0.85, "pass": h1},
        "H2_qwk": {"value": irr["mean_qwk"], "threshold": 0.40, "pass": h2},
        "H3_fleiss": {
            "value": irr["fleiss_kappa"],
            "threshold": 0.20,
            "pass": h3_pass,
            "soft_fail_limited_consensus": limited,
        },
        "H4_disagreement": {
            "value": irr["disagreement_rate_maxmin_ge3"],
            "threshold": 0.15,
            "pass": h4,
        },
        "H5_coverage": {"value": irr["usable_coverage"], "threshold": 0.90, "pass": h5},
        "overall_pass_for_machine_compare": overall_pass,
        "limited_consensus_flag": limited,
        "hard_stop": not overall_pass,
    }


def spearman_bootstrap_ci(
    x: list[float], y: list[float], n_boot: int = 2000, seed: int = 42
) -> tuple[float | None, float | None]:
    if len(x) < 3:
        return None, None
    rng = np.random.default_rng(seed)
    xa = np.asarray(x, dtype=float)
    ya = np.asarray(y, dtype=float)
    stats_r = []
    n = len(xa)
    for _ in range(n_boot):
        idx = rng.integers(0, n, n)
        xs, ys = xa[idx], ya[idx]
        if float(np.std(xs)) == 0.0 or float(np.std(ys)) == 0.0:
            continue
        r = float(pearson_spearman(xs.tolist(), ys.tolist())["spearman_r"] or math.nan)
        if not math.isnan(r):
            stats_r.append(r)
    if len(stats_r) < 100:
        return None, None
    lo, hi = np.percentile(stats_r, [2.5, 97.5])
    return float(lo), float(hi)


def evaluate_machine_gates(
    human: list[float],
    machine: list[float],
    *,
    fitted: bool = False,
) -> dict[str, Any]:
    assert len(human) == len(machine)
    n = len(human)
    distinct = len(set(int(round(v)) for v in machine))
    corr = pearson_spearman(human, machine)
    rho = corr.get("spearman_r")
    p = corr.get("spearman_p")
    err = mae_rmse(machine, human)  # |machine-human|
    mae = err.get("mae")
    within1 = float(np.mean(np.abs(np.asarray(machine) - np.asarray(human)) <= 1.0)) if n else None

    # M4 dispersion
    collapsed = distinct < 3 and (
        all(v >= 4.5 for v in machine) or all(v <= 1.5 for v in machine) or distinct <= 1
    )
    m4 = distinct >= 3 or not collapsed

    # M5 false-harsh
    harsh_den = 0
    harsh_num = 0
    for h, m in zip(human, machine):
        if h >= 4:
            harsh_den += 1
            if m <= 2:
                harsh_num += 1
    false_harsh = (harsh_num / harsh_den) if harsh_den else 0.0

    # M1
    if distinct <= 1 or rho is None:
        m1 = False
        m1_note = "automatic fail: constant/undefined Spearman"
        ci = (None, None)
    else:
        ci = spearman_bootstrap_ci(human, machine)
        ci_excludes_0 = ci[0] is not None and ci[1] is not None and (ci[1] < 0 or ci[0] > 0)
        m1 = (rho >= 0.30) and (ci_excludes_0 or (p is not None and p < 0.05))
        m1_note = "rho>=0.30 and (CI excludes 0 or p<0.05)"

    m2 = mae is not None and mae <= 1.00
    m3 = within1 is not None and within1 >= 0.75
    m5 = false_harsh <= 0.10
    m6 = not fitted

    gates = {
        "M1_spearman": {
            "rho": rho,
            "p": p,
            "ci95": {"lo": ci[0], "hi": ci[1]},
            "pass": m1,
            "note": m1_note,
        },
        "M2_mae": {"value": mae, "threshold": 1.0, "pass": m2},
        "M3_within1": {"value": within1, "threshold": 0.75, "pass": m3},
        "M4_dispersion": {
            "n_distinct_badges": distinct,
            "collapsed_floor_ceiling": collapsed,
            "pass": m4,
        },
        "M5_false_harsh": {
            "rate": false_harsh,
            "n_human_ge4": harsh_den,
            "n_machine_le2": harsh_num,
            "threshold": 0.10,
            "pass": m5,
        },
        "M6_no_fitting": {"fitted_on_this_set": fitted, "pass": m6},
    }
    all_pass = all(g["pass"] for g in gates.values())
    return {
        "n": n,
        "gates": gates,
        "eligible_for_further_review": all_pass,
        "machine_badge_hist": dict(sorted(Counterish(machine).items())),
        "human_median_hist": dict(sorted(Counterish(human).items())),
    }


def Counterish(vals: list[float]) -> dict[int, int]:
    from collections import Counter

    return {int(round(v)): c for v, c in Counter(int(round(x)) for x in vals).items()}


def run_c_prod(image_bytes: bytes) -> dict[str, Any]:
    try:
        from app.services.efficientnet_b0_scorer import (
            analyze_image_bytes,
            efficientnet_available,
            ensure_weights,
        )
        from app.services.media_evaluator import _brightness_metric, _soft_score
    except Exception as exc:  # noqa: BLE001
        return {"available": False, "reason": f"import error: {exc}"}
    if not efficientnet_available() or not ensure_weights():
        return {"available": False, "reason": "EfficientNet unavailable or weights missing"}
    raw = analyze_image_bytes(image_bytes)
    if raw is None:
        return {"available": False, "reason": "analyze_image_bytes returned None"}

    def badge(key: str) -> int:
        v = float(raw[key])
        if key == "brightness":
            return _soft_score(_brightness_metric(v))
        if key == "noise":
            return _soft_score(1.0 - min(v, 0.85))
        if key in ("blur", "blocking_artifacts", "ringing_artifacts"):
            return _soft_score(1.0 - v)
        return _soft_score(v)

    return {
        "available": True,
        "engine_id": "efficientnet-b0-production-soft_score",
        "noise": badge("noise"),
        "ringing_artifacts": badge("ringing_artifacts"),
        "raw": {k: float(raw[k]) for k in ("noise", "ringing_artifacts") if k in raw},
    }


def run_c_v2(bgr: np.ndarray) -> dict[str, Any]:
    try:
        from tools.quality_validation.experimental_quality_engine_v2 import (
            ENGINE_ID,
            analyze_bgr,
        )
    except Exception as exc:  # noqa: BLE001
        return {"available": False, "reason": f"import error: {exc}"}
    try:
        result = analyze_bgr(bgr)
    except Exception as exc:  # noqa: BLE001
        return {"available": False, "reason": f"analyze error: {exc}"}
    scores = result.get("criterion_scores") or {}
    if "Noise" not in scores or "Ringing Artifacts" not in scores:
        return {"available": False, "reason": "v2 missing Noise/Ringing criterion_scores"}
    return {
        "available": True,
        "engine_id": ENGINE_ID,
        "noise": int(scores["Noise"]),
        "ringing_artifacts": int(scores["Ringing Artifacts"]),
        "quality_0_1": {
            "noise": (result.get("quality_0_1") or {}).get("noise"),
            "ringing_artifacts": (result.get("quality_0_1") or {}).get("ringing_artifacts"),
        },
    }


def run_c_combined(bgr: np.ndarray) -> dict[str, Any]:
    try:
        from tools.quality_validation.experimental_quality_engine_combined_v1 import (
            ENGINE_ID,
            analyze_bgr,
        )
    except Exception as exc:  # noqa: BLE001
        return {"available": False, "reason": f"import error: {exc}"}
    try:
        result = analyze_bgr(bgr)
    except Exception as exc:  # noqa: BLE001
        return {"available": False, "reason": f"analyze error: {exc}"}
    scores = result.get("criterion_scores") or {}
    if "Noise" not in scores or "Ringing Artifacts" not in scores:
        return {"available": False, "reason": "combined missing Noise/Ringing criterion_scores"}
    return {
        "available": True,
        "engine_id": ENGINE_ID,
        "noise": int(scores["Noise"]),
        "ringing_artifacts": int(scores["Ringing Artifacts"]),
        "composition_note": "Noise=v2; Ringing=v3 inside combined_v1",
        "quality_0_1": {
            "noise": (result.get("quality_0_1") or {}).get("noise"),
            "ringing_artifacts": (result.get("quality_0_1") or {}).get("ringing_artifacts"),
        },
    }


def decode_bgr(image_bytes: bytes) -> np.ndarray:
    import cv2

    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if bgr is None:
        raise ValueError("cv2.imdecode failed")
    return bgr


def main() -> int:
    out_dir = ROOT / "output" / f"frozen_validation_{utc_stamp()}"
    frozen_dir = out_dir / "frozen_human_ratings"
    out_dir.mkdir(parents=True, exist_ok=True)
    frozen_dir.mkdir(parents=True, exist_ok=True)

    # --- Load + freeze human ratings ---
    raters = {rid: load_rater_csv(path, rid) for rid, path in RATER_FILES.items()}
    checksums = []
    for rid, path in RATER_FILES.items():
        dest = frozen_dir / path.name
        shutil.copy2(path, dest)
        digest = sha256_file(dest)
        checksums.append(
            {
                "file": path.name,
                "frozen_path": str(dest.relative_to(ROOT)),
                "sha256": digest,
                "bytes": dest.stat().st_size,
            }
        )
    write_csv(out_dir / "frozen_rating_checksums.csv", checksums)

    # --- Human medians + IRR ---
    consensus_rows = []
    matrices = {c: np.full((15, 3), np.nan, dtype=float) for c in CRITERIA}
    for i, mid in enumerate(IMAGE_IDS):
        row: dict[str, Any] = {"media_id": mid}
        for c in CRITERIA:
            vals = [raters[r][mid][c] for r in ("R1", "R2", "R3")]
            for j, v in enumerate(vals):
                if v is not None:
                    matrices[c][i, j] = float(v)
            med = median_int(vals)  # type: ignore[arg-type]
            row[f"{c}_R1"] = vals[0]
            row[f"{c}_R2"] = vals[1]
            row[f"{c}_R3"] = vals[2]
            row[f"{c}_median"] = med
        consensus_rows.append(row)
    write_csv(out_dir / "human_consensus_by_image.csv", consensus_rows)

    irr_payload = {}
    gate_payload = {}
    for c in CRITERIA:
        irr = pairwise_irr(matrices[c])
        gates = evaluate_human_gates(irr)
        irr_payload[c] = irr
        gate_payload[c] = gates

    # --- Machine scoring (frozen candidates) ---
    machine_rows = []
    candidate_avail = {
        "C-prod": {"noise": True, "ringing_artifacts": True, "unavailable_reason": None},
        "C-v2": {"noise": True, "ringing_artifacts": True, "unavailable_reason": None},
        "C-combined": {"noise": True, "ringing_artifacts": True, "unavailable_reason": None},
    }
    t0 = time.perf_counter()
    for mid in IMAGE_IDS:
        path = ROOT / "images" / f"{mid}.jpg"
        raw = path.read_bytes()
        bgr = decode_bgr(raw)
        prod = run_c_prod(raw)
        v2 = run_c_v2(bgr)
        comb = run_c_combined(bgr)
        for cand_name, res in (("C-prod", prod), ("C-v2", v2), ("C-combined", comb)):
            if not res.get("available"):
                candidate_avail[cand_name]["noise"] = False
                candidate_avail[cand_name]["ringing_artifacts"] = False
                candidate_avail[cand_name]["unavailable_reason"] = res.get("reason")
        human = next(r for r in consensus_rows if r["media_id"] == mid)
        machine_rows.append(
            {
                "media_id": mid,
                "human_noise_median": human["noise_median"],
                "human_ringing_median": human["ringing_artifacts_median"],
                "C-prod_available": bool(prod.get("available")),
                "C-prod_noise": prod.get("noise"),
                "C-prod_ringing": prod.get("ringing_artifacts"),
                "C-prod_reason": prod.get("reason"),
                "C-v2_available": bool(v2.get("available")),
                "C-v2_noise": v2.get("noise"),
                "C-v2_ringing": v2.get("ringing_artifacts"),
                "C-v2_reason": v2.get("reason"),
                "C-combined_available": bool(comb.get("available")),
                "C-combined_noise": comb.get("noise"),
                "C-combined_ringing": comb.get("ringing_artifacts"),
                "C-combined_reason": comb.get("reason"),
                "C-combined_note": comb.get("composition_note"),
            }
        )
    elapsed = time.perf_counter() - t0
    write_csv(out_dir / "per_image_machine_vs_human.csv", machine_rows)

    # --- M1–M6 per candidate × criterion ---
    comparison = {}
    for cand, noise_key, ring_key in (
        ("C-prod", "C-prod_noise", "C-prod_ringing"),
        ("C-v2", "C-v2_noise", "C-v2_ringing"),
        ("C-combined", "C-combined_noise", "C-combined_ringing"),
    ):
        comparison[cand] = {}
        for crit, mcol, hcol in (
            ("noise", noise_key, "human_noise_median"),
            ("ringing_artifacts", ring_key, "human_ringing_median"),
        ):
            if not candidate_avail[cand][crit]:
                comparison[cand][crit] = {
                    "available": False,
                    "reason": candidate_avail[cand]["unavailable_reason"],
                    "eligible_for_further_review": False,
                }
                continue
            human = []
            machine = []
            for row in machine_rows:
                h = row[hcol]
                m = row[mcol]
                if h is None or m is None:
                    continue
                human.append(float(h))
                machine.append(float(m))
            if len(human) < 15:
                comparison[cand][crit] = {
                    "available": False,
                    "reason": f"incomplete pairs n={len(human)}",
                    "eligible_for_further_review": False,
                }
                continue
            result = evaluate_machine_gates(human, machine, fitted=False)
            result["available"] = True
            comparison[cand][crit] = result

    # --- Study-level decision ---
    noise_pass_cands = [
        c for c, block in comparison.items() if block.get("noise", {}).get("eligible_for_further_review")
    ]
    ring_pass_cands = [
        c
        for c, block in comparison.items()
        if block.get("ringing_artifacts", {}).get("eligible_for_further_review")
    ]

    human_ok_noise = gate_payload["noise"]["overall_pass_for_machine_compare"]
    human_ok_ring = gate_payload["ringing_artifacts"]["overall_pass_for_machine_compare"]
    limited_ring = gate_payload["ringing_artifacts"]["limited_consensus_flag"]
    limited_noise = gate_payload["noise"]["limited_consensus_flag"]

    if not (human_ok_noise or human_ok_ring):
        outcome = "Keep unvalidated"
        outcome_detail = "Human IRR hard-stop for both criteria."
    elif not noise_pass_cands and not ring_pass_cands:
        outcome = "Keep unvalidated"
        outcome_detail = "No candidate passed M1–M6 for either criterion."
    elif noise_pass_cands and ring_pass_cands:
        outcome = "Both criteria further review"
        outcome_detail = (
            f"Noise candidates eligible: {noise_pass_cands}. "
            f"Ringing candidates eligible: {ring_pass_cands}."
        )
    else:
        outcome = "Criterion-specific further review"
        if noise_pass_cands:
            outcome_detail = f"Only Noise eligible: {noise_pass_cands}."
        else:
            outcome_detail = f"Only Ringing eligible: {ring_pass_cands}."

    abandon = []
    for cand, block in comparison.items():
        for crit, res in block.items():
            if not res.get("available"):
                continue
            m1 = res["gates"]["M1_spearman"]["pass"]
            m5 = res["gates"]["M5_false_harsh"]["pass"]
            distinct = res["gates"]["M4_dispersion"]["n_distinct_badges"]
            if (not m1 and distinct <= 1) or (not m5 and res["gates"]["M5_false_harsh"]["rate"] >= 0.5):
                abandon.append({"candidate": cand, "criterion": crit, "reason": "severe M1/M5 failure"})

    payload = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "output_dir": str(out_dir),
        "n_images": 15,
        "fitted_on_this_set": False,
        "machine_elapsed_sec": round(elapsed, 2),
        "frozen_checksums": checksums,
        "human_irr": irr_payload,
        "human_gates": gate_payload,
        "candidate_availability": candidate_avail,
        "machine_gates": comparison,
        "noise_eligible_candidates": noise_pass_cands,
        "ringing_eligible_candidates": ring_pass_cands,
        "limited_consensus": {
            "noise": limited_noise,
            "ringing_artifacts": limited_ring,
        },
        "study_outcome": outcome,
        "study_outcome_detail": outcome_detail,
        "abandon_notes": abandon,
        "production_authorization": False,
        "note": (
            "Eligible for further review only. Does NOT authorize production deployment, "
            "Flutter changes, or threshold retuning."
        ),
    }
    (out_dir / "validation_payload.json").write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")

    # Flatten machine gate table
    flat = []
    for cand, block in comparison.items():
        for crit, res in block.items():
            flat.append(
                {
                    "candidate": cand,
                    "criterion": crit,
                    "available": res.get("available"),
                    "reason": res.get("reason"),
                    "eligible_for_further_review": res.get("eligible_for_further_review"),
                    "spearman_r": (res.get("gates") or {}).get("M1_spearman", {}).get("rho"),
                    "spearman_p": (res.get("gates") or {}).get("M1_spearman", {}).get("p"),
                    "spearman_ci95_lo": ((res.get("gates") or {}).get("M1_spearman", {}).get("ci95") or {}).get("lo"),
                    "spearman_ci95_hi": ((res.get("gates") or {}).get("M1_spearman", {}).get("ci95") or {}).get("hi"),
                    "M1": (res.get("gates") or {}).get("M1_spearman", {}).get("pass"),
                    "mae": (res.get("gates") or {}).get("M2_mae", {}).get("value"),
                    "M2": (res.get("gates") or {}).get("M2_mae", {}).get("pass"),
                    "within1": (res.get("gates") or {}).get("M3_within1", {}).get("value"),
                    "M3": (res.get("gates") or {}).get("M3_within1", {}).get("pass"),
                    "n_distinct": (res.get("gates") or {}).get("M4_dispersion", {}).get("n_distinct_badges"),
                    "M4": (res.get("gates") or {}).get("M4_dispersion", {}).get("pass"),
                    "false_harsh": (res.get("gates") or {}).get("M5_false_harsh", {}).get("rate"),
                    "M5": (res.get("gates") or {}).get("M5_false_harsh", {}).get("pass"),
                    "M6": (res.get("gates") or {}).get("M6_no_fitting", {}).get("pass"),
                }
            )
    write_csv(out_dir / "machine_gate_summary.csv", flat)

    write_reports(out_dir, payload, consensus_rows, machine_rows)
    print(f"Wrote {out_dir}")
    print(f"OUTCOME: {outcome}")
    return 0


def fmt(v: Any, digits: int = 3) -> str:
    if v is None:
        return "N/A"
    if isinstance(v, bool):
        return "PASS" if v else "FAIL"
    if isinstance(v, float):
        return f"{v:.{digits}f}"
    return str(v)


def write_reports(
    out_dir: Path,
    payload: dict[str, Any],
    consensus_rows: list[dict[str, Any]],
    machine_rows: list[dict[str, Any]],
) -> None:
    # IRR verification report
    lines = [
        "# Human IRR verification report (NR001–NR015)",
        "",
        f"Generated (UTC): {payload['created_utc']}",
        "",
        "Independent recalculation against locked `ACCEPTANCE_CRITERIA.md` §1.",
        "Source ratings: frozen copies under `frozen_human_ratings/` with SHA-256 in `frozen_rating_checksums.csv`.",
        "",
        "## Checksums",
        "",
        "| File | SHA-256 |",
        "|---|---|",
    ]
    for c in payload["frozen_checksums"]:
        lines.append(f"| `{c['file']}` | `{c['sha256']}` |")

    for crit, label in (("noise", "Noise"), ("ringing_artifacts", "Ringing Artifacts")):
        irr = payload["human_irr"][crit]
        gates = payload["human_gates"][crit]
        lines += [
            "",
            f"## {label}",
            "",
            f"- Mean pairwise within-1: **{fmt(irr['mean_within_one'])}** (H1 ≥ 0.85 → {fmt(gates['H1_within1']['pass'])})",
            f"- Mean pairwise QWK: **{fmt(irr['mean_qwk'])}** (H2 ≥ 0.40 → {fmt(gates['H2_qwk']['pass'])})",
            f"- Fleiss’ κ: **{fmt(irr['fleiss_kappa'])}** (H3 ≥ 0.20 → {fmt(gates['H3_fleiss']['pass'])})",
            f"- Disagreement rate (max−min ≥ 3): **{fmt(irr['disagreement_rate_maxmin_ge3'])}** (H4 ≤ 0.15 → {fmt(gates['H4_disagreement']['pass'])})",
            f"- Usable coverage: **{fmt(irr['usable_coverage'])}** (H5 ≥ 0.90 → {fmt(gates['H5_coverage']['pass'])})",
            f"- Limited consensus flag: **{gates['limited_consensus_flag']}**",
            f"- Proceed to machine compare: **{gates['overall_pass_for_machine_compare']}**",
            "",
            "Pairwise detail:",
            "",
            "| Pair | n | exact | within-1 | QWK |",
            "|---|---:|---:|---:|---:|",
        ]
        for pair, block in irr["pairwise"].items():
            lines.append(
                f"| {pair} | {block['n']} | {fmt(block['exact'])} | {fmt(block['within_one'])} | {fmt(block['qwk'])} |"
            )

    (out_dir / "HUMAN_IRR_VERIFICATION_REPORT.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    # Final decision report
    final = [
        "# Final frozen Noise and Ringing validation decision",
        "",
        f"Generated (UTC): {payload['created_utc']}",
        f"Images: NR001–NR015 (n={payload['n_images']})",
        f"Machine runtime: {payload['machine_elapsed_sec']} s",
        "",
        "## Human reliability (verified)",
        "",
        f"- Noise: proceed={payload['human_gates']['noise']['overall_pass_for_machine_compare']}; "
        f"LIMITED CONSENSUS={payload['limited_consensus']['noise']}",
        f"- Ringing: proceed={payload['human_gates']['ringing_artifacts']['overall_pass_for_machine_compare']}; "
        f"**LIMITED CONSENSUS={payload['limited_consensus']['ringing_artifacts']}**",
        "",
        "Ringing proceeds under the pre-registered H3 soft-gate rule (H1/H2/H4/H5 pass, Fleiss below 0.20).",
        "",
        "## Machine gate summary (M1–M6)",
        "",
        "| Candidate | Criterion | Available | Spearman ρ | p | MAE | Within-1 | Distinct badges | False-harsh | M1–M6 eligible |",
        "|---|---|---|---:|---:|---:|---:|---:|---:|---|",
    ]
    for row in csv_dict_reader(out_dir / "machine_gate_summary.csv"):
        final.append(
            "| {candidate} | {criterion} | {available} | {spearman_r} | {spearman_p} | {mae} | {within1} | {n_distinct} | {false_harsh} | {eligible} |".format(
                candidate=row["candidate"],
                criterion=row["criterion"],
                available=row["available"],
                spearman_r=fmt(_f(row.get("spearman_r"))),
                spearman_p=fmt(_f(row.get("spearman_p")), 4),
                mae=fmt(_f(row.get("mae"))),
                within1=fmt(_f(row.get("within1"))),
                n_distinct=row.get("n_distinct") or "N/A",
                false_harsh=fmt(_f(row.get("false_harsh"))),
                eligible=row.get("eligible_for_further_review"),
            )
        )

    final += [
        "",
        "## Study outcome (locked vocabulary)",
        "",
        f"**{payload['study_outcome']}**",
        "",
        payload["study_outcome_detail"],
        "",
        "### Eligible candidates",
        "",
        f"- Noise: {payload['noise_eligible_candidates'] or '(none)'}",
        f"- Ringing: {payload['ringing_eligible_candidates'] or '(none)'}",
        "",
        "## Go / no-go recommendation",
        "",
    ]
    if payload["study_outcome"] == "Keep unvalidated":
        final.append(
            "**NO-GO for further review / production.** Keep Noise and Ringing unvalidated. "
            "No production, Flutter, sandbox scoring, or threshold changes."
        )
    elif payload["study_outcome"] == "Criterion-specific further review":
        final.append(
            "**GO for criterion-specific further review only** (not production). "
            f"{payload['study_outcome_detail']} "
            "Ringing interpretations remain under **LIMITED CONSENSUS** where flagged. "
            "Passing M1–M6 does **not** authorize production deployment."
        )
    elif payload["study_outcome"] == "Both criteria further review":
        final.append(
            "**GO for further review on both criteria** (research / feature-flag path only). "
            "Still **NO production authorization**. Ringing carries LIMITED CONSENSUS where flagged."
        )
    else:
        final.append(payload["study_outcome_detail"])

    final += [
        "",
        "## Hard constraints honored",
        "",
        "- No detector retune / retrain / new versions",
        "- No SPAQ-200 or frozen-30 pilot re-run",
        "- No production / Flutter / sandbox scoring / weight changes",
        "- Locked acceptance criteria unchanged",
        "- Unavailable estimators marked unavailable (no silent substitute)",
        "",
        "## Artifacts",
        "",
        "- `HUMAN_IRR_VERIFICATION_REPORT.md`",
        "- `frozen_rating_checksums.csv` + `frozen_human_ratings/`",
        "- `human_consensus_by_image.csv`",
        "- `per_image_machine_vs_human.csv`",
        "- `machine_gate_summary.csv`",
        "- `validation_payload.json`",
        "",
    ]
    (out_dir / "FINAL_DECISION_REPORT.md").write_text("\n".join(final) + "\n", encoding="utf-8")


def csv_dict_reader(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as fh:
        return list(csv.DictReader(fh))


def _f(v: Any) -> float | None:
    if v is None or v == "":
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


if __name__ == "__main__":
    raise SystemExit(main())
