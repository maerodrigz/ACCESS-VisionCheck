"""One-off Phase 5 audit helper (read-only)."""

from __future__ import annotations

import collections
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "workspace" / "human_pilot"


def main() -> None:
    imgs = sorted((ROOT / "rater_pack" / "images").glob("PILOT-*.jpg"))
    print("images", len(imgs), "unique", len({p.name for p in imgs}))

    with (ROOT / "facilitator" / "facilitator_manifest.csv").open(encoding="utf-8-sig") as f:
        fac = list(csv.DictReader(f))
    print("facilitator_rows", len(fac), "cols", list(fac[0].keys()))
    fac_ids = [r["anonymous_id"] for r in fac]
    print(
        "fac_dupes",
        [i for i, c in collections.Counter(fac_ids).items() if c > 1],
        "sha_dupes",
        [
            h
            for h, c in collections.Counter(r["file_sha256"] for r in fac).items()
            if c > 1
        ],
    )

    with (
        ROOT / "output" / "pilot_hvsm_20261108T114511Z" / "human_consensus_by_image.csv"
    ).open(encoding="utf-8-sig") as f:
        cons = list(csv.DictReader(f))
    with (
        ROOT / "output" / "pilot_hvsm_20261108T114511Z" / "machine_scores_joined.csv"
    ).open(encoding="utf-8-sig") as f:
        mach = list(csv.DictReader(f))
    with (
        ROOT / "output" / "phase1_hybrid_nr_iqa_20261113" / "hybrid_per_image.csv"
    ).open(encoding="utf-8-sig") as f:
        hyb = list(csv.DictReader(f))
    with (
        ROOT / "output" / "phase1_hybrid_nr_iqa_20261113" / "comparison_joined.csv"
    ).open(encoding="utf-8-sig") as f:
        joined = list(csv.DictReader(f))

    print("consensus", len(cons), "machine", len(mach), "hybrid", len(hyb), "joined", len(joined))
    print("hybrid_cols", list(hyb[0].keys()))
    print(
        "joined_key_cols",
        [
            c
            for c in joined[0].keys()
            if any(
                x in c.lower()
                for x in (
                    "media",
                    "human",
                    "enet",
                    "hybrid",
                    "musiq",
                    "sharp",
                    "blur",
                    "bright",
                    "contr",
                    "overall",
                    "badge",
                )
            )
        ][:50],
    )

    img_ids = {p.stem for p in imgs}
    cons_ids = {r["media_id"] for r in cons}
    mach_ids = {r["media_id"] for r in mach}
    hyb_ids = {r["media_id"] for r in hyb}
    fac_set = set(fac_ids)
    print("missing imgs vs fac", sorted(img_ids - fac_set))
    print("missing imgs vs cons", sorted(img_ids - cons_ids))
    print("missing imgs vs mach", sorted(img_ids - mach_ids))
    print("missing imgs vs hyb", sorted(img_ids - hyb_ids))

    # n_raters and blank medians
    for col in (
        "sharpness",
        "blur",
        "noise",
        "brightness",
        "contrast",
        "blocking_artifacts",
        "ringing_artifacts",
        "overall_visual_quality",
    ):
        n_ok = sum(1 for r in cons if (r.get(f"{col}_median") or "").strip() != "")
        ns = [int(float(r[f"{col}_n"])) for r in cons if (r.get(f"{col}_n") or "").strip()]
        print(
            f"consensus {col}: n_with_median={n_ok} n_rater_min={min(ns) if ns else None} max={max(ns) if ns else None}"
        )

    act = ROOT / "actual_ratings"
    for p in sorted(act.glob("*.csv*")):
        with p.open(encoding="utf-8-sig") as f:
            rows = list(csv.DictReader(f))
        ids = [r["media_id"] for r in rows]
        dup = [i for i, c in collections.Counter(ids).items() if c > 1]
        crits = [
            "sharpness",
            "blur",
            "noise",
            "brightness",
            "contrast",
            "blocking_artifacts",
            "ringing_artifacts",
            "overall_visual_quality",
        ]
        missing = {c: 0 for c in crits}
        for r in rows:
            for c in crits:
                if (r.get(c) or "").strip() == "":
                    missing[c] += 1
        print(f"actual {p.name}: n={len(rows)} unique={len(set(ids))} dups={dup} blanks={missing}")

    # empty template sheets in rater_pack
    for name in ("ratings_R1.csv", "ratings_DEV.csv"):
        p = ROOT / "rater_pack" / name
        with p.open(encoding="utf-8-sig") as f:
            rows = list(csv.DictReader(f))
        filled = sum(1 for r in rows if (r.get("sharpness") or "").strip())
        print(f"rater_pack/{name}: rows={len(rows)} sharpness_filled={filled}")

    shadow = Path(
        r"c:\Users\Dell\Desktop\access_mobile\access_backend\research_logs"
    )
    if shadow.exists():
        print("shadow_dirs", [p.name for p in shadow.iterdir() if p.is_dir()])
        for p in shadow.rglob("*.jsonl"):
            lines = [ln for ln in p.read_text(encoding="utf-8").splitlines() if ln.strip()]
            print("shadow_file", p.relative_to(shadow), "n", len(lines))
            if lines:
                print("shadow_keys", list(json.loads(lines[-1]).keys())[:30])


if __name__ == "__main__":
    main()
