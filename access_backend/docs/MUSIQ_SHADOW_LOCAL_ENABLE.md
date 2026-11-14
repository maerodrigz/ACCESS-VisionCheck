# Enable MUSIQ worker shadow mode locally

Production quality stays **EfficientNet-B0** (`QUALITY_ENGINE=enet`).  
Shadow calls the Docker MUSIQ worker asynchronously and writes research logs only.

## Prerequisites

1. MUSIQ worker healthy: `GET http://127.0.0.1:8080/ready` → `musiq_ready: true`
2. Compose default token (unless you set a custom secret): `dev-local-musiq-token`

## Backend `.env` (gitignored)

```env
APP_ENV=development
QUALITY_ENGINE=enet
QUALITY_SHADOW_ENABLED=true
MUSIQ_WORKER_URL=http://127.0.0.1:8080
MUSIQ_WORKER_TOKEN=dev-local-musiq-token
MUSIQ_WORKER_TIMEOUT_SEC=90
MUSIQ_WORKER_TLS_VERIFY=false
MUSIQ_WORKER_PREFER_REMOTE=true
QUALITY_SHADOW_LOG_DIR=research_logs/quality_shadow
```

Restart FastAPI after editing `.env`.

## Verify

```powershell
cd access_backend
python scripts/verify_musiq_shadow_live.py
```

Expect:

- `production_uses_enet: true`
- `quality_engine: enet`
- shadow record `musiq_status: ok` with finite `musiq_opq_raw`
- `musiq_source: musiq_worker`
- `criteria_q` present
- `production_payload_mutated: false`
- log line under `research_logs/quality_shadow/quality_shadow_YYYYMMDD.jsonl`

Member/admin UI and XP paths are unchanged. Experimental feedback stays in research logs only.
