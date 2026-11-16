#!/usr/bin/env python3
"""Build blinded human packs for Phase 4A (image quality + feedback quality).

Creates sheets for three raters. Does not invent ratings. Copies or hardlinks
images under anonymous INDVAL ids. Feedback sheets are filled after machine eval
observations exist (or left with blank system columns for later merge).
"""

from __future__ import annotations

import argparse
import csv
import json
import shutil
from pathlib import Path

_TOOLKIT = Path(__file__).resolve().parent
DEFAULT_MANIFEST = _TOOLKIT / "workspace" / "phase4a_indval" / "holdout_manifest.csv"
DEFAULT_OUT = _TOOLKIT / "workspace" / "phase4a_indval" / "human_packs"
DEFAULT_FEEDBACK_OBS = (
    _TOOLKIT / "workspace" / "phase4a_indval" / "machine_output" / "experimental_feedback_observations.csv"
)
RATERS = ("R1", "R2", "R3")

IMAGE_QUALITY_FIELDS = [
    "media_id",
    "rater_id",
    "media_type",
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
    "color_balance",
    "color_saturation",
    "flickering",
    "motion_stability",
    "overall_visual_quality",
    "notes",
]

# Independent issue labels (tick Y/N). Separate from 1-5 image quality.
ISSUE_LABEL_FIELDS = [
    "media_id",
    "rater_id",
    "soft_focus",
    "bad_exposure",
    "low_contrast",
    "blocking",
    "color_cast",
    "bad_saturation",
    "notes",
]

FEEDBACK_QUALITY_FIELDS = [
    "media_id",
    "rater_id",
    "criterion",
    "system_observation",
    "rule_triggered",
    "reference_issue_identified_by_human",
    "observation_correctness_1to5",
    "recommendation_relevance_1to5",
    "clarity_1to5",
    "usefulness_1to5",
    "notes",
]


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        w = csv.DictWriter(handle, fieldnames=fieldnames)
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k, "") for k in fieldnames})


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    ap.add_argument("--output", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--feedback-obs", type=Path, default=DEFAULT_FEEDBACK_OBS)
    ap.add_argument("--copy-images", action="store_true", help="Copy images into blinded pack")
    args = ap.parse_args()

    if not args.manifest.is_file():
        raise SystemExit(f"Missing manifest: {args.manifest}")

    manifest = _read_csv(args.manifest)
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    images_dir = out / "images"
    if args.copy_images:
        images_dir.mkdir(parents=True, exist_ok=True)
        for row in manifest:
            src = Path(row["path"])
            dst = images_dir / row["blind_file_name"]
            if src.is_file() and not dst.is_file():
                shutil.copy2(src, dst)

    instructions = out / "INSTRUCTIONS.md"
    instructions.write_text(
        """# Phase 4A blinded human evaluation

You are rating photographs for ACCESS VisionCheck research.

## Pack contents

1. `images/INDVAL-*.jpg` — anonymous photos (if provided).
2. `image_quality_ratings_<RATER>.csv` — **image quality** 1–5 (see HUMAN_RATING_RUBRIC.md).
3. `issue_labels_<RATER>.csv` — independent Y/N issue presence (not the same as 1–5 scores).
4. `feedback_quality_ratings_<RATER>.csv` — rate **system feedback text quality** 1–5 (correctness, relevance, clarity, usefulness). Leave blank until facilitators paste system observations, or use prefilled observation columns if present.

## Rules

- Do not open facilitator_mapping.csv or machine_scores.csv.
- Do not invent scores. Use N/A when you cannot judge a criterion.
- Image-quality 1–5 and feedback-quality 1–5 are different tasks.
- For issue labels use `Y` or `N` only (or blank if unsure — do not guess).
- Photos: flickering and motion_stability = N/A.

## Status

Human cells start empty. Validation is incomplete until all three raters submit.
""",
        encoding="utf-8",
    )

    # Copy rubric reference
    rubric_src = _TOOLKIT / "HUMAN_RATING_RUBRIC.md"
    if rubric_src.is_file():
        shutil.copy2(rubric_src, out / "HUMAN_RATING_RUBRIC.md")

    obs_by_id: dict[str, list[dict[str, str]]] = {}
    if args.feedback_obs.is_file():
        for row in _read_csv(args.feedback_obs):
            if row.get("suppressed") in ("True", "true", "1"):
                continue
            if row.get("observation_kind") == "suppressed_duplicate":
                continue
            obs_by_id.setdefault(row["indval_id"], []).append(row)

    for rater in RATERS:
        iq_rows = []
        issue_rows = []
        fb_rows = []
        for row in manifest:
            mid = row["indval_id"]
            iq_rows.append(
                {
                    "media_id": mid,
                    "rater_id": rater,
                    "media_type": "photo",
                    "sharpness": "",
                    "blur": "",
                    "noise": "",
                    "brightness": "",
                    "contrast": "",
                    "blocking_artifacts": "",
                    "ringing_artifacts": "",
                    "color_balance": "",
                    "color_saturation": "",
                    "flickering": "N/A",
                    "motion_stability": "N/A",
                    "overall_visual_quality": "",
                    "notes": "",
                }
            )
            issue_rows.append(
                {
                    "media_id": mid,
                    "rater_id": rater,
                    "soft_focus": "",
                    "bad_exposure": "",
                    "low_contrast": "",
                    "blocking": "",
                    "color_cast": "",
                    "bad_saturation": "",
                    "notes": "",
                }
            )
            obs_list = obs_by_id.get(mid, [])
            if obs_list:
                for obs in obs_list:
                    fb_rows.append(
                        {
                            "media_id": mid,
                            "rater_id": rater,
                            "criterion": obs.get("criterion", ""),
                            "system_observation": obs.get("observation", ""),
                            "rule_triggered": obs.get("rule_id", ""),
                            "reference_issue_identified_by_human": "",
                            "observation_correctness_1to5": "",
                            "recommendation_relevance_1to5": "",
                            "clarity_1to5": "",
                            "usefulness_1to5": "",
                            "notes": "",
                        }
                    )
            else:
                # Placeholder rows per criterion so sheets exist before machine eval
                for criterion in (
                    "sharpness",
                    "brightness",
                    "contrast",
                    "blocking_artifacts",
                    "color_balance",
                    "color_saturation",
                ):
                    fb_rows.append(
                        {
                            "media_id": mid,
                            "rater_id": rater,
                            "criterion": criterion,
                            "system_observation": "",
                            "rule_triggered": "",
                            "reference_issue_identified_by_human": "",
                            "observation_correctness_1to5": "",
                            "recommendation_relevance_1to5": "",
                            "clarity_1to5": "",
                            "usefulness_1to5": "",
                            "notes": "Fill system columns after machine eval or re-run this script.",
                        }
                    )

        _write_csv(out / f"image_quality_ratings_{rater}.csv", IMAGE_QUALITY_FIELDS, iq_rows)
        _write_csv(out / f"issue_labels_{rater}.csv", ISSUE_LABEL_FIELDS, issue_rows)
        _write_csv(out / f"feedback_quality_ratings_{rater}.csv", FEEDBACK_QUALITY_FIELDS, fb_rows)

    meta = {
        "raters": list(RATERS),
        "n_images": len(manifest),
        "feedback_obs_prefilled": args.feedback_obs.is_file(),
        "images_copied": bool(args.copy_images),
        "human_scores_fabricated": False,
    }
    (out / "pack_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"[PHASE4A] human packs -> {out}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
