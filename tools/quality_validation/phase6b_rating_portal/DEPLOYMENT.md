# Phase 6B — Deploy a public HTTPS rating portal

The portal does **not** need the MUSIQ Docker worker. It only needs the 100 blinded INDVAL JPGs and invite secrets.

**Do not claim the site is online until you complete the verification section below.**

---

## What the facilitator must provide

| Item | Purpose |
|---|---|
| Fly.io account (or other host) | Public HTTPS |
| `EVALUATOR_INVITES` | Three long random tokens for R1/R2/R3 |
| `FACILITATOR_TOKEN` | CSV export / status API |
| Optional custom domain | Branded link |

Generate secrets locally (do not commit):

```powershell
cd tools\quality_validation\phase6b_rating_portal
python scripts\generate_secrets.py --write-env .env --public-base-url https://access-phase6b-ratings.fly.dev
```

---

## A) Local smoke test (before hosting)

```powershell
cd tools\quality_validation\phase6b_rating_portal
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
python scripts\generate_secrets.py --write-env .env
# Edit .env IMAGES_DIR if needed (default points at Phase 6A pack)
$env:IMAGES_DIR = (Resolve-Path ..\workspace\phase6a_human_validation\rater_pack\images)
.\.venv\Scripts\uvicorn app.main:app --host 127.0.0.1 --port 8090
```

Open the three `/r/<token>` links printed by `generate_secrets.py`.

Tests:

```powershell
.\.venv\Scripts\pytest -q
```

---

## B) Fly.io HTTPS deploy (recommended path already used for MUSIQ worker)

1. Install [flyctl](https://fly.io/docs/hands-on/install-flyctl/) and run `fly auth login`.

2. From this folder, stage images into the Docker build context:

```powershell
python scripts\stage_images.py
```

3. Create app + volume (once):

```powershell
fly apps create access-phase6b-ratings
fly volumes create phase6b_data --region sin --size 1 -a access-phase6b-ratings
```

4. Set secrets (paste from `generate_secrets.py`; never print into chat logs you will share):

```powershell
fly secrets set EVALUATOR_INVITES="R1:...,R2:...,R3:..." FACILITATOR_TOKEN="..." PUBLIC_BASE_URL="https://access-phase6b-ratings.fly.dev" -a access-phase6b-ratings
```

5. Deploy:

```powershell
fly deploy --remote-only --config fly.toml
```

6. Verification (required before telling raters the site is live):

```powershell
curl -fsS https://access-phase6b-ratings.fly.dev/api/health
# Expect: "status":"ok", "n_images_on_disk":100, "musiq_worker_required":false

# Open one invite link in a private browser window and confirm an INDVAL image loads.
```

If health fails or images are 0, **do not** distribute links.

---

## C) Facilitator export (after ratings)

```powershell
curl -fsS -H "X-Facilitator-Token: $env:FACILITATOR_TOKEN" `
  "https://access-phase6b-ratings.fly.dev/api/facilitator/export.csv?evaluator_id=R1" `
  -o ratings_R1.csv
```

Place `ratings_R1.csv` … `ratings_R3.csv` into a folder and run:

```powershell
cd tools\quality_validation
python generate_phase6a_consensus.py --ratings-dir <folder-with-filled-csvs>
```

---

## Security notes

- Evaluator isolation is enforced server-side by session ↔ `evaluator_id`.
- Images require a valid session (not world-readable).
- Facilitator mapping / machine scores are **not** packaged into this service.
- Rotate invites if a link leaks. Submitted finals are locked per evaluator.
- Frontend never embeds database paths or facilitator tokens.

---

## Status of this document

Prepared for deployment. **Public HTTPS is not verified in this session unless you run the Fly steps above.**
