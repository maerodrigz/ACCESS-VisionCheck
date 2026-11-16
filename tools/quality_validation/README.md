# ACCESS VisionCheck — Quality Validation Toolkit

Non-production tooling. Does **not** write to PostgreSQL, upload to Supabase, call PROBE/WaveRep, or call Gemini.

This is **not** a scientific validation of EfficientNet-B0. Use it to collect real human ratings and compare them to the live quality pipeline.

## Phase 3 — real-world ACCESS criteria (use this for the 40 photo / 20 video study)

Scoring contract: `SCORING_CONTRACT.md`. Human rubric: `HUMAN_RATING_RUBRIC.md`.

Workspace (local originals only, gitignored media):

```
tools/quality_validation/workspace/real_world/
  photos/     # 40 real photographs
  videos/     # 20 real videos
  ratings/    # completed human CSVs
  output/     # machine scores and reports
  manifest.csv  # written by --prepare
```

### Add real media

Copy original files into `photos/` and `videos/`. Do not generate synthetic stand-ins for this study. Do not import production `uploads/` or database rows.

```powershell
cd C:\Users\Dell\Desktop\access_mobile
$env:PYTHONPATH = "access_backend;."
python tools/quality_validation/real_world_batch.py --prepare
python tools/quality_validation/real_world_batch.py --dry-run
```

`--prepare` assigns `PHOTO-001` … and `VIDEO-001` … and writes `manifest.csv`. Fill `quality_condition` labels in that CSV (for example `well_exposed`, `low_light`, `handheld`).

### Human ratings

Criterion-specific protocol (prepare only until you approve live rating): `HUMAN_VALIDATION_PROTOCOL.md`, `HUMAN_RATING_RUBRIC.md`, `HUMAN_RATING_TEMPLATE.csv`, `VALIDATION_DATASET_PLAN.md`.

1. Give raters `HUMAN_RATING_RUBRIC.md` and a blank `HUMAN_RATING_TEMPLATE.csv`. Do not give machine scores or KonIQ MOS.
2. Need at least three independent raters (`R1`, `R2`, `R3`).
3. Score 1–5, higher is better (including Blur and Noise). Use `N/A` when a criterion cannot be judged.
4. Photos: Flickering and Motion Stability must be `N/A`.
5. `overall_visual_quality` is an independent impression, not required to equal the mean of the other scores.
6. Save the completed file under `workspace/real_world/ratings/`.
7. Published KonIQ MOS stays overall-only. Do not copy it into criterion columns.

### System predictions (production quality path)

```powershell
python tools/quality_validation/real_world_batch.py --output-dir tools/quality_validation/workspace/real_world/output/run_001
```

This calls `evaluate_bytes(..., include_authenticity=False)` so EfficientNet-B0 can fall back to OpenCV the same way production does. Failures stay failures (no 0.5). AI detection and Gemini are not invoked. Nothing is written to PostgreSQL.

### Comparison report

Only after both human ratings and machine results exist:

```powershell
python tools/quality_validation/real_world_analyze.py `
  --machine-results tools/quality_validation/workspace/real_world/output/run_001/machine_results.json `
  --human-ratings tools/quality_validation/workspace/real_world/ratings/human_ratings.csv `
  --manifest tools/quality_validation/workspace/real_world/manifest.csv `
  --output-dir tools/quality_validation/workspace/real_world/output/run_001
```

Outputs: `comparison_summary.csv`, `VALIDATION_REPORT.md`, `analysis_report.json`. MAE and Spearman are reported only for paired observations. There is no invented accuracy percentage.

Forced-engine A/B (EfficientNet vs OpenCV, no fallback) remains available below for diagnostics. It is not the production path.

---

## Research datasets (KonIQ-10k 40 photos / LIVE-VQC 20 videos)

Preparation only. No downloads and no scoring in this step. Details: `DATASETS.md`.

```powershell
cd C:\Users\Dell\Desktop\access_mobile
$env:PYTHONPATH = "access_backend;."
python tools/quality_validation/research_preview.py --inspect-only
```

After you place official files yourself:

```powershell
python tools/quality_validation/research_preview.py --dataset koniq10k --photo-n 40 --seed 20261106
python tools/quality_validation/research_import.py --dataset koniq10k --n 40 --seed 20261106
python tools/quality_validation/research_preview.py --dataset live_vqc --inspect-only
```

Extract only the 40 selected KonIQ JPEGs from a local official ZIP (dry-run first):

```powershell
python tools/quality_validation/koniq_extract.py --zip "C:\path\to\koniq10k_1024x768.zip" --dry-run
python tools/quality_validation/koniq_extract.py --zip "C:\path\to\koniq10k_1024x768.zip"
```

KonIQ production-path scoring (after approval; dry-run does not score):

```powershell
python tools/quality_validation/research_evaluate.py --dry-run
python tools/quality_validation/research_evaluate.py --output-dir tools/quality_validation/workspace/datasets/koniq10k/metadata/output/run_001
```

Run 002 stratified 100-image selection (no extract/score until approved):

```powershell
python tools/quality_validation/koniq_stratify.py --seed 20261107 --n-per-stratum 20
```

Published MOS is overall-only. Independent ACCESS criterion CSVs stay under `workspace/real_world/`. Do not compute Fleiss kappa from MOS.

---

## Milestone 1 — forced-engine baseline (optional)

Non-production tooling to batch-score local photos/videos with **EfficientNet-B0** or **OpenCV only** (no silent fallback), export machine results, merge **human ratings**, and produce correlation reports. Does **not** write to PostgreSQL or change production scoring code.

## Dataset layout

Use **either** a CSV manifest **or** folder convention (never mix splits for calibration vs held-out tuning).

### Option A — Folder convention

```
my_dataset/
  dev/
    photos/*.jpg
    videos/*.mp4
  held_out/
    photos/
    videos/
```

### Option B — Manifest CSV

Copy `templates/dataset_manifest.example.csv`. Columns:

- `media_id` — anonymous stable id (no PII in published reports)
- `relative_path` — path under dataset root
- `media_type` — `photo` or `video`
- `dataset_split` — `dev` or `held_out`

**Policy:** Use **dev** for exploratory analysis only. **held_out** is reported for generalization; do not tune weights/thresholds on held_out.

## Human ratings (ACCESS protocol)

1. Copy `templates/human_rating_template.csv`.
2. One row per **(media_id, rater_id)**. At least 3 raters per item recommended.
3. Rate 1–5 or `NA` / `Cannot Rate` for dimensions that do not apply (e.g. flicker on photos).
4. Dimensions: sharpness_blur, exposure, noise_contrast, compression_artifacts, color_balance, composition_framing, subject_clarity, video_motion_stability, video_flickering, overall_documentation.

Optional multi-column format: `{criterion}_rater1`, `{criterion}_rater2` is also supported by the analyzer for Fleiss kappa.

## External dataset reference labels (SPAQ, LIVE-VQC)

Use **`reference_labels.csv`** to preserve official human MOS and attributes without overwriting raw values. Derived `*_mapped_1_5` columns are computed for machine comparison only.

### Schema

See `templates/reference_labels.example.csv` and `reference_schema.py`. Important fields:

- `source_dataset`, `source_media_key`, `label_provenance` (`human_subjective` vs `computed_indicator`)
- Raw: `mos_quality_raw`, `attr_*_raw`, `mos_scale`, `attribute_scale`
- Mapped (nullable): `overall_documentation_mapped_1_5`, `sharpness_blur_mapped_1_5`, `exposure_mapped_1_5`, `noise_quality_mapped_1_5`, `contrast_quality_mapped_1_5`, `color_balance_mapped_1_5`
- `missing_dimensions` lists absent attrs (never filled with 0 or neutral)

**Directionality:** SPAQ noisiness is inverted into `noise_quality_mapped_1_5` (higher = less noise, aligned with ACCESS Noise). Sharpness uses Sharpness-only machine pairing (Blur excluded). Brightness/contrast/colorfulness are **related_proxy** or **not_comparable** in reports.

### After you download official files

1. Open the official score file and note **exact column headers** (do not guess).
2. Copy `templates/import_mapping.spaq.example.json` or `import_mapping.live_vqc.example.json` and replace `REPLACE_WITH_*` placeholders.
3. Build `manifest.csv` for your pilot subset (dev / held_out).
4. Import reference metadata:

```powershell
$env:PYTHONPATH = "access_backend;."
python tools/quality_validation/import_reference.py `
  --dataset spaq `
  --source D:\pilot\spaq\MOS_and_attributes.csv `
  --mapping D:\pilot\import_mapping.spaq.json `
  --dataset-root D:\pilot\access_quality_pilot `
  --manifest D:\pilot\access_quality_pilot\manifest.csv `
  --output D:\pilot\access_quality_pilot\reference_labels.csv
```

For LIVE-VQC, use `--dataset live_vqc` and point `--source` at official CSV or `.mat`. For `.xlsx` SPAQ files, install `openpyxl` (`pip install openpyxl`) or export scores to CSV first.

5. Validate manifest and reference alignment:

```powershell
python tools/quality_validation/validate_manifest.py `
  --dataset-root D:\pilot\access_quality_pilot `
  --manifest D:\pilot\access_quality_pilot\manifest.csv `
  --reference-labels D:\pilot\access_quality_pilot\reference_labels.csv `
  --output tools/quality_validation/output/manifest_validation.json
```

Checks: unique `media_id`, duplicate SHA-256, **no dev/held_out content overlap**, file existence, media type vs extension, manifest/reference `media_id` and path consistency.

## Run batch evaluation

From repository root (Windows PowerShell example):

```powershell
cd C:\path\to\access_mobile
$env:PYTHONPATH = "access_backend;."
python tools/quality_validation/batch_runner.py `
  --dataset-root path\to\my_dataset `
  --output-dir tools/quality_validation/output/run_001 `
  --engine efficientnet `
  --engine opencv
```

Options:

- `--manifest path\to\manifest.csv` — optional manifest
- `--split dev` — evaluate one split only
- `--video-sample-frames 4` — override `EVALUATION_VIDEO_SAMPLE_FRAMES`

Outputs in `--output-dir`:

- `machine_results.json` — full records + run metadata
- `machine_results.csv` — flat table
- `run_metadata.json` — git revision, weights hash, library versions

## Repeatability

```powershell
python tools/quality_validation/repeatability.py `
  --dataset-root path\to\my_dataset `
  --engine opencv `
  --repeats 5 `
  --output-dir tools/quality_validation/output/repeat_test
```

## Analysis (reference labels and/or ACCESS human ratings)

```powershell
python tools/quality_validation/analyze_ratings.py `
  --machine-results tools/quality_validation/output/run_001/machine_results.json `
  --reference-labels D:\pilot\access_quality_pilot\reference_labels.csv `
  --output tools/quality_validation/output/run_001/analysis_report.json
```

Optional: add `--human-ratings path\to\human_ratings.csv` for ACCESS rater study in parallel.

Reference sections split metrics into:

- **`validated_criterion_metrics`** (`directly_comparable`): e.g. overall MOS, noise after inversion
- **`exploratory_proxy_metrics`** (`related_proxy`): e.g. SPAQ sharpness vs machine Sharpness only
- **`not_comparable`**: e.g. colorfulness vs no machine rubric

Do **not** cite proxy metrics as validated criterion accuracy. ACCESS human-rating sections (if provided) still use median vs machine and Fleiss kappa where applicable.

## Engine probe

```powershell
python -c "import sys; sys.path[:0]=['access_backend','.']; from tools.quality_validation.engines import engine_availability; print(engine_availability())"
```

## Limitations

- Uses the same `_photo_criteria` / `_build_payload` helpers as production but **forces** one engine; failed EfficientNet does not fall back to OpenCV.
- Photography dimensions (color, composition, subject) are **not** in the machine rubric yet; human columns for those will show low/zero pairs until Phase 2.
- Video motion/flicker scores still follow production heuristics (including limited-frame defaults in `media_evaluator`).
- Passing unit tests does **not** prove human agreement.

## Tests

```powershell
cd access_backend
python -m pytest ../tools/quality_validation/tests -q
```

Phase 3 tests live in `tests/test_real_world_validation.py`.

## Baseline report

Fill in `BASELINE_REPORT_TEMPLATE.md` after dev/held-out runs and human collection.
