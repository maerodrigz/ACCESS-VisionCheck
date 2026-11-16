# ACCESS VisionCheck — Production Deployment Guide

Do not deploy until the checklist in `docs/PRODUCTION_READINESS_CHECKLIST.md` is green.

## Architecture

| Piece | Role |
|-------|------|
| FastAPI (`access_backend`) | Auth, media, evaluations, admin APIs |
| PostgreSQL | Application database |
| Supabase Storage | Private media blobs (service role on server only) |
| Firebase | FCM push only (`FIREBASE_STORAGE_ENABLED=false` when Supabase is on) |
| PROBE-DINOv2 | Photo authenticity (`AI_DETECTOR_BACKEND=probe`) |
| MUSIQ worker | Quality scoring (`QUALITY_ENGINE=musiq_worker`) |
| React admin (`admin-web`) | Vite SPA behind nginx |
| Flutter | Android release via Play / sideload |

**UnivFD and EfficientNet-B0 are permanently retired.** Do not ship `univfd` weights or set `AI_DETECTOR_BACKEND=univfd` / `QUALITY_ENGINE=enet`.

## Backend

1. Install Python 3.12+, FFmpeg/FFprobe, PostgreSQL.
2. Copy `access_backend/.env.production.example` → `.env` and fill secrets.
3. Place PROBE checkpoint where `PROBE_CHECKPOINT_PATH` points (or default under `experiments/probe/...`).
4. Run migrations / `create_tables` only with an approved ops runbook (never wipe production data casually).
5. Start with reload **off**:
   ```bash
   cd access_backend
   python manage.py runserver --host 0.0.0.0 --port 3001 --no-reload
   ```
   On Render, set `PORT` (injected automatically). `manage.py` and the Dockerfile `CMD` bind `0.0.0.0` and prefer `$PORT`, then `API_PORT`, then `3001`.
6. Put nginx (TLS) in front when self-hosting. Terminate HTTPS; proxy `/api` to uvicorn. Do **not** proxy raw practice media under `/uploads/images` or `/uploads/videos` publicly.
7. Docker / Render:
   ```bash
   # From repository root
   docker build -f access_backend/Dockerfile -t access-api .
   ```
   - Dockerfile path: `access_backend/Dockerfile`
   - Build context: repository root (`.`)
   - Do not bake `.env`, keystores, or service-role keys (see root `.dockerignore`).
   - PROBE / WaveRep checkpoints are **not** in the image. Mount a disk or set `PROBE_CHECKPOINT_PATH` (and WaveRep paths) at runtime.

### Runtime dependencies

- `requirements.txt` (pin versions for a freeze before go-live)
- FFmpeg + FFprobe on `PATH`
- PyTorch available to the API process for PROBE
- PROBE checkpoint file + SHA match (see `probe_dino_detector.py`)
- MUSIQ worker reachable with a non-empty token

## React admin

```bash
cd admin-web
cp .env.production.example .env.production   # or empty VITE_API_BASE_URL for same-origin /api
npm ci
npm run build
```

Serve `admin-web/dist` with SPA fallback (`try_files $uri /index.html`). Proxy `/api` to the FastAPI upstream.

## Flutter Android release

1. Create an upload keystore. Copy `android/key.properties.example` → `android/key.properties` (gitignored).
2. Ensure `config/firebase.json` and `android/app/google-services.json` exist on the build machine (not committed if secret).
3. Build with HTTPS API:
   ```bash
   flutter build appbundle -t lib/mobile_app/main_mobile.dart \
     --dart-define=API_BASE_URL=https://api.example.com
   ```
4. Release builds disable cleartext HTTP and LAN probing. Debug builds still allow LAN HTTP.

## Render (Docker)

| Setting | Value |
|---------|--------|
| Dockerfile path | `access_backend/Dockerfile` |
| Docker build context | Repository root (`.`) |
| Health check path | `/api/health` |

Recommended env (set in Render dashboard — never commit real values):

- `APP_ENV=production`
- `PORT` (Render injects; do not override unless required)
- `DATABASE_URL` or `DB_HOST` / `DB_PORT` / `DB_USERNAME` / `DB_PASSWORD` / `DB_NAME`
- `JWT_SECRET` (≥32 random chars)
- `ALLOWED_HOSTS` = your Render hostname (and custom domain)
- `CORS_ORIGINS` = HTTPS admin / app origins (no `*`)
- `AI_DETECTOR_BACKEND=probe`
- `PROBE_CHECKPOINT_PATH` = path to mounted `DINOv2_best_model_step_34999.pth`
- `QUALITY_ENGINE=musiq_worker` + `MUSIQ_WORKER_URL` + `MUSIQ_WORKER_TOKEN`
- `SUPABASE_*` + service role via Render secret file / env
- `EMAIL_ENABLED=true` + SMTP_* ; `SMS_PROVIDER=textbee` (+ keys)
- Firebase service account for FCM (file mount or JSON env)

**Blockers:** PROBE / WaveRep weight files are gitignored and dockerignored — attach a persistent disk or object download. Full image builds pull `torch` + `transformers` and need substantial disk/RAM.

## Security notes

- `APP_ENV=production` refuses `CORS_ORIGINS=*`, `ALLOWED_HOSTS=*`, `SMS_PROVIDER=log`, `EMAIL_ENABLED=false`, empty `DB_PASSWORD`, and weak `JWT_SECRET`.
- Production never returns OTP `dev_code` in API JSON.
- Unhandled 500s return a generic message + `request_id`; details stay in server logs.
- Local path resolution rejects `..` traversal outside `UPLOAD_DIR`.
- Supabase signed stream URLs use a 1-hour TTL.
