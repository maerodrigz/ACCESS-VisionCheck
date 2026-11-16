#!/usr/bin/env python3
"""Select a disjoint Phase 4A independent-validation image holdout.

Excludes the 30-image human pilot and documents SPAQ-200 as non-primary.
Does not invent human ratings. Research-only.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import random
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_TOOLKIT = Path(__file__).resolve().parent
_WS = _TOOLKIT / "workspace"
PILOT_MANIFEST = _WS / "human_pilot" / "facilitator" / "facilitator_manifest.csv"
BENCH_CSV = (
    _WS / "datasets" / "koniq10k" / "musiq_paq2piq_benchmark" / "raw_predictions.csv"
)
RUN2_IMAGES = _WS / "datasets" / "koniq10k" / "run_002" / "images"
RUN1_IMAGES = _WS / "datasets" / "koniq10k" / "images"
SPAQ_RATINGS = _WS / "datasets" / "spaq" / "metadata" / "human_ratings_200.csv"
DEFAULT_OUT = _WS / "phase4a_indval"
SEED = "20261113_phase4a_indval"
TARGET_N = 100


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _pilot_keys() -> set[str]:
    return {r["source_media_key"] for r in _read_csv(PILOT_MANIFEST) if r.get("source_media_key")}


def _spaq_keys() -> set[str]:
    if not SPAQ_RATINGS.is_file():
        return set()
    return {r["source_media_key"] for r in _read_csv(SPAQ_RATINGS) if r.get("source_media_key")}


def _bench_by_key() -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    if not BENCH_CSV.is_file():
        return out
    for row in _read_csv(BENCH_CSV):
        key = row.get("source_media_key", "")
        if key:
            out[key] = row
    return out


def _pool_candidates(pilot: set[str]) -> list[dict[str, Any]]:
    bench = _bench_by_key()
    rows: list[dict[str, Any]] = []
    for pool_name, root in (("run_002", RUN2_IMAGES), ("run_001_images", RUN1_IMAGES)):
        if not root.is_dir():
            continue
        for path in sorted(root.glob("*.jpg")):
            key = path.name
            if key in pilot:
                continue
            b = bench.get(key, {})
            mos = b.get("mos_quality_raw") or b.get("overall_mapped_1_5") or ""
            try:
                mos_f = float(mos) if mos != "" else None
            except ValueError:
                mos_f = None
            rows.append(
                {
                    "source_media_key": key,
                    "pool": pool_name,
                    "path": str(path),
                    "mos_quality_raw": mos_f,
                    "koniq_media_id": b.get("media_id", ""),
                    "file_sha256": None,  # filled for selected only
                }
            )
    return rows


def _quintile(values: list[float], x: float) -> int:
    xs = sorted(values)
    if not xs:
        return 0
    # 0..4
    ranks = [sum(1 for v in xs if v <= x) / len(xs)]
    p = ranks[0]
    if p <= 0.2:
        return 0
    if p <= 0.4:
        return 1
    if p <= 0.6:
        return 2
    if p <= 0.8:
        return 3
    return 4


def stratified_sample(
    candidates: list[dict[str, Any]],
    *,
    n: int,
    seed: str,
) -> list[dict[str, Any]]:
    rng = random.Random(seed)
    with_mos = [c for c in candidates if c.get("mos_quality_raw") is not None]
    without = [c for c in candidates if c.get("mos_quality_raw") is None]
    mos_vals = [float(c["mos_quality_raw"]) for c in with_mos]
    buckets: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for c in with_mos:
        buckets[_quintile(mos_vals, float(c["mos_quality_raw"]))].append(c)
    for b in buckets.values():
        rng.shuffle(b)
    rng.shuffle(without)

    # Proportional draw from MOS quintiles, then fill from without-MOS.
    selected: list[dict[str, Any]] = []
    if with_mos:
        per = max(1, n // 5)
        for q in range(5):
            take = buckets[q][:per]
            selected.extend(take)
        # trim / top-up
        leftovers = []
        for q in range(5):
            leftovers.extend(buckets[q][per:])
        rng.shuffle(leftovers)
        while len(selected) < n and leftovers:
            selected.append(leftovers.pop())
    while len(selected) < n and without:
        selected.append(without.pop())
    # If still over (unlikely), trim deterministically
    selected = selected[:n]
    return selected


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--n", type=int, default=TARGET_N)
    ap.add_argument("--seed", type=str, default=SEED)
    args = ap.parse_args()

    pilot = _pilot_keys()
    spaq = _spaq_keys()
    candidates = _pool_candidates(pilot)
    # Hard exclude SPAQ filenames if any collision (KonIQ vs SPAQ keys differ normally)
    candidates = [c for c in candidates if c["source_media_key"] not in spaq]

    # Deduplicate by filename
    seen: set[str] = set()
    uniq: list[dict[str, Any]] = []
    for c in candidates:
        if c["source_media_key"] in seen:
            continue
        seen.add(c["source_media_key"])
        uniq.append(c)
    candidates = uniq

    if len(candidates) < args.n:
        raise SystemExit(
            f"Not enough candidates: have {len(candidates)}, need {args.n}. "
            "Collect ACCESS-native photos or expand KonIQ local extract."
        )

    selected = stratified_sample(candidates, n=args.n, seed=args.seed)
    for i, row in enumerate(selected, start=1):
        path = Path(row["path"])
        row["indval_id"] = f"INDVAL-{i:03d}"
        row["file_sha256"] = _sha256_file(path)
        row["blind_file_name"] = f"{row['indval_id']}.jpg"

    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    manifest_path = out / "holdout_manifest.csv"
    fields = [
        "indval_id",
        "blind_file_name",
        "source_media_key",
        "pool",
        "path",
        "mos_quality_raw",
        "koniq_media_id",
        "file_sha256",
    ]
    with manifest_path.open("w", newline="", encoding="utf-8") as handle:
        w = csv.DictWriter(handle, fieldnames=fields)
        w.writeheader()
        for row in selected:
            w.writerow({k: row.get(k, "") for k in fields})

    # Facilitator-only mapping (not for raters)
    fac_path = out / "facilitator_mapping.csv"
    with fac_path.open("w", newline="", encoding="utf-8") as handle:
        w = csv.DictWriter(
            handle,
            fieldnames=["indval_id", "source_media_key", "pool", "path", "file_sha256"],
        )
        w.writeheader()
        for row in selected:
            w.writerow(
                {
                    "indval_id": row["indval_id"],
                    "source_media_key": row["source_media_key"],
                    "pool": row["pool"],
                    "path": row["path"],
                    "file_sha256": row["file_sha256"],
                }
            )

    report = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "seed": args.seed,
        "target_n": args.n,
        "selected_n": len(selected),
        "pilot_excluded_n": len(pilot),
        "spaq_keys_noted_n": len(spaq),
        "candidate_pool_n": len(candidates),
        "selected_by_pool": {
            "run_002": sum(1 for r in selected if r["pool"] == "run_002"),
            "run_001_images": sum(1 for r in selected if r["pool"] == "run_001_images"),
        },
        "overlap_checks": {
            "pilot_keys_in_selected": sorted(
                r["source_media_key"] for r in selected if r["source_media_key"] in pilot
            ),
            "spaq_keys_in_selected": sorted(
                r["source_media_key"] for r in selected if r["source_media_key"] in spaq
            ),
            "duplicate_source_keys": [],
        },
        "limitations": [
            "Holdout is KonIQ-domain, not ACCESS-native club documentation photos.",
            "Run002 remainder shares dataset family with the pilot (same corpus, disjoint files).",
            "SPAQ-200 excluded from primary holdout due to prior classical exploratory use.",
            "Published KonIQ MOS is overall-only proxy, not ACCESS criterion GT.",
            "Human ACCESS 1-5 criterion labels for this holdout are NOT yet collected.",
        ],
        "recommendation": (
            f"n={len(selected)} is larger than the Phase 1 pilot (30). "
            "Prefer this holdout for independent hybrid + feedback validation after freeze. "
            "Still collect ACCESS-native photos for ecological validity before production claims."
        ),
    }
    keys = [r["source_media_key"] for r in selected]
    if len(keys) != len(set(keys)):
        report["overlap_checks"]["duplicate_source_keys"] = sorted(
            {k for k in keys if keys.count(k) > 1}
        )

    (out / "selection_report.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    print(f"[PHASE4A] wrote {manifest_path} n={len(selected)}", flush=True)
    print(f"[PHASE4A] pilot_overlap={report['overlap_checks']['pilot_keys_in_selected']}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
