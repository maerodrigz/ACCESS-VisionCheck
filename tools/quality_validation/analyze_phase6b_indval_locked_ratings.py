#!/usr/bin/env python3
"""Phase 6B INDVAL: validate locked R2/R3 exports, join machines, analyze.

Reads (does not modify):
  workspace/phase4a_indval/phase6b_R2_locked_ratings.csv.csv
  workspace/phase4a_indval/phase6b_R3_locked_ratings.csv.csv
  workspace/phase4a_indval/machine_output/machine_scores.csv
  workspace/phase4a_indval/machine_output/musiq_live_docker_20261114T074630Z/musiq_live_scores.csv

Writes NEW files only:
  workspace/phase4a_indval/phase6b_locked_ratings.csv
  workspace/phase4a_indval/phase6b_statistical_analysis/*
"""

from __future__ import annotations

import csv
import json
import math
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

_TOOLKIT = Path(__file__).resolve().parent
if str(_TOOLKIT) not in sys.path:
    sys.path.insert(0, str(_TOOLKIT))

from metrics import mae_rmse, pearson_spearman, quadratic_weighted_kappa  # noqa: E402

ROOT = _TOOLKIT / "workspace" / "phase4a_indval"
# Actual on-disk names (Windows double .csv.csv); originals are never renamed.
R2_PATH = ROOT / "phase6b_R2_locked_ratings.csv.csv"
R3_PATH = ROOT / "phase6b_R3_locked_ratings.csv.csv"
OPENCV_PATH = ROOT / "machine_output" / "machine_scores.csv"
MUSIQ_PATH = (
    ROOT
    / "machine_output"
    / "musiq_live_docker_20261114T074630Z"
    / "musiq_live_scores.csv"
)
COMBINED_OUT = ROOT / "phase6b_locked_ratings.csv"
OUT_DIR = ROOT / "phase6b_statistical_analysis"

CRITERIA = (
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
    "overall_visual_quality",
)

# Conceptually matched human↔machine pairs (MUSIQ = overall only).
OPENCV_PAIRS = (
    ("sharpness", "hybrid_badge_sharpness", "hybrid_q_sharpness"),
    ("blur", "hybrid_badge_blur", "hybrid_q_blur"),
    ("brightness", "hybrid_badge_brightness", "hybrid_q_brightness"),
    ("contrast", "hybrid_badge_contrast", "hybrid_q_contrast"),
    ("blocking_artifacts", "hybrid_badge_blocking_artifacts", "hybrid_q_blocking_artifacts"),
)

EXPECTED_IDS = [f"INDVAL-{i:03d}" for i in range(1, 101)]


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def _write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str] | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows and not fieldnames:
        path.write_text("", encoding="utf-8")
        return
    cols = fieldnames or []
    if not cols:
        for row in rows:
            for k in row:
                if k not in cols:
                    cols.append(k)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k, "") for k in cols})


def _parse_rating(v: Any) -> float | None | str:
    """Return float 1-5, 'N/A', or None (missing/invalid)."""
    if v is None:
        return None
    if isinstance(v, (int, float)):
        if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
            return None
        fv = float(v)
        if fv == int(fv) and 1 <= int(fv) <= 5:
            return float(int(fv))
        return None
    s = str(v).strip()
    if s == "" or s.lower() in {"null", "none"}:
        return None
    if s.upper() == "N/A":
        return "N/A"
    try:
        fv = float(s)
    except ValueError:
        return None
    if fv == int(fv) and 1 <= int(fv) <= 5:
        return float(int(fv))
    return None


def _parse_ratings_json(raw: str) -> dict[str, Any]:
    if not raw or not str(raw).strip():
        return {}
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise ValueError("ratings_json is not an object")
    return data


def validate_locked_export(path: Path, expected_evaluator: str) -> list[dict[str, Any]]:
    if not path.is_file():
        raise SystemExit(f"ERROR: missing export: {path}")
    rows = _read_csv(path)
    required = {"evaluator_id", "media_id", "status", "ratings_json"}
    if not rows:
        raise SystemExit(f"ERROR: empty CSV: {path}")
    missing_cols = required - set(rows[0].keys())
    if missing_cols:
        raise SystemExit(f"ERROR: {path.name} missing columns {sorted(missing_cols)}")

    parsed: list[dict[str, Any]] = []
    ids: list[str] = []
    for i, row in enumerate(rows, start=2):
        eid = (row.get("evaluator_id") or "").strip()
        mid = (row.get("media_id") or "").strip()
        status = (row.get("status") or "").strip().lower()
        if eid != expected_evaluator:
            raise SystemExit(
                f"ERROR: {path.name} line {i}: expected evaluator_id={expected_evaluator}, got {eid!r}"
            )
        if status != "locked":
            raise SystemExit(
                f"ERROR: {path.name} line {i} {mid}: status={status!r}, expected locked"
            )
        try:
            rj = _parse_ratings_json(row.get("ratings_json") or "")
        except Exception as exc:  # noqa: BLE001
            raise SystemExit(f"ERROR: {path.name} line {i} {mid}: bad ratings_json ({exc})") from exc

        scores: dict[str, Any] = {}
        n_numeric = 0
        for c in CRITERIA:
            if c not in rj:
                raise SystemExit(
                    f"ERROR: {path.name} line {i} {mid}: ratings_json missing criterion {c}"
                )
            parsed_v = _parse_rating(rj[c])
            if parsed_v is None:
                raise SystemExit(
                    f"ERROR: {path.name} line {i} {mid}: invalid value for {c}={rj[c]!r}"
                )
            scores[c] = parsed_v
            if isinstance(parsed_v, float):
                n_numeric += 1
        if n_numeric == 0:
            raise SystemExit(
                f"ERROR: {path.name} line {i} {mid}: no numeric ratings (all N/A or empty)"
            )
        ids.append(mid)
        out = {
            "evaluator_id": eid,
            "media_id": mid,
            "status": "locked",
            "ratings_json": json.dumps(
                {c: (int(scores[c]) if isinstance(scores[c], float) else scores[c]) for c in CRITERIA},
                ensure_ascii=False,
                separators=(",", ":"),
            ),
            **{f"human_{c}": scores[c] for c in CRITERIA},
            "n_numeric_criteria": n_numeric,
            "source_file": path.name,
        }
        parsed.append(out)

    if len(ids) != 100:
        raise SystemExit(f"ERROR: {path.name}: expected 100 rows, got {len(ids)}")
    if len(set(ids)) != 100:
        dups = [k for k, v in Counter(ids).items() if v > 1]
        raise SystemExit(f"ERROR: {path.name}: duplicate media_id {dups[:5]}")
    if set(ids) != set(EXPECTED_IDS):
        missing = sorted(set(EXPECTED_IDS) - set(ids))
        extra = sorted(set(ids) - set(EXPECTED_IDS))
        raise SystemExit(
            f"ERROR: {path.name}: ID set mismatch missing={missing[:5]} extra={extra[:5]}"
        )
    # Enforce INDVAL-001..100 order for reproducibility
    by_id = {r["media_id"]: r for r in parsed}
    return [by_id[i] for i in EXPECTED_IDS]


def _float_or_none(v: Any) -> float | None:
    if v is None:
        return None
    s = str(v).strip()
    if s == "" or s.upper() == "N/A" or s.lower() in {"nan", "none", "null"}:
        return None
    try:
        x = float(s)
    except ValueError:
        return None
    if not math.isfinite(x):
        return None
    return x


def _pairs(a: list[float | None], b: list[float | None]) -> tuple[list[float], list[float]]:
    xs: list[float] = []
    ys: list[float] = []
    for x, y in zip(a, b, strict=True):
        if x is None or y is None:
            continue
        xs.append(float(x))
        ys.append(float(y))
    return xs, ys


def _human_val(row: dict[str, Any], criterion: str) -> float | None:
    v = row.get(f"human_{criterion}")
    if v == "N/A" or v is None:
        return None
    return float(v)


def main() -> int:
    print("Validating locked exports…")
    print(f"  R2 path: {R2_PATH}")
    print(f"  R3 path: {R3_PATH}")
    if not R2_PATH.is_file() or not R3_PATH.is_file():
        raise SystemExit(
            "ERROR: expected phase6b_R2/R3_locked_ratings.csv not found; "
            f"found double-extension files only if present: "
            f"R2={R2_PATH.is_file()} R3={R3_PATH.is_file()}"
        )

    r2 = validate_locked_export(R2_PATH, "R2")
    r3 = validate_locked_export(R3_PATH, "R3")
    print("  R2/R3: 100 unique INDVAL IDs, evaluator OK, status=locked, ratings_json OK")

    if not OPENCV_PATH.is_file():
        raise SystemExit(f"ERROR: missing OpenCV scores: {OPENCV_PATH}")
    if not MUSIQ_PATH.is_file():
        raise SystemExit(f"ERROR: missing MUSIQ scores: {MUSIQ_PATH}")

    opencv_rows = _read_csv(OPENCV_PATH)
    musiq_rows = _read_csv(MUSIQ_PATH)
    opencv_by = {r["indval_id"].strip(): r for r in opencv_rows}
    musiq_by = {r["indval_id"].strip(): r for r in musiq_rows}
    if set(opencv_by) != set(EXPECTED_IDS):
        raise SystemExit("ERROR: OpenCV machine_scores.csv ID set != INDVAL-001..100")
    if set(musiq_by) != set(EXPECTED_IDS):
        raise SystemExit("ERROR: MUSIQ live scores ID set != INDVAL-001..100")

    # SHA mapping check
    sha_mismatch = []
    for mid in EXPECTED_IDS:
        s1 = (opencv_by[mid].get("file_sha256") or "").strip().lower()
        s2 = (musiq_by[mid].get("file_sha256") or "").strip().lower()
        if s1 and s2 and s1 != s2:
            sha_mismatch.append(mid)
    if sha_mismatch:
        raise SystemExit(f"ERROR: OpenCV↔MUSIQ SHA mismatch: {sha_mismatch[:5]}")

    # Combined long export (preserve originals)
    combined = []
    for rows in (r2, r3):
        for r in rows:
            combined.append(
                {
                    "evaluator_id": r["evaluator_id"],
                    "media_id": r["media_id"],
                    "status": r["status"],
                    "ratings_json": r["ratings_json"],
                    **{
                        c: (int(r[f"human_{c}"]) if isinstance(r[f"human_{c}"], float) else r[f"human_{c}"])
                        for c in CRITERIA
                    },
                    "n_numeric_criteria": r["n_numeric_criteria"],
                    "source_file": r["source_file"],
                }
            )
    if COMBINED_OUT.exists():
        raise SystemExit(f"ERROR: refusing to overwrite existing {COMBINED_OUT}")
    _write_csv(COMBINED_OUT, combined)
    print(f"  wrote combined: {COMBINED_OUT}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Wide join table
    r2_by = {r["media_id"]: r for r in r2}
    r3_by = {r["media_id"]: r for r in r3}
    joined: list[dict[str, Any]] = []
    for mid in EXPECTED_IDS:
        o = opencv_by[mid]
        m = musiq_by[mid]
        a = r2_by[mid]
        b = r3_by[mid]
        row: dict[str, Any] = {
            "media_id": mid,
            "file_sha256": o.get("file_sha256"),
            "source_media_key": o.get("source_media_key"),
            "musiq_opq_raw": _float_or_none(m.get("musiq_opq_raw")),
            "musiq_status": m.get("musiq_status"),
            "musiq_finite_ok": m.get("musiq_finite_ok"),
        }
        for c in CRITERIA:
            row[f"R2_{c}"] = a[f"human_{c}"]
            row[f"R3_{c}"] = b[f"human_{c}"]
            # pairwise consensus median when both numeric
            hv = []
            for rr in (a, b):
                v = rr[f"human_{c}"]
                if isinstance(v, float):
                    hv.append(v)
            row[f"human_median_{c}"] = float(np.median(hv)) if hv else None
            row[f"human_n_{c}"] = len(hv)
        for _, badge_col, q_col in OPENCV_PAIRS:
            row[badge_col] = _float_or_none(o.get(badge_col))
            row[q_col] = _float_or_none(o.get(q_col))
        joined.append(row)

    _write_csv(OUT_DIR / "joined_human_opencv_musiq.csv", joined)

    # Descriptive statistics
    desc_rows: list[dict[str, Any]] = []
    for rater, data in (("R2", r2), ("R3", r3)):
        for c in CRITERIA:
            vals = [_human_val(r, c) for r in data]
            nums = [v for v in vals if v is not None]
            n_na = sum(1 for r in data if r[f"human_{c}"] == "N/A")
            desc_rows.append(
                {
                    "rater": rater,
                    "criterion": c,
                    "n_numeric": len(nums),
                    "n_na": n_na,
                    "mean": round(float(np.mean(nums)), 4) if nums else None,
                    "median": round(float(np.median(nums)), 4) if nums else None,
                    "std": round(float(np.std(nums, ddof=1)), 4) if len(nums) > 1 else None,
                    "min": int(min(nums)) if nums else None,
                    "max": int(max(nums)) if nums else None,
                }
            )
    _write_csv(OUT_DIR / "descriptive_human_by_criterion.csv", desc_rows)

    # Inter-rater R2 vs R3
    irr_rows: list[dict[str, Any]] = []
    for c in CRITERIA:
        a = [_human_val(r2_by[mid], c) for mid in EXPECTED_IDS]
        b = [_human_val(r3_by[mid], c) for mid in EXPECTED_IDS]
        xs, ys = _pairs(a, b)
        corr = pearson_spearman(xs, ys)
        # exact agreement + QWK on paired integers only
        exact = sum(1 for x, y in zip(xs, ys, strict=True) if int(x) == int(y))
        qwk = quadratic_weighted_kappa(
            [int(x) for x in xs],
            [int(y) for y in ys],
            1,
            5,
        )
        abs_diff = [abs(x - y) for x, y in zip(xs, ys, strict=True)]
        irr_rows.append(
            {
                "criterion": c,
                "n_paired_numeric": len(xs),
                "n_excluded_na_or_missing": 100 - len(xs),
                "spearman_r": corr.get("spearman_r"),
                "spearman_p": corr.get("spearman_p"),
                "pearson_r": corr.get("pearson_r"),
                "pearson_p": corr.get("pearson_p"),
                "quadratic_weighted_kappa": qwk,
                "exact_agreement": exact,
                "exact_agreement_rate": (exact / len(xs)) if xs else None,
                "mae": (float(np.mean(abs_diff)) if abs_diff else None),
                "corr_note": corr.get("note"),
            }
        )
    _write_csv(OUT_DIR / "inter_rater_R2_vs_R3.csv", irr_rows)

    # Human vs machine (use median of available raters; also report per-rater)
    hvm_rows: list[dict[str, Any]] = []

    def add_hvm(
        label: str,
        human_series: list[float | None],
        machine_series: list[float | None],
        *,
        machine_kind: str,
        criterion: str,
        mae_applicable: bool,
        note: str,
    ) -> None:
        xs, ys = _pairs(human_series, machine_series)
        corr = pearson_spearman(xs, ys)
        err = mae_rmse(xs, ys) if mae_applicable else {"mae": None, "rmse": None, "n": len(xs)}
        hvm_rows.append(
            {
                "comparison": label,
                "criterion": criterion,
                "machine_kind": machine_kind,
                "n": len(xs),
                "spearman_r": corr.get("spearman_r"),
                "spearman_p": corr.get("spearman_p"),
                "pearson_r": corr.get("pearson_r"),
                "pearson_p": corr.get("pearson_p"),
                "mae": err.get("mae") if mae_applicable else None,
                "mae_applicable": mae_applicable,
                "note": note,
                "corr_note": corr.get("note"),
            }
        )

    for human_c, badge_col, q_col in OPENCV_PAIRS:
        human_med = [joined[i][f"human_median_{human_c}"] for i in range(100)]
        # Convert median may be float like 3.5 — keep as float for Spearman
        badge = [joined[i][badge_col] for i in range(100)]
        q = [joined[i][q_col] for i in range(100)]
        add_hvm(
            f"human_median_vs_opencv_badge_{human_c}",
            human_med,
            badge,
            machine_kind="opencv_equal_bin_badge",
            criterion=human_c,
            mae_applicable=True,
            note="OpenCV experimental equal-bin badge (1-5); higher=better",
        )
        add_hvm(
            f"human_median_vs_opencv_q_{human_c}",
            human_med,
            q,
            machine_kind="opencv_continuous_q",
            criterion=human_c,
            mae_applicable=False,
            note="OpenCV continuous q in [0,1]; MAE omitted (scale mismatch)",
        )
        for rater, prefix in (("R2", "R2_"), ("R3", "R3_")):
            hs = [
                None if joined[i][f"{prefix}{human_c}"] == "N/A" else _float_or_none(joined[i][f"{prefix}{human_c}"])
                for i in range(100)
            ]
            add_hvm(
                f"{rater}_vs_opencv_badge_{human_c}",
                hs,
                badge,
                machine_kind="opencv_equal_bin_badge",
                criterion=human_c,
                mae_applicable=True,
                note=f"{rater} only vs OpenCV badge",
            )

    # MUSIQ vs overall only
    overall_med = [joined[i]["human_median_overall_visual_quality"] for i in range(100)]
    musiq = [joined[i]["musiq_opq_raw"] for i in range(100)]
    add_hvm(
        "human_median_overall_vs_musiq_opq",
        overall_med,
        musiq,
        machine_kind="musiq_paq2piq_opq",
        criterion="overall_visual_quality",
        mae_applicable=False,
        note="MUSIQ ~0-100 overall OPQ only; not a criterion-specific predictor; MAE omitted",
    )
    for rater, prefix in (("R2", "R2_"), ("R3", "R3_")):
        hs = [
            None
            if joined[i][f"{prefix}overall_visual_quality"] == "N/A"
            else _float_or_none(joined[i][f"{prefix}overall_visual_quality"])
            for i in range(100)
        ]
        add_hvm(
            f"{rater}_overall_vs_musiq_opq",
            hs,
            musiq,
            machine_kind="musiq_paq2piq_opq",
            criterion="overall_visual_quality",
            mae_applicable=False,
            note=f"{rater} overall vs MUSIQ OPQ; scale mismatch; MAE omitted",
        )

    # Explicit non-matched criteria inventory
    for c in ("noise", "ringing_artifacts"):
        hvm_rows.append(
            {
                "comparison": f"no_machine_match_{c}",
                "criterion": c,
                "machine_kind": "none",
                "n": None,
                "spearman_r": None,
                "spearman_p": None,
                "pearson_r": None,
                "pearson_p": None,
                "mae": None,
                "mae_applicable": False,
                "note": "Human criterion has no frozen OpenCV/MUSIQ counterpart in this join; IRR only",
                "corr_note": None,
            }
        )

    _write_csv(OUT_DIR / "human_vs_machine_spearman.csv", hvm_rows)

    # N/A inventory
    na_rows = []
    for rater, data in (("R2", r2), ("R3", r3)):
        for c in CRITERIA:
            ids_na = [r["media_id"] for r in data if r[f"human_{c}"] == "N/A"]
            na_rows.append(
                {
                    "rater": rater,
                    "criterion": c,
                    "n_na": len(ids_na),
                    "media_ids": ";".join(ids_na),
                }
            )
    _write_csv(OUT_DIR / "na_inventory.csv", na_rows)

    # Graphs
    fig, axes = plt.subplots(2, 4, figsize=(14, 7))
    axes = axes.ravel()
    for i, c in enumerate(CRITERIA):
        ax = axes[i]
        xs, ys = _pairs(
            [_human_val(r2_by[mid], c) for mid in EXPECTED_IDS],
            [_human_val(r3_by[mid], c) for mid in EXPECTED_IDS],
        )
        ax.scatter(xs, ys, alpha=0.55, s=22, c="#0052D4")
        ax.plot([1, 5], [1, 5], "--", color="#94A3B8", linewidth=1)
        ax.set_xlim(0.5, 5.5)
        ax.set_ylim(0.5, 5.5)
        ax.set_xticks(range(1, 6))
        ax.set_yticks(range(1, 6))
        ax.set_title(c.replace("_", " "), fontsize=9)
        ax.set_xlabel("R2")
        ax.set_ylabel("R3")
        if xs:
            sr = pearson_spearman(xs, ys).get("spearman_r")
            ax.text(
                0.05,
                0.95,
                f"n={len(xs)}\nρ={sr:.3f}" if sr is not None else f"n={len(xs)}",
                transform=ax.transAxes,
                va="top",
                fontsize=8,
            )
    fig.suptitle("INDVAL inter-rater: R2 vs R3 (1–5)", fontsize=12)
    fig.tight_layout()
    fig.savefig(OUT_DIR / "fig_inter_rater_R2_vs_R3.png", dpi=150)
    plt.close(fig)

    # HVM OpenCV badge bar
    labels = []
    rhos = []
    ns = []
    for human_c, badge_col, _ in OPENCV_PAIRS:
        row = next(
            r
            for r in hvm_rows
            if r["comparison"] == f"human_median_vs_opencv_badge_{human_c}"
        )
        labels.append(human_c.replace("_artifacts", ""))
        rhos.append(row["spearman_r"] if row["spearman_r"] is not None else 0.0)
        ns.append(row["n"])
    fig, ax = plt.subplots(figsize=(8, 4.5))
    colors = ["#0052D4" if (r is not None and r == r) else "#94A3B8" for r in rhos]
    ax.bar(labels, [r if r is not None else 0 for r in rhos], color=colors)
    ax.axhline(0, color="#64748B", linewidth=0.8)
    ax.set_ylabel("Spearman ρ")
    ax.set_title("Human median vs OpenCV equal-bin badge")
    for i, (rho, n) in enumerate(zip(rhos, ns, strict=True)):
        ax.text(i, (rho or 0) + 0.02, f"n={n}", ha="center", fontsize=8)
    fig.tight_layout()
    fig.savefig(OUT_DIR / "fig_human_vs_opencv_badge_spearman.png", dpi=150)
    plt.close(fig)

    # MUSIQ vs overall scatter
    fig, ax = plt.subplots(figsize=(5.5, 4.5))
    xs, ys = _pairs(overall_med, musiq)
    ax.scatter(ys, xs, alpha=0.55, s=28, c="#00C4E8")
    ax.set_xlabel("MUSIQ OPQ (~0–100)")
    ax.set_ylabel("Human overall median (1–5)")
    ax.set_title("Overall visual quality vs MUSIQ")
    corr = pearson_spearman(xs, ys)
    ax.text(
        0.05,
        0.95,
        f"n={len(xs)}\nSpearman ρ={corr.get('spearman_r'):.3f}\np={corr.get('spearman_p'):.4g}"
        if corr.get("spearman_r") is not None
        else f"n={len(xs)}",
        transform=ax.transAxes,
        va="top",
        fontsize=9,
    )
    fig.tight_layout()
    fig.savefig(OUT_DIR / "fig_overall_vs_musiq.png", dpi=150)
    plt.close(fig)

    # Interpretation
    def fmt_rho(row: dict[str, Any]) -> str:
        r = row.get("spearman_r")
        p = row.get("spearman_p")
        n = row.get("n_paired_numeric", row.get("n"))
        if r is None:
            return f"n={n}, ρ undefined"
        return f"n={n}, ρ={r:.3f}, p={p:.4g}"

    lines = [
        "# Phase 6B INDVAL statistical analysis (R2/R3 locked + OpenCV + MUSIQ)",
        "",
        f"**Generated (UTC):** {_now()}",
        f"**Combined ratings:** `{COMBINED_OUT}`",
        f"**Output folder:** `{OUT_DIR}`",
        "",
        "## Data provenance",
        "",
        f"- Human R2 source file on disk: `{R2_PATH.name}` (double `.csv.csv` extension)",
        f"- Human R3 source file on disk: `{R3_PATH.name}` (double `.csv.csv` extension)",
        "- Originals were not modified or overwritten.",
        "- OpenCV: frozen `machine_scores.csv` hybrid_q / hybrid_badge columns.",
        "- MUSIQ: `musiq_live_docker_20261114T074630Z/musiq_live_scores.csv` (100/100 ok).",
        "- Join key: `media_id` / `indval_id` = INDVAL-001…100; SHA matched OpenCV↔MUSIQ.",
        "",
        "## Validation",
        "",
        "- Each rater export: 100 unique INDVAL IDs, `evaluator_id` R2/R3, `status=locked`.",
        "- `ratings_json` present for all eight criteria; values are integers 1–5 or N/A.",
        "- Pairwise analyses exclude N/A (and never impute).",
        "",
        "## Inter-rater reliability (R2 vs R3)",
        "",
    ]
    for row in irr_rows:
        qwk = row["quadratic_weighted_kappa"]
        qwk_s = f"{qwk:.3f}" if qwk is not None else "n/a"
        ea = row["exact_agreement_rate"]
        ea_s = f"{ea:.3f}" if ea is not None else "n/a"
        lines.append(
            f"- **{row['criterion']}:** {fmt_rho(row)}; QWK={qwk_s}; exact agreement rate={ea_s}"
        )

    lines += [
        "",
        "## Human vs machine (Spearman)",
        "",
        "### OpenCV equal-bin badges (conceptually matched criteria)",
        "",
    ]
    for human_c, _, _ in OPENCV_PAIRS:
        row = next(
            r
            for r in hvm_rows
            if r["comparison"] == f"human_median_vs_opencv_badge_{human_c}"
        )
        lines.append(f"- **{human_c}:** {fmt_rho(row)}")

    musiq_row = next(
        r for r in hvm_rows if r["comparison"] == "human_median_overall_vs_musiq_opq"
    )
    lines += [
        "",
        "### MUSIQ PaQ-2-PiQ (overall construct only)",
        "",
        f"- **overall_visual_quality vs MUSIQ OPQ:** {fmt_rho(musiq_row)}",
        "- MUSIQ is an overall perceptual score (~0–100). It is **not** treated as a",
        "  predictor of sharpness, blur, noise, brightness, contrast, blocking, or ringing.",
        "",
        "### No machine counterpart in this freeze",
        "",
        "- **noise**, **ringing_artifacts**: human IRR only (no OpenCV/MUSIQ criterion columns).",
        "",
        "## Interpretation (research-ready, cautious)",
        "",
        "- This analysis uses **two locked human raters (R2, R3)** on the INDVAL holdout.",
        "  R1 was not included in the provided locked exports.",
        "- Inter-rater Spearman/QWK summarize agreement after dropping N/A pairwise.",
        "  Moderate disagreement is expected for subtle compression/noise criteria.",
        "- OpenCV badges are **experimental a-priori equal-bin** maps (`phase9_a_priori_equal_bin_v1`),",
        "  not production member-facing scores. Correlations vs humans are descriptive,",
        "  not a claim of production readiness or superiority over EfficientNet-B0.",
        "- MUSIQ correlations are reported **only vs overall visual quality**.",
        "  MAE is omitted for MUSIQ because scales differ (1–5 vs ~0–100) without a frozen calibrator.",
        "- N/A cells are excluded from correlations; they are inventoried in `na_inventory.csv`.",
        "",
        "## Limitations",
        "",
        "- Only two raters (no three-rater consensus / Fleiss κ across R1–R3).",
        "- Human medians use n=1 when the other rater marked N/A for that criterion.",
        "- OpenCV badge MAE assumes comparable 1–5 ordinal labels; still experimental.",
        "- No multiple-comparison correction; p-values are nominal.",
        "- Phase 4A blank templates were not used and were not overwritten.",
        "",
        "## Output files",
        "",
        "- `joined_human_opencv_musiq.csv`",
        "- `descriptive_human_by_criterion.csv`",
        "- `inter_rater_R2_vs_R3.csv`",
        "- `human_vs_machine_spearman.csv`",
        "- `na_inventory.csv`",
        "- `fig_inter_rater_R2_vs_R3.png`",
        "- `fig_human_vs_opencv_badge_spearman.png`",
        "- `fig_overall_vs_musiq.png`",
        "- `INTERPRETATION.md` (this file)",
        "- `run_meta.json`",
        "",
    ]
    (OUT_DIR / "INTERPRETATION.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    meta = {
        "generated_at_utc": _now(),
        "r2_source": str(R2_PATH),
        "r3_source": str(R3_PATH),
        "combined_out": str(COMBINED_OUT),
        "opencv": str(OPENCV_PATH),
        "musiq": str(MUSIQ_PATH),
        "n_images": 100,
        "raters": ["R2", "R3"],
        "sha_mismatch_opencv_musiq": sha_mismatch,
        "originals_modified": False,
        "musiq_treated_as_overall_only": True,
        "note": "Source exports used double extension .csv.csv on disk",
    }
    (OUT_DIR / "run_meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    print(f"Analysis complete -> {OUT_DIR}")
    print("Primary IRR / HVM Spearman:")
    for row in irr_rows:
        print(
            f"  IRR {row['criterion']}: n={row['n_paired_numeric']} "
            f"ρ={row['spearman_r']} p={row['spearman_p']}"
        )
    for human_c, _, _ in OPENCV_PAIRS:
        row = next(
            r
            for r in hvm_rows
            if r["comparison"] == f"human_median_vs_opencv_badge_{human_c}"
        )
        print(
            f"  HVM OpenCV badge {human_c}: n={row['n']} ρ={row['spearman_r']} p={row['spearman_p']}"
        )
    print(
        f"  HVM MUSIQ overall: n={musiq_row['n']} ρ={musiq_row['spearman_r']} p={musiq_row['spearman_p']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
