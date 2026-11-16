# Independent Noise and Ringing validation protocol

**Status:** Preparation only. Do not launch ratings or machine evaluation until the facilitator checklist is complete and acceptance criteria are locked.  
**Disjointness:** Images must be **previously unseen** relative to the frozen ACCESS 30-image pilot and must not be used to tune detectors.  
**Forbidden in this study:** SPAQ-200 re-runs, frozen-pilot re-inference, detector retuning, production/sandbox scoring changes.

Companions:

- `00_EVIDENCE_SUMMARY.md`
- `NOISE_RINGING_RUBRIC.md`
- `ACCEPTANCE_CRITERIA.md`
- `EXECUTION_CHECKLIST.md`
- `templates/`

Reusable analyzers (after ratings exist; do not invent scores to test them):

- `tools/quality_validation/analyze_human_pilot_validation.py` (IRR + consensus CSVs)
- `tools/quality_validation/real_world_analyze.py` (if joining a full real-world pack)

---

## 1. Purpose

1. Obtain reliable **human** 1–5 labels for Noise and Ringing on a new independent photo set.
2. Only then compare **frozen** machine estimators (read-only) against those labels.
3. Produce a single go / no-go / revise-rubric decision. No endless retune loop on the same images.

---

## 2. Roles

| Role | Duties | Sees machine scores? |
|------|--------|----------------------|
| Facilitator | Builds packs, strata, blinding; runs analysis after lock | Yes, **after** human lock only |
| Raters R1, R2, R3 | Independent ratings | **No** |
| Adjudicator (optional) | Rates flagged large disagreements | No machine scores |

The facilitator does not rate in the same wave if they already saw machine outputs for these images.

---

## 3. Dataset design (independent photographs)

### 3.1 Size (finite target)

| Split | Target n | Use |
|-------|----------|-----|
| Calibration / training | 12–16 photos | Discussion + practice only; **never** in validation metrics |
| Independent validation | **40–60** photos | Locked human labels + later machine comparison |
| Reserve / replacement | 8–10 | Swap only for corrupt files; not a silent expansion of n |

Do not grow the validation set after seeing machine correlations.

### 3.2 Stratification (facilitator labels only; raters never see these tags)

Each validation image receives planned strata **before** rating:

| Field | Allowed values |
|-------|----------------|
| `noise_stratum` | `clean`, `mild`, `moderate`, `severe` |
| `ringing_stratum` | `clean`, `mild`, `moderate`, `severe` |
| `content_tag` | short free text (e.g. indoor, night, sky, text-signage) |

Target roughly balanced counts per Noise stratum and per Ringing stratum (about 20–30% each). An image may be `noise=severe` and `ringing=clean` (and vice versa). Include distractors that tempt confusion (heavy texture, JPEG blocking, sharp natural edges).

### 3.3 Inclusion / exclusion

**Include:** real ACCESS-like documentation photos (events, venues, members in context), consumer phone or camera JPEGs, varied lighting.

**Exclude:** the frozen 30 pilot IDs; images previously used to tune Noise/Ringing estimators; synthetic ladders used only for unit tests; images with unreadable subjects for reasons unrelated to Noise/Ringing if they prevent judgment (mark replace).

### 3.4 Blinding file layout

- Copy files to a rating pack named only by `media_id` (e.g. `NRV-017.jpg`).
- Keep the authoritative mapping in `noise_ringing_image_manifest.csv` (facilitator only).
- Raters receive: images + `NOISE_RINGING_RUBRIC.md` + blank rating CSV. No stratum column.

---

## 4. Rater calibration (required; separate examples)

Complete before any validation rating. Calibration images are **not** validation images.

1. Facilitator and raters read `NOISE_RINGING_RUBRIC.md`, especially the confusion matrix.
2. **Group walkthrough (discussion allowed):** 8–10 calibration images spanning clean→severe for both constructs, plus known confusers (texture, blocking, sharp edges).
3. **Independent practice:** 6 held-out calibration images; each rater fills `noise_ringing_calibration_rating_template.csv`.
4. Facilitator computes pairwise within-1 and off-by-≥2 rates for Noise and Ringing only.
5. **Pass rule for calibration:** for each criterion, mean pairwise within-1 ≥ **0.80** on the 6 images, and no rater has off-by-≥2 on more than 2 of 6 images. If fail: one remediation discussion + one re-rate of the same 6. If still fail: stop and revise rubric examples before building the validation wave.
6. Log completion in `noise_ringing_calibration_log.csv` (rater_id, dates, pack id, pass/fail). Do not commit invented scores.

---

## 5. Independent rating process (validation wave)

1. Three raters minimum (`R1`, `R2`, `R3`).
2. One row per `(media_id, rater_id)`.
3. Required: `noise`, `ringing_artifacts` ∈ {1,2,3,4,5,N/A}.
4. Work independently. No score discussion until all sheets are submitted.
5. Target 2–4 minutes per photo (fit + 100% passes).
6. Save under e.g. `workspace/noise_ringing_validation/ratings/` (create when launching; not required for this prep package).

---

## 6. Consistency checks (before unblinding machines)

1. Schema and allowed values.
2. Completeness: every `media_id` has three raters.
3. Unique `(media_id, rater_id)`.
4. Straight-lining flag: same integer on Noise and Ringing for >30% of a rater’s rows → review.
5. Disagreement flag: `max − min ≥ 3` on a criterion → optional adjudicator rating stored separately.

Primary consensus = **median of R1,R2,R3** (same convention as `analyze_human_pilot_validation.py`).

---

## 7. Human reliability gate (must pass before machine headline)

See `ACCEPTANCE_CRITERIA.md` §1. If IRR gates fail, **stop**. Do not interpret frozen detector Spearman as success or failure; fix rubric/calibration and only then consider a new disjoint set.

---

## 8. Machine comparison pass (only after §7 pass)

1. Freeze human consensus CSV.
2. Run **existing** estimators read-only (no threshold edits). Candidate list is fixed in acceptance criteria.
3. Join on `media_id`.
4. Report Spearman, MAE, bias, within-1, badge histograms, false-harsh counts.
5. Apply pre-registered acceptance criteria (§2–3). Record a single decision: promote-for-further-review / keep-unvalidated / abandon-candidate.
6. **Do not** retune on this set after seeing results. A failed candidate stays failed for this wave.

---

## 9. What this protocol deliberately does not do

- No new detector versions.
- No production, Flutter, or sandbox scoring changes.
- No use of quality scores as member skill grades.
- No silent expansion of n after peeking at correlations.
