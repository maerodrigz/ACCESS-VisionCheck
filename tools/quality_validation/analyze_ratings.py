#!/usr/bin/env python3
"""Compare machine scores to human ratings (dev vs held-out enforced for reporting)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import pandas as pd

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for p in (_BACKEND, _REPO):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from tools.quality_validation.analyze_reference import analyze_reference_split  # noqa: E402
from tools.quality_validation.export import load_machine_results  # noqa: E402
from tools.quality_validation.reference_io import load_reference_labels  # noqa: E402
from tools.quality_validation.metrics import (  # noqa: E402
    fleiss_kappa,
    mae_rmse,
    pearson_spearman,
    quadratic_weighted_kappa,
    repeatability_std,
)

HUMAN_CRITERIA = [
    "sharpness_blur",
    "exposure",
    "noise_contrast",
    "compression_artifacts",
    "color_balance",
    "composition_framing",
    "subject_clarity",
    "video_motion_stability",
    "video_flickering",
    "overall_documentation",
]

MACHINE_MAP = {
    "sharpness_blur": ["Sharpness", "Blur"],
    "exposure": ["Brightness"],
    "noise_contrast": ["Noise", "Contrast"],
    "compression_artifacts": ["Blocking Artifacts", "Ringing Artifacts"],
    "color_balance": [],
    "composition_framing": [],
    "subject_clarity": [],
    "video_motion_stability": ["Motion Stability"],
    "video_flickering": ["Flickering"],
    "overall_documentation": ["__overall__"],
}


def _parse_rating(val) -> float | None:
    if val is None or (isinstance(val, float) and pd.isna(val)):
        return None
    s = str(val).strip().upper()
    if s in ("NA", "N/A", "CANNOT_RATE", "CANNOT RATE", "CR", ""):
        return None
    try:
        v = float(s)
        if 1 <= v <= 5:
            return v
    except ValueError:
        pass
    return None


def load_human_ratings(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    if "media_id" not in df.columns:
        raise ValueError("Human ratings CSV must include media_id")
    return df


def machine_overall(row: dict) -> float | None:
    o = row.get("overall_score")
    if o is None:
        return None
    return float(o)


def machine_criterion_mean(row: dict, names: list[str]) -> float | None:
    scores = row.get("criterion_scores") or {}
    vals = [scores.get(n) for n in names if scores.get(n) is not None]
    if not vals:
        return None
    return float(sum(vals) / len(vals))


def analyze_split(
    human: pd.DataFrame,
    machine_rows: list[dict],
    *,
    split: str,
    engine: str | None,
) -> dict:
    mdf = pd.DataFrame(machine_rows)
    mdf = mdf[(mdf["dataset_split"] == split) & (mdf["analysis_status"] == "ok")]
    if engine:
        mdf = mdf[mdf["engine"] == engine]

    report: dict = {
        "split": split,
        "engine": engine or "all",
        "n_machine_ok": len(mdf),
        "failure_rate": None,
        "criteria": {},
        "inter_rater": {},
    }

    total_machine = len([r for r in machine_rows if r.get("dataset_split") == split and (not engine or r.get("engine") == engine)])
    failed = total_machine - len(mdf)
    if total_machine:
        report["failure_rate"] = failed / total_machine

    human_split = human[human["dataset_split"] == split] if "dataset_split" in human.columns else human

    for crit in HUMAN_CRITERIA:
        human_cols = [c for c in human_split.columns if c == crit or c.startswith(f"{crit}_rater")]
        if not human_cols:
            continue
        pairs_h: list[float] = []
        pairs_m: list[float] = []
        for media_id, grp in human_split.groupby("media_id"):
            ratings = []
            if len(human_cols) == 1 and human_cols[0] == crit:
                for _, row in grp.iterrows():
                    v = _parse_rating(row.get(crit))
                    if v is not None:
                        ratings.append(v)
            else:
                for col in human_cols:
                    for val in grp[col].dropna().tolist():
                        v = _parse_rating(val)
                        if v is not None:
                            ratings.append(v)
            if not ratings:
                continue
            h_med = float(pd.Series(ratings).median())
            mrows = mdf[mdf["media_id"] == media_id]
            if mrows.empty:
                continue
            mrow = mrows.iloc[0].to_dict()
            if MACHINE_MAP[crit] == ["__overall__"]:
                mval = machine_overall(mrow)
            elif MACHINE_MAP[crit]:
                mval = machine_criterion_mean(mrow, MACHINE_MAP[crit])
            else:
                mval = None
            if mval is None:
                continue
            pairs_h.append(h_med)
            pairs_m.append(mval)

        report["criteria"][crit] = {
            **pearson_spearman(pairs_m, pairs_h),
            **mae_rmse(pairs_m, pairs_h),
            "quadratic_weighted_kappa": quadratic_weighted_kappa(
                [int(round(v)) for v in pairs_m],
                [int(round(v)) for v in pairs_h],
            ),
            "pairs_used": len(pairs_h),
        }

    # Inter-rater Fleiss on human columns ending with _raterN
    if "rater_id" in human_split.columns:
        rater_ids = sorted(human_split["rater_id"].dropna().unique())
        if len(rater_ids) >= 2:
            for crit in HUMAN_CRITERIA:
                if crit not in human_split.columns:
                    continue
                matrix_rows = []
                for media_id, grp in human_split.groupby("media_id"):
                    row_vals = []
                    for rid in rater_ids:
                        sub = grp[grp["rater_id"] == rid]
                        v = _parse_rating(sub[crit].iloc[0] if len(sub) else None)
                        row_vals.append(float("nan") if v is None else v)
                    if any(not pd.isna(x) for x in row_vals):
                        matrix_rows.append(row_vals)
                if matrix_rows:
                    mat = pd.DataFrame(matrix_rows).to_numpy(dtype=float)
                    report["inter_rater"][crit] = {"fleiss_kappa": fleiss_kappa(mat)}
    for crit in HUMAN_CRITERIA:
        rater_cols = [c for c in human_split.columns if c.startswith(f"{crit}_rater")]
        if len(rater_cols) < 2:
            continue
        matrix_rows = []
        for media_id, grp in human_split.groupby("media_id"):
            row_vals = []
            for col in rater_cols:
                v = _parse_rating(grp[col].iloc[0] if col in grp.columns else None)
                row_vals.append(float("nan") if v is None else v)
            if any(not pd.isna(x) for x in row_vals):
                matrix_rows.append(row_vals)
        if matrix_rows:
            mat = pd.DataFrame(matrix_rows).to_numpy(dtype=float)
            report["inter_rater"][f"{crit}_wide"] = {"fleiss_kappa": fleiss_kappa(mat)}

    return report


def compare_engines(machine_rows: list[dict], split: str) -> dict:
    dev = [r for r in machine_rows if r.get("dataset_split") == split and r.get("analysis_status") == "ok"]
    by_id: dict[str, dict[str, float]] = {}
    for r in dev:
        mid = r["media_id"]
        eng = r["engine"]
        o = r.get("overall_score")
        if o is not None:
            by_id.setdefault(mid, {})[eng] = float(o)
    pairs_x, pairs_y = [], []
    for scores in by_id.values():
        if "efficientnet" in scores and "opencv" in scores:
            pairs_x.append(scores["efficientnet"])
            pairs_y.append(scores["opencv"])
    return {"split": split, "engine_comparison_overall": pearson_spearman(pairs_x, pairs_y), "n_paired": len(pairs_x)}


def repeatability_report(repeat_rows: list[dict]) -> dict:
    by_key: dict[tuple, list[float]] = {}
    for r in repeat_rows:
        if r.get("analysis_status") != "ok":
            continue
        key = (r.get("media_id"), r.get("engine"))
        o = r.get("overall_score")
        if o is not None:
            by_key.setdefault(key, []).append(float(o))
    stats_out = {}
    for key, vals in by_key.items():
        stats_out[f"{key[0]}|{key[1]}"] = repeatability_std(vals)
    return stats_out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Analyze human vs machine quality validation results")
    parser.add_argument("--machine-results", type=Path, required=True)
    parser.add_argument("--human-ratings", type=Path, default=None, help="ACCESS human rating CSV (optional)")
    parser.add_argument(
        "--reference-labels",
        type=Path,
        default=None,
        help="reference_labels.csv from dataset import (SPAQ / LIVE-VQC)",
    )
    parser.add_argument("--output", type=Path, default=Path("tools/quality_validation/output/analysis_report.json"))
    parser.add_argument(
        "--calibration-split",
        default="dev",
        help="Split used for exploratory metrics (held-out reported separately, not for tuning in this tool)",
    )
    args = parser.parse_args(argv)

    if not args.human_ratings and not args.reference_labels:
        parser.error("Provide --human-ratings and/or --reference-labels")

    meta, machine_rows = load_machine_results(args.machine_results.resolve())
    human = load_human_ratings(args.human_ratings.resolve()) if args.human_ratings else None
    reference = load_reference_labels(args.reference_labels.resolve()) if args.reference_labels else None

    held_out_note = (
        "Held-out metrics are reported for generalization only. "
        "Do not use held_out split for weight/threshold calibration."
    )

    def split_block(split: str) -> dict:
        block: dict = {"engine_comparison": compare_engines(machine_rows, split)}
        if human is not None:
            block["access_human_ratings"] = {
                "efficientnet": analyze_split(human, machine_rows, split=split, engine="efficientnet"),
                "opencv": analyze_split(human, machine_rows, split=split, engine="opencv"),
            }
        if reference is not None:
            block["reference_labels"] = {
                "efficientnet": analyze_reference_split(reference, machine_rows, split=split, engine="efficientnet"),
                "opencv": analyze_reference_split(reference, machine_rows, split=split, engine="opencv"),
            }
        return block

    report = {
        "metadata": meta,
        "policy_note": held_out_note,
        "dev": split_block("dev"),
        "held_out": split_block("held_out"),
        "missing_data_rates": {
            "human_rows": len(human) if human is not None else 0,
            "reference_rows": len(reference) if reference is not None else 0,
            "machine_rows": len(machine_rows),
            "machine_failed": sum(1 for r in machine_rows if r.get("analysis_status") != "ok"),
        },
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"Wrote analysis to {args.output.resolve()}")
    print(held_out_note)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
