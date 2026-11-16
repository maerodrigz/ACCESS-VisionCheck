# Execution checklist — Five Classical criteria validation

Print or copy when launching. Check items in order.  
Preparation package only until you intentionally start a new wave.

---

## A. Preparation

- [ ] Read `00_EVIDENCE_SUMMARY.md` and `../FIVE_CRITERIA_EVIDENCE_AUDIT.md`.
- [ ] Lock `ACCEPTANCE_CRITERIA.md` (do not edit after ratings start).
- [ ] Confirm raters will use `FIVE_CRITERIA_RUBRIC.md` (Brightness + Blocking confusions reviewed).
- [ ] Confirm **no** production / Flutter / EfficientNet / Classical formula edits.
- [ ] Confirm pilot-30 and NR001–NR015 are excluded.
- [ ] Confirm Noise/Ringing pack remains unmodified.

## B. Build image packs (after download approval)

- [ ] Follow `IMAGE_COLLECTION_PLAN.md` + `COLLECTION_CHECKLIST.md`.
- [ ] Fill working `five_criteria_image_manifest.csv` from the example template.
- [ ] Assign all five stratum fields **before** rating.
- [ ] Verify Brightness under/over minima and Blocking clean vs severe minima.
- [ ] Create blinded rating folder named only by `FC###`.

## C. Calibration

- [ ] Group walkthrough of 10–12 calibration images (discussion OK).
- [ ] Independent rating of 6 practice images (`five_criteria_calibration_rating_template.csv`).
- [ ] Compute within-1 and off-by-≥2 for **each** of five criteria.
- [ ] Pass calibration rule in protocol §4 (or remediate once / stop).
- [ ] Log in `five_criteria_calibration_log.csv`.

## D. Validation rating wave

- [ ] Distribute rubric + `eval_web` or blank human rating CSV + blinded images.
- [ ] Collect R1, R2, R3 independently.
- [ ] Schema / completeness / disagreement checks.
- [ ] Build human consensus (median).
- [ ] Evaluate IRR gates H1–H6 per criterion.
- [ ] If hard IRR fail → **STOP** for that criterion (do not headline machines).

## E. Machine comparison (only after IRR pass / allowed LIMITED CONSENSUS)

- [ ] Freeze human consensus CSV (+ checksums).
- [ ] Score frozen **C-prod** and **C-classical** only (read-only).
- [ ] Apply M1–M6 (+ M5a/M5b) per candidate × criterion.
- [ ] Record criterion-specific outcomes.
- [ ] Do **not** retune detectors on this set.

## F. Close-out

- [ ] Archive manifest, ratings, consensus, IRR, machine join, decision note.
- [ ] Leave production and Classical sources unchanged.
- [ ] Do not reopen Noise/Ringing KEEP UNVALIDATED from this study.
