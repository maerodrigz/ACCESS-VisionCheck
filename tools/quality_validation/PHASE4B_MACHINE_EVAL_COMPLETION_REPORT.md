# Phase 4B: Machine Evaluation Completion Report

**Status:** machine-side preparation **complete**. Independent validation is **not** complete until human sheets are filed.  
**Freeze id:** `phase4a_freeze_20261113`  
**Generated:** 2026-11-13 (local run)  
**Production:** EfficientNet serving, PROBE, WaveRep, XP, UI, DB, and `QUALITY_SHADOW_ENABLED` were **not** changed (shadow remains false).

## 1. Image count and integrity

| Check | Result |
|-------|--------|
| Manifest n | 100 |
| Unique `indval_id` / `source_media_key` | 100 / 100 |
| Files exist on disk | 100 / 100 |
| SHA-256 matches manifest | 100 / 100 |
| Overlap with human pilot | **none** |
| Overlap with SPAQ-200 | **none** |
| Duplicate keys / hashes | **none** |

Evidence: `workspace/phase4a_indval/phase4b_integrity_precheck.json`

## 2. Machine evaluation results

Output directory: `tools/quality_validation/workspace/phase4a_indval/machine_output/`

| Artifact | Status |
|----------|--------|
| `machine_scores.csv` | **100 unique rows** |
| Hybrid core q (sharpness, blur, brightness, contrast, blocking) | **100/100 complete** |
| Hybrid equal-bin badges | **100/100 complete** |
| Experimental feedback observations | **700 rows** (7 criteria × 100); blur often `suppressed_duplicate` |
| EfficientNet-B0 baseline (`enet_status=ok`) | **100/100** |
| ENET core technical criteria | **100/100** |
| ENET Color Balance blank (N/A heuristic) | 5 images |
| ENET Color Saturation blank (N/A heuristic) | 3 images |
| Cached MUSIQ CSV used for holdout | **false** |

Hybrid `status=partial` on all 100 because MUSIQ OPQ is unavailable (classical + feedback still complete).

### MUSIQ inference status

| Item | Value |
|------|--------|
| Live TF Hub / TensorFlow runtime | **Unavailable** in backend venv and Phase 1 TF research venv (`tensorflow` not importable) |
| Live MUSIQ scores | **0 / 100** |
| `musiq_status` | `unavailable` for all 100 |
| Historical `musiq_paq2piq_benchmark` CSV substituted | **No** |

To retry live MUSIQ later (research host only): use `run_phase4b_live_musiq.py` with `.venv_musiq_phase4b` (writes a separate `musiq_live_*` folder; does not overwrite `machine_scores.csv`). **2026-11-13 restore:** TF 2.21.0 + hub installed, but Windows Smart App Control / Code Integrity blocked `_dtypes.pyd` (WinError 4551). See `PHASE4B_MUSIQ_LIVE_RESTORE_REPORT.md`.

### Research evaluator note (non-production)

`real_world_evaluate.py` was updated to accept current production photo criteria (Color Balance/Saturation instead of Noise/Ringing) and to allow color N/A. This is research tooling only; production `media_evaluator` was not modified.

## 3. Human evaluation packs (R1 / R2 / R3)

Root: `tools/quality_validation/workspace/phase4a_indval/human_packs/`

| Path | Contents |
|------|----------|
| `images/` | **100** blinded `INDVAL-*.jpg` copies |
| `image_quality_ratings_R1.csv` … `_R3.csv` | Image-quality 1–5 sheets (**empty scores**) |
| `issue_labels_R1.csv` … `_R3.csv` | Independent Y/N issue labels (**empty**) |
| `feedback_quality_ratings_R1.csv` … `_R3.csv` | Feedback-quality Likert; system observations prefilled from machine feedback where present; **human Likert empty** |
| `INSTRUCTIONS.md` | Rater protocol |
| `HUMAN_RATING_RUBRIC.md` | Image-quality anchors |

**Blinding:** `machine_scores.csv`, `facilitator_mapping.csv`, and ENET/hybrid numeric tables are **not** inside `human_packs/`. Raters must not open `machine_output/` or `facilitator_mapping.csv` while doing image-quality or issue labeling. Feedback evaluation is a **separate** task using the feedback sheets only.

## 4. Missing data / execution errors

| Item | Detail |
|------|--------|
| MUSIQ | Unavailable for all 100 (runtime missing) |
| ENET color N/A | Up to 5 Color Balance / 3 Color Saturation blanks (heuristic unavailable, not crashes) |
| Human ratings | Intentionally empty; not fabricated |
| Final statistics | **Not run** (gated until humans submit) |

## 5. Exact instructions for collecting completed human sheets

1. Give each rater only: `human_packs/images/`, their three CSVs (`image_quality_ratings_R*`, `issue_labels_R*`, `feedback_quality_ratings_R*`), `INSTRUCTIONS.md`, and `HUMAN_RATING_RUBRIC.md`.
2. **Task order (recommended):**  
   a. Complete **image_quality_ratings** for all INDVAL images (integers 1–5 or N/A).  
   b. Complete **issue_labels** (Y/N) without looking at system feedback text if possible, or at least without machine numeric scores.  
   c. Separately complete **feedback_quality_ratings** Likert columns (correctness, relevance, clarity, usefulness). Do not change image-quality scores during this task.
3. Raters must not receive `machine_output/`, `facilitator_mapping.csv`, or freeze comparison tables until after image-quality + issue sheets are submitted.
4. Collect the nine completed CSVs back into `human_packs/` (overwrite empty templates).
5. Only then run:  
   `python analyze_phase4a_results.py`  
   (Do **not** use `--allow-empty` for the real report.)
6. Do not claim independent validation complete until step 5 succeeds with filled sheets.

## 6. Claim boundary

Phase 4B prepared machine scores and empty human packs. **Independent validation is not complete.** No accuracy, superiority, or production-readiness claim is authorized from this report alone.
