# Facilitator checklist — Phase 6A

## Distribute to each rater (only)

- `rater_pack/images/`
- `rater_pack/ratings_R#.csv` (one sheet per rater)
- `rater_pack/HUMAN_RATING_RUBRIC.md`
- `rater_pack/INSTRUCTIONS.md`
- optional `rater_pack/rating_sheet.html`

## Do NOT distribute

- `facilitator/` (ID mapping, source keys, SHA-256)
- `freeze/`
- anything under `workspace/phase4a_indval/machine_output/`
- Phase 5 pilot machine scores or AI labels
- `holdout_manifest.csv` / `facilitator_mapping.csv` from Phase 4A

## Receive back

Three CSVs: `ratings_R1.csv`, `ratings_R2.csv`, `ratings_R3.csv` with filled 1–5 cells.

Place filled sheets into `rater_pack/` (or `actual_ratings/`) then run:

```bash
python generate_phase6a_consensus.py --ratings-dir <path-to-filled-sheets>
```

Consensus generation refuses empty sheets by default.
