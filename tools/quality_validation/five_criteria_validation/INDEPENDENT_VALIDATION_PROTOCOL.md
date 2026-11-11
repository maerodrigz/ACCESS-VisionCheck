# Independent five-criteria validation protocol

**Status:** Preparation only. Do not launch ratings or machine evaluation until the facilitator checklist is complete and acceptance criteria are locked.  
**Disjointness:** Images must be previously unused for training, tuning, model selection, or evaluation of these detectors — and must **not** include frozen pilot-30 or NR001–NR015.  
**Forbidden:** SPAQ/KonIQ re-runs for fitting, detector retuning, production/sandbox scoring changes, Noise/Ringing study edits.

Companions: `00_EVIDENCE_SUMMARY.md`, `FIVE_CRITERIA_RUBRIC.md`, `ACCEPTANCE_CRITERIA.md`, `IMAGE_COLLECTION_PLAN.md`, `EXECUTION_CHECKLIST.md`, `templates/`, `eval_web/`.

---

## 1. Purpose

1. Obtain reliable human 1–5 labels for five criteria on a new independent photo set.  
2. Only then compare **frozen** C-prod vs C-classical against those labels.  
3. Produce **criterion-specific** further-review / keep-unvalidated decisions. No retune loop on the same images.

---

## 2. Roles

| Role | Duties | Sees machine scores? |
|------|--------|----------------------|
| Facilitator | Packs, strata, blinding; analysis after lock | Yes, **after** human lock only |
| Raters R1–R3 | Independent ratings | **No** |
| Adjudicator (optional) | Large disagreements (`max−min ≥ 3`) | No machines |

The facilitator does not rate in the same wave if they already saw machine outputs for these images.

---

## 3. Dataset design

### 3.1 Size

| Split | Target n | Use |
|-------|----------|-----|
| Calibration | 12–16 (+ 6 independent practice) | Discussion / practice only; **never** in validation metrics |
| Independent validation | **36–48** (target **40**) | Locked humans + later machine compare |
| Reserve | 8–10 | Corrupt-file swaps only |

IDs reserved for this study: `FC001`…`FC0xx` (Five Criteria). Do not reuse `NR*` or `PILOT-*` IDs.

### 3.2 Stratification (facilitator only)

Assign before rating (see `IMAGE_COLLECTION_PLAN.md` and rubric strata fields). Roughly balance severity for **each** criterion, with special force-balance for:

- Brightness: under **and** over exposure  
- Blocking: clean through severe (avoid all-clean packs)

### 3.3 Inclusion / exclusion

**Include:** Real ACCESS-like documentation photos; consumer phone/camera JPEGs; varied lighting and compression.

**Exclude:** Pilot-30; NR001–NR015; images used to select Classical thresholds; pure synthetic unit-test ladders as validation items; unreadable files.

### 3.4 Blinding

- Rating files named only `FC###.jpg` (or png).  
- Mapping in `five_criteria_image_manifest.csv` (facilitator only).  
- Raters get images + rubric + instructions + blank sheet / `eval_web`. No stratum columns.

---

## 4. Rater calibration (required)

Complete before any validation rating. Calibration images ≠ validation images.

1. Read `FIVE_CRITERIA_RUBRIC.md`, especially the confusion matrix and Brightness under/over rule.  
2. **Group walkthrough:** 10–12 calibration images spanning clean→severe for all five, with known Brightness and Blocking confusers.  
3. **Independent practice:** 6 held-out calibration images → `templates/five_criteria_calibration_rating_template.csv`.  
4. Facilitator computes pairwise within-1 and off-by-≥2 **per criterion**.  
5. **Calibration pass rule:** for **each** of the five criteria, mean pairwise within-1 ≥ **0.80** on the 6 images, and no rater has off-by-≥2 on more than 2 of 6 images for that criterion.  
6. If fail: one remediation (emphasis on Brightness and Blocking) + one re-rate of the same 6. If still fail: **stop** and revise rubric examples before the validation wave.  
7. Log in `five_criteria_calibration_log.csv`.

---

## 5. Validation rating process

1. Three raters (`R1`, `R2`, `R3`).  
2. Preferred UI: `eval_web/` (offline). Fallback: CSV templates.  
3. Required columns: `sharpness`, `blur`, `brightness`, `contrast`, `blocking_artifacts` ∈ {1,2,3,4,5,N/A}.  
4. Leave Noise/Ringing/overall blank or `N/A` (focused study).  
5. Independent work; no score discussion until all sheets submitted.  
6. Target **4–6 minutes** per photo (five criteria + crops).  
7. Save under `ratings/` when launching (not required for this prep-only package).

---

## 6. Analysis order (after lock)

1. Completeness / schema / `N/A` rates.  
2. Human IRR gates H1–H6 per criterion (`ACCEPTANCE_CRITERIA.md` §1).  
3. If hard fail → STOP for that criterion (no machine headline).  
4. If pass or allowed LIMITED CONSENSUS → freeze consensus medians.  
5. Score **frozen** C-prod and C-classical only (read-only).  
6. Apply M1–M6 per candidate × criterion.  
7. One written decision report; no retune on this set.

Optional analyzer reuse after real ratings exist: `../analyze_human_pilot_validation.py` (column-compatible). Do not invent scores to exercise scripts.

---

## 7. Integrity

- No production / Flutter / weight / Classical formula edits.  
- No Noise/Ringing pack modifications.  
- No expanding n after seeing machine ρ.  
- Report LIMITED CONSENSUS whenever H3 soft-fails.
