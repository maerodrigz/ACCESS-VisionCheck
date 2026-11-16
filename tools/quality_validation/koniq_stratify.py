#!/usr/bin/env python3
"""Select a stratified KonIQ-10k subset. Writes manifests only. No ZIP extract. No scoring."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
_REPO = _TOOLKIT.parents[1]
_BACKEND = _REPO / "access_backend"
for path in (_BACKEND, _REPO):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from tools.quality_validation.importers.koniq10k import import_koniq10k_rows  # noqa: E402
from tools.quality_validation.research_datasets import (  # noqa: E402
    KONIQ_ROOT,
    STRATUM_LABELS,
    assign_mos_quintile,
    deterministic_subset,
    koniq_quintile_cuts,
    write_published_mos,
    write_subset_manifest,
)

DEFAULT_SEED = 20261107
DEFAULT_PER_STRATUM = 20
RUN001_MANIFEST = KONIQ_ROOT / "metadata" / "subset_manifest.csv"
SCORES = KONIQ_ROOT / "metadata" / "koniq10k_scores_and_distributions.csv"
RUN002_ROOT = KONIQ_ROOT / "run_002"
SELECTION_COLUMNS = (
    "media_id",
    "source_media_key",
    "relative_path",
    "media_type",
    "mos_quality_raw",
    "overall_mapped_1_5",
    "stratum_id",
    "stratum_label",
    "stratum_mos_low",
    "stratum_mos_high",
    "selection_seed",
    "excluded_run001",
)


def load_run001_filenames(path: Path) -> set[str]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return {(row.get("source_media_key") or "").strip() for row in csv.DictReader(handle) if row.get("source_media_key")}


def stratum_bounds(cuts: tuple[float, ...], stratum_id: int) -> tuple[float, float]:
    if stratum_id == 1:
        return cuts[0], cuts[1]
    if stratum_id == 5:
        return cuts[4], cuts[5]
    return cuts[stratum_id - 1], cuts[stratum_id]


def select_stratified(
    rows: list[dict[str, Any]],
    *,
    exclude: set[str],
    n_per_stratum: int,
    seed: int,
    id_prefix: str = "KONIQ2",
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    with_mos = [r for r in rows if isinstance(r.get("mos_quality_raw"), (int, float))]
    cuts = koniq_quintile_cuts([float(r["mos_quality_raw"]) for r in with_mos])
    by_stratum: dict[int, list[dict[str, Any]]] = defaultdict(list)
    catalog_counts: Counter[int] = Counter()
    pool_counts: Counter[int] = Counter()
    for rec in with_mos:
        sid = assign_mos_quintile(float(rec["mos_quality_raw"]), cuts)
        catalog_counts[sid] += 1
        key = str(rec["source_media_key"])
        if key in exclude:
            continue
        pool_counts[sid] += 1
        by_stratum[sid].append(rec)

    selected: list[dict[str, Any]] = []
    shortfalls: dict[int, int] = {}
    index = 0
    for sid in range(1, 6):
        keys = [str(r["source_media_key"]) for r in by_stratum[sid]]
        take = deterministic_subset(keys, n_per_stratum, seed)
        if len(take) < n_per_stratum:
            shortfalls[sid] = n_per_stratum - len(take)
        lookup = {str(r["source_media_key"]): r for r in by_stratum[sid]}
        low, high = stratum_bounds(cuts, sid)
        for key in take:
            index += 1
            src = lookup[key]
            mos = float(src["mos_quality_raw"])
            selected.append(
                {
                    "media_id": f"{id_prefix}-{index:03d}",
                    "source_dataset": "KonIQ-10k",
                    "source_media_key": key,
                    "media_type": "photo",
                    "relative_path": f"images/{Path(key).name}",
                    "file_exists": False,
                    "mos_quality_raw": mos,
                    "mos_scale": src.get("mos_scale") or "1-5",
                    "mos_direction": "higher_is_better",
                    "overall_mapped_1_5": src.get("overall_mapped_1_5"),
                    "selection_seed": seed,
                    "selection_index": index,
                    "label_provenance": "human_subjective",
                    "quality_condition": STRATUM_LABELS[sid],
                    "notes": "published MOS overall only; Run 002 stratified quintiles",
                    "stratum_id": sid,
                    "stratum_label": STRATUM_LABELS[sid],
                    "stratum_mos_low": low,
                    "stratum_mos_high": high,
                    "excluded_run001": "true",
                }
            )
    summary = {
        "catalog_n": len(with_mos),
        "excluded_n": len(exclude),
        "cuts": {
            "min": cuts[0],
            "p20": cuts[1],
            "p40": cuts[2],
            "p60": cuts[3],
            "p80": cuts[4],
            "max": cuts[5],
        },
        "stratum_rules": {
            "1": f"MOS <= {cuts[1]}",
            "2": f"{cuts[1]} < MOS <= {cuts[2]}",
            "3": f"{cuts[2]} < MOS <= {cuts[3]}",
            "4": f"{cuts[3]} < MOS <= {cuts[4]}",
            "5": f"MOS > {cuts[4]}",
        },
        "catalog_counts": {str(k): catalog_counts[k] for k in range(1, 6)},
        "pool_counts_after_run001_exclusion": {str(k): pool_counts[k] for k in range(1, 6)},
        "selected_counts": dict(Counter(int(r["stratum_id"]) for r in selected)),
        "selected_n": len(selected),
        "n_per_stratum": n_per_stratum,
        "selection_seed": seed,
        "shortfalls": shortfalls,
        "method": "empirical_quintiles_linear_interpolation_on_all_official_MOS",
    }
    return selected, summary


def write_selection_manifest(records: list[dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(SELECTION_COLUMNS), extrasaction="ignore")
        writer.writeheader()
        for rec in records:
            writer.writerow({col: rec.get(col, "") for col in SELECTION_COLUMNS})


def write_extract_preview(records: list[dict[str, Any]], path: Path, summary: dict[str, Any]) -> None:
    payload = {
        "dataset": "KonIQ-10k",
        "run": "run_002",
        "selection_seed": summary["selection_seed"],
        "subset": {
            "selected_n": len(records),
            "selection_seed": summary["selection_seed"],
            "strata": summary["stratum_rules"],
        },
        "subset_records": [
            {"media_id": r["media_id"], "source_media_key": r["source_media_key"]} for r in records
        ],
    }
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Write KonIQ stratified selection (no extract, no scoring)")
    parser.add_argument("--scores", type=Path, default=SCORES)
    parser.add_argument("--exclude-manifest", type=Path, default=RUN001_MANIFEST)
    parser.add_argument("--output-root", type=Path, default=RUN002_ROOT)
    parser.add_argument("--n-per-stratum", type=int, default=DEFAULT_PER_STRATUM)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    args = parser.parse_args(argv)

    rows, warnings = import_koniq10k_rows(args.scores)
    exclude = load_run001_filenames(args.exclude_manifest) if args.exclude_manifest.is_file() else set()
    selected, summary = select_stratified(
        rows, exclude=exclude, n_per_stratum=args.n_per_stratum, seed=args.seed
    )
    root = args.output_root.resolve()
    meta = root / "metadata"
    images = root / "images"
    out = root / "output"
    meta.mkdir(parents=True, exist_ok=True)
    images.mkdir(parents=True, exist_ok=True)
    out.mkdir(parents=True, exist_ok=True)
    (images / ".gitkeep").write_text("", encoding="utf-8")
    write_selection_manifest(selected, meta / "selection_manifest.csv")
    write_subset_manifest(selected, meta / "subset_manifest.csv")
    write_published_mos(
        selected,
        meta / "published_mos.csv",
        license_note="KonIQ-10k published MOS overall only. Run 002 stratified quintiles. Not criterion ratings.",
    )
    write_extract_preview(selected, meta / "extract_preview.json", summary)
    (meta / "strata.json").write_text(json.dumps({**summary, "warnings": warnings}, indent=2), encoding="utf-8")
    printable = {
        "ok": True,
        "output_root": str(root),
        "selected_n": len(selected),
        "summary": summary,
        "warnings": warnings,
    }
    print(json.dumps(printable, indent=2, default=str))
    return 0 if not summary["shortfalls"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
