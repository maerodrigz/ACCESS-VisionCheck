# Phase 7I — Controlled local MUSIQ + OpenCV cutover

- Local cutover activated: **True**
- Actual active quality engine: **musiq_worker**
- `production_uses_enet`: **False**
- `.env` backup retained: **True**
- EfficientNet weights retained: **True**
- Production/cloud deploy: **False**
- Report complete: **True**

## Smoke tests

- Photo HTTP: **PASS**
- Video HTTP: **PASS**
- Worker-offline fallback: **PASS**
- Rollback availability: **PASS**

## Gates

- `loaded_engine_is_musiq_worker`: **True**
- `production_uses_enet_false`: **True**
- `worker_ready`: **True**
- `photo_http_musiq_ok`: **True**
- `video_http_musiq_ok`: **True**
- `offline_opencv_fallback_ok`: **True**
- `enet_not_used_on_musiq_path`: **True**
- `enet_weights_retained`: **True**
- `vectorized_blocking`: **True**
- `preview_defers_auth_and_xp`: **True**

## Blockers

- None

## Changed files

- `access_backend/.env (QUALITY_ENGINE + missing MUSIQ_WORKER_* if needed)`
- `access_backend/phase7i_local_cutover/env_backups/.env.pre_phase7i_*`
- `access_backend/scripts/apply_phase7i_local_cutover_env.py`
- `access_backend/scripts/verify_phase7i_local_cutover.py`
- `access_backend/scripts/run_phase7i_local_cutover.bat`
- `access_backend/phase7i_local_cutover/PHASE7I_REPORT.md`

## Rollback

```bat
cd /d C:\Users\Dell\Desktop\access_mobile\access_backend
python scripts\apply_phase7i_local_cutover_env.py --restore
REM Stop the current FastAPI process, then:
python manage.py runserver
```

## Architecture

1. Primary: MUSIQ PaQ-2-PiQ + classical OpenCV (`musiq_worker`)
2. Fallback: optimized local OpenCV (vectorized blocking)
3. EfficientNet-B0 inactive on this path; weights retained for `QUALITY_ENGINE=enet`
4. PROBE/WaveRep authenticity unchanged (preview remains deferred)
