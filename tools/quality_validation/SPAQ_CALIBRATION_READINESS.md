# SPAQ calibration readiness (inspection only)

**Status:** inspection and reporting only. No calibration or evaluation was performed. No production scoring, weights, API, Flutter, XP, authenticity, Gemini, or MUSIQ changed. The locked SPAQ-200 evaluation set was not modified or regenerated. Original annotations and existing research reports were not overwritten.

**Date:** 2026-11-07.
**Workspace:** `tools/quality_validation/workspace/datasets/spaq/`

## Objective answer

**Can the remaining SPAQ dataset images be used for Tenengrad (Sharpness) and residual-based (Noise) calibration without contaminating the locked SPAQ-200 evaluation set?**

**No, not from the locally available material.** The only SPAQ image files physically on disk are exactly the locked 200 evaluation images. The full SPAQ annotation (all 11,125 image ratings) is present in `MOS and Image attribute scores.xlsx`, but the corresponding image bytes for the 10,925 non-evaluation images are not present locally and would have to be downloaded, which this task forbids. Using any of the 200 for calibration would train on the test set (contamination). Therefore a SPAQ-based calibration split that excludes the locked 200 is **definable but not executable now**.

## 1. Reports inspected

- `SPAQ_200_INTEGRITY.md` — 200 readable JPEGs, 1:1 with annotations, 0 empty cells, 0 duplicates, 0 missing. Status `ok`.
- `SPAQ_200_EVALUATION_PLAN.md` — proposed (then run) procedure; SPAQ attributes are 0-100; Noise is a cleanliness badge (invert); Sharpness higher = sharper; no calibration/retraining from the subset.
- `SPAQ_200_EVALUATION_REPORT.md` — 200/200 scored with EfficientNet, 0 fallback; badges compressed (Sharpness piles at 3, Noise 3-5, Brightness 73% at 5); notes "n=200 of 11,125".

## 2. Locked evaluation image IDs (exactly 200)

Identified from the selection/mapping files (read-only):

- Selection: `spaq_mos_stratified_200.csv` and `metadata/human_ratings_200.csv` — 200 rows, MOS-stratified, `selection_seed = 20261107`, `n_per_stratum = 40`, strata Q1_very_low..Q5_very_high (40 each).
- Key column: `source_media_key` (e.g., `06664.jpg`); `media_id` = `spaq_<digits>` (e.g., `spaq_06664`).
- Integrity index: `metadata/integrity_index.csv` — 200 rows with sha256, dimensions, bytes; all `jpeg_readable=True`.
- Mapping: `metadata/import_mapping.spaq_200.json` — `mos_scale=0-100`, `attribute_scale=0-100`, `source_media_key_column=source_media_key`; comment: "Do not retrain production heads on this subset."

The exact 200 keys are the `source_media_key` values in `metadata/human_ratings_200.csv` (the authoritative locked list). Counts: 200 unique, 0 duplicates.

## 3. Original annotation spreadsheet and extracted metadata

- **Original spreadsheet** `MOS and Image attribute scores.xlsx` (read-only parse; openpyxl not installed, parsed the xlsx zip directly):
  - 1 sheet (`Sheet1`), dimension `A1:G11126` -> **11,125 data rows**, **11,125 unique image names**.
  - Columns: `Image name, MOS, Brightness, Colorfulness, Contrast, Noisiness, Sharpness` (0-100).
  - Sample: `00001.jpg` MOS 48.86, Brightness 47.43, Colorfulness 55.57, Contrast 55.71, Noisiness 37.86, Sharpness 42.57.
  - This is the **full SPAQ annotation**, the only file that holds ratings beyond the 200.
- **Extracted metadata** `extracted/SPAQ_Part_1..5/` and `metadata/parts/SPAQ_Part_N_human_ratings.csv`:
  - Each part holds exactly 40 images and a 40-row `human_ratings.csv` (200 total). These CSVs are the **normalized selection** (same columns as `human_ratings_200.csv`, including `stratum_id`, `selection_seed`, `n_per_stratum`) — i.e. the 200 selection split across the 5 original parts, not the raw full annotation.
- **ZIP archives** `SPAQ_Part_1..5.zip`: each contains 40 jpgs + the same 40-row `human_ratings.csv` (200 total). So the ZIPs also ship only the selected 200, not the full image set.

## 4. Availability, scale, and direction of Sharpness / Noisiness

| Source | n | Sharpness | Noisiness | Scale | Direction |
|---|---|---|---|---|---|
| xlsx (full) | 11,125 | valid all (0 empty) | valid all (0 empty) | 0-100 | Sharpness higher = sharper = better; Noisiness higher = more noise = worse |
| Locked 200 (subset) | 200 | 4.13-90.67 (mean 47.4) | 4.0-96.67 (mean 53.0) | 0-100 | same |

Direction vs the candidate metrics:
- Tenengrad (prototype): higher = sharper = better. Matches SPAQ Sharpness direction. Use rank correlation; no invert.
- Residual noise std (prototype): higher = more noise = worse. Matches SPAQ Noisiness direction (amount). For a member-facing "Noise" cleanliness badge, invert both: SPAQ cleanliness = 100 - Noisiness; candidate cleanliness = 1 - normalized residual. Same polarity as the existing production Noise badge (cleanliness, higher = better).

Scale note: SPAQ is 0-100 continuous human; Tenengrad is unbounded energy and residual std is an unbounded amount. Pearson mixes scales; Spearman (rank) is the appropriate comparison. MAE only after an explicit, pre-declared a-priori 1-5 map, not from these raw scales.

## 5. Additional SPAQ images physically available with valid ratings

| Count | Value |
|---|---|
| Total SPAQ images with ratings (xlsx) | 11,125 |
| Valid Sharpness + Noisiness (both, 0 empty) | 11,125 |
| Locked evaluation images | 200 |
| Locked images present in xlsx | 200 / 200 (strict subset; 0 missing) |
| Additional images with valid ratings | 10,925 |
| Additional images with a local image file | **0** |
| Local image files on disk (extracted + ZIPs) | 200 (exactly the locked set) |

So 10,925 images have valid Sharpness/Noisiness ratings but no local image bytes; 0 additional images are usable for calibration from the current workspace.

## 6. Overlap, duplicates, missing, previously used images

- **Overlap:** the locked 200 are a strict subset of the xlsx 11,125 (200/200 present, 0 not in xlsx). No locked image is outside the full annotation.
- **Duplicates:** 0 duplicate keys in the locked 200; 0 in the xlsx image-name set (11,125 unique).
- **Missing files among the 200:** 0 (integrity report: all readable, 1:1).
- **Extra local images:** 0. The `extracted/` tree and the 5 ZIPs contain exactly the 200 selected images and nothing more.
- **Previously used for calibration/dev:** none found. The 200 have been used only as the evaluation set (Phase 12 scoring, Phase 13 runtime benchmark, the Tenengrad/residual-noise prototype). No separate SPAQ calibration or development split exists locally.
- **Key-format note:** the xlsx uses `Image name` like `06664.jpg`, the locked set uses `source_media_key` like `06664.jpg` (these match after stripping), and `media_id` like `spaq_06664`. The join was verified on the stripped numeric form (200/200 match).

## 7. Recommended reproducible calibration split (excludes all locked evaluation images)

A SPAQ-based calibration split is **definable but not executable now** (images missing; download forbidden). Definition for a future, separately-approved step:

- Let **L** = the locked 200 `source_media_key` values in `metadata/human_ratings_200.csv` (seed `20261107`, 40 per MOS quintile). L is strictly excluded and never scored during calibration.
- Let **F** = the 11,125 image names in `MOS and Image attribute scores.xlsx` with valid Sharpness AND Noisiness.
- Calibration pool **C = F \ L** = 10,925 candidate images (all with valid 0-100 Sharpness/Noisiness).
- Reproducible split: from C, a deterministic MOS-stratified sample using a **declared seed distinct from the evaluation seed** (recommend `20261108`, not `20261107`, to avoid any coupling), with a declared `n_per_stratum`, pre-registered before any scoring. Stratify on MOS quintile edges computed on C only (not on L), declared before looking at candidate scores.
- Hard exclusion check: assert `len(selected ∩ L) == 0` before any fit.
- This split requires the 10,925 image bytes, which are not on disk. Executing it requires a separate SPAQ image download approval, which is outside this task.

**Primary recommendation (no download): do not use SPAQ for calibration.** Keep the 200 SPAQ as a held-out related-proxy check only (never used to fit thresholds). Calibrate the Tenengrad and residual-noise ladders on an independent ACCESS-native 1-5 development pack collected via `HUMAN_RATING_RUBRIC.md` / `HUMAN_VALIDATION_PROTOCOL.md` on held-out real ACCESS photos (no download). This matches the SHARPNESS_NOISE_PROTOTYPE_READINESS proposal and the Phase 12 decision matrix ("ACCESS-native 1-5 ratings are still missing; SPAQ 0-100 is a related proxy only").

## 8. Can Tenengrad / residual-noise be evaluated against the attribute ratings without modifying production code?

**Yes — code-ready, data-blocked.** The existing implementations in `tools/quality_validation/sharpness_noise_prototype.py` import production `app.services.image_orientation.decode_oriented_bgr` and `app.services.opencv_quality.analyze_bgr` read-only and compute Tenengrad (`mean(gx*gx + gy*gy)`, Sobel ksize=3) and residual noise std (`std(|gray - GaussianBlur(gray,5,5)|)`) matching `classical_quality_metrics`. The prototype already evaluates these against SPAQ `attr_sharpness_raw` and `attr_noisiness_raw` (exploratory Spearman, n=200) with no production change. Extending to more images needs only image bytes (read) and the same read-only import path; no production scoring, weights, API, Flutter, XP, authenticity, Gemini, or MUSIQ modification is required. The blocker is image availability, not code.

Confirmed prototype results on the locked 200 (for reference, not calibration): Tenengrad vs SPAQ Sharpness Spearman 0.753 (CI 0.679-0.799); residual noise vs SPAQ Noisiness 0.682 (CI 0.601-0.745). These are exploratory on the evaluation set and must not be used to fit thresholds.

## Dataset limitations

1. **Only the 200 evaluation images are local.** The full SPAQ image corpus is not on disk; the ZIPs and extracted tree ship exactly the selected 200.
2. **Ratings without images:** 10,925 images have ratings in the xlsx but no local image bytes; usable only after a separately-approved download.
3. **No SPAQ calibration/dev split exists** beyond the locked 200. Any SPAQ calibration must carve it from C = F \ L, which needs the missing images.
4. **Construct gap:** SPAQ attributes are 0-100 lab opinions; Tenengrad/residual are technical heuristics. Rank correlation is valid; absolute MAE is not, unless a pre-declared a-priori 1-5 map is applied first.
5. **Unlabeled criteria:** SPAQ has no separate Blur/Blocking/Ringing labels matching the ACCESS constructs; this inspection covers only Sharpness and Noisiness.

## Recommended next steps (no execution in this task)

1. Do not calibrate on SPAQ. Use the independent ACCESS-native 1-5 dev pack (no download) for any calibration; keep SPAQ-200 as a held-out related-proxy report only.
2. If a SPAQ-based calibration is later desired: obtain the 10,925 non-evaluation images under a separate download approval, then build C = F \ L with a declared seed (`20261108`), pre-register the MOS-stratified sample, and assert zero overlap with L before fitting.
3. Before any production change, also measure EfficientNet at the 1024 px resize cap (Phase 13 measured only OpenCV/Tenengrad) to confirm no regression on the ENET path.
4. Fix (separately, with approval) the dormant `_soft_score` signature mismatch in `image_quality.py` — confirmed not in the active production pipeline (see SHARPNESS_NOISE_PROTOTYPE_READINESS.md), but a latent TypeError in dead code.

## Restrictions honored

- No production scoring/weights/API/Flutter/XP/authenticity/Gemini/MUSIQ changes.
- Locked SPAQ-200 not modified or regenerated.
- Original annotations and existing reports not overwritten.
- No calibration or evaluation performed.
- Inspection only; all scripts were read-only (zipfile/csv/xml parse) and wrote nothing into the workspace.

Artifacts: this report (`tools/quality_validation/SPAQ_CALIBRATION_READINESS.md`). No dataset files were created or modified.
