# SPAQ 200-image dataset integrity

**Generated:** 2026-11-07T07:17:48.088352+00:00
**Status:** `ok`

Research workspace only. Production scoring, weights, API, Flutter, XP, authenticity, Gemini, and MUSIQ were not changed. Original ZIP `human_ratings.csv` values were copied, not rewritten.

## Counts

| Check | Value |
|-------|-------|
| ZIP packages | 5 |
| Annotation rows | 200 |
| Unique `source_media_key` | 200 |
| JPEGs on disk | 200 |
| Readable JPEGs | 200 |
| 1:1 image-annotation | True |
| Empty rating cells | 0 |
| Value mismatches vs selected list | 0 |

## MOS quintiles (must be 40 each)

| Stratum | Count |
|---------|-------|
| 1 `Q1_very_low` | 40 |
| 2 `Q2_low` | 40 |
| 3 `Q3_mid` | 40 |
| 4 `Q4_high` | 40 |
| 5 `Q5_very_high` | 40 |

## Rating summaries (original 0-100 values)

| Field | n | min | max | mean |
|-------|---|-----|-----|------|
| `mos_quality_raw` | 200 | 3.38 | 92.0 | 50.885 |
| `attr_brightness_raw` | 200 | 5.0 | 93.0 | 55.6705 |
| `attr_colorfulness_raw` | 200 | 9.13 | 92.33 | 60.4057 |
| `attr_contrast_raw` | 200 | 7.63 | 92.67 | 57.0354 |
| `attr_noisiness_raw` | 200 | 4.0 | 96.67 | 53.0398 |
| `attr_sharpness_raw` | 200 | 4.13 | 90.67 | 47.384 |

## Duplicates / missing

- Duplicate keys: none
- Missing JPEGs: none
- Extra JPEGs: none
- Unreadable: none

## Issues

- none

## Files

- Images: `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq\images`
- Master annotations: `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq\metadata\human_ratings_200.csv`
- Per-part original CSVs: `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq\metadata\parts`
- Integrity index: `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq\metadata\integrity_index.csv`

Scoring was not run in this step. Proposed comparison procedure: `SPAQ_200_EVALUATION_PLAN.md`.

