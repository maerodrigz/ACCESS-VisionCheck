# Phase 6B — Cloudflare Pages + Supabase Free (Windows PowerShell)

**Implementation is in-repo. This guide does not create cloud resources by itself.**  
Stop and verify each step before sharing evaluator links.

Local FastAPI portal remains the offline/dev reference (`..\static` + `..\app`).

---

## 0. Accounts you must create manually

1. Cloudflare account (Free)
2. **New** Supabase Free project for research only (not production ACCESS)
3. Optional: password manager for invite + facilitator tokens

---

## 1. Supabase schema + private storage

1. Open Supabase SQL editor.
2. Run migrations in order:
   - `supabase/migrations/20261114_001_phase6b_ratings.sql`
   - `supabase/migrations/20261114_002_storage_bucket_notes.sql` (notes only)
3. Create private Storage bucket `phase6b-indval` (Public = OFF).
4. Generate invites:

```powershell
cd tools\quality_validation\phase6b_rating_portal
python scripts\generate_secrets.py --write-env .env.cloud_secrets --public-base-url https://YOUR-PAGES.pages.dev
```

5. Hash each invite and insert into `evaluators`:

```powershell
cd cloud\scripts
.\hash_invite.ps1 -Token "<R1 plaintext invite>"
# Repeat for R2/R3, then INSERT hashes (see supabase/seed_evaluators.example.sql)
```

6. Upload images (service role — never commit):

```powershell
$env:SUPABASE_URL = "https://YOUR_PROJECT.supabase.co"   # NO /rest/v1/
$env:SUPABASE_SECRET_KEY = "<sb_secret_...>"             # preferred
$env:SUPABASE_STORAGE_BUCKET = "phase6b-indval"
.\upload_indval_images.ps1 -DryRun
.\upload_indval_images.ps1
```

---

## 2. Cloudflare Worker API

`sb_secret_` keys are sent on the **`apikey` header only** (not as JWT Bearer).  
Legacy `service_role` JWTs still work via `SUPABASE_SERVICE_ROLE_KEY` if needed.

```powershell
cd tools\quality_validation\phase6b_rating_portal\cloud\worker
npm install -g wrangler   # if needed
wrangler login
# Edit wrangler.toml name if taken
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_SECRET_KEY
wrangler secret put FACILITATOR_TOKEN
# Optional: set PAGES_BASE_URL in wrangler.toml [vars] after Pages exists
# Do NOT put secrets in Pages frontend env
wrangler deploy
```

Verify:

```powershell
curl.exe -fsS https://YOUR-WORKER.workers.dev/api/health
# Expect: supabase_key_kind=sb_secret, supabase_auth_mode=apikey_header_only
curl.exe -fsS https://YOUR-WORKER.workers.dev/api/meta
```

---

## 3. Cloudflare Pages (static UI)

```powershell
cd tools\quality_validation\phase6b_rating_portal\cloud
$env:PHASE6B_API_BASE = "https://YOUR-WORKER.workers.dev"
.\scripts\sync_pages_from_static.ps1
# Deploy pages folder:
# wrangler pages project create access-phase6b-ui
# wrangler pages deploy pages --project-name access-phase6b-ui
```

Set Worker `PAGES_BASE_URL` to the Pages HTTPS origin so `/r/<invite>` redirects work.

Evaluator links (preferred):

`https://YOUR-PAGES.pages.dev/?invite=<R1_TOKEN>`

---

## 4. Facilitator export + consensus

```powershell
curl.exe -fsS -H "X-Facilitator-Token: $env:FACILITATOR_TOKEN" `
  "https://YOUR-WORKER.workers.dev/api/facilitator/export.csv?evaluator_id=R1" `
  -o ratings_R1.csv
# Repeat R2/R3, then:
cd tools\quality_validation
python generate_phase6a_consensus.py --ratings-dir <folder>
```

---

## 5. Backup procedure

| Cadence | Action |
|---|---|
| After each rater finishes a session block | Facilitator CSV export for that `R#` |
| Daily during active rating | Export R1+R2+R3 (or ALL) to an offline folder / Drive |
| Before any Worker/Pages redeploy | CSV export snapshot |
| Disaster | Re-upload images from local Phase 6A pack; re-seed evaluators; restore ratings from CSV if needed |

Free plan: **no automatic PITR**. CSV exports are the backup.

---

## 6. Supabase Free inactivity pause

Free projects **pause after ~1 week without activity**.

Mitigations:

1. During the study, open `/api/health` or the Supabase dashboard at least weekly.
2. Or schedule a tiny ping (facilitator calendar reminder).
3. Or upgrade the research project to Pro if the campaign will be idle >7 days.
4. If paused: unpause in Supabase dashboard, re-check Worker health, then notify raters.

---

## 7. Security checklist

- [ ] `SUPABASE_SECRET_KEY` (`sb_secret_...`) only in Worker secrets / local env
- [ ] Anon/publishable key unused by frontend for ratings/images
- [ ] Facilitator token not in Pages HTML
- [ ] Storage bucket private; signed URLs only after session auth
- [ ] No facilitator mapping / machine scores in Pages or Worker responses
- [ ] Separate Supabase project from production ACCESS
- [ ] Legacy `service_role` JWT rotated/invalidated if it was ever exposed

## 8. Verify legacy service_role JWT invalidation

Creating a new `sb_secret_` key does **not** revoke the legacy JWT.

1. Dashboard → **Project Settings → API Keys** (Legacy API keys section).
2. Prefer **JWT Secret → Rotate / Generate new** if available (invalidates all old `anon` / `service_role` JWTs for that project).
3. Or use any **Rotate service_role / legacy keys** control your plan shows.
4. Confirm: a request with the **old** JWT to Storage or REST returns **401/403**.
5. Confirm: Worker health shows `supabase_key_kind: "sb_secret"` after secrets are set.
6. Update/remove any local `.env` copies of the old JWT; clear terminal history that may contain it.
7. Re-test upload DryRun / Worker with the new secret only.

---

## Status

Code + migrations + tests prepared. **Public deployment not performed in this session.**
