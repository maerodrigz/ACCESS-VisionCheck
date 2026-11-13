# Phase 4A: Frozen Independent Validation Protocol

**Freeze id:** `phase4a_freeze_20261113` (see `phase4a_freeze_manifest.json`)  
**Status:** FROZEN for preparation. Do not edit hybrid maps, feedback thresholds, or this freeze id after human rating starts without cutting a new freeze.

## Scope

Independent validation preparation for:

1. Hybrid NR-IQA criterion measurements (+ MUSIQ OPQ when live runtime exists)
2. Experimental rule-based feedback (`hybrid_feedback_rules_v1`)
3. Comparison to EfficientNet-B0 baseline (research read-only)

**Out of scope / unchanged:** production ENET serving path, PROBE, WaveRep, XP, Flutter/admin UI, DB evaluation rows, `QUALITY_SHADOW_ENABLED` (remains false in production).

## Frozen artifacts

| Component | Frozen value |
|-----------|----------------|
| Classical map | `phase9_a_priori_equal_bin_v1` (LAP_SCALE=420, q bands 0.25/0.45/0.65) |
| Feedback ruleset | `hybrid_feedback_rules_v1` |
| Shadow engine label | `hybrid_nr_iqa_shadow_v1` |
| MUSIQ | TF Hub PaQ-2-PiQ only if live; else `unavailable` (no CSV backfill) |
| Holdout seed | `20261113_phase4a_indval`, n=100 |

## Workflow (reproducible)

```bash
# 1) Select disjoint holdout
python select_phase4a_holdout.py

# 2) Machine eval (research only; no DB writes)
python run_phase4a_machine_eval.py
# Optional: --skip-musiq if TF Hub unavailable; --skip-enet to skip baseline

# 3) Blinded human packs (3 raters)
python prepare_phase4a_human_packs.py --copy-images

# 4) Raters complete CSVs (no fabricated scores)

# 5) Analysis (fails if human cells empty)
python analyze_phase4a_results.py
```

## Human tasks (three qualified evaluators)

### A. Image-quality assessment (rubric)

- Sheet: `image_quality_ratings_R*.csv`
- Protocol: `HUMAN_RATING_RUBRIC.md` (1–5 ACCESS criteria + overall)
- Includes color_balance / color_saturation columns (pilot lacked these)

### B. Independent issue labels

- Sheet: `issue_labels_R*.csv`
- Y/N for: soft_focus, bad_exposure, low_contrast, blocking, color_cast, bad_saturation
- Independent of system feedback text

### C. Feedback-quality ratings

- Sheet: `feedback_quality_ratings_R*.csv`
- Rate system observations on correctness / relevance / clarity / usefulness (1–5)
- **Not** the same as image-quality 1–5

## Metrics (computed only after real submissions)

### Image-quality track

- Spearman / Pearson: hybrid badge vs human median; ENET badge vs human; MUSIQ raw vs human overall
- MAE / RMSE: only for 1–5 compatible pairs (not MUSIQ raw vs 1–5)
- Inter-rater: quadratic weighted kappa (pairwise) + Fleiss kappa

### Feedback track

- Issue-level precision / recall / F1 (micro) with and without mild severity
- Likert means for feedback-quality dimensions
- Do not merge feedback Likert into image MOS tables

## Safeguards

- No synthetic human ratings in any script
- Analysis aborts if rating sheets are empty
- Duplicate / pilot overlap checked at selection time
- Missing annotations → excluded from pairwise metrics (not imputed)
- Cached MUSIQ benchmark CSV must not be used for holdout images

## Remaining requirements before claiming validation complete

1. Three raters finish all three sheet types for all INDVAL images (or a predeclared complete subset).
2. Live MUSIQ runtime decided (ok or documented unavailable).
3. Machine eval finished under the freeze id.
4. `analyze_phase4a_results.py` run without `--allow-empty`.
5. ACCESS-native follow-up set planned for ecological validity (recommended before production migration).
