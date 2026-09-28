# ACCESS VisionCheck — AI Media Pipeline

Technical reference for capstone/demo deployment. This document describes the **integrated** quality + authenticity-risk pipeline validated in integration Steps 7A–8B. It is not a model benchmark report.

## 1. Purpose

Member practice evaluations combine:

- **Technical quality** (EfficientNet-B0 + OpenCV/FFmpeg support)
- **AI authenticity risk** (PROBE-DINOv2 when enabled via environment)
- **Narrative coaching** (Google Gemini on quality, not authenticity)
- **Integrity policy** (XP, review queues, admin alerts)

Preview is fast and **does not** run final authenticity. Save triggers a **deferred background worker** that runs the full pipeline once.

## 2. Quality evaluation

- **Engine:** EfficientNet-B0 heads (sharpness, blur, noise, brightness, contrast, artifacts).
- **Video:** FFmpeg (or OpenCV fallback) samples up to **6** frames; quality criteria are averaged across frames plus flicker/motion heuristics.
- **Scope:** Technical quality only. Quality scores are authoritative in preview and final save (preview metadata may skip re-running EfficientNet on save when integrity allows).

## 3. Authenticity-risk evaluation (PROBE)

- **Model:** PROBE-DINOv2 (when `AI_DETECTOR_BACKEND=probe`).
- **Resize:** Max long edge **1344 px** before tiling (`PROBE_MAX_LONG_EDGE`).
- **Output:** Raw **P(fake)** in \[0, 1\]. This is a **risk signal**, not proof of AI or human origin.
- **Default backend in code:** `univfd` (UnivFD). PROBE is enabled **only** via environment configuration for controlled staging/capstone.

**Risk bands (validated candidate thresholds, not universal calibration):**

| P(fake) | Risk level | Member/review posture |
|--------|------------|------------------------|
| &lt; 0.30 | low | Automated low risk; XP may apply if quality rules allow |
| 0.30 – 0.44 | suspicious | Review recommended; XP pending |
| ≥ 0.45 | high | Officer review; XP pending; admin alert when policy requires |

Environment keys: `PROBE_LOW_RISK_THRESHOLD`, `PROBE_HIGH_RISK_THRESHOLD`.

If PROBE is selected but the checkpoint is missing, corrupt, or inference fails, the backend **must not** treat the upload as low risk. Analysis fails into **suspicious / requires review** with an explicit detail message.

## 4. Preview flow (`POST /api/media/evaluate`)

1. Quality analysis runs on the request thread (offloaded with `asyncio.to_thread`).
2. **`include_authenticity=False`:** authenticity is **deferred** (`analysis_status: deferred`, `is_final: false`).
3. PROBE/UnivFD **not** invoked on preview.
4. Client may merge Gemini narrative before save.

## 5. Final save flow (`POST /api/media/upload`)

1. Upload returns immediately with `processing_status: processing` for member evaluations.
2. Background worker (`MAX_MEDIA_EVALUATION_WORKERS`, default **1**) runs `run_pipeline` with **`include_authenticity=True`**.
3. Deferred preview metadata **cannot** bypass final authenticity (`is_deferred_authenticity_preview` rejects fast-path reuse).
4. Full analysis: quality (or reused preview quality where allowed) + PROBE + integrity policy + DB persistence + XP + notifications.
5. Client polls `GET /api/media/{id}` until `processing_status: completed`.

## 6. Risk policy (PROBE)

Downstream fields (compatibility): `verdict`, `detection_result`, `review_status`, `requires_review`, `ai_probability` stored consistently with raw PROBE probability (no UnivFD fusion on PROBE path).

Admin AI alerts fire for PROBE when `requires_review` is true (suspicious/high), gated by system notification settings.

## 7. XP behavior

- **Low risk + authentic tier:** XP awarded from quality payload when eligible (`member_rankings.total_points`).
- **Suspicious / high:** XP pending or blocked until officer review outcome.
- Idempotent: repeated polls do not duplicate XP or evaluation rows.

## 8. Review / admin behavior

- Low risk: `automated_low_ai_risk`
- Suspicious: `needs_further_review`
- High: `pending_review`
- Officer actions use existing review workflow; member messaging explains provisional scores.

## 9. Video

- Supported formats via FFmpeg/OpenCV; practical cap **60 seconds** for member uploads (product rule).
- Quality: up to **6** extracted frames.
- Authenticity (PROBE): up to **5** frames sampled from extracted set; **max P(fake)** across sampled frames drives final risk (see `detect_ai_generated_from_frames`).
- **CPU latency** can be large (minutes) on long/high-resolution clips or many patches. One worker limits parallel eval load.

## 10. Gemini

- Optional narrative quality feedback (tips, explanations).
- **Not** an authenticity detector. Does not replace PROBE or integrity policy.

## 11. Known limitations

- Detectors can **miss** AI-generated media and produce **false positives**.
- Validation was limited (integration smoke: 2 photos in 8A, 1 photo + 1 short video in 8B); **do not overstate accuracy** from smoke tests.
- High CPU use; human review required for flagged content.
- **PROBE implementation and checkpoint licensing** must be reviewed before commercial or public deployment.

## 12. Runtime configuration (capstone / demo)

Set in process environment (or `.env` for local capstone only). **Do not** change the code default from `univfd`.

```env
AI_DETECTOR_BACKEND=probe
PROBE_MAX_LONG_EDGE=1344
PROBE_LOW_RISK_THRESHOLD=0.30
PROBE_HIGH_RISK_THRESHOLD=0.45
MAX_MEDIA_EVALUATION_WORKERS=1
```

Optional: `PROBE_CHECKPOINT_PATH` if checkpoint is not in the default experiments path.

Restart backend after changes. On startup, `python manage.py runserver` logs detector backend, worker count, and PROBE settings (non-secret).

## 13. Validated smoke tests (integration only)

| Step | Scope | Result summary |
|------|--------|----------------|
| **8A** | 1 REAL + 1 AI photo, PROBE staging env | Preview deferred; save-path PROBE; policy; idempotency; admin alert on high-risk AI image |
| **8B** | DB-backed XP + 1 short video | XP delta matched expected awards; video preview deferred; save-path PROBE on 5 frames; ~157 s processing; health stayed responsive |

These smokes validate **wiring**, not detector accuracy on a large dataset.

## Related code

- Preview: `app/api/routes/media.py` (`include_authenticity=False`)
- Evaluator: `app/services/media_evaluator.py`
- Deferred worker: `app/services/deferred_media_pipeline.py`
- PROBE: `app/services/probe_dino_detector.py`, `app/services/ai_authenticity_detector.py`
- Router: `app/services/dedicated_ai_detector.py`
