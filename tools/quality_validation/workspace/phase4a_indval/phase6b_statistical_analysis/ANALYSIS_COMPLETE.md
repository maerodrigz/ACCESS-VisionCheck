# Phase 6B INDVAL analysis complete

UTC: 20261114T093000Z

## Validation (no mapping problems)

| Check | R2 | R3 |
|---|---|---|
| Rows | 100 | 100 |
| Unique IDs | INDVAL-001..100 | INDVAL-001..100 |
| evaluator_id | R2 | R3 |
| status | locked | locked |
| ratings_json numeric 1-5 or N/A | yes | yes |

OpenCV `machine_output/machine_scores.csv` and MUSIQ `musiq_live_docker_20261114T074630Z/musiq_live_scores.csv` join 100/100 on INDVAL IDs. MUSIQ all `ok` with finite OPQ. Originals not modified (on-disk names use double extension `.csv.csv`).

## Outputs

| Path | Role |
|---|---|
| `../phase6b_locked_ratings.csv` | NEW combined R2+R3 (denormalized criteria; N/A preserved) |
| `joined_human_opencv_musiq.csv` | Human + OpenCV badge/q + MUSIQ OPQ |
| `inter_rater_R2_vs_R3.csv` | IRR (Spearman, Pearson, QWK) |
| `descriptive_human_by_criterion.csv` | Means/medians by rater |
| `na_inventory.csv` | N/A locations |
| `human_vs_machine_spearman.csv` | Concept-matched HVM correlations |
| `fig_*.svg` | Labeled graphs |
| `INTERPRETATION.md` | Research-ready summary |

## Headline results

- IRR sharpness: n=100, ρ=0.424, p=1.12e-5, QWK=0.502
- Human median overall vs MUSIQ: n=100, ρ=0.541, p=6.21e-9
- OpenCV blocking badge: constant 5 on INDVAL; Spearman undefined
- MUSIQ matched to overall only (not per-criterion)

Reproduce: `python tools/quality_validation/analyze_phase6b_indval_locked_ratings_stdlib.py`
