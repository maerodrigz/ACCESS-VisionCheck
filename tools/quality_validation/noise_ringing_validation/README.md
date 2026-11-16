# Noise and Ringing — final validation preparation pack

Finite, scientifically defensible **preparation** for independent human validation of Noise and Ringing Artifacts.

**This pack does not** modify production, Flutter, EfficientNet weights, sandbox scoring, or research detectors.  
**This pack does not** run SPAQ-200, the frozen 30-image pilot, or any new machine evaluation.

---

## Why this exists

Frozen pilot evidence showed:

- Weak human ordinal agreement on Noise and Ringing (near-chance κ / low QWK).
- Negative or null machine rank agreement; Noise v4 and Ringing v3/v4 **REGRESSED**.

Further detector experiments on that same pilot are frozen. The next step is a **new disjoint labeled set** with a clearer rubric and **pre-registered** gates.

Details: `00_EVIDENCE_SUMMARY.md`

---

## Deliverables in this folder

| File | Contents |
|------|----------|
| `NOISE_RINGING_RUBRIC.md` | 1–5 visual definitions, strata guidance, confusion matrix (grain vs chroma vs texture vs blocking vs ringing) |
| `INDEPENDENT_VALIDATION_PROTOCOL.md` | Unseen-photo protocol, calibration, blinding, analysis order |
| `ACCEPTANCE_CRITERIA.md` | Pre-registered human IRR + machine gates (lock before launch) |
| `EXECUTION_CHECKLIST.md` | Short runbook |
| `templates/noise_ringing_human_rating_template.csv` | Independent human rating sheet (schema-compatible extras as `N/A`) |
| `templates/noise_ringing_image_manifest.example.csv` | Manifest with split + severity strata |
| `templates/noise_ringing_calibration_rating_template.csv` | Calibration-only ratings |
| `templates/noise_ringing_calibration_log.example.csv` | Calibration pass/fail log |

---

## Reuse existing analyzers (after real ratings exist)

- `../analyze_human_pilot_validation.py` — consensus + inter-rater tables
- `../real_world_analyze.py` — optional join path for broader real-world packs
- Column names align with `../templates/human_rating_access_criteria.csv` (`noise`, `ringing_artifacts`, …)

Do not invent scores solely to exercise those scripts.

---

## Acceptance snapshot (locked text in `ACCEPTANCE_CRITERIA.md`)

1. **Human first:** within-1 ≥ 0.85 and QWK ≥ 0.40 for Noise and for Ringing (plus coverage / disagreement caps).
2. **Then machines (frozen only):** Spearman ≥ 0.30 with non-null dispersion; MAE ≤ 1.0; within-1 ≥ 0.75; false-harsh ≤ 10%; no fitting on this set.
3. **One decision** — no retune loop on the same images.

---

## Preliminary 15-image collection (2026-11-09)

| Item | Path |
|------|------|
| Images | `images/NR001.jpg` … `NR015.jpg` (**15/15 ready**) |
| Manifest | `noise_ringing_image_manifest.csv` |
| Facilitator notes (hidden from raters) | `facilitator/collection_notes.csv` |
| Blank rating sheets | `ratings/R1_noise_ringing_ratings.csv` (and R2, R3) |
| Evaluator instructions | `HUMAN_EVALUATION_INSTRUCTIONS.md` |
| Offline evaluation UI | `eval_web/` → http://127.0.0.1:8766/eval_web/ |
| Integrity checker | `check_collection_integrity.py` |
| Status report | `COLLECTION_STATUS_REPORT.md` |
| Commons collector | `collect_open_license_images.py` |

Status: integrity checks **passed**. Human ratings and machine comparison are **not** started.

## Launch posture

Follow `EXECUTION_CHECKLIST.md` (calibration → blind human ratings → IRR gates → only then frozen machine compare).  
Do not retune detectors on this set. Do not claim validation from the collection alone.
