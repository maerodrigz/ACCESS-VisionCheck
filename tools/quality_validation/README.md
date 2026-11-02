# ACCESS VisionCheck — Quality Validation Toolkit (Milestone 1)

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

## Baseline report

Fill in `BASELINE_REPORT_TEMPLATE.md` after dev/held-out runs and human collection.
