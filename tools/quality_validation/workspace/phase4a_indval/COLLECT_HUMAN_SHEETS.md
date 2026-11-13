# Facilitator: collect Phase 4B human sheets

## Distribute (per rater)

Only these paths (or a zip of them):

- `human_packs/images/`
- `human_packs/image_quality_ratings_R#.csv`
- `human_packs/issue_labels_R#.csv`
- `human_packs/feedback_quality_ratings_R#.csv`
- `human_packs/INSTRUCTIONS.md`
- `human_packs/HUMAN_RATING_RUBRIC.md`

Do **not** distribute:

- `machine_output/`
- `facilitator_mapping.csv`
- `holdout_manifest.csv` (contains source paths)
- `PHASE4B_MACHINE_EVAL_COMPLETION_REPORT.md` score tables (optional to withhold until after image/issue tasks)

## Receive back

Nine CSVs with filled human cells (3 raters × 3 sheet types). Place them back under `human_packs/`.

## Then analyze

```bash
cd tools/quality_validation
python analyze_phase4a_results.py
```

Do not run analysis with `--allow-empty` for Chapter 4 numbers.
