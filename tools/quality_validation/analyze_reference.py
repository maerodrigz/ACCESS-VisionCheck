"""Compare machine scores to external reference_labels.csv (SPAQ, LIVE-VQC)."""

from __future__ import annotations

from typing import Any

import pandas as pd

from tools.quality_validation.comparisons import ReferenceComparisonSpec, specs_for_media_type
from tools.quality_validation.metrics import mae_rmse, pearson_spearman, quadratic_weighted_kappa
from tools.quality_validation.reference_io import reference_mapped_value


def _machine_overall(row: dict) -> float | None:
    o = row.get("overall_score")
    return None if o is None else float(o)


def _machine_criterion(row: dict, spec: ReferenceComparisonSpec) -> float | None:
    if spec.machine_aggregate == "overall":
        return _machine_overall(row)
    scores = row.get("criterion_scores") or {}
    names = spec.machine_criterion_names
    if not names:
        return None
    vals = [scores.get(n) for n in names if scores.get(n) is not None]
    if not vals:
        return None
    if spec.machine_aggregate == "single":
        return float(vals[0])
    return float(sum(vals) / len(vals))


def analyze_reference_split(
    reference: pd.DataFrame,
    machine_rows: list[dict],
    *,
    split: str,
    engine: str | None,
) -> dict[str, Any]:
    mdf = pd.DataFrame(machine_rows)
    mdf = mdf[(mdf["dataset_split"] == split) & (mdf["analysis_status"] == "ok")]
    if engine:
        mdf = mdf[mdf["engine"] == engine]

    ref_split = reference[reference["dataset_split"] == split] if "dataset_split" in reference.columns else reference

    validated: dict[str, Any] = {}
    exploratory: dict[str, Any] = {}
    not_comparable: dict[str, Any] = {}

    has_media_type = "media_type" in ref_split.columns and ref_split["media_type"].astype(str).str.strip().ne("").any()

    for media_type in ("photo", "video"):
        if has_media_type:
            ref_mt = ref_split[ref_split["media_type"].str.lower() == media_type]
        else:
            ref_mt = ref_split if media_type == "photo" else ref_split.iloc[0:0]
        if ref_mt.empty:
            continue
        for spec in specs_for_media_type(media_type):
            bucket = {
                "directly_comparable": validated,
                "related_proxy": exploratory,
                "not_comparable": not_comparable,
            }[spec.comparability]

            if spec.comparability == "not_comparable":
                bucket[spec.key] = {
                    "comparability": spec.comparability,
                    "direction_note": spec.direction_note,
                    "pairs_used": 0,
                    "skipped_reason": "No machine rubric for this reference dimension.",
                }
                continue

            pairs_h: list[float] = []
            pairs_m: list[float] = []
            for _, rrow in ref_mt.iterrows():
                media_id = str(rrow.get("media_id", "")).strip()
                href = reference_mapped_value(rrow.to_dict(), spec.reference_mapped_column)
                if href is None:
                    continue
                mrows = mdf[mdf["media_id"] == media_id]
                if mrows.empty:
                    continue
                mrow = mrows.iloc[0].to_dict()
                mval = _machine_criterion(mrow, spec)
                if mval is None:
                    continue
                pairs_h.append(href)
                pairs_m.append(mval)

            entry: dict[str, Any] = {
                "comparability": spec.comparability,
                "reference_column": spec.reference_mapped_column,
                "machine_criteria": list(spec.machine_criterion_names) or ["__overall__"],
                "direction_note": spec.direction_note,
                **pearson_spearman(pairs_m, pairs_h),
                **mae_rmse(pairs_m, pairs_h),
                "pairs_used": len(pairs_h),
            }
            if len(pairs_h) >= 1:
                entry["quadratic_weighted_kappa"] = quadratic_weighted_kappa(
                    [int(round(v)) for v in pairs_m],
                    [int(round(v)) for v in pairs_h],
                )
            else:
                entry["quadratic_weighted_kappa"] = None

            if spec.comparability == "related_proxy":
                entry["validation_disclaimer"] = (
                    "Exploratory proxy only; do not report as validated criterion accuracy."
                )

            bucket[spec.key] = entry

    return {
        "split": split,
        "engine": engine or "all",
        "validated_criterion_metrics": validated,
        "exploratory_proxy_metrics": exploratory,
        "not_comparable": not_comparable,
        "policy_note": (
            "Only 'validated_criterion_metrics' (comparability=directly_comparable) may be cited "
            "as criterion-level validation. Proxy metrics are exploratory."
        ),
    }
