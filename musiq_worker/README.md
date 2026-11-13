# ACCESS VisionCheck — MUSIQ + OpenCV Worker

Linux FastAPI service that loads **official TF Hub MUSIQ PaQ-2-PiQ** once at startup and scores images with:

- Raw MUSIQ overall quality (`output_0`, ~0–100)
- Phase 1–3 hybrid OpenCV/NumPy criteria (vendored from `access_backend`)
- Experimental rule-based feedback (research ruleset `hybrid_feedback_rules_v1`)
- Bounded video frame sampling + transparent aggregation

The ACCESS FastAPI backend keeps **EfficientNet-B0** as the default production engine (`QUALITY_ENGINE=enet`). This worker is called over HTTPS with a shared bearer token for test/shadow paths until an explicit cutover.

## Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/health` | no | Liveness |
| GET | `/ready` | no | Ready only if MUSIQ is loaded |
| POST | `/v1/evaluate` | Bearer | Photo/video multipart evaluation |

### Evaluate form fields

- `file`: image or video bytes
- `media_type`: `photo` or `video`
- `file_ext`: optional (e.g. `.mp4`)

## Cloud deploy without local Docker (recommended)

Primary host: **Fly.io** (remote builder + HTTPS + 8 GB RAM). Config: `fly.toml`.  
Checklist: [`docs/CLOUD_DEPLOYMENT.md`](docs/CLOUD_DEPLOYMENT.md). Backend wiring: [`docs/BACKEND_HTTPS_INTEGRATION.md`](docs/BACKEND_HTTPS_INTEGRATION.md).

```bash
# One-time: flyctl install + auth (Docker Desktop not required)
fly apps create access-musiq-worker
fly volumes create musiq_tfhub --region sin --size 5 -a access-musiq-worker
fly secrets set MUSIQ_WORKER_TOKEN="YOUR_LONG_RANDOM_SECRET" -a access-musiq-worker
cd musiq_worker
fly deploy --remote-only --config fly.toml
```

Or run GitHub Action **Deploy MUSIQ worker (Fly.io)** with `confirm=deploy` (secrets `FLY_API_TOKEN`, `MUSIQ_WORKER_TOKEN`).

After deploy, verify for real (do not skip):

```bash
curl -sS https://APP/ready
python musiq_worker/scripts/verify_remote_worker.py --image sample.jpg
```

This repository does **not** auto-deploy or purchase hosting.

## Local Linux / Docker (optional)

```bash
cd musiq_worker
cp .env.example .env   # set MUSIQ_WORKER_TOKEN
docker compose up --build
curl -s http://127.0.0.1:8080/health
# wait until ready (first boot downloads TF Hub model into volume)
curl -s http://127.0.0.1:8080/ready
curl -s -H "Authorization: Bearer $MUSIQ_WORKER_TOKEN" \
  -F media_type=photo -F file=@sample.jpg \
  http://127.0.0.1:8080/v1/evaluate
```

Build without compose:

```bash
docker build -t access-musiq-worker -f musiq_worker/Dockerfile musiq_worker
```

## Backend wiring

In `access_backend/.env` (defaults keep production ENET):

```env
QUALITY_ENGINE=enet
MUSIQ_WORKER_URL=https://your-worker.example.com
MUSIQ_WORKER_TOKEN=same-as-worker
MUSIQ_WORKER_TIMEOUT_SEC=60
```

Client: `app/services/musiq_worker_client.py`.  
Shadow MUSIQ prefers the remote worker when URL+token are set (`MUSIQ_WORKER_PREFER_REMOTE=true`).

## Tests

```bash
# Worker (mocked MUSIQ, no TF download)
cd musiq_worker && pip install fastapi uvicorn python-multipart pydantic pydantic-settings numpy opencv-python-headless pytest httpx
pytest -q

# Backend client mocks
cd ../access_backend && pytest -q tests/test_musiq_worker_client.py
```

## Hybrid logic sync

```bash
python musiq_worker/scripts/sync_hybrid_logic.py
```

## Resource estimates (CPU VM)

| Resource | Guidance |
|----------|----------|
| vCPU | 2+ (4 better for video) |
| RAM | 4 GB minimum; **8 GB** recommended (TF + model + OpenCV) |
| Disk | 10 GB (image + TF Hub cache ~250 MB+) |
| Cold start | 1–3 min first model download; then `/ready` |
| Photo latency | ~1–3 s/image on modest CPU after warm |
| Video | `VIDEO_SAMPLE_FRAMES` (default 4) × photo cost |

## Rollback

1. Keep `QUALITY_ENGINE=enet` (never required a cutover for this phase).
2. Clear `MUSIQ_WORKER_URL` / token on the backend to stop remote calls.
3. `docker compose down` (or stop the VM service).
4. Production member/admin scores remain EfficientNet-B0.

See `docs/DEPLOYMENT_READINESS.md` and `docs/LICENSE_NOTES.md`.
