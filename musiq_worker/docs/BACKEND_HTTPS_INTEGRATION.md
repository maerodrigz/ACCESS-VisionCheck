# Local FastAPI ↔ remote MUSIQ worker (HTTPS)

Architecture: **Windows/local FastAPI** keeps serving members; **Linux Fly worker** runs MUSIQ + OpenCV.  
`QUALITY_ENGINE=enet` stays the production quality path until you explicitly cut over later.

## 1. Backend `.env` (local machine only)

Edit `access_backend/.env` (gitignored). Do **not** commit tokens.

```env
QUALITY_ENGINE=enet
MUSIQ_WORKER_URL=https://access-musiq-worker.fly.dev
MUSIQ_WORKER_TOKEN=<same value as Fly secret>
MUSIQ_WORKER_TIMEOUT_SEC=90
MUSIQ_WORKER_TLS_VERIFY=true
MUSIQ_WORKER_PREFER_REMOTE=true
QUALITY_SHADOW_ENABLED=false
```

Restart the FastAPI process after changing env (`python manage.py runserver` or your usual command).

## 2. Confirm production path unchanged

```powershell
cd access_backend
python -c "from app.config import settings; from app.services.musiq_worker_client import production_uses_enet, quality_engine; print(settings.quality_engine, production_uses_enet(), quality_engine())"
```

Expected: `enet True enet`

Member evaluations, XP, feedback text, and AI detection still come from the existing EfficientNet / PROBE pipeline.

## 3. Real client smoke (after `/ready` is green)

Prefer putting URL/token in gitignored `access_backend/.env`, restart the API, then:

```powershell
cd access_backend
python -c "from pathlib import Path; from app.services.musiq_worker_client import readiness_check, evaluate_bytes, production_uses_enet; print(production_uses_enet(), readiness_check()); p=Path(r'PATH\to\sample.jpg'); o=evaluate_bytes(p.read_bytes(), filename=p.name); m=o.get('musiq') or {}; print(o.get('status'), m.get('musiq_opq_raw'), o.get('duration_ms'), o.get('error'))"
```

Or use the worker-side verifier (httpx only):

```powershell
$env:MUSIQ_WORKER_URL="https://access-musiq-worker.fly.dev"
$env:MUSIQ_WORKER_TOKEN="<token>"
python musiq_worker\scripts\verify_remote_worker.py --image PATH\to\sample.jpg
```

Offline/timeout → `status=unavailable` and `musiq_opq_raw=null` (no invented scores).

## 4. curl equivalents

```bash
curl -sS https://APP/ready
curl -sS -H "Authorization: Bearer TOKEN" \
  -F media_type=photo -F file=@sample.jpg \
  https://APP/v1/evaluate
```

## 5. Optional shadow logging (non-prod only)

Only if you intentionally want research JSONL with remote MUSIQ:

```env
QUALITY_SHADOW_ENABLED=true
APP_ENV=development
```

Forbidden when `APP_ENV=production`. Keep false for normal staging member traffic.

## 6. Failure modes

| Symptom | Action |
|---------|--------|
| `/ready` 503 | Wait for model load; check Fly logs `fly logs -a access-musiq-worker` |
| Client `worker_timeout` | Raise `MUSIQ_WORKER_TIMEOUT_SEC`; confirm machine not auto-stopped mid-load |
| `401` | Token mismatch between Fly secret and backend `.env` |
| TLS errors | Keep `MUSIQ_WORKER_TLS_VERIFY=true`; fix system CA store; do not disable in prod |
