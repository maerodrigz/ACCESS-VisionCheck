# ACCESS VisionCheck — human vs machine pilot analysis

Generated (UTC): 2026-11-08T11:45:11.605777+00:00
Output directory: `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\human_pilot\output\pilot_hvsm_20261108T114511Z`

## Scope and safety

- Pilot: 30 blinded photos (`PILOT-001` … `PILOT-030`), three raters (`R1`, `R2`, `R3`).
- Machine scores: existing KonIQ Run 002 EfficientNet-B0 badges. **No re-inference.**
- Join key: `facilitator_manifest.csv` (`anonymous_id` → `koniq2_media_id`).
- KonIQ MOS was **not** used as ground truth for any of the seven criteria.
- Original human CSVs and Run 001/002 folders were not modified.
- These statistics describe agreement on this pilot set. They are **not** a claim of production accuracy or successful scientific validation of EfficientNet-B0.

## Data quality

- Human rows loaded: 90
- Raters present: R1, R2, R3
- Validation errors: 0
- Validation warnings (including explicit missing cells): 4
- OK to analyze: True

### Explicit missing human cells

| Rater | Media | Criterion |
|---|---|---|
| R1 | PILOT-020 | blocking_artifacts |
| R2 | PILOT-012 | contrast |
| R3 | PILOT-012 | brightness |
| R3 | PILOT-013 | ringing_artifacts |

Missing cells were excluded from pairwise IRR and from medians for that rater only.

## Inter-rater reliability

Pairwise exact and within-one rates average the three rater pairs. Fleiss' kappa uses ordinal categories 1–5 with missing cells omitted as documented in the JSON.

| Criterion | Missing cells | Mean exact | Mean within-1 | Mean QWK | Fleiss κ |
|---|---:|---:|---:|---:|---:|
| sharpness | 0 | 0.511 | 0.956 | 0.690 | 0.326 |
| blur | 0 | 0.567 | 0.989 | 0.773 | 0.401 |
| noise | 0 | 0.378 | 0.911 | 0.305 | 0.039 |
| brightness | 1 | 0.261 | 0.761 | -0.029 | -0.038 |
| contrast | 1 | 0.398 | 0.909 | 0.578 | 0.162 |
| blocking_artifacts | 1 | 0.477 | 0.908 | 0.163 | 0.086 |
| ringing_artifacts | 1 | 0.433 | 0.830 | 0.185 | 0.128 |
| overall_visual_quality | 0 | 0.456 | 0.989 | 0.603 | 0.199 |

## Human consensus vs machine (seven criteria)

Human reference = median of available R1/R2/R3 integers. Machine values are Run 002 criterion integers. Bias = machine − human.

| Criterion | n | MAE | RMSE | Bias | Spearman r | Within-1 |
|---|---:|---:|---:|---:|---:|---:|
| Sharpness | 30 | 0.933 | 1.125 | -0.400 | 0.104 | 0.833 |
| Blur | 30 | 0.933 | 1.183 | -0.733 | 0.160 | 0.767 |
| Noise | 30 | 0.733 | 1.033 | -0.467 | -0.275 | 0.833 |
| Brightness | 30 | 0.800 | 1.065 | 0.667 | 0.064 | 0.833 |
| Contrast | 30 | 1.017 | 1.242 | -0.783 | 0.092 | 0.800 |
| Blocking Artifacts | 30 | 0.950 | 1.158 | -0.883 | 0.001 | 0.800 |
| Ringing Artifacts | 30 | 0.883 | 1.158 | -0.750 | 0.013 | 0.767 |

## Overall construct comparison (separate)

Different constructs: human overall_visual_quality is an independent gestalt rating; machine overall_score is the arithmetic mean of the seven technical badge integers.

- n_paired: 30
- MAE: 0.738
- RMSE: 0.853
- Bias (machine − human): -0.252
- Spearman r: 0.035 (p=0.8542)
- Within-1 rate: 0.767
- KonIQ MOS used as criterion GT: False

## Limitations

- n=30 photos and 3 raters; confidence intervals are wide and not claimed here.
- Several human cells are intentionally blank; medians use only available ratings.
- Machine criterion badges on this pilot show restricted range (often 3–5 only), which can depress Spearman.
- Human overall_visual_quality and machine overall_score are different constructs.
- KonIQ published MOS is overall-only and was not used as criterion ground truth.
- This pilot does not authorize production threshold/weight changes.
- Results are descriptive for ACCESS documentation quality on this set, not a general IQA leaderboard claim.

## Interpretation guardrails

- Do not treat within-1 rate as model accuracy percentage.
- Do not retrain, retune `_soft_score`, or change production weights from this pilot alone.
- Low Spearman with low variance in machine badges can reflect restricted range, not necessarily rubric failure.

## Generated artifacts

- `data_quality_issues.csv`
- `human_ratings_combined.csv`
- `human_consensus_by_image.csv`
- `machine_scores_joined.csv`
- `inter_rater_agreement.csv`
- `per_image_human_vs_machine.csv`
- `criterion_comparison_summary.csv`
- `overall_construct_comparison.csv`
- `analysis_report.json`
- `HUMAN_VS_MACHINE_PILOT_REPORT.md`
