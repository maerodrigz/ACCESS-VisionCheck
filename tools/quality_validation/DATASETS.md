# Research datasets (KonIQ-10k and LIVE-VQC)

Workspace preparation only. **Do not claim accuracy has been validated.** This folder does not download media.

Official files stay on your machine. Git ignores images, videos, `.mat`, score tables, and generated `published_mos.csv` / `subset_manifest.csv`.

## Layout

```
tools/quality_validation/workspace/datasets/
  koniq10k/images/
  koniq10k/metadata/
  live_vqc/videos/
  live_vqc/metadata/
```

Independent ACCESS criterion ratings (3 raters, Sharpness/Blur/Noise, …) still use `workspace/real_world/`. Published MOS is **not** a substitute for those ratings.

## What each label is

| Source | What it is | Use for | Do not use for |
|---|---|---|---|
| KonIQ-10k `MOS` | Aggregate 5-point ACR mean | Overall quality vs system `overall_score` | Fleiss kappa, ACCESS criteria |
| KonIQ-10k `MOS_zscore` | Different normalized scale | Keep as raw sidecar only | Mapping to ACCESS 1–5 |
| LIVE-VQC MOS | Aggregate continuous MOS (literature: 0–100) | Overall quality vs system `overall_score` after documented 0–100 → 1–5 map | Criterion scores, three raters |
| `human_rating_access_criteria.csv` | Independent raters on ACCESS criteria | Criterion MAE / kappa | Inventing MOS |

## KonIQ-10k metadata (documented)

Download yourself from [MMSP KonIQ-10k](https://database.mmsp-kn.de/koniq-10k-database.html) / [DaRUS 10.18419/DARUS-2435](https://doi.org/10.18419/DARUS-2435). Follow their license.

Place:

1. `koniq10k_scores_and_distributions.tab` (or `.csv`) in `koniq10k/metadata/`
2. JPEG images in `koniq10k/images/` (full set or only the 40 files named in the subset after preview)

Required headers: `image_name`, `MOS`.  
Documented extra headers: `c1`–`c5`, `c_total`, `SD`, `MOS_zscore`.  
`c1`–`c5` are category counts, not ACCESS raters.

Column mapping: `templates/import_mapping.koniq10k.json`.

## LIVE-VQC metadata (inspect, then map)

Download yourself from [LIVE VQC](https://live.ece.utexas.edu/research/LIVEVQC/) after agreeing to the LIVE lab terms. Literature describes MOS on a **0–100** scale. **MAT variable names are not hardcoded.**

Place `data.mat` (or a CSV export) in `live_vqc/metadata/` and videos in `live_vqc/videos/`.

Then inspect keys. Copy the printed names into a mapping JSON. Do not guess.

## Preview (no scoring)

From the repo root in PowerShell:

```powershell
cd C:\Users\Dell\Desktop\access_mobile
$env:PYTHONPATH = "access_backend;."

python tools/quality_validation/research_preview.py --inspect-only
python tools/quality_validation/research_preview.py --dataset koniq10k --photo-n 40 --seed 20261106
python tools/quality_validation/research_preview.py --dataset live_vqc --inspect-only
```

`--inspect-only` prints headers or MAT keys. Full preview checks file existence and MOS distributions and writes `metadata/preview_report.json` for KonIQ when the scores file is present.

## Import a reproducible subset (still no scoring)

```powershell
python tools/quality_validation/research_import.py --dataset koniq10k --n 40 --seed 20261106
```

LIVE-VQC import is blocked until placeholders are gone:

```powershell
Copy-Item tools/quality_validation/templates/import_mapping.live_vqc.example.json `
  tools/quality_validation/workspace/datasets/live_vqc/metadata/import_mapping.live_vqc.json

# After inspect-only, edit that JSON: replace every REPLACE_WITH_* value.

python tools/quality_validation/research_import.py `
  --dataset live_vqc `
  --n 20 `
  --seed 20261106 `
  --mapping tools/quality_validation/workspace/datasets/live_vqc/metadata/import_mapping.live_vqc.json
```

Writes (gitignored): `subset_manifest.csv`, `published_mos.csv`. Raw MOS is kept. Mapped 1–5 is filled only when the scale is documented (`1-5` for KonIQ; `0-100` for LIVE-VQC after a filled mapping).

## Extract the 40 KonIQ JPEGs from a local ZIP (no scoring)

Use the official 1024×768 or 512×384 JPEG archive you already downloaded. The tool reads selected names from `preview_report.json` and writes only those files into `koniq10k/images/`.

Dry-run first (lists matches, missing names, ambiguous duplicates, and estimated size):

```powershell
cd C:\Users\Dell\Desktop\access_mobile
$env:PYTHONPATH = "access_backend;."

python tools/quality_validation/koniq_extract.py `
  --zip "C:\path\to\koniq10k_1024x768.zip" `
  --dry-run
```

If the archive contains both resolutions, add `--resolution 1024x768` or `--resolution 512x384`.

Extract after dry-run looks correct:

```powershell
python tools/quality_validation/koniq_extract.py `
  --zip "C:\path\to\koniq10k_1024x768.zip"
```

Existing files in `images/` are not replaced unless you pass `--overwrite`. Results are written to `workspace/datasets/koniq10k/metadata/extraction_report.json`. This does not download data and does not run quality evaluation.

## KonIQ-10k production-path evaluation (do not run until approved)

Uses `evaluate_bytes(..., include_authenticity=False)` through `real_world_evaluate.py`. No HTTP, PostgreSQL, PROBE, or Gemini. Compares **machine overall** to **published MOS overall** only.

Dry-run (files, MOS join, engine availability; no scoring):

```powershell
cd C:\Users\Dell\Desktop\access_mobile
$env:PYTHONPATH = "access_backend;."

python tools/quality_validation/research_evaluate.py --dry-run
```

40-image evaluation after approval:

```powershell
python tools/quality_validation/research_evaluate.py `
  --output-dir tools/quality_validation/workspace/datasets/koniq10k/metadata/output/run_001
```

Do not use `real_world_batch.py --prepare` on this folder (it would scan `photos/` and mint `PHOTO-001` IDs that do not match KonIQ MOS). Do not use `batch_runner.py` (forced-engine path, not production fallback).

## Run 002 stratified KonIQ sample (100 images)

Empirical MOS quintiles on all 10,073 official scores, seed `20261107`, excludes the 40 Run 001 files. Selection lives under `workspace/datasets/koniq10k/run_002/` and does not modify `output/run_001/`.

Write/refresh the selection (no extract, no scoring):

```powershell
python tools/quality_validation/koniq_stratify.py --seed 20261107 --n-per-stratum 20
```

Extract after approval (separate image folder):

```powershell
python tools/quality_validation/koniq_extract.py `
  --zip "C:\Users\Dell\Downloads\koniq10k_1024x768.zip" `
  --preview-report tools/quality_validation/workspace/datasets/koniq10k/run_002/metadata/extract_preview.json `
  --images-dir tools/quality_validation/workspace/datasets/koniq10k/run_002/images `
  --report tools/quality_validation/workspace/datasets/koniq10k/run_002/metadata/extraction_report.json `
  --resolution 1024x768 `
  --dry-run
```

Score after extraction approval:

```powershell
python tools/quality_validation/research_evaluate.py `
  --dataset-root tools/quality_validation/workspace/datasets/koniq10k/run_002 `
  --manifest tools/quality_validation/workspace/datasets/koniq10k/run_002/metadata/subset_manifest.csv `
  --published-mos tools/quality_validation/workspace/datasets/koniq10k/run_002/metadata/published_mos.csv `
  --output-dir tools/quality_validation/workspace/datasets/koniq10k/run_002/output
```

## Later analysis (do not run until you approve scoring)

Independent criterion ratings:

```powershell
python tools/quality_validation/real_world_analyze.py `
  --machine-results tools/quality_validation/workspace/real_world/output/run_001/machine_results.json `
  --human-ratings tools/quality_validation/workspace/real_world/ratings/human_ratings.csv `
  --output-dir tools/quality_validation/workspace/real_world/output/run_001
```

Published MOS overall only (no Fleiss kappa):

```powershell
python tools/quality_validation/real_world_analyze.py `
  --machine-results tools/quality_validation/workspace/datasets/koniq10k/metadata/machine_results.json `
  --published-mos tools/quality_validation/workspace/datasets/koniq10k/metadata/published_mos.csv `
  --output-dir tools/quality_validation/workspace/datasets/koniq10k/metadata/output
```

## Tests

```powershell
cd C:\Users\Dell\Desktop\access_mobile
$env:PYTHONPATH = "access_backend;."
python -m pytest tools/quality_validation/tests -q
```
