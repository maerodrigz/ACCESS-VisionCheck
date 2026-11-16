# MUSIQ worker — cloud deployment (no local Docker required)

**Status:** configuration ready. **Not deployed by this document.**  
Do not claim live integration success until `/ready` and a real JPG `/v1/evaluate` succeed against the hosted URL.

Local Windows has no Docker Desktop / WSL distro. Deploy by building on the **cloud remote builder**.

---

## Provider choice: Fly.io (recommended)

| Criterion | Why Fly.io |
|-----------|------------|
| Remote Docker build | `fly deploy --remote-only` builds on Fly; laptop Docker not required |
| GitHub path | Workflow `.github/workflows/musiq-worker-fly.yml` (manual dispatch) |
| HTTPS | `force_https = true` on `*.fly.dev` |
| Memory | Configurable **8 GB** VM (needed for TensorFlow + MUSIQ) |
| Model cache | Persistent volume mount at `/models/tfhub` |
| Region | Default `sin` (Singapore) for PH-adjacent latency; change in `fly.toml` |

**Alternatives (not configured in-repo):** Google Cloud Run (good scale-to-zero, but cold starts with TF are harsh); Railway/Render free tiers are usually **too small** for TF 2.21 + MUSIQ.

This repo does **not** purchase a Fly plan. Creating an app on your Fly account may incur charges.

---

## Resource estimates (approximate, not SLA)

| Resource | Estimate | Notes |
|----------|----------|-------|
| vCPU | 2 shared | `shared-cpu-2x` in `fly.toml` |
| RAM | **8 GB** | 4 GB may OOM during model load; treat 8 GB as staging minimum |
| Disk / volume | **5 GB** volume | TF Hub SavedModel cache ~250 MB+; leave headroom |
| Image size | ~2–4 GB | Python + TensorFlow wheel (estimate) |
| First start | **3–8 minutes** | Download + load MUSIQ into memory (estimate) |
| Later start (warm volume) | **1–3 minutes** | Load from cache (estimate) |
| Photo latency (CPU) | **1–4 s** after warm | Colab/CPU vary; measure on your VM |
| Idle cost (1× 8 GB machine) | **Roughly mid single-digit to low tens USD/month** | Label: **estimate only**; check current Fly pricing |
| Scale-to-zero | Optional (`min_machines_running = 0`) | Saves money; adds multi-minute cold starts |

---

## Secrets (never commit)

| Secret | Where |
|--------|--------|
| `MUSIQ_WORKER_TOKEN` | Fly secrets + GitHub Actions secret + local `access_backend/.env` |
| `FLY_API_TOKEN` | GitHub Actions secret only |

Repo already ignores `**/.env`. `.env.example` keeps placeholders only.

Cloud must keep `ALLOW_INSECURE_EMPTY_TOKEN=false`. Empty token → `/v1/evaluate` returns 503.

---

## Manual deployment checklist

### A. One-time Fly setup (operator laptop or CI machine with `flyctl`)

1. Install [flyctl](https://fly.io/docs/flyctl/install/) (does **not** require Docker Desktop).
2. `fly auth login`
3. From repo:
   ```bash
   fly apps create access-musiq-worker
   fly volumes create musiq_tfhub --region sin --size 5 -a access-musiq-worker
   ```
4. Generate a long random token (do not commit it):
   ```bash
   # PowerShell
   [Convert]::ToBase64String((1..48 | ForEach-Object { Get-Random -Maximum 256 }) -as [byte[]])
   ```
5. `fly secrets set MUSIQ_WORKER_TOKEN="YOUR_TOKEN" -a access-musiq-worker`
6. Deploy with **remote builder**:
   ```bash
   cd musiq_worker
   fly deploy --remote-only --config fly.toml
   ```
7. Or trigger GitHub Action **Deploy MUSIQ worker (Fly.io)** with input `confirm=deploy` after setting repo secrets `FLY_API_TOKEN` and `MUSIQ_WORKER_TOKEN`.

### B. Live verification (required before calling it “working”)

Replace `APP` with your Fly hostname (e.g. `access-musiq-worker.fly.dev`):

```bash
# 1) Liveness (may be ok while MUSIQ still loads)
curl -sS https://APP/health

# 2) Readiness — must return 200 with musiq_ready=true
curl -sS -w "\nHTTP %{http_code}\n" https://APP/ready

# 3) Auth required (expect 401)
curl -sS -o /dev/null -w "%{http_code}\n" -F media_type=photo -F file=@sample.jpg https://APP/v1/evaluate

# 4) Real JPG inference
curl -sS -H "Authorization: Bearer YOUR_TOKEN" \
  -F media_type=photo -F file=@sample.jpg \
  https://APP/v1/evaluate
```

Pass criteria for step 4:

- `status` is `ok` (or `partial` only if classical ok but MUSIQ failed; for go-live require MUSIQ `ok`)
- `musiq.musiq_opq_raw` is a finite float
- `criteria_q` / `criteria_raw` present
- `experimental_feedback` present
- `duration_ms` present
- `musiq.model_id` is `tfhub:google/musiq/paq2piq/1`

### C. Local FastAPI backend (still ENET)

See `BACKEND_HTTPS_INTEGRATION.md`. Keep:

```env
QUALITY_ENGINE=enet
MUSIQ_WORKER_URL=https://APP
MUSIQ_WORKER_TOKEN=YOUR_TOKEN
QUALITY_SHADOW_ENABLED=false
```

### D. Rollback

```bash
fly apps suspend access-musiq-worker
# and/or clear backend MUSIQ_WORKER_URL / MUSIQ_WORKER_TOKEN
```

Production member scores remain EfficientNet while `QUALITY_ENGINE=enet`.

---

## Licensing before public deployment

Review `LICENSE_NOTES.md`:

- TF Hub PaQ-2-PiQ export labeled **Apache 2.0**
- Training data upstream PaQ-2-PiQ / FLIVE: **CC BY-NC-SA 4.0** (counsel review for commercial use)
- Do not ship GCS unlabeled `.npz` checkpoints
- Keep worker private (Bearer) until legal + product approval

---

## What this prep does **not** do

- Does not install Docker/WSL on Windows
- Does not modify Smart App Control
- Does not purchase hosting or run `fly deploy` for you
- Does not set `QUALITY_ENGINE` to MUSIQ or change production scores/XP/detection
