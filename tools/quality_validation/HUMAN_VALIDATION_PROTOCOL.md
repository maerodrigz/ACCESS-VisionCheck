# ACCESS VisionCheck — criterion-specific human validation protocol

Research procedure only. It does **not** retrain EfficientNet-B0, change production scoring, or claim scientific validity before ratings exist.

Companion files:

- `HUMAN_RATING_RUBRIC.md`
- `HUMAN_RATING_TEMPLATE.csv`
- `VALIDATION_DATASET_PLAN.md`

Analyzer compatibility: completed sheets use the same columns as `templates/human_rating_access_criteria.csv` so `real_world_analyze.py --human-ratings` can run **after** ratings exist. Do not invent scores to test that path.

---

## 1. Purpose and constructs

| Construct | Human task | System counterpart | Allowed use of KonIQ MOS |
|---|---|---|---|
| Seven ACCESS criteria | Independent 1–5 ratings per criterion | Production criterion integers | **Never** as criterion labels |
| Independent overall | `overall_visual_quality` | Compared separately to system overall (mean of 7) | Optional parallel overall check |
| Published KonIQ MOS | Not shown to raters | Compared only to system overall | Overall-quality comparison only |

Do not copy MOS into Sharpness, Blur, Noise, Brightness, Contrast, Blocking, or Ringing.

---

## 2. Roles

| Role | Who | Sees machine scores / MOS? |
|---|---|---|
| Facilitator | One person who prepares packs and later runs analysis | Yes, after ratings are locked |
| Raters R1, R2, R3 | At least three people who meet the training checklist | **No** |
| Adjudicator | Optional fourth person for flagged disagreements | No machine scores; may see the three human integers |

The facilitator must not rate in the same session if they have already seen Run 001/002 CSVs. If staff is limited, the facilitator rates first, then is barred from viewing results until the other two finish.

---

## 3. Blinding

1. Build a **rating pack** of image files named only by `media_id` (for example `KONIQ2-019.jpg`), not original Flickr IDs if those are stored beside MOS tables in the rater's workspace.
2. Give raters: the image pack, this protocol, `HUMAN_RATING_RUBRIC.md`, and a blank copy of `HUMAN_RATING_TEMPLATE.csv`.
3. Do **not** give: `published_mos.csv`, `per_image_results.csv`, `machine_results.json`, `selection_manifest.csv`, stratum names, Run 001/002 reports, or `MODEL_VALIDITY_DIAGNOSTIC.md`.
4. Raters work **independently**. No talking through scores until all sheets are submitted.
5. After lock, the facilitator joins human CSVs to machine results and to KonIQ MOS on `media_id`.

---

## 4. Rater training (before the pilot)

Do not start the scored pilot until this checklist is done. **This repository does not include gold ratings.** The facilitator prepares a small calibration pack *after* this protocol is approved, using images that will **not** enter the pilot analysis set (see dataset plan).

1. Read `HUMAN_RATING_RUBRIC.md`, especially Sharpness versus Blur.
2. Review 8–12 calibration images together (discussion allowed).
3. Rate 6 held-out calibration images **independently**.
4. Facilitator computes pairwise exact-agreement and off-by-more-than-1 rates per criterion (no production model involved).
5. If any rater has off-by-more-than-1 on more than one-third of calibration images for the same criterion, repeat that criterion's examples and re-rate the 6 images once.
6. Record training completion in a facilitator log (rater_id, date, calibration pack id). Do not store invented scores in git.

---

## 5. Independent rating process (pilot)

1. At least **three** raters per image (`R1`, `R2`, `R3`).
2. One row per `(media_id, rater_id)`.
3. Integers 1–5 or `N/A` only.
4. Photos: `flickering` = `N/A`, `motion_stability` = `N/A`.
5. Fill `overall_visual_quality` independently.
6. Optional `notes` for odd cases (heavy crop, watermark). Notes must not mention MOS or machine scores.
7. Save as `workspace/real_world/ratings/pilot_koniq_R1.csv` (or one combined file). Do not overwrite Run 001/002 machine output directories.

Target duration: about 2–4 minutes per photo (two viewing passes).

---

## 6. Consistency checks (during and after)

After all sheets are in, and **before** unblinding machine scores:

1. Schema check: required columns present; scores in {1,2,3,4,5,N/A}; photos have video criteria `N/A`.
2. Completeness: every media_id has three rater_ids.
3. Duplicate rows: unique `(media_id, rater_id)`.
4. Straight-lining: flag a rater who uses a single integer for all seven criteria on more than 20% of images (review, do not auto-discard).
5. Disagreement flag: for each criterion, if `max(R1,R2,R3) - min(R1,R2,R3) >= 3` (ignoring N/A), mark the cell for adjudication.

**Adjudication:** The adjudicator rates that criterion once, still blind to MOS and machine scores. Store `R_adj` in a separate column or file. Primary analysis uses the **median of R1,R2,R3** (existing `real_world_analyze.py` behavior). Report adjudicated values as a sensitivity table, not as a replacement that hides disagreement.

Do not average MOS into a fourth "human" rater.

---

## 7. Inter-rater reliability

Compute on the locked human sheet, still before treating machine comparison as the headline:

| Metric | How | Notes |
|---|---|---|
| Fleiss' kappa | Integer categories 1–5 per criterion; skip N/A by dropping that item for all raters or use available-case | Already implemented for overall in `real_world_analyze.py`; extend the same helper per criterion in a later analysis run |
| Off-by-at-most-1 rate | Pairwise fraction with \|Ri − Rj\| ≤ 1 | Descriptive; not accuracy |
| Median vs each rater MAE | Stability of the aggregate | Low n will be noisy |

Interpret kappa as agreement among humans, not as model quality. If kappa is poor on a criterion, do not train or recalibrate that head until the rubric or training is fixed.

---

## 8. Comparison to system criterion scores

Only after human sheets are locked:

```powershell
cd C:\Users\Dell\Desktop\access_mobile
$env:PYTHONPATH = "access_backend;."
python tools/quality_validation/real_world_analyze.py `
  --machine-results <path-to-machine_results.json> `
  --human-ratings <path-to-combined-human.csv> `
  --output-dir <new-output-dir-not-run_001-or-run_002>
```

Rules:

- Pair **Sharpness** human median with system Sharpness, **Blur** with Blur, and so on. Seven separate comparisons.
- Metrics: n_paired, MAE, RMSE, Spearman, Pearson, bias (system minus human median), fraction \|error\| ≤ 1. No accuracy percentage.
- Failed system evaluations stay failed (exclude from MAE, list IDs).
- Do not back-fill missing human cells.
- **Published KonIQ MOS** is joined only to system `overall_score` (as in Run 001/002 `--published-mos`). It is not a human criterion.

Independent `overall_visual_quality` is compared to system overall as a **different construct** (human gestalt vs mean of seven technical integers).

---

## 9. What this protocol will not do

- Retrain or edit `efficientnet_b0_heads.pt`
- Change `_soft_score` or production formulas
- Write PostgreSQL rows
- Use PROBE, WaveRep, or Gemini
- Modify Flutter, Admin Web, or FastAPI
- Overwrite Run 001 or Run 002 result folders

---

## 10. Stop conditions

Do not start live rating until:

1. Calibration pack is chosen and excluded from the pilot list (`VALIDATION_DATASET_PLAN.md`).
2. Three raters complete training.
3. Blind packs contain no MOS or machine CSVs.

Do not start retraining until the dataset plan's train/validation/held-out split exists **and** this protocol's human labels are collected on a set that is not the held-out test.
