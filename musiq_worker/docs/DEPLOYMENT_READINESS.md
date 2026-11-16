# Deployment readiness — MUSIQ worker

**Status:** cloud-deploy **configuration** ready (Fly.io remote builder). **Not** live-verified in this repo session. Production quality engine remains **EfficientNet-B0** (`QUALITY_ENGINE=enet`).

Local Windows verification on 2026-11-13 was **blocked** (no Docker Desktop / no WSL distro). See `RUNTIME_VERIFICATION_20261113.md`. Use cloud remote build instead of installing Docker on the laptop unless you choose to.

## Checklist

| Item | Status |
|------|--------|
| Dockerized Linux worker | Yes (`musiq_worker/Dockerfile`, `$PORT`-aware `entrypoint.sh`) |
| Remote cloud build config | Yes (`fly.toml`, `.github/workflows/musiq-worker-fly.yml`) |
| Model load once at startup | Yes (`PRELOAD_MUSIQ`, `/ready` 503 until loaded) |
| Bearer auth + size limits + timeouts | Yes |
| Hybrid classical + feedback reused | Yes (vendored Phase 1–3) |
| FastAPI HTTPS client | Yes (`musiq_worker_client.py`) |
| Default `QUALITY_ENGINE=enet` | Yes |
| Production eval / XP / Flutter unchanged | Yes |
| Worker timeouts invent no scores | Yes |
| Video frame aggregate + temporal preserved on backend | Yes |
| Secrets excluded from git | Yes (`**/.env` ignored; examples only) |
| License review before public deploy | **Required** (`LICENSE_NOTES.md`) |
| Human-rated MUSIQ validation complete | **No** |
| Live cloud `/ready` + JPG evaluate | **Pending operator deploy** |

## Exact next steps (no local Docker)

Follow **`CLOUD_DEPLOYMENT.md`** (Fly.io recommended). Short form:

1. **Legal:** TF Hub Apache label + PaQ-2-PiQ NC-SA training-data review (`LICENSE_NOTES.md`).
2. `flyctl` auth → create app + 5 GB volume → set `MUSIQ_WORKER_TOKEN` secret.
3. `fly deploy --remote-only --config musiq_worker/fly.toml` (or GitHub Action).
4. `curl https://APP/ready` then `python musiq_worker/scripts/verify_remote_worker.py --image sample.jpg`.
5. Point local backend with `QUALITY_ENGINE=enet` + `MUSIQ_WORKER_URL`/`TOKEN` (`BACKEND_HTTPS_INTEGRATION.md`).
6. **Cutover later (separate change):** only after legal + live verify + product approval.

## Rollback

See README Rollback section. Default ENET path never required the worker.

## Colab verification reference (research)

Live TF 2.21.0 PaQ-2-PiQ scores on five JPGs (not a production SLA):

| Image | MUSIQ |
|-------|------:|
| Clear | 78.79 |
| Blurry | 53.52 |
| Underexposed | 68.76 |
| Overexposed | 78.74 |
| Low contrast | 77.70 |
