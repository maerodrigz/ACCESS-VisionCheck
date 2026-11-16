#!/usr/bin/env python3
"""Phase 11: offline scoring diagnostics and calibration feasibility.

Uses existing SPAQ-200 predictions. Does not change production, retrain, or
replace the live scorer. Supervised maps are fit on training folds only.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
if str(_REPO) not in sys.path:
    sys.path.insert(0, str(_REPO))

from tools.quality_validation.metrics import correlation_bootstrap, pearson_spearman
from tools.quality_validation.scoring_candidates import (
    clip01,
    equal_bin_1_5,
    linear_continuous_1_5,
    linear_round_1_5,
    production_brightness_q,
    production_soft_score,
)

SPAQ_CSV = (
    _TOOLKIT
    / "workspace"
    / "datasets"
    / "spaq"
    / "output"
    / "run_001"
    / "spaq_200_machine_scores.csv"
)
DEFAULT_OUT = _TOOLKIT / "workspace" / "datasets" / "spaq" / "output" / "phase11_run_001"
SEED = 20261107
N_FOLDS = 5
RIDGE_LAM = 1.0

HEADS = (
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
)
BADGE_COLS = {
    "sharpness": "criterion_Sharpness",
    "blur": "criterion_Blur",
    "noise": "criterion_Noise",
    "brightness": "criterion_Brightness",
    "contrast": "criterion_Contrast",
    "blocking_artifacts": "criterion_Blocking_Artifacts",
    "ringing_artifacts": "criterion_Ringing_Artifacts",
}
# Human pairs that may be correlated. Blur/blocking/ringing excluded.
HUMAN_PAIRS = (
    {
        "key": "overall_mos",
        "human": "mos_quality_raw",
        "invert_human": False,
        "q_key": "mean_q",
        "badge_key": "overall_score",
        "raw_key": "raw_mean_seven",
        "comparability": "related_proxy",
    },
    {
        "key": "noise",
        "human": "attr_noisiness_raw",
        "invert_human": True,
        "q_key": "q_noise",
        "badge_key": "criterion_Noise",
        "raw_key": "raw_noise_quality",
        "comparability": "directly_comparable_after_invert",
    },
    {
        "key": "sharpness",
        "human": "attr_sharpness_raw",
        "invert_human": False,
        "q_key": "q_sharpness",
        "badge_key": "criterion_Sharpness",
        "raw_key": "raw_sharpness",
        "comparability": "related_proxy",
    },
    {
        "key": "brightness",
        "human": "attr_brightness_raw",
        "invert_human": False,
        "q_key": "q_brightness",
        "badge_key": "criterion_Brightness",
        "raw_key": "raw_brightness",
        "comparability": "related_proxy",
    },
    {
        "key": "contrast",
        "human": "attr_contrast_raw",
        "invert_human": False,
        "q_key": "q_contrast",
        "badge_key": "criterion_Contrast",
        "raw_key": "raw_contrast",
        "comparability": "related_proxy",
    },
)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def fnum(row: dict[str, str], key: str) -> float | None:
    v = row.get(key)
    if v is None or str(v).strip() == "":
        return None
    return float(v)


def reconstruct_row(row: dict[str, str]) -> dict[str, Any]:
    rec: dict[str, Any] = dict(row)
    raw = {h: fnum(row, f"raw_{h}") for h in HEADS}
    rec["raw"] = raw
    q = {
        "sharpness": None if raw["sharpness"] is None else clip01(raw["sharpness"]),
        "blur": None if raw["blur"] is None else clip01(1.0 - raw["blur"]),
        "noise": None if raw["noise"] is None else clip01(1.0 - min(raw["noise"], 0.85)),
        "brightness": None if raw["brightness"] is None else production_brightness_q(raw["brightness"]),
        "contrast": None if raw["contrast"] is None else clip01(min(raw["contrast"], 1.0)),
        "blocking_artifacts": None if raw["blocking_artifacts"] is None else clip01(1.0 - raw["blocking_artifacts"]),
        "ringing_artifacts": None if raw["ringing_artifacts"] is None else clip01(1.0 - raw["ringing_artifacts"]),
    }
    rec["q"] = q
    rec["boosted"] = {k: None if v is None else clip01(v * 0.5 + 0.42) for k, v in q.items()}
    rec["recon_badge"] = {k: None if v is None else production_soft_score(v) for k, v in q.items()}
    rec["equal_bin"] = {k: None if v is None else equal_bin_1_5(v) for k, v in q.items()}
    rec["linear_round"] = {k: None if v is None else linear_round_1_5(v) for k, v in q.items()}
    rec["linear_cont"] = {k: None if v is None else linear_continuous_1_5(v) for k, v in q.items()}
    qvals = [float(q[k]) for k in HEADS if q[k] is not None]
    rec["mean_q"] = sum(qvals) / len(qvals) if qvals else None
    rec["mean_equal_bin"] = (
        sum(rec["equal_bin"][k] for k in HEADS) / 7.0 if all(rec["equal_bin"][k] is not None for k in HEADS) else None
    )
    rec["mean_linear_cont"] = (
        sum(rec["linear_cont"][k] for k in HEADS) / 7.0 if all(rec["linear_cont"][k] is not None for k in HEADS) else None
    )
    rec["raw_noise_quality"] = None if raw["noise"] is None else clip01(1.0 - raw["noise"])
    rec["q_noise"] = q["noise"]
    rec["q_sharpness"] = q["sharpness"]
    rec["q_brightness"] = q["brightness"]
    rec["q_contrast"] = q["contrast"]
    rec["stratum_id"] = int(row["stratum_id"])
    rec["overall_score"] = fnum(row, "overall_score")
    rec["mos_quality_raw"] = fnum(row, "mos_quality_raw")
    rec["attr_noisiness_raw"] = fnum(row, "attr_noisiness_raw")
    rec["attr_sharpness_raw"] = fnum(row, "attr_sharpness_raw")
    rec["attr_brightness_raw"] = fnum(row, "attr_brightness_raw")
    rec["attr_contrast_raw"] = fnum(row, "attr_contrast_raw")
    rec["raw_mean_seven"] = fnum(row, "raw_mean_seven")
    rec["raw_sharpness"] = raw["sharpness"]
    rec["raw_noise"] = raw["noise"]
    rec["raw_brightness"] = raw["brightness"]
    rec["raw_contrast"] = raw["contrast"]
    rec["criterion_Noise"] = fnum(row, "criterion_Noise")
    rec["criterion_Sharpness"] = fnum(row, "criterion_Sharpness")
    rec["criterion_Brightness"] = fnum(row, "criterion_Brightness")
    rec["criterion_Contrast"] = fnum(row, "criterion_Contrast")
    rec["criterion_Blur"] = fnum(row, "criterion_Blur")
    rec["criterion_Blocking_Artifacts"] = fnum(row, "criterion_Blocking_Artifacts")
    rec["criterion_Ringing_Artifacts"] = fnum(row, "criterion_Ringing_Artifacts")
    return rec


def human_value(rec: dict[str, Any], spec: dict[str, Any]) -> float | None:
    v = rec.get(spec["human"])
    if v is None:
        return None
    return 100.0 - float(v) if spec["invert_human"] else float(v)


def series(rows: list[dict[str, Any]], spec: dict[str, Any], machine_key: str) -> tuple[list[float], list[float]]:
    hs: list[float] = []
    ms: list[float] = []
    for rec in rows:
        h = human_value(rec, spec)
        m = rec.get(machine_key)
        if machine_key.startswith("q_") or machine_key in rec.get("q", {}):
            pass
        if h is None or m is None:
            continue
        hs.append(float(h))
        ms.append(float(m))
    return hs, ms


def get_machine(rec: dict[str, Any], key: str) -> float | None:
    if key in rec and not isinstance(rec[key], dict):
        v = rec[key]
        return None if v is None else float(v)
    if key.startswith("q_") and "q" in rec:
        return rec["q"].get(key[2:])
    return None


def corr_pack(hs: list[float], ms: list[float], seed: int = SEED, *, bootstrap: bool = False) -> dict[str, Any]:
    if len(hs) < 2:
        return {"n": len(hs), "pearson_r": None, "spearman_r": None, "note": "insufficient_n"}
    base = pearson_spearman(ms, hs)
    boot = correlation_bootstrap(ms, hs, seed=seed, n_boot=400) if bootstrap and len(hs) >= 5 else {}
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
        "human_n_unique": len(set(hs)),
        "machine_std": float(np.std(ms, ddof=1)) if len(ms) > 1 else 0.0,
    }


def dist(values: list[float], integer: bool = False) -> dict[str, Any]:
    if not values:
        return {"n": 0}
    arr = np.asarray(values, dtype=float)
    out: dict[str, Any] = {
        "n": int(arr.size),
        "min": float(arr.min()),
        "max": float(arr.max()),
        "mean": float(arr.mean()),
        "std": float(arr.std(ddof=1)) if arr.size > 1 else 0.0,
        "n_unique": int(len(set(values))) if not integer else int(len(set(int(round(v)) for v in values))),
        "p05": float(np.quantile(arr, 0.05)),
        "p25": float(np.quantile(arr, 0.25)),
        "p50": float(np.quantile(arr, 0.50)),
        "p75": float(np.quantile(arr, 0.75)),
        "p95": float(np.quantile(arr, 0.95)),
    }
    if integer:
        c = Counter(int(round(v)) for v in values)
        out["histogram_1_5"] = {str(i): c.get(i, 0) for i in range(1, 6)}
        out["n_at_1"] = c.get(1, 0)
        out["n_at_5"] = c.get(5, 0)
    return out


def stratified_folds(rows: list[dict[str, Any]], *, n_folds: int = N_FOLDS, seed: int = SEED) -> list[int]:
    rng = np.random.default_rng(seed)
    folds = [-1] * len(rows)
    by_s: dict[int, list[int]] = {}
    for i, rec in enumerate(rows):
        by_s.setdefault(int(rec["stratum_id"]), []).append(i)
    for idxs in by_s.values():
        order = list(idxs)
        rng.shuffle(order)
        for j, idx in enumerate(order):
            folds[idx] = j % n_folds
    return folds


def ridge_fit(X: np.ndarray, y: np.ndarray, lam: float = RIDGE_LAM) -> np.ndarray:
    n, p = X.shape
    A = np.hstack([np.ones((n, 1)), X])
    reg = np.eye(p + 1) * lam
    reg[0, 0] = 0.0
    gram = A.T @ A + reg
    return np.linalg.solve(gram, A.T @ y)


def ridge_predict(coef: np.ndarray, X: np.ndarray) -> np.ndarray:
    A = np.hstack([np.ones((X.shape[0], 1)), X])
    return A @ coef


def univariate_linear_fit(x: np.ndarray, y: np.ndarray) -> tuple[float, float]:
    xm = float(x.mean())
    ym = float(y.mean())
    var = float(np.dot(x - xm, x - xm))
    if var <= 1e-18:
        return 0.0, ym
    b = float(np.dot(x - xm, y - ym) / var)
    a = ym - b * xm
    return a, b


def isotonic_predict(x_train: np.ndarray, y_train: np.ndarray, x_test: np.ndarray) -> np.ndarray:
    """PAV isotonic regression, nondecreasing. Fit on train only."""
    order = np.argsort(x_train, kind="mergesort")
    x_s = x_train[order]
    y_s = y_train[order].astype(float).copy()
    w = np.ones_like(y_s)
    blocks = [[i] for i in range(len(y_s))]
    means = y_s.copy()
    i = 0
    while i < len(means) - 1:
        if means[i] <= means[i + 1] + 1e-15:
            i += 1
            continue
        new_w = w[i] + w[i + 1]
        new_m = (means[i] * w[i] + means[i + 1] * w[i + 1]) / new_w
        means[i] = new_m
        w[i] = new_w
        blocks[i] = blocks[i] + blocks[i + 1]
        means = np.delete(means, i + 1)
        w = np.delete(w, i + 1)
        del blocks[i + 1]
        i = max(i - 1, 0)
    xs_block = []
    ys_block = []
    for mean, block in zip(means, blocks, strict=True):
        xs_block.append(float(x_s[block[0]]))
        ys_block.append(float(mean))
    # merge duplicate x
    out = np.empty_like(x_test, dtype=float)
    xp = np.array(xs_block)
    yp = np.array(ys_block)
    for i, xt in enumerate(x_test):
        if xt <= xp[0]:
            out[i] = yp[0]
        elif xt >= xp[-1]:
            out[i] = yp[-1]
        else:
            out[i] = float(np.interp(xt, xp, yp))
    return out


def train_quantile_bins(x_train: np.ndarray) -> list[float]:
    """Five equal-count edges from train. Can emit 1-5. Not used as production."""
    qs = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
    edges = [float(np.quantile(x_train, q)) for q in qs]
    for i in range(1, len(edges)):
        if edges[i] <= edges[i - 1]:
            edges[i] = edges[i - 1] + 1e-9
    return edges


def apply_edges(x: float, edges: list[float]) -> int:
    for i in range(1, 6):
        if x <= edges[i] or i == 5:
            return i
    return 5


def badge_match(rows: list[dict[str, Any]]) -> dict[str, Any]:
    mismatch = 0
    n = 0
    per: dict[str, int] = {}
    for rec in rows:
        for k, col in BADGE_COLS.items():
            recon = rec["recon_badge"][k]
            stored = rec.get(col)
            if recon is None or stored is None or str(stored).strip() == "":
                continue
            stored_i = int(round(float(stored)))
            n += 1
            if recon != stored_i:
                mismatch += 1
                per[k] = per.get(k, 0) + 1
    return {"n_compared": n, "n_mismatch": mismatch, "per_head": per}


def stage_table(rows: list[dict[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for k in HEADS:
        raws = [rec["raw"][k] for rec in rows if rec["raw"][k] is not None]
        qs = [rec["q"][k] for rec in rows if rec["q"][k] is not None]
        boosts = [rec["boosted"][k] for rec in rows if rec["boosted"][k] is not None]
        badges = [float(rec[BADGE_COLS[k]]) for rec in rows if rec.get(BADGE_COLS[k]) is not None]
        q_for_badge = []
        for rec in rows:
            if rec["q"][k] is None:
                continue
            q_for_badge.append((rec["q"][k], rec["recon_badge"][k]))
        # rank preservation q vs badge
        if qs and badges:
            hs = [a for a, _ in q_for_badge]
            ms = [float(b) for _, b in q_for_badge]
            sp = pearson_spearman(hs, ms)
        else:
            sp = {}
        # which _soft_score bins the q values land in
        bin_from_q = Counter(production_soft_score(q) for q in qs)
        out[k] = {
            "raw": dist(raws),
            "q": dist(qs),
            "boosted": dist(boosts),
            "badge": dist(badges, integer=True),
            "spearman_q_vs_badge": sp.get("spearman_r"),
            "soft_score_from_q": {str(i): bin_from_q.get(i, 0) for i in range(1, 6)},
            "q_range_for_badge_2": [0.0, 0.08],
            "q_range_for_badge_3": [0.08, 0.44],
            "q_range_for_badge_4": [0.44, 0.76],
            "q_range_for_badge_5": [0.76, 1.0],
            "n_q_in_badge2": sum(1 for q in qs if q < 0.08),
            "n_q_in_badge3": sum(1 for q in qs if 0.08 <= q < 0.44),
            "n_q_in_badge4": sum(1 for q in qs if 0.44 <= q < 0.76),
            "n_q_in_badge5": sum(1 for q in qs if q >= 0.76),
        }
    return out


def exploratory_full(rows: list[dict[str, Any]]) -> dict[str, Any]:
    """Full-n=200 description. Not independent validation."""
    pairs = {}
    for spec in HUMAN_PAIRS:
        for mkey, label in (
            (spec["raw_key"], "raw_or_amount"),
            (spec["q_key"], "q_quality"),
            (spec["badge_key"], "badge"),
            ("linear_cont_mean" if spec["key"] == "overall_mos" else f"linear_cont_{spec['key']}", "linear_continuous"),
            ("equal_bin_mean" if spec["key"] == "overall_mos" else f"equal_bin_{spec['key']}", "equal_bin"),
        ):
            if spec["key"] != "overall_mos" and label == "linear_continuous":
                hs, ms = [], []
                for rec in rows:
                    h = human_value(rec, spec)
                    m = rec["linear_cont"].get(
                        {"noise": "noise", "sharpness": "sharpness", "brightness": "brightness", "contrast": "contrast"}[spec["key"]]
                    )
                    if h is None or m is None:
                        continue
                    hs.append(h)
                    ms.append(float(m))
                pairs[f"{spec['key']}|{label}"] = {**corr_pack(hs, ms, bootstrap=True), "comparability": spec["comparability"]}
            elif spec["key"] != "overall_mos" and label == "equal_bin":
                hs, ms = [], []
                head = {"noise": "noise", "sharpness": "sharpness", "brightness": "brightness", "contrast": "contrast"}[spec["key"]]
                for rec in rows:
                    h = human_value(rec, spec)
                    m = rec["equal_bin"].get(head)
                    if h is None or m is None:
                        continue
                    hs.append(h)
                    ms.append(float(m))
                pairs[f"{spec['key']}|{label}"] = {**corr_pack(hs, ms, bootstrap=True), "comparability": spec["comparability"]}
            elif spec["key"] == "overall_mos" and label == "linear_continuous":
                hs = [human_value(r, spec) for r in rows]
                ms = [r["mean_linear_cont"] for r in rows]
                hs2 = [a for a, b in zip(hs, ms) if a is not None and b is not None]
                ms2 = [float(b) for a, b in zip(hs, ms) if a is not None and b is not None]
                pairs[f"{spec['key']}|{label}"] = {**corr_pack(hs2, ms2, bootstrap=True), "comparability": spec["comparability"]}
            elif spec["key"] == "overall_mos" and label == "equal_bin":
                hs = [human_value(r, spec) for r in rows]
                ms = [r["mean_equal_bin"] for r in rows]
                hs2 = [a for a, b in zip(hs, ms) if a is not None and b is not None]
                ms2 = [float(b) for a, b in zip(hs, ms) if a is not None and b is not None]
                pairs[f"{spec['key']}|{label}"] = {**corr_pack(hs2, ms2, bootstrap=True), "comparability": spec["comparability"]}
            else:
                hs, ms = [], []
                for rec in rows:
                    h = human_value(rec, spec)
                    m = get_machine(rec, mkey)
                    if h is None or m is None:
                        continue
                    hs.append(h)
                    ms.append(m)
                pairs[f"{spec['key']}|{label}"] = {**corr_pack(hs, ms, bootstrap=True), "comparability": spec["comparability"]}
    return {"label": "exploratory_full_n200_not_held_out", "pairs": pairs}


def cv_supervised(rows: list[dict[str, Any]], folds: list[int]) -> dict[str, Any]:
    results: dict[str, list[dict[str, Any]]] = {}
    feature_sets = {
        "ridge_raw7_to_mos": {
            "target": "mos_quality_raw",
            "invert": False,
            "features": lambda r: [r["raw"][h] for h in HEADS],
        },
        "ridge_q7_to_mos": {
            "target": "mos_quality_raw",
            "invert": False,
            "features": lambda r: [r["q"][h] for h in HEADS],
        },
        "ridge_badge7_to_mos": {
            "target": "mos_quality_raw",
            "invert": False,
            "features": lambda r: [float(r[BADGE_COLS[h]]) for h in HEADS],
        },
    }
    def spec_for(key: str) -> dict[str, Any]:
        return next(s for s in HUMAN_PAIRS if s["key"] == key)

    for fold in range(N_FOLDS):
        train = [r for i, r in enumerate(rows) if folds[i] != fold]
        test = [r for i, r in enumerate(rows) if folds[i] == fold]
        # ridge MOS
        for name, cfg in feature_sets.items():
            Xtr = np.array([cfg["features"](r) for r in train], dtype=float)
            ytr = np.array([r[cfg["target"]] for r in train], dtype=float)
            Xte = np.array([cfg["features"](r) for r in test], dtype=float)
            yte = np.array([r[cfg["target"]] for r in test], dtype=float)
            if not np.isfinite(Xtr).all() or not np.isfinite(Xte).all():
                results.setdefault(name, []).append({"fold": fold, "n_test": len(test), "note": "nonfinite"})
                continue
            coef = ridge_fit(Xtr, ytr)
            pred = ridge_predict(coef, Xte)
            pack = corr_pack(list(yte), list(pred), seed=SEED + fold)
            pack.update({"fold": fold, "n_train": len(train), "n_test": len(test), "coef": [float(c) for c in coef]})
            results.setdefault(name, []).append(pack)
        # univariate linear / isotonic / train bins
        for name, spec_key, src, head in (
            ("uni_linear_q_noise", "noise", "q", "noise"),
            ("uni_linear_q_sharpness", "sharpness", "q", "sharpness"),
            ("uni_linear_q_brightness", "brightness", "q", "brightness"),
            ("uni_linear_q_contrast", "contrast", "q", "contrast"),
        ):
            sp = spec_for(spec_key)
            xtr = np.array([r[src][head] for r in train], dtype=float)
            ytr = np.array([human_value(r, sp) for r in train], dtype=float)
            xte = np.array([r[src][head] for r in test], dtype=float)
            yte = np.array([human_value(r, sp) for r in test], dtype=float)
            a, b = univariate_linear_fit(xtr, ytr)
            pred = a + b * xte
            pack = corr_pack(list(yte), list(pred), seed=SEED + fold)
            pack.update({"fold": fold, "n_train": len(train), "n_test": len(test), "intercept": a, "slope": b, "ranking_changed_if_slope_positive": False})
            results.setdefault(name, []).append(pack)
        for name, spec_key, head in (
            ("uni_isotonic_q_noise", "noise", "noise"),
            ("uni_isotonic_q_sharpness", "sharpness", "sharpness"),
            ("uni_isotonic_q_brightness", "brightness", "brightness"),
            ("uni_isotonic_q_contrast", "contrast", "contrast"),
        ):
            sp = spec_for(spec_key)
            xtr = np.array([r["q"][head] for r in train], dtype=float)
            ytr = np.array([human_value(r, sp) for r in train], dtype=float)
            xte = np.array([r["q"][head] for r in test], dtype=float)
            yte = np.array([human_value(r, sp) for r in test], dtype=float)
            pred = isotonic_predict(xtr, ytr, xte)
            pack = corr_pack(list(yte), list(pred), seed=SEED + fold)
            pack.update({"fold": fold, "n_train": len(train), "n_test": len(test)})
            results.setdefault(name, []).append(pack)
        for name, spec_key, head in (
            ("train_quantile_bins_noise", "noise", "noise"),
            ("train_quantile_bins_sharpness", "sharpness", "sharpness"),
            ("train_quantile_bins_brightness", "brightness", "brightness"),
            ("train_quantile_bins_contrast", "contrast", "contrast"),
        ):
            sp = spec_for(spec_key)
            xtr = np.array([r["q"][head] for r in train], dtype=float)
            edges = train_quantile_bins(xtr)
            yte = []
            pred = []
            for r in test:
                h = human_value(r, sp)
                if h is None or r["q"][head] is None:
                    continue
                yte.append(h)
                pred.append(float(apply_edges(float(r["q"][head]), edges)))
            pack = corr_pack(yte, pred, seed=SEED + fold)
            pack.update({"fold": fold, "n_train": len(train), "n_test": len(yte), "edges": edges})
            results.setdefault(name, []).append(pack)
        # a priori maps on held-out (no fitting)
        for spec in HUMAN_PAIRS:
            for label, getter in (
                ("heldout_q", lambda r, s=spec: get_machine(r, s["q_key"])),
                ("heldout_badge", lambda r, s=spec: get_machine(r, s["badge_key"])),
            ):
                hs, ms = [], []
                for r in test:
                    h = human_value(r, spec)
                    m = getter(r)
                    if h is None or m is None:
                        continue
                    hs.append(h)
                    ms.append(float(m))
                pack = corr_pack(hs, ms, seed=SEED + fold)
                pack.update({"fold": fold, "n_test": len(hs)})
                results.setdefault(f"{spec['key']}|{label}", []).append(pack)
    summarized = {}
    for name, folds_out in results.items():
        rs = [f.get("spearman_r") for f in folds_out if f.get("spearman_r") is not None]
        ps = [f.get("pearson_r") for f in folds_out if f.get("pearson_r") is not None]
        summarized[name] = {
            "n_folds": len(folds_out),
            "spearman_mean": float(np.mean(rs)) if rs else None,
            "spearman_std": float(np.std(rs, ddof=1)) if len(rs) > 1 else None,
            "pearson_mean": float(np.mean(ps)) if ps else None,
            "pearson_std": float(np.std(ps, ddof=1)) if len(ps) > 1 else None,
            "folds": folds_out,
        }
    return summarized


def soft_score_analysis() -> dict[str, Any]:
    grid = [i / 100.0 for i in range(101)]
    badges = [production_soft_score(q) for q in grid]
    return {
        "formula": "boosted = clip(q * 0.5 + 0.42); 5 if >=0.80 else 4 if >=0.64 else 3 if >=0.46 else 2 if >=0.28 else 1",
        "q0_boosted": 0.42,
        "q0_badge": production_soft_score(0.0),
        "q1_boosted": 0.92,
        "q1_badge": production_soft_score(1.0),
        "min_badge_on_unit_interval": min(badges),
        "max_badge_on_unit_interval": max(badges),
        "n_grid_at_1": sum(1 for b in badges if b == 1),
        "q_needed_for_badge1": "boosted < 0.28 => q < -0.28 (impossible for q in [0,1])",
        "q_for_2": "0 <= q < 0.08 (boosted in [0.42, 0.46))",
        "q_for_3": "0.08 <= q < 0.44",
        "q_for_4": "0.44 <= q < 0.76",
        "q_for_5": "q >= 0.76",
        "note": "Affine boost shifts the entire [0,1] metric into [0.42, 0.92], so the 1-bin and most of the 2-bin are unused.",
    }


def fmt(v: Any) -> str:
    if v is None:
        return "n/a"
    if isinstance(v, float):
        return f"{v:.3f}"
    return str(v)


def write_report(payload: dict[str, Any], path: Path) -> None:
    stages = payload["stages"]
    expl = payload["exploratory_full"]["pairs"]
    cv = payload["cross_validation"]
    lines = [
        "# Phase 11: Scoring diagnostics and calibration feasibility",
        "",
        f"**Generated:** {payload['generated_at']}",
        "**Status:** research only. Production scoring was not changed. No retraining. SPAQ-200 files were not rewritten.",
        "",
        "Input: existing `spaq_200_machine_scores.csv` (n=200, all EfficientNet). Seed `20261107`. Five-fold split stratified by MOS quintile (8 test images per stratum per fold, 40 test / 160 train).",
        "",
        "## 1. Where compression happens",
        "",
        "Production map (copied, not modified):",
        "",
        "`boosted = clip(q * 0.5 + 0.42, 0, 1)` then 5/4/3/2/1 at 0.80 / 0.64 / 0.46 / 0.28.",
        "",
        f"- At q=0, boosted={payload['soft_score']['q0_boosted']}, badge={payload['soft_score']['q0_badge']}.",
        f"- Badge **1 is unreachable** for any q in [0, 1]: needs boosted < 0.28, i.e. q < -0.28.",
        "- Badge 2 only for q < 0.08. Badge 3 for q in [0.08, 0.44). Badge 4 [0.44, 0.76). Badge 5 q ≥ 0.76.",
        "",
        "Quality `q` is not always the raw head: defect heads invert (`1-raw`; Noise also `min(raw, 0.85)`). Brightness `q` is a triangle around luma 0.48.",
        "",
        "| Head | raw mean [min, max] | q mean [min, max] | q in bins 2/3/4/5 | badge hist 1–5 |",
        "|------|---------------------|-------------------|-------------------|----------------|",
    ]
    for k in HEADS:
        st = stages[k]
        rq = st["raw"]
        qq = st["q"]
        bh = st["badge"].get("histogram_1_5") or {}
        lines.append(
            f"| {k} | {fmt(rq['mean'])} [{fmt(rq['min'])}, {fmt(rq['max'])}] | "
            f"{fmt(qq['mean'])} [{fmt(qq['min'])}, {fmt(qq['max'])}] | "
            f"{st['n_q_in_badge2']}/{st['n_q_in_badge3']}/{st['n_q_in_badge4']}/{st['n_q_in_badge5']} | "
            f"{bh.get('1',0)}/{bh.get('2',0)}/{bh.get('3',0)}/{bh.get('4',0)}/{bh.get('5',0)} |"
        )
    lines += [
        "",
        f"Reconstructed `_soft_score(q)` matched stored badges on {payload['badge_reconstruct']['n_compared']} cells, mismatches={payload['badge_reconstruct']['n_mismatch']}.",
        "",
        "### Why particular integers dominate",
        "",
        "- **Brightness:** raw heads sit near mid/high luma, triangle `q` is high, so most photos land in the badge-5 bin (q ≥ 0.76).",
        "- **Contrast / Sharpness:** q piles in the wide badge-3 interval [0.08, 0.44).",
        "- **Noise:** after invert, many q values sit in badge 3–4.",
        "- **Overall:** mean of seven integers in a narrow set, so MOS-stratified photos still get overall 3.0–4.0.",
        "",
        "This is mapping geometry plus raw-head concentration. It is not a display bug in Flutter.",
        "",
        "## 2. Useful signal in raw heads? (exploratory, n=200, not held-out)",
        "",
        "Spearman on the same 200 used in Phase 10. This describes information loss, it is **not** a new independent validation.",
        "",
        "| Pair | raw/amount | q (quality) | integer badge | linear continuous 1–5 | equal-bin int |",
        "|------|------------|-------------|---------------|----------------------|---------------|",
    ]
    for key in ("overall_mos", "noise", "sharpness", "brightness", "contrast"):
        def r(label: str) -> str:
            return fmt(expl.get(f"{key}|{label}", {}).get("spearman_r"))

        lines.append(
            f"| {key} | {r('raw_or_amount')} | {r('q_quality')} | {r('badge')} | {r('linear_continuous')} | {r('equal_bin')} |"
        )
    lines += [
        "",
        "Math: a **strictly increasing** remap of one series cannot change Spearman against humans. Affine `a*x+b` with a>0 also leaves Pearson unchanged. Integer bins **can** change Spearman by adding ties. Averaging seven quantized heads **can** change overall ranking relative to averaging seven continuous `q` values.",
        "",
        f"Exploratory MOS: badge overall Spearman {fmt(expl.get('overall_mos|badge', {}).get('spearman_r'))}; mean of seven `q` {fmt(expl.get('overall_mos|q_quality', {}).get('spearman_r'))}; mean of seven raw heads {fmt(expl.get('overall_mos|raw_or_amount', {}).get('spearman_r'))}.",
        "",
        "## 3. Held-out results (5-fold, fit on train only)",
        "",
        "Each fold: 160 train / 40 test, 8 images from each MOS quintile. Supervised models never see test labels while fitting. Numbers below are **mean ± std of Spearman across folds**.",
        "",
        "| Method | Changes ranking? | Fit uses labels? | Spearman mean (std) |",
        "|--------|------------------|------------------|---------------------|",
    ]

    def cvrow(name: str) -> str:
        b = cv.get(name) or {}
        return f"{fmt(b.get('spearman_mean'))} ({fmt(b.get('spearman_std'))})"

    lines += [
        f"| MOS vs production overall badge | yes vs raw (quantize+mean) | no | {cvrow('overall_mos|heldout_badge')} |",
        f"| MOS vs mean of 7 `q` (held-out) | vs badge: yes | no | {cvrow('overall_mos|heldout_q')} |",
        f"| MOS ridge on 7 raw heads | yes | yes | {cvrow('ridge_raw7_to_mos')} |",
        f"| MOS ridge on 7 `q` | yes | yes | {cvrow('ridge_q7_to_mos')} |",
        f"| MOS ridge on 7 badges | yes | yes | {cvrow('ridge_badge7_to_mos')} |",
        f"| Noise vs `q` (held-out) | no vs raw invert | no | {cvrow('noise|heldout_q')} |",
        f"| Noise vs badge (held-out) | ties | no | {cvrow('noise|heldout_badge')} |",
        f"| Noise univariate linear on `q` | no if slope>0 | yes | {cvrow('uni_linear_q_noise')} |",
        f"| Noise isotonic on `q` | ties only | yes | {cvrow('uni_isotonic_q_noise')} |",
        f"| Noise train-quantile 5 bins | ties | yes (x only) | {cvrow('train_quantile_bins_noise')} |",
        f"| Sharpness vs `q` / badge | | no | {cvrow('sharpness|heldout_q')} / {cvrow('sharpness|heldout_badge')} |",
        f"| Sharpness linear / isotonic / train bins | | mixed | {cvrow('uni_linear_q_sharpness')} / {cvrow('uni_isotonic_q_sharpness')} / {cvrow('train_quantile_bins_sharpness')} |",
        f"| Brightness vs `q` / badge | | no | {cvrow('brightness|heldout_q')} / {cvrow('brightness|heldout_badge')} |",
        f"| Brightness linear / isotonic / train bins | | mixed | {cvrow('uni_linear_q_brightness')} / {cvrow('uni_isotonic_q_brightness')} / {cvrow('train_quantile_bins_brightness')} |",
        f"| Contrast vs `q` / badge | | no | {cvrow('contrast|heldout_q')} / {cvrow('contrast|heldout_badge')} |",
        f"| Contrast linear / isotonic / train bins | | mixed | {cvrow('uni_linear_q_contrast')} / {cvrow('uni_isotonic_q_contrast')} / {cvrow('train_quantile_bins_contrast')} |",
        "",
        "Blur, Blocking, and Ringing have **no SPAQ labels**. They are omitted from correlation tables.",
        "",
        "## 4. What mapping can and cannot do",
        "",
        "- **Cannot** create Sharpness / Brightness / Contrast / MOS agreement if the **q / raw ranking** itself is near zero vs SPAQ. Monotone calibration cannot invent rank signal.",
        "- **Can** change member-visible histograms (emit 1, reduce Brightness-at-5 pile-up) with an a priori ladder such as equal-width bins on `q`. That is a **display** change. It does not by itself make SPAQ Spearman large.",
        "- **Can** slightly change Spearman via fewer ties (continuous `q` vs 3-level badges). Phase 10 already showed MOS vs raw-mean ~0.17 vs badge ~0.",
        "- **Can** re-rank overall by learning weights on seven heads (ridge). That is a different predictor, not a display remap of the current overall mean. Held-out ridge Spearman must beat held-out `q`-mean and badge to count as evidence.",
        "",
        "## 5. Recommended next steps (evidence / feasibility / risk)",
        "",
        "Ranked after the numbers in this file. Production stays frozen until you approve a later change.",
        "",
        "1. **Treat member badges as compressed by design.** Evidence: unreachable 1, Brightness q in the 5-bin, Contrast/Sharpness in the 3-bin. Feasible display-only remap exists. Risk: XP and copy that assume 1–5 meaning.",
        "2. **Do not expect calibration of Sharpness, Brightness, Contrast, or overall badges to match SPAQ.** Held-out univariate maps track `q`, which is weakly aligned. Needs a **better predictor** (new labels, new heads, or a validated IQA model), not a new `_soft_score`.",
        "3. **Noise is the only SPAQ-aligned criterion with weak signal.** Mapping cannot turn 0.26 into a strong IQA score. Optional later work: keep invert, consider less quantization, or collect ACCESS-native noise ratings.",
        "4. **If overall MOS tracking is the product goal, evaluate a MOS-trained model (research MUSIQ/official TF Hub already in the toolkit) as a separate overall channel.** Do not silently replace the seven-head mean. High risk if mixed into XP without a product decision.",
        "5. **Do not retrain EfficientNet on these 200 SPAQ photos.** n is small and would leak this evaluation set.",
        "",
        "No production changes were implemented.",
        "",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run(csv_path: Path, out_dir: Path) -> dict[str, Any]:
    with csv_path.open(newline="", encoding="utf-8-sig") as handle:
        raw_rows = list(csv.DictReader(handle))
    rows = [reconstruct_row(r) for r in raw_rows]
    folds = stratified_folds(rows)
    fold_counts = Counter(folds)
    stratum_fold = Counter((rows[i]["stratum_id"], folds[i]) for i in range(len(rows)))
    payload = {
        "generated_at": _now(),
        "n": len(rows),
        "seed": SEED,
        "n_folds": N_FOLDS,
        "fold_sizes": dict(fold_counts),
        "stratum_fold_counts": {f"{s}:{k}": n for (s, k), n in sorted(stratum_fold.items())},
        "soft_score": soft_score_analysis(),
        "badge_reconstruct": badge_match(rows),
        "stages": stage_table(rows),
        "exploratory_full": exploratory_full(rows),
        "cross_validation": cv_supervised(rows, folds),
        "production_untouched": True,
        "phase10_csv_untouched": True,
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "phase11_metrics.json").write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
    write_report(payload, out_dir / "PHASE11_SCORING_DIAGNOSTICS.md")
    write_report(payload, _TOOLKIT / "PHASE11_SCORING_DIAGNOSTICS.md")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, default=SPAQ_CSV)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    payload = run(args.csv.resolve(), args.output_dir.resolve())
    print(
        json.dumps(
            {
                "n": payload["n"],
                "mismatches": payload["badge_reconstruct"]["n_mismatch"],
                "out": str(args.output_dir),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
