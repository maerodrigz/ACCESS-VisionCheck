# MUSIQ worker integration (backend)

Production quality engine is **`QUALITY_ENGINE=musiq_worker` only**. EfficientNet-B0 (`QUALITY_ENGINE=enet`) is permanently retired and rejected at startup.

## Architecture

| Role | Engine |
|------|--------|
| Primary | MUSIQ Docker worker (classical OpenCV criteria + MUSIQ OPQ context) |
| Fallback | Optimized local OpenCV (`USE_VECTORIZED_BLOCKING`) |
| Retired | EfficientNet-B0 (not used in production routing) |

Setting `QUALITY_ENGINE=enet` raises a configuration error. Do not restore ENET without an explicit product decision.

## Config

| Env | Default | Role |
|-----|---------|------|
| `QUALITY_ENGINE` | `musiq_worker` | Only supported value |
| `MUSIQ_WORKER_URL` | empty | HTTPS base URL of Linux worker |
| `MUSIQ_WORKER_TOKEN` | empty | Shared bearer secret |
| `MUSIQ_WORKER_TIMEOUT_SEC` | `60` | Client timeout |
| `MUSIQ_WORKER_TLS_VERIFY` | `true` | Verify TLS certificates |
| `MUSIQ_WORKER_PREFER_REMOTE` | `true` | Shadow MUSIQ uses worker when configured |

## Client + adapter

- `app/services/musiq_worker_client.py` — HTTPS `/v1/evaluate`; timeouts → unavailable
- `app/services/musiq_quality_adapter.py` — maps worker `criteria_raw` → production metrics
- Fallback when worker fails: **local OpenCV only**
- Payload `analysis.quality_engine` reports the engine that actually scored
- New payloads set `analysis.efficientnet_used: false` (schema retained for historical rows)

## Mapping rules

- Individual 1–5 criteria come from classical OpenCV raw (via adapter + existing `_soft_score`)
- MUSIQ OPQ is attached under `analysis.musiq_opq` with `context_only: true` only
- Color Balance / Saturation and video Flickering / Motion Stability stay on FastAPI

## Historical notes

Older evaluations may still record `scoring_model: efficientnet-b0`. Those rows remain readable; they are not re-scored.
The scorer module and `ml/efficientnet_b0_heads.pt` have been removed. Historical ENET research scripts live under `tools/quality_validation/archive_efficientnet_retired/`.
