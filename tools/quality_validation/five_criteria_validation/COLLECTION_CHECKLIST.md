# Collection checklist — Five Classical criteria (facilitator)

Use after approval to download. **Do not start until approved.**

---

## Before first download

- [ ] Confirm exclusion lists: pilot-30, NR001–NR015, Classical threshold-selection images.
- [ ] Prepare empty folders: `images/`, `facilitator/`, `ratings/` (empty).
- [ ] Copy `templates/five_criteria_image_manifest.example.csv` → `five_criteria_image_manifest.csv`.

## Per candidate image

- [ ] License recorded (CC / public domain / written permission).
- [ ] Source URL / Commons title recorded.
- [ ] File opens; resolution adequate for 100% crops.
- [ ] SHA-256 recorded.
- [ ] `previously_used_in_eval_sets` confirmed disjoint.
- [ ] Planned strata assigned for all five criteria.
- [ ] Assigned to calibration / validation / reserve **before** any rating.

## Pack balance gates (validation)

- [ ] n in 36–48 (target 40).
- [ ] Brightness under + over minima met (`IMAGE_COLLECTION_PLAN.md` §4).
- [ ] Blocking: ≥8 clean and ≥8 moderate/severe planned.
- [ ] Sharpness / Blur / Contrast not all “clean.”
- [ ] Content mix roughly matches the plan.

## Before releasing to raters

- [ ] Filenames blinded (`FC###` only).
- [ ] Stratum columns absent from rater materials.
- [ ] Calibration pack separate from validation pack.
- [ ] `eval_web/images` symlink or copy ready (when using the webpage).

## Stop conditions

- Cannot meet Blocking or Brightness balance without excluded IDs → pause and redesign pack.
- License unclear → exclude.
- Temptation to “pre-score with Classical to pick hard cases” → **forbidden** (selection bias).
