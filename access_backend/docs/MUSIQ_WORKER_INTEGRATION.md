# MUSIQ worker integration (backend)

Production scoring remains **EfficientNet-B0** (`QUALITY_ENGINE=enet`).

## Config

| Env | Default | Role |
|-----|---------|------|
| `QUALITY_ENGINE` | `enet` | Active production engine selector (ENET until cutover) |
| `MUSIQ_WORKER_URL` | empty | HTTPS base URL of Linux worker |
| `MUSIQ_WORKER_TOKEN` | empty | Shared bearer secret |
| `MUSIQ_WORKER_TIMEOUT_SEC` | `60` | Client timeout |
| `MUSIQ_WORKER_TLS_VERIFY` | `true` | Verify TLS certificates |
| `MUSIQ_WORKER_PREFER_REMOTE` | `true` | Shadow MUSIQ uses worker when configured |

## Client

`app/services/musiq_worker_client.py`

- `evaluate_bytes(...)` — full worker payload (classical + MUSIQ + feedback)
- `health_check` / `readiness_check`
- Timeouts/offline → `status=unavailable`, **no invented scores**
- `production_uses_enet()` is **True** in this release even if `QUALITY_ENGINE=musiq_worker`

## Shadow path

When URL+token are set, `quality_shadow.musiq_opq.score_image_bytes_musiq` prefers the remote worker, then optional local TF. Keep `QUALITY_SHADOW_ENABLED=false` in production.

## Worker package

See:

- `musiq_worker/README.md`
- `musiq_worker/docs/CLOUD_DEPLOYMENT.md` (Fly.io remote deploy, no local Docker)
- `musiq_worker/docs/BACKEND_HTTPS_INTEGRATION.md`
- `musiq_worker/docs/DEPLOYMENT_READINESS.md`
- `musiq_worker/docs/LICENSE_NOTES.md`
