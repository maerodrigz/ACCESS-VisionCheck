#!/usr/bin/env python3
"""Generate Phase 6A human consensus medians AFTER R1/R2/R3 sheets are filled.

By default this script REFUSES to run when rating cells are empty, so it is safe
to ship alongside the Phase 6A package before collection.

Usage (after collection):
  python generate_phase6a_consensus.py \\
    --ratings-dir workspace/phase6a_human_validation/actual_ratings \\
    --output workspace/phase6a_human_validation/output/consensus_<stamp>

Does not invent ratings. Does not join machine scores.
"""

from __future__ import annotations

import argparse
import csv
import statistics
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
DEFAULT_PACK = _TOOLKIT / "workspace" / "phase6a_human_validation"

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
RATERS = ("R1", "R2", "R3")


def _now_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def _parse_score(raw: str) -> float | None:
    s = (raw or "").strip()
    if s == "" or s.upper() == "N/A":
        return None
    try:
        v = float(s)
    except ValueError:
        return None
    if v != v:
        return None
    return v


def _find_sheet(ratings_dir: Path, rater: str) -> Path | None:
    candidates = [
        ratings_dir / f"ratings_{rater}.csv",
        ratings_dir / f"ratings_{rater}.csv.csv",
        ratings_dir / f"image_quality_ratings_{rater}.csv",
    ]
    for p in candidates:
        if p.is_file():
            return p
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--ratings-dir",
        type=Path,
        default=DEFAULT_PACK / "rater_pack",
        help="Directory containing filled ratings_R1.csv … ratings_R3.csv",
    )
    ap.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output directory for consensus CSVs",
    )
    ap.add_argument(
        "--allow-empty",
        action="store_true",
        help="Dangerous: allow empty sheets (for dry-run structure checks only)",
    )
    args = ap.parse_args()

    sheets: dict[str, list[dict[str, str]]] = {}
    for rater in RATERS:
        path = _find_sheet(args.ratings_dir, rater)
        if path is None:
            print(f"ERROR: missing sheet for {rater} under {args.ratings_dir}", file=sys.stderr)
            return 2
        sheets[rater] = _read_csv(path)

    # Coverage of filled technical/overall cells
    filled = 0
    expected = 0
    for rater, rows in sheets.items():
        for row in rows:
            for c in CRITERIA:
                expected += 1
                if _parse_score(row.get(c, "")) is not None:
                    filled += 1

    if filled == 0 and not args.allow_empty:
        print(
            "REFUSED: no filled human criterion scores found. "
            "Phase 6A consensus must wait until R1/R2/R3 submit ratings. "
            "Pass --allow-empty only for structural dry-runs.",
            file=sys.stderr,
        )
        return 3

    if filled < expected * 0.5 and not args.allow_empty:
        print(
            f"REFUSED: only {filled}/{expected} criterion cells filled "
            f"({100.0 * filled / max(expected, 1):.1f}%). "
            "Collect complete sheets before consensus.",
            file=sys.stderr,
        )
        return 3

    # Index by media_id
    by_id: dict[str, dict[str, dict[str, str]]] = {}
    for rater, rows in sheets.items():
        for row in rows:
            mid = row.get("media_id", "").strip()
            if not mid:
                continue
            by_id.setdefault(mid, {})[rater] = row

    combined_rows: list[dict[str, Any]] = []
    consensus_rows: list[dict[str, Any]] = []
    for mid in sorted(by_id.keys()):
        cons: dict[str, Any] = {"media_id": mid}
        for c in CRITERIA:
            vals: list[float] = []
            for rater in RATERS:
                row = by_id[mid].get(rater)
                if not row:
                    continue
                v = _parse_score(row.get(c, ""))
                combined_rows.append(
                    {
                        "media_id": mid,
                        "rater_id": rater,
                        "criterion": c,
                        "score": "" if v is None else v,
                    }
                )
                if v is not None:
                    vals.append(v)
                    cons[f"{c}_{rater}"] = v
                else:
                    cons[f"{c}_{rater}"] = ""
            cons[f"{c}_n"] = len(vals)
            cons[f"{c}_median"] = statistics.median(vals) if vals else ""
        consensus_rows.append(cons)

    out = args.output or (
        DEFAULT_PACK / "output" / f"consensus_{_now_stamp()}"
    )
    out.mkdir(parents=True, exist_ok=True)

    cons_fields = ["media_id"]
    for c in CRITERIA:
        cons_fields.extend([f"{c}_R1", f"{c}_R2", f"{c}_R3", f"{c}_n", f"{c}_median"])

    with (out / "human_consensus_by_image.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cons_fields, extrasaction="ignore")
        w.writeheader()
        for row in consensus_rows:
            w.writerow(row)

    with (out / "human_ratings_long.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(
            f, fieldnames=["media_id", "rater_id", "criterion", "score"]
        )
        w.writeheader()
        for row in combined_rows:
            w.writerow(row)

    meta = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "n_images": len(consensus_rows),
        "filled_criterion_cells": filled,
        "expected_criterion_cells": expected,
        "ratings_dir": str(args.ratings_dir),
        "fabricated": False,
        "machine_joined": False,
    }
    (out / "consensus_meta.json").write_text(
        __import__("json").dumps(meta, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Consensus written to {out}")
    print(f"  images={len(consensus_rows)} filled_cells={filled}/{expected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
