# Human evaluation instructions — Noise and Ringing (NR001–NR015)

Preliminary independent validation collection. Research only.

## What you receive

1. Blinded image files `NR001`…`NR015` (JPEG/PNG) in the rating pack
2. Preferred: offline webpage at `eval_web/` (see `eval_web/README.md`)
3. Fallback blank sheet: `ratings/R#_noise_ringing_ratings.csv`
4. Rubric: `NOISE_RINGING_RUBRIC.md`
5. These instructions

You do **not** receive machine scores, other raters’ sheets, facilitator stratum hints, or collection notes.

## Before you start (calibration)

If the facilitator has not yet completed calibration with you:

1. Read `NOISE_RINGING_RUBRIC.md`, especially the confusion matrix (grain vs chroma vs texture vs blocking vs ringing).
2. Complete the short calibration procedure in `INDEPENDENT_VALIDATION_PROTOCOL.md` §4 using **calibration-only** images (not NR001–NR015).
3. Do not begin NR001–NR015 until calibration is logged as pass.

## How to rate each photograph

1. Open the image in a color-managed viewer. No auto-enhance, sharpening, or denoise.
2. Fit-to-window pass for context.
3. **100%** crop on flat midtones/shadows for **Noise**.
4. **100%** (and 200% only if needed) on high-contrast edges for **Ringing**.
5. Enter integers **1–5** in `noise` and `ringing_artifacts` only.
6. Leave other criterion columns blank or `N/A` (focused study).
7. Use `N/A` only if you truly cannot judge. Never use 3 as “unknown.”
8. Optional short `notes` for odd cases (watermark, extreme crop). Do not mention machines or other raters.

## Scale reminder

| Score | Meaning |
|------:|---------|
| 5 | Excellent / clean on that criterion |
| 4 | Good / minor defect only |
| 3 | Fair / clearly visible defect |
| 2 | Needs improvement / retake normally |
| 1 | Poor / defect dominates |

Higher is always better for both Noise and Ringing.

## Integrity rules

- Work independently. No discussing scores until all three sheets are submitted.
- Do not open facilitator files under `facilitator/`.
- Do not run or view the quality sandbox scores for these IDs while rating.
- Do not infer photographer skill from these scores.

## When finished

Return your CSV to the facilitator. Do not edit another rater’s file.
