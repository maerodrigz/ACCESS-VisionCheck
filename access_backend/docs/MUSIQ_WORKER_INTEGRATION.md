# MUSIQ worker integration (backend)

Production `.env` default remains **`QUALITY_ENGINE=enet`** until an explicit cutover.

## Phase 7G target architecture (when `QUALITY_ENGINE=musiq_worker`)

| Role | Engine |
|------|--------|
| Primary | MUSIQ Docker worker (classical OpenCV criteria + MUSIQ OPQ context) |
| Fallback | Optimized local OpenCV (`USE_VECTORIZED_BLOCKING`) |
| Inactive | EfficientNet-B0 (weights retained for rollback) |

**Rollback:** set `QUALITY_ENGINE=enet` and restart FastAPI (do not delete `ml/efficientnet_b0_heads.pt`).

Do **not** flip `.env` to `musiq_worker` until Phase 7G verification reports `cutover_ready: true`.

## Config

| Env | Default | Role |
|-----|---------|------|
| `QUALITY_ENGINE` | `enet` | `enet` (rollback / current prod) or `musiq_worker` (cutover target) |
| `MUSIQ_WORKER_URL` | empty | HTTPS base URL of Linux worker |
| `MUSIQ_WORKER_TOKEN` | empty | Shared bearer secret |
| `MUSIQ_WORKER_TIMEOUT_SEC` | `60` | Client timeout |
| `MUSIQ_WORKER_TLS_VERIFY` | `true` | Verify TLS certificates |
| `MUSIQ_WORKER_PREFER_REMOTE` | `true` | Shadow MUSIQ uses worker when configured |

## Client + adapter

- `app/services/musiq_worker_client.py` — HTTPS `/v1/evaluate`; timeouts → unavailable
- `app/services/musiq_quality_adapter.py` — maps worker `criteria_raw` → production metrics
- `production_uses_enet()` is True iff `QUALITY_ENGINE != musiq_worker`
- Fallback when worker fails (musiq path): **local OpenCV only** (no ENET)
- Payload `analysis.quality_engine` reports the engine that actually scored

## Mapping rules

- Individual 1–5 criteria come from classical OpenCV raw (via adapter + existing `_soft_score`)
- MUSIQ OPQ is attached under `analysis.musiq_opq` with `context_only: true` only
- Color Balance / Saturation and video Flickering / Motion Stability stay on FastAPI
- PROBE / WaveRep / provenance are unchanged (authenticity isolation)

## Shadow path

Enable with `QUALITY_SHADOW_ENABLED=true` **and** `MUSIQ_WORKER_URL` + `MUSIQ_WORKER_TOKEN` while keeping `QUALITY_ENGINE=enet`.

`quality_shadow.scoring.run_shadow_score` calls `musiq_worker_client.evaluate_bytes` (multipart `/v1/evaluate`) once when remote is preferred. Results go only to `QUALITY_SHADOW_LOG_DIR` JSONL/CSV. Worker failures mark MUSIQ unavailable/partial and never block `media_pipeline` production scoring.

Local how-to: `docs/MUSIQ_SHADOW_LOCAL_ENABLE.md`  
Live smoke: `python scripts/verify_musiq_shadow_live.py`  
Cutover verification: `python scripts/verify_musiq_cutover_phase7g.py`

## Worker package

See:

- `musiq_worker/README.md`
- `musiq_worker/docs/CLOUD_DEPLOYMENT.md` (Fly.io remote deploy, no local Docker)
- `musiq_worker/docs/BACKEND_HTTPS_INTEGRATION.md`
- `musiq_worker/docs/DEPLOYMENT_READINESS.md`
- `musiq_worker/docs/LICENSE_NOTES.md`
