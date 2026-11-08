# ACCESS VisionCheck — human validation dataset plan

Documents and templates only. **No rating and no retraining in this step.**

Preserve Run 001 (`workspace/datasets/koniq10k/metadata/output/run_001/`) and Run 002 (`workspace/datasets/koniq10k/run_002/output/`).

Published KonIQ MOS remains **overall** ground truth only.

---

## 1. Pilot (protocol + IRR, not model fitting)

**Goal:** Test the rubric, blinding, and three-rater workflow on real photographs already on disk.

**Source:** KonIQ-10k Run 002 images (`run_002/images/`), seed `20261107`, empirical MOS quintiles. These files are already extracted. Machine scores already exist and must be **hidden from raters**.

**Proposed composition (30 photos):**

| Band | Run 002 stratum | Count | Role |
|---|---|---:|---|
| Low | Q1_very_low | 10 | Stress low-MOS over-score finding |
| Medium | Q3_mid | 10 | Typical mid quality |
| High | Q5_very_high | 10 | Check under-score vs high MOS |

Facilitator draws 10 filenames **per band** from `run_002/metadata/selection_manifest.csv` using a new documented seed (recommended `20261107` plus a distinct draw key recorded in the facilitator log, for example salt `pilot30`). Do not use MOS values on rater materials. Do not use Run 001's 40 IDs in this pilot if you want the human set disjoint from the first MOS-only run; Run 002 already excluded those files.

**Calibration pack (8–12 images):** choose from Run 002 Q2 or Q4 leftovers, or from the KonIQ catalog **not** in the 30-image pilot. Calibration images are **excluded** from MAE/correlation of the pilot.

**Workload:** 30 images × 3 raters = 90 rows. Photos only (`flickering` / `motion_stability` = `N/A`).

**Outputs (after approval to rate, not now):**

- Blind image pack under `workspace/real_world/photos/` or a dedicated `workspace/human_pilot/images/` (do not mix into `run_002/output/`)
- Combined human CSV for `real_world_analyze.py --human-ratings`
- Facilitator key: `media_id`, original filename, stratum, MOS (facilitator only)

**Analysis after lock:**

1. IRR on the 30 (section 7 of the protocol).
2. Criterion MAE/Spearman vs Run 002 **machine criterion integers** for those 30 `media_id`s.
3. Separate table: system overall vs published MOS for the same 30 (MOS still overall-only).

If IRR is too low on a criterion, stop. Revise the rubric or training. Do not retrain.

---

## 2. Why this pilot is not a training set

The EfficientNet-B0 heads were trained on synthetic degradations. A 30-image human pilot is sized for **process and agreement**, not for fitting 8,967 head parameters (or an unfrozen backbone). Using the pilot as gradient updates would overfit and leak into the only labeled check.

---

## 3. Future training / validation / held-out (before any retrain)

Collect a **new** labeled pool of real photographs with ACCESS criterion ratings (same rubric, ≥3 raters, median aggregate). Recommended minimum before considering a head retrain: on the order of **several hundred** images with full seven-criterion labels, stratified across quality and content. Exact n is a later design choice; do not invent a dataset here.

**Split by image ID, never by rater row:**

| Split | Suggested share | Use |
|---|---|---|
| Train | ~70% | Fit heads (and optional backbone unfreeze) **only after** this protocol is approved as a separate project |
| Validation | ~15% | Early stopping, `_soft_score` experiments, architecture choices |
| Held-out test | ~15% | One-time final report. No tuning. |

**Leakage rules:**

1. No image in held-out appears in train, validation, calibration, or this 30-image pilot if the pilot was used to change the rubric.
2. If the rubric changes after the pilot, relabel or discard affected sets; do not mix old and new anchors.
3. KonIQ **MOS** may still be used on a disjoint overall-quality track (train/val/test by image for *overall* predictors only). Never copy MOS into the seven ACCESS label columns.
4. SPAQ (or similar) attributes may be used only with a written mapping (see existing `reference_schema.py` / noisiness inversion). Unmapped attributes stay empty.
5. Synthetic `SyntheticIQADataset` must not be mixed into the human train split as if it were human ground truth. If used at all, treat it as a separate pretrain and say so.

**Held-out test report** (future): criterion MAE/Spearman vs human medians, IRR on a held-out human subset, plus optional overall MOS comparison on images that have MOS. No accuracy percentage.

---

## 4. Video

This photo protocol does not replace a video study. Flickering and Motion Stability need a later clip set (for example LIVE-VQC **after** mapping is filled) and the same three-rater rule. Do not start video rating in this preparation step.

---

## 5. File locations (when work is approved)

| Item | Path |
|---|---|
| Rubric | `tools/quality_validation/HUMAN_RATING_RUBRIC.md` |
| Blank sheet | `tools/quality_validation/HUMAN_RATING_TEMPLATE.csv` |
| Completed ratings | `tools/quality_validation/workspace/real_world/ratings/` (gitignored) |
| Pilot machine join | New directory, **not** `run_001` or `run_002` output folders |
| Facilitator unblind key | Local only, gitignored, never in the rater pack |

---

## 6. Immediate stop

Do not select the final 30 filenames into a public chat sheet that includes MOS if raters can see this repo path. The facilitator should generate the blind list at rating time.

Do not start rating, do not start training, and do not modify production weights or `_soft_score` in this preparation step.
