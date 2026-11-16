# ACCESS VisionCheck — Final Media Quality Implementation Report

**Date:** 2026-11-09  
**Scope:** Replace active photo presentation of Noise / Ringing Artifacts with heuristic Color Balance / Color Saturation; keep production EfficientNet-B0 (or OpenCV fallback) for the first five criteria.  
**Not in scope:** Model training, classical v2/v3 promotion, locked NR/pilot tuning, AI authenticity changes, auto-deploy.

**Follow-up (same day):** EfficientNet-B0 quality development is **FROZEN**. See `tools/quality_validation/EFFICIENTNET_B0_FROZEN_STATUS.md`.

---

## Phase 1 — Audit summary

| Area | Finding |
|------|---------|
| Production quality path | `access_backend/app/services/media_evaluator.py` → EfficientNet-B0 (`efficientnet_b0_scorer`) with OpenCV fallback; FFmpeg frames for video. |
| Experimental classical | `experimental_classical_v2` / Blocking v3 live under research tools only. **Not** wired into production `evaluate_photo`. |
| Noise / Ringing evidence | Frozen validation: **KEEP UNVALIDATED / NO-GO**. Five-criteria audit: production ENET heads **FAILED VALIDATION** on pilot evidence; classical **PROMISING BUT UNVALIDATED**. |
| Flutter results | `photo_evaluation_result.dart` + `media_evaluation_ui.dart` / `criterion_score_bar.dart` / evaluation detail sheet. |
| Aggregation | Mean of scored 1–5 criteria → `overall_score`; `legacy.*` columns for DB. |
| History | `criteria_json` + `media_evaluations.noise_score` (inverted polarity historically). |
| Photo/video share | Same `_photo_criteria` for both; video adds Flickering + Motion Stability only. |

**Decision retained:** Do not promote classical v2/v3. Keep ENET/OpenCV for Sharpness, Blur, Brightness, Contrast, Blocking Artifacts. Add explainable OpenCV heuristics only for Color Balance and Color Saturation.

---

## 1. Files changed

### Backend
- `access_backend/app/services/color_quality_criteria.py` (**new**)
- `access_backend/app/services/media_evaluator.py`
- `access_backend/app/services/quality_score_display.py`
- `access_backend/app/services/image_quality.py` (`legacy_scores_from_payload` Noise optional)
- `access_backend/tests/test_color_quality_criteria.py` (**new**)
- `access_backend/tests/test_media_quality_eval_correctness.py`
- `access_backend/tests/test_supplementary_quality_insights.py`
- `access_backend/tests/test_media_evaluate_preview_step7c.py`
- `access_backend/tests/test_quality_preview_save_path.py`
- `access_backend/tests/test_preview_metadata_waverep_bypass.py`

### Flutter
- `lib/shared/models/photo_evaluation_result.dart`
- `lib/mobile_app/widgets/media_evaluation_ui.dart`
- `lib/mobile_app/widgets/criterion_score_bar.dart`
- `lib/mobile_app/widgets/evaluation_criterion_meta.dart`
- `lib/mobile_app/widgets/eval_ai_processing_view.dart`
- `lib/mobile_app/sheets/evaluation_detail_sheet.dart`
- `lib/shared/controllers/app_state.dart`

### Docs
- `MEDIA_QUALITY_FINAL_IMPLEMENTATION_REPORT.md` (this file)

**Unchanged (intentionally):** EfficientNet weights, AI authenticity / PROBE / WaveRep, classical research detectors, locked validation datasets, admin-web Noise **DB column** mapping (legacy field).

---

## 2. Existing detectors retained

| Criterion | Engine |
|-----------|--------|
| Sharpness | Production EfficientNet-B0 head → `_soft_score` (OpenCV fallback if ENET unavailable) |
| Blur | Same (`1 - blur` then soft score) |
| Brightness | Same (`_brightness_metric` triangle remap) |
| Contrast | Same |
| Blocking Artifacts | Same (`1 - blocking_artifacts`) |
| Flickering / Motion Stability (video) | Unchanged frame-delta heuristics |

Experimental Classical v2 / Blocking v3 remain research-only.

---

## 3. New algorithms and measurements

### Color Balance (`analyze_color_balance_criterion_bgr`)
- Convert BGR → LAB; measure mean `a*` / `b*` deviation from 128 (cast magnitude `hypot(a_dev, b_dev)`).
- RGB R−G imbalance + warmish flag softens strong warm casts slightly (heuristic; sunsets / tungsten).
- HSV mean saturation and LAB luma gates: monochrome / extreme dark or bright → **`available: false` (N/A)**.

### Color Saturation (`analyze_color_saturation_criterion_bgr`)
- HSV S mean and P90; chroma pixel fraction.
- Grayscale / near-mono → N/A (not scored as a defect).
- High mean + clipped bright P90 → lower estimated score; muted mid-range → mid score; typical band → higher estimate.
- High saturation is **not** automatically treated as failure without extreme clipping signals.

Both criteria set `estimate_kind: "heuristic_experimental"`.

---

## 4. Scoring assumptions and limitations

| Item | Status |
|------|--------|
| Thresholds (`_CAST_*`, `_SAT_*`, mono/luma gates) | **Heuristic / experimental.** Documented in source comments. **Not** human-validated. **Not** tuned on locked NR15 or pilot-30. |
| 1–5 outputs | Estimated presentation scores only. |
| N/A cases | Prefer unavailable over invented confidence (mono, extreme luma, decode failure). |
| Overall score | Mean of **available** scored criteria only (N/A excluded). |
| Artistic intent | Explicitly not modeled; disclaimer required in UI/API. |
| Skill / competency | These seven scores must **not** be treated as validated photographer skill ratings. |
| ENET Noise / Ringing heads | Still computed internally when ENET runs; Noise metric still feeds `legacy.noise_score` for DB continuity. **Not** shown in new active criteria list. |

---

## 5. Backend changes

- Active `_PHOTO_CRITERION_NAMES`: Sharpness, Blur, Brightness, Contrast, Blocking Artifacts, Color Balance, Color Saturation.
- `_LEGACY_PHOTO_CRITERION_NAMES` retained for historical readability helpers.
- `SCORING_ENGINE` → `efficientnet-b0+ffmpeg+color-heuristics` (OpenCV path: `opencv+color-heuristics`).
- Payload adds `quality_disclaimer`, `analysis.color_heuristics: true`.
- `preview_quality_complete` requires the new seven names (old Noise/Ringing-only previews re-evaluate).
- Display helpers skip `available: false`; historical Noise/Ringing rows still render when present in old `criteria_json`.
- Auth / integrity / authenticity paths unchanged (`include_authenticity`, PROBE policy untouched).

---

## 6. Flutter UI changes

- Photo/video criterion order prefers Color Balance / Color Saturation; Noise / Ringing only if present on older payloads.
- `CriterionScore.available` drives N/A chips and bar UI (stacked + horizontal).
- Results panel / detail sheet: section title **TECHNICAL QUALITY** + disclaimer:  
  *Quality ratings are automated estimates and may not reflect artistic intent or human judgment.*
- Processing stages and criterion meta updated for the new pair.
- AI authenticity remains a separate block (integrity / PROBE UI unchanged).

---

## 7. Test results

Automated (backend):

```text
pytest tests/test_color_quality_criteria.py \
       tests/test_media_quality_eval_correctness.py \
       tests/test_supplementary_quality_insights.py \
       tests/test_media_evaluate_preview_step7c.py \
       tests/test_quality_preview_save_path.py \
       tests/test_preview_metadata_waverep_bypass.py -q
→ 57 passed
```

Functional synthetic cases covered in `test_color_quality_criteria.py`:

1. Daylight-ish / neutral color  
2. Warm sunset-like cast  
3. Low light  
4. Overexposed  
5. Oversaturated  
6. Desaturated / muted  
7. Grayscale  
8. Blurry JPEG  
9. Heavily compressed JPEG  
10. Invalid bytes  

Plus evaluate_photo seven-name order (no Noise/Ringing) and evaluate_video Flickering + Motion Stability retention.

These tests establish **functionality**, not perceptual accuracy.

---

## 8. Remaining issues

- Heuristic thresholds are experimental; no claim of photographer-grade accuracy.
- Admin-web still surfaces legacy **Noise** DB percent from `noise_score` / historical display helpers; full admin criteria cards for Color Balance/Saturation were not redesigned in this pass (member Flutter is primary).
- Unused client stub `lib/shared/services/efficientnet_scoring_service.dart` still lists Noise/Ringing if ever revived; production scoring is server-side.
- Old cached preview metadata with Noise/Ringing names will fail `preview_quality_complete` and re-run evaluation (intended migration behavior).
- Physical-device Flutter screenshot pass not run in this session.

---

## 9. Did production behavior change?

**Yes (photo quality presentation and aggregation inputs).**

- New uploads/evaluations expose Color Balance + Color Saturation instead of Noise + Ringing Artifacts in `criteria`.
- Overall mean excludes N/A color criteria and no longer includes Noise/Ringing presentation scores.
- `legacy.noise_score` may still be written from the ENET/OpenCV noise metric for DB compatibility.
- Historical `criteria_json` with Noise/Ringing remains readable.
- AI authenticity detection: **unchanged**.
- Video-only Flickering / Motion Stability: **unchanged**.
- EfficientNet weights: **unchanged**.
- **Not deployed** by this task (restart backend + rebuild/restart app required manually).

---

## 10. Exact manual verification steps

1. Restart backend: `cd access_backend` → `python manage.py runserver` (or your usual uvicorn entry).
2. Confirm `GET /api/health` returns 200.
3. Log in as a member on Flutter (emulator or device with correct `API_PUBLIC_HOST` / Set backend URL).
4. Upload a normal daylight photo for practice evaluation; open results.
5. Confirm seven technical criteria in order; **no** Noise / Ringing on a fresh result.
6. Confirm disclaimer under TECHNICAL QUALITY.
7. Confirm AI authenticity / integrity section remains separate.
8. Spot-check: warm sunset, low-light, B&W, oversaturated JPEGs → scores or N/A without crash.
9. Upload a short practice video → same seven + Flickering + Motion Stability; authenticity still runs.
10. Open an **old** evaluation that still has Noise/Ringing in JSON → historical rows still display; app does not crash.
11. Admin: open Media Integrity / evaluation detail for a new eval → confirm no API 500; note Noise DB column may still show legacy noise polarity.

---

## PASS / FAIL / NOT TESTED checklist

| Check | Result |
|-------|--------|
| Audit completed before implementation | **PASS** |
| Color Balance heuristic implemented (no training) | **PASS** |
| Color Saturation heuristic implemented (no training) | **PASS** |
| First five production detectors left as ENET/OpenCV | **PASS** |
| Classical v2/v3 not promoted | **PASS** |
| EfficientNet weights untouched | **PASS** |
| AI authenticity untouched | **PASS** |
| Video Flickering / Motion Stability retained | **PASS** (automated) |
| Historical Noise/Ringing readable in display order | **PASS** (code path) |
| Flutter seven-criterion order + N/A + disclaimer | **PASS** (code) |
| Backend structured payload + disclaimer | **PASS** (automated) |
| Functional synthetic image suite | **PASS** (57 related tests) |
| Locked datasets used for tuning | **PASS** (not used) |
| Production auto-deploy | **NOT TESTED / NOT DONE** (by design) |
| Physical device Flutter UI screenshots | **NOT TESTED** |
| End-to-end live upload against running server in this session | **NOT TESTED** |
| Admin-web Color Balance/Saturation redesign | **NOT TESTED** (deferred; legacy Noise column remains) |
| Perceptual accuracy / human agreement | **NOT TESTED** (out of scope) |

**Overall implementation gate:** **PASS** for functional integration. Manual device + live server smoke tests remain for the operator before treating the change as released.
