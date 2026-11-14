# Phase 6B INDVAL statistical analysis

Generated UTC: 20261114T091500Z

Sources: `phase6b_R2_locked_ratings.csv.csv`, `phase6b_R3_locked_ratings.csv.csv` (double `.csv.csv` on disk; user-facing names omit the extra extension)

Combined: `phase6b_locked_ratings.csv` (NEW denormalized R2+R3 stack; originals untouched; N/A kept as N/A)

Output: `phase6b_statistical_analysis/`

## Validation

- R2 and R3 each: 100 unique INDVAL-001..100 IDs, `evaluator_id` R2/R3, `status=locked`, `ratings_json` with criteria scored 1-5 or N/A (every row has at least one numeric criterion).
- OpenCV `machine_scores.csv` and live MUSIQ `musiq_live_docker_20261114T074630Z/musiq_live_scores.csv` joined on INDVAL IDs; SHA256 matched image-by-image; MUSIQ 100/100 `ok` + finite OPQ.
- Original locked rating CSVs and machine outputs were not modified.

## Inter-rater R2 vs R3 (Spearman / QWK)

N/A excluded pairwise (never imputed).

- **sharpness:** n=100, ρ=0.424, p=1.12e-5, QWK=0.502, exact=0.610
- **blur:** n=100, ρ=0.375, p=1.21e-4, QWK=0.404, exact=0.390
- **noise:** n=100, ρ=0.386, p=7.42e-5, QWK=0.389, exact=0.450
- **brightness:** n=100, ρ=0.278, p=5.10e-3, QWK=0.217, exact=0.410
- **contrast:** n=98, ρ=0.286, p=4.24e-3, QWK=0.264, exact=0.286
- **blocking_artifacts:** n=99, ρ=0.360, p=2.55e-4, QWK=0.315, exact=0.465
- **ringing_artifacts:** n=100, ρ=0.210, p=0.0362, QWK=0.198, exact=0.370
- **overall_visual_quality:** n=97, ρ=0.297, p=3.13e-3, QWK=0.287, exact=0.330

Agreement is moderate for sharpness/noise/blur/blocking and weaker for ringing, brightness, contrast, and overall. Exact agreement rates are well below 0.5 for most criteria, so rater disagreement is material for INDVAL.

## Human vs OpenCV badge (human median)

OpenCV equal-bin badges are experimental Phase 9 maps, not production scores.

- **sharpness:** n=100, ρ=0.354, p=2.97e-4, MAE=1.795
- **blur:** n=100, ρ=0.354, p=3.02e-4, MAE=1.635
- **brightness:** n=100, ρ=0.216, p=0.0312, MAE=1.195
- **contrast:** n=100, ρ=0.004, p=0.966, MAE=1.125 (no detectable rank association)
- **blocking_artifacts:** n=100, Spearman undefined (OpenCV badge is constant 5 for all INDVAL images); continuous q also near null (ρ=-0.040, p=0.695)

## MUSIQ (overall only)

- Human median overall vs MUSIQ PaQ-2-PiQ OPQ: n=100, ρ=0.541, p=6.21e-9 (Pearson r=0.645). MAE omitted because scales differ (1-5 vs ~0-100).
- MUSIQ is an overall perceptual score only. It is not treated as a substitute for sharpness, blur, noise, brightness, contrast, blocking, or ringing.

## Interpretation

Two locked raters (R2, R3) on the INDVAL holdout show statistically detectable but only moderate inter-rater reliability. Human-OpenCV associations are positive and significant for sharpness/blur, weak for brightness, and absent for contrast and blocking badges. The strongest human-machine association in this pack is overall human median versus live MUSIQ OPQ. These are descriptive validation correlations only; they do not authorize production cutover of OpenCV badges or MUSIQ.

## Limitations

- R1 is not in these locked exports; IRR is two-rater only.
- Nominal p-values without multiplicity correction.
- Human median uses n=1 when the other rater marked N/A.
- OpenCV blocking badges have zero variance on this set, so badge correlation is undefined.
- Source export filenames use double extension `.csv.csv`.
- Agent Shell execution was unavailable; statistics were computed via an equivalent stdlib Spearman/QWK implementation (average ranks, Student-t p via incomplete beta) and written to this folder.
