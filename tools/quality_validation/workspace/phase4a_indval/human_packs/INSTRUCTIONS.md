# Phase 4B blinded human evaluation

You are rating photographs for ACCESS VisionCheck research (freeze `phase4a_freeze_20261113`).

## Pack contents

1. `images/INDVAL-001.jpg` … `INDVAL-100.jpg` — anonymous photos only.
2. `image_quality_ratings_<YOUR_ID>.csv` — **image quality** 1–5 (see `HUMAN_RATING_RUBRIC.md`).
3. `issue_labels_<YOUR_ID>.csv` — independent Y/N issue presence.
4. `feedback_quality_ratings_<YOUR_ID>.csv` — rate **system feedback text** quality (separate task).

## Required task order

1. Finish **all** image-quality ratings first.
2. Finish **all** issue labels next (Y/N). Do not use machine numeric scores.
3. Only then open the feedback sheet and rate feedback text (correctness, relevance, clarity, usefulness).

Image-quality scores and feedback-quality scores are different. Do not copy one into the other.

## Rules

- Do **not** open `machine_output/`, `facilitator_mapping.csv`, or any ENET/hybrid score tables.
- Do not invent scores. Use `N/A` when you cannot judge a criterion.
- Issue labels: `Y` or `N` only (leave blank only if truly unsure; do not guess).
- Photos: `flickering` and `motion_stability` = `N/A`.
- Return your three completed CSV files to the facilitator.

## Status

Human score cells start empty on purpose. Validation is incomplete until R1, R2, and R3 all submit.
