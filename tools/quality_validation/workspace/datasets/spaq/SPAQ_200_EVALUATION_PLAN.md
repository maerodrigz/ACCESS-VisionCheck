# SPAQ 200: proposed evaluation procedure (not run)

**Status:** plan only. Integrity is `ok` (200 readable JPEGs, 1:1 with annotations). **No model comparison has been run.**

**Date:** 2026-11-07.

This is research-only. Production scoring, weights, API, Flutter, XP, authenticity, Gemini, and MUSIQ stay unchanged. SPAQ human ratings in the merged CSV are copies of the ZIP files and will not be rewritten.

---

## 1. What would be scored

| Item | Path |
|------|------|
| Images | `workspace/datasets/spaq/images/*.jpg` (n=200) |
| Human ratings | `workspace/datasets/spaq/metadata/human_ratings_200.csv` |
| Script | `tools/quality_validation/run_spaq_200_validation.py` |
| Output (if approved) | `workspace/datasets/spaq/output/run_001/` |

Command after approval:

```text
python run_spaq_200_validation.py --infer
```

Without `--infer` the script only writes `comparison_plan.json`.

---

## 2. Proposed ACCESS scorer (needs confirmation)

Primary call: existing `evaluate_production_quality` in `real_world_evaluate.py`.

That is the live `media_evaluator.evaluate_bytes` photo path with:

- `include_authenticity=False`
- AI detector and DB patched to fail closed
- integer badges after production `_soft_score`
- `overall_score` = mean of the seven photo criteria (not a MOS-trained head)

**Open question A (engine fallback):** production `resolve_quality_engine_for_bytes` tries EfficientNet first, then OpenCV if EfficientNet is missing or fails. Proposal: keep that production path, record `quality_engine` and `opencv_fallback` per image, and report correlations twice (all successful images, and EfficientNet-only). Do not silently drop failed images or fill 0.5 placeholders.

**Open question B (raw vs badge):** this plan uses the **integer badge scores** members see, not raw EfficientNet floats and not Phase 9 `scoring_candidates` mappings. If you want raw head probabilities as a second table, say so; it would still be research-only and would not replace the badge comparison.

---

## 3. Direction, scale, and which pairs get which metrics

SPAQ attributes are 0-100 continuous human opinions. ACCESS badges are 1-5 integers after `_soft_score`. Pearson and Spearman do not require the same numeric scale. MAE/RMSE only make sense after an explicit 1-5 map, and only where constructs match.

| SPAQ field | ACCESS field | Direction | Comparability | Pearson / Spearman | MAE / RMSE |
|------------|--------------|-----------|---------------|--------------------|------------|
| MOS | `overall_score` | both higher = better | related_proxy | yes | no |
| Noisiness | Noise | invert SPAQ first (high noisiness = worse; ACCESS Noise high = cleaner) | directly_comparable_after_invert | yes | yes, on mapped 1-5 vs integer badge, labeled as scale-mixed |
| Sharpness | Sharpness | both higher = sharper | related_proxy | yes | no |
| Brightness | Brightness | both higher = better exposure-ish | related_proxy | yes | no |
| Contrast | Contrast | both higher = more contrast | related_proxy | yes | no |
| Colorfulness | none | n/a | not comparable | no | no |
| (none) | Blur | n/a | **no human label** | **no** | **no** |
| (none) | Blocking Artifacts | n/a | **no human label** | **no** | **no** |
| (none) | Ringing Artifacts | n/a | **no human label** | **no** | **no** |

Notes:

- SPAQ Sharpness is “inversely proportional to blur” in Fang et al. ACCESS still has a separate Blur head. Correlation is Sharpness-to-Sharpness only. That is **not** a Blur validation.
- SPAQ Brightness is “poorly exposed” vs good exposure. ACCESS Brightness is a production exposure-style head. Same word, not the same rater brief.
- SPAQ Contrast is reduced vs strong contrast. Not a clip/harsh-contrast penalty study.
- For unlabeled criteria, if `--infer` runs, the report would list **machine score distributions only**, with `correlation_computed: false`.

**Open question C (Noise MAE):** MAE is proposed because the constructs match after invert, but SPAQ is continuous and ACCESS is integer. Confirm before treating that MAE as an accuracy number. If you prefer correlations only, MAE will be omitted.

---

## 4. What will not be claimed

- Human-rated validation of Blur, Blocking, or Ringing.
- That SPAQ Brightness/Contrast/Sharpness equal ACCESS badges.
- That ACCESS overall_score is a SPAQ MOS predictor in the IQA-benchmark sense (it is the mean of seven boosted integers).
- Calibration or retraining from this subset.
- Any number invented for a missing pair.

---

## 5. Outputs if you approve `--infer`

- `spaq_200_machine_scores.csv`: one row per image, original human columns plus machine badges, engine flags, status.
- `spaq_200_metrics.json`: n, Pearson, Spearman, optional bootstrap CI, optional Noise MAE, unlabeled distributions.
- Failed or fallback images stay in the CSV with status flags. They are not imputed.

---

## 6. Stop

Scoring has not started. Reply whether to run `--infer` as specified, and answers to A/B/C if you want a different scorer, a raw-head table, or no MAE.
