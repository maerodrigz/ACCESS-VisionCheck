# Human evaluation instructions — Five Classical criteria

Research-only independent validation. Preparation text; launch only after facilitator approval.

## What you receive

1. Blinded images `FC001`… (JPEG/PNG) when the wave starts  
2. Preferred: offline webpage at `eval_web/` (see `eval_web/README.md`)  
3. Fallback CSV: `ratings/R#_five_criteria_ratings.csv`  
4. Rubric: `FIVE_CRITERIA_RUBRIC.md`  
5. These instructions  

You do **not** receive machine scores, other raters’ sheets, stratum hints, or collection notes.

## Before you start (calibration)

1. Read `FIVE_CRITERIA_RUBRIC.md`, especially the confusion matrix and Brightness under/over rule.  
2. Complete calibration in `INDEPENDENT_VALIDATION_PROTOCOL.md` §4 using **calibration-only** images (not FC validation IDs).  
3. Do not begin the validation wave until calibration is logged as pass.

## How to rate each photograph

1. Open in a color-managed viewer. No auto-enhance, sharpening, denoise, or contrast stretch.  
2. Fit-to-window pass for context.  
3. **100%** crops as needed for subject detail (Sharpness/Blur), exposure (Brightness), midtones (Contrast), and flat regions (Blocking).  
4. Enter integers **1–5** for: `sharpness`, `blur`, `brightness`, `contrast`, `blocking_artifacts`.  
5. Leave Noise, Ringing, overall blank or `N/A`.  
6. Use `N/A` only if you truly cannot judge. Never use 3 as “unknown.”  
7. Optional short `notes` for odd cases. Do not mention machines or other raters.

## Scale reminder

| Score | Meaning |
|------:|---------|
| 5 | Excellent / clean on that criterion |
| 4 | Good / minor defect only |
| 3 | Fair / clearly visible defect |
| 2 | Needs improvement / retake normally |
| 1 | Poor / defect dominates |

Higher is always better for all five criteria. Under- and over-exposure both lower Brightness.

## Integrity rules

- Work independently. No discussing scores until all three sheets are submitted.  
- Do not open facilitator files.  
- Do not run quality sandbox / production scores for these IDs while rating.  
- Do not infer photographer skill from these scores.

## When finished

Return your CSV (or eval_web export) to the facilitator. Do not edit another rater’s file.
