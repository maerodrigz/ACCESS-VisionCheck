# Execution checklist — Noise and Ringing independent validation

Print or copy this list when launching the study. Check items in order.  
Preparation package only until you intentionally start a new wave.

---

## A. Preparation (this repo package)

- [ ] Read `00_EVIDENCE_SUMMARY.md` (pilot IRR + detector failures).
- [ ] Lock `ACCEPTANCE_CRITERIA.md` (do not edit after ratings start).
- [ ] Confirm raters will use `NOISE_RINGING_RUBRIC.md` (confusion matrix reviewed).
- [ ] Confirm **no** production / Flutter / sandbox scoring / detector edits are planned.
- [ ] Confirm **no** SPAQ-200 or frozen-30 pilot re-run is planned.

## B. Build image packs

- [ ] Select previously unseen real photos (disjoint from frozen pilot).
- [ ] Fill `templates/noise_ringing_image_manifest.example.csv` → save as working `noise_ringing_image_manifest.csv`.
- [ ] Assign `noise_stratum` / `ringing_stratum` (`clean|mild|moderate|severe`) **before** rating.
- [ ] Split **calibration** (12–16) vs **validation** (40–60) vs **reserve** (8–10).
- [ ] Create blinded rating folder named only by `media_id` (no stratum in filenames).

## C. Calibration (training examples only)

- [ ] Group walkthrough of 8–10 calibration images (discussion OK).
- [ ] Independent rating of 6 held-out calibration images (`noise_ringing_calibration_rating_template.csv`).
- [ ] Compute within-1 and off-by-≥2 for Noise and Ringing.
- [ ] Pass calibration rule in protocol §4 (or remediate once / stop).
- [ ] Log results in `noise_ringing_calibration_log.csv`.

## D. Validation rating wave

- [ ] Distribute rubric + blank `noise_ringing_human_rating_template.csv` + blinded images.
- [ ] Collect R1, R2, R3 sheets independently.
- [ ] Schema / completeness / disagreement checks (protocol §6).
- [ ] Build human consensus (median); optionally run `analyze_human_pilot_validation.py` on compatible CSVs.
- [ ] Evaluate **human IRR gates** (`ACCEPTANCE_CRITERIA.md` §1).
- [ ] If IRR fail → **STOP** (do not unblind machines for a headline claim).

## E. Machine comparison (only after IRR pass)

- [ ] Freeze human consensus CSV.
- [ ] Score with **frozen** estimators only (read-only).
- [ ] Apply M1–M6 per candidate × criterion.
- [ ] Record a **single** study outcome (§3).
- [ ] Do **not** retune detectors on this set.

## F. Close-out

- [ ] Archive manifest, raw ratings, consensus, IRR table, machine join, decision note.
- [ ] Update research TDR pointer if desired (optional).
- [ ] Leave production and sandbox scoring unchanged.
