# Phase 2: Hybrid NR-IQA Shadow Scoring

**Status:** implemented, **disabled by default** (`QUALITY_SHADOW_ENABLED=false`).  
**Not production-validated.** Phase 1 pilot rank gains do **not** authorize describing the hybrid as more accurate in production.

## Architecture summary

```
Upload / deferred media-eval worker
        │
        ▼
 media_pipeline.run_pipeline  ──► EfficientNet / OpenCV production scores
        │                         XP, feedback, criteria_json, DB rows (unchanged)
        │
        └─ maybe_schedule_quality_shadow()   # no-op if flag false
                    │
                    ▼ (dedicated ThreadPoolExecutor: quality-shadow)
           classical OpenCV/NumPy criteria (Phase 1 maps)
           + optional MUSIQ OPQ (lazy TF Hub; else status=unavailable)
                    │
                    ▼
           research_logs/quality_shadow/*.jsonl (+ CSV mirror)
```

| Concern | Behavior |
|---------|----------|
| Feature flag | `QUALITY_SHADOW_ENABLED` (default `false`) |
| Production scores / badges / feedback / XP / rankings / DB eval rows | Untouched |
| MUSIQ vs criteria | Separate fields; never pass MUSIQ through `_soft_score` |
| Cached Phase 1 MUSIQ CSV | **Not** used for new uploads |
| TF / MUSIQ missing | Log `musiq_status=unavailable` / `status=partial` |
| Videos | Skipped (`is_photo=False`) |
| Trusted preview save | `run_pipeline` may receive empty `file_bytes`; shadow worker reloads from upload cache / storage |
| Schedule timing | Right after `create_evaluation` + `create_ai_result` (before XP/notify) |
| Preview `POST /evaluate` | Never triggers shadow (does not call `run_pipeline`) |
| DB migration | None |
| Production env | `QUALITY_SHADOW_ENABLED=true` **refused** when `APP_ENV=production` |

## Files created / modified

| Path | Change |
|------|--------|
| `app/services/quality_shadow/` | New package: classical, musiq_opq, scoring, logging_store, worker |
| `app/services/media_pipeline.py` | Fire-and-forget schedule after successful eval create |
| `app/config.py` | Shadow settings + production refuse validator |
| `.env.example` | Documented flag (default false) |
| `tests/test_quality_shadow_scoring.py` | Automated isolation tests |
| `docs/PHASE2_QUALITY_SHADOW_SCORING.md` | This doc |
| `docs/samples/SAMPLE_quality_shadow.jsonl` | Anonymized sample line |
| `.gitignore` | `access_backend/research_logs/` |

## Sample anonymized shadow log

See `docs/samples/SAMPLE_quality_shadow.jsonl`. Fields include evaluation id, HMAC media anon id, engine versions, MUSIQ raw + scale, classical raw/q/equal-bin badges, durations, status/error. No bytes, URLs, names, or EXIF.

## Retention and access

- Directory: `QUALITY_SHADOW_LOG_DIR` (default `research_logs/quality_shadow`).
- Target retention: `QUALITY_SHADOW_RETENTION_DAYS` (default 90). Ops prune older files.
- Restrict filesystem ACLs to research/ops accounts. Do not commit live logs.
- Anonymization: HMAC-SHA256(`media:{id}`, salt=`QUALITY_SHADOW_ANON_SALT` or JWT secret).

## CPU / RAM / latency

| Item | Note |
|------|------|
| Flag off | Zero extra model load; schedule returns immediately; no TF import |
| Flag on, classical | OpenCV only; typically tens of ms on 1024 px cap; shares OpenCV already in prod |
| Flag on, MUSIQ | Optional; TensorFlow SavedModel is heavy (hundreds of MB RAM). Lazy-loaded once on first shadow job. Keep `QUALITY_SHADOW_MAX_WORKERS=1` |
| Request path | Schedule copies bytes and `submit()` only; tests assert caller not blocked by shadow work |
| Primary eval workers | Separate executor (`quality-shadow-*`) so media-eval pool is not shared |

Do not enable on memory-constrained hosts that already run PROBE + WaveRep until RAM is reviewed.

## Rollback procedure

1. Set `QUALITY_SHADOW_ENABLED=false` (or remove the var).
2. Restart the API process (`python manage.py runserver` / service restart).
3. Optionally delete or archive `research_logs/quality_shadow/`.
4. No DB rollback required (no migration).
5. Production EfficientNet path is unchanged throughout.

## Test results

```text
pytest tests/test_quality_shadow_scoring.py -q
13 passed
```

Coverage includes: flag off (no schedule / no MUSIQ load), successful classical+MUSIQ stub, MUSIQ unavailable, classical failure, production payload immutability, no XP/feedback calls, schedule non-blocking, video skip, log hygiene, soft_score not applied to MUSIQ.

## Remaining blockers before independent validation / production migration

1. Live official TF Hub MUSIQ install in the target runtime (not present in default `requirements.txt`).
2. Legal/product sign-off on TF Hub Apache weights vs training-data / GCS npz limitations.
3. Larger ACCESS-native holdout **disjoint** from the 30-image Phase 1 pilot; absolute 1–5 calibration still unvalidated.
4. Independent human ratings for color balance / saturation (pilot lacked those columns).
5. Sharpness/Blur axis duplication (Phase 9) still not resolved for product UX.
6. Shadow vs production badge MAE / calibration study before any dual-read UI.
7. Explicit ops approval; keep flag false until then. **Do not** claim hybrid superiority from Phase 1 alone.

## Enabling in a research/dev environment (not production)

```bash
# .env (APP_ENV must not be production)
QUALITY_SHADOW_ENABLED=true
QUALITY_SHADOW_MAX_WORKERS=1
QUALITY_SHADOW_ANON_SALT=<random-secret>
# Optional: pip install tensorflow-cpu tensorflow-hub in a controlled venv
```

Restart backend. Confirm JSONL lines appear under `research_logs/quality_shadow/` after a practice **photo** evaluation. Member UI scores must match pre-enable behavior.
