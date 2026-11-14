# Phase 6B — Cloudflare Free + Supabase Free Deployment Readiness Audit

**Status:** audit + migration plan only.  
**Date:** 2026-11-14  
**Do not deploy / do not create cloud projects from this document alone.**  
**Locked rubric:** unchanged. No fabricated ratings.

---

## 1. Current implementation (inspected)

| Area | Current behavior | Persistence / security notes |
|---|---|---|
| Stack | FastAPI + static SPA (`static/`), SQLite (`data/ratings.sqlite3`) | Single process; local disk |
| Images | `GET /api/images/{INDVAL}.jpg` after session header | Files from Phase 6A pack on disk; not world-readable |
| Invite exchange | `POST /api/auth/exchange` with invite token → session token | Invite stored as SHA-256 hash; plaintext never in DB |
| Ratings | `PUT /api/ratings/{media_id}` autosave; progress; final `POST /api/submit` locks | Isolation by `evaluator_id` from session (server-side) |
| Facilitator | `X-Facilitator-Token` → CSV / status | Token in env only; not in frontend |
| Rubric UI | Finalized Bisaya + English; 1–5 circles; N/A; zoom; resume | In `app/criteria.py` + static assets |
| Separation | Research portal under `tools/quality_validation/` | Not wired to production ACCESS FastAPI / Flutter / PROBE / WaveRep |

**Gap vs free Cloudflare+Supabase goal:** SQLite + local files do not survive ephemeral serverless deploys; FastAPI-as-is expects a long-lived filesystem.

---

## 2. Image pack vs Supabase Free storage

Measured on Phase 6A blinded pack (`INDVAL-001`…`100`):

| Metric | Value |
|---|---|
| File count | **100** |
| Total size | **52.10 MB** (~54.6e6 bytes) |
| Average | ~534 KB |
| Max single file | ~1.08 MB |

| Supabase Free quota (public pricing) | Fit? |
|---|---|
| File storage **1 GB** included | **Yes** (~5% of quota) |
| Max upload 50 MB / file | **Yes** (max ~1 MB) |
| DB size 500 MB | **Yes** (ratings tables are tiny) |
| Egress 5 GB (+ 5 GB cached) / org | **Likely OK** for 3 raters if each loads ~100 images once (~0.16 GB raw); **risk** if heavy reloads / shared device refreshes without caching |
| Project pause after **1 week inactivity** | **Operational blocker** for slow multi-week campaigns unless someone hits the API weekly or you upgrade |

**Verdict:** 100 JPEGs fit Free storage comfortably. Egress and inactivity pause are the real Free-tier risks, not disk size.

---

## 3. Cloudflare Free fit (important)

| Goal | Free reality | Implication |
|---|---|---|
| Host static UI | Cloudflare Pages: suitable | Serve `index.html` / `app.js` / `styles.css` |
| Host current FastAPI unchanged | Not a drop-in on Pages Functions (JS). Python Workers support FastAPI but Free CPU is **10 ms / request** | Full FastAPI+SQLite port is a **poor fit** |
| API + auth + CSV | Needs a BFF (Worker / Edge Function) or a small always-on host | Minimum change is **not** “upload FastAPI as-is to Pages” |
| Daily Workers requests | 100k / day Free | Fine for 3 human raters |

### Recommended target architecture (minimum secure free design)

```text
Evaluator browser
    │
    ├─ static UI ──────────────► Cloudflare Pages (Free)
    │
    └─ API (invite, ratings, export, signed image URLs)
           │
           ▼
    Cloudflare Worker (JS/TS)  OR  Supabase Edge Functions
           │                         (service role / secrets only here)
           ├─ Supabase Postgres (ratings, sessions, evaluators)
           └─ Supabase Storage private bucket (INDVAL JPGs)
```

**Do not** put `service_role` key, facilitator token, or facilitator mapping in the Pages frontend.

**Keep research Supabase project separate** from any production ACCESS VisionCheck Supabase project/database.

---

## 4. Minimum code / config changes (proposed; not implemented)

Preserve UI/rubric behavior. Change only backend persistence and image delivery.

| # | Change | Why |
|---|---|---|
| 1 | Extract DB interface from SQLite `db.py` → Postgres (asyncpg / Supabase client) | Survive restarts/deploys |
| 2 | Replace `FileResponse` images with **short-lived signed Storage URLs** (or Worker proxy) after session check | Private bucket; no public INDVAL listing |
| 3 | Move secrets to Cloudflare/Supabase secret stores: invite hashes, facilitator token, `SUPABASE_SERVICE_ROLE` | Never ship to evaluators |
| 4 | Split deploy: Pages = `static/`; Worker/Edge = API routes currently in `main.py` | Fits Free hosting split |
| 5 | Optional: keep local FastAPI+SQLite for offline facilitator rehearsal | Dev parity |
| 6 | Seed script: upload 100 INDVAL objects to private bucket; insert R1/R2/R3 invite hashes | One-time setup |
| 7 | Facilitator CSV endpoint unchanged in shape | Compatible with `generate_phase6a_consensus.py` |

**Not required for this migration:** rubric edits, production ACCESS backend changes, MUSIQ worker, Flutter.

### Auth / isolation model (server-side)

1. Invite token → server verifies against `evaluators.invite_token_hash`.
2. Issue opaque session (or JWT with `evaluator_id` + short TTL) stored hashed server-side.
3. All rating reads/writes scoped to `session.evaluator_id`.
4. Postgres **RLS** as defense-in-depth (see proposed SQL). Service role used only in Worker/Edge; browsers never use service role.
5. Facilitator routes require separate facilitator secret; RLS denies facilitator table access from evaluator JWTs.
6. Final submit sets immutable lock (`final_submissions` + `image_ratings.status='locked'`).

### Image authorization

- Bucket: `phase6b-indval` (private).
- Object keys: `INDVAL-001.jpg` … `INDVAL-100.jpg` only (no source filenames).
- After valid evaluator session: mint signed URL (60–120 s) for one `media_id`.
- Frontend continues blob/img load pattern (swap disk fetch for signed URL fetch).
- Never grant list-bucket to anon/authenticated evaluator policies.

---

## 5. Proposed SQL (draft — do not apply until implementation phase)

```sql
-- Research project only. Separate from production ACCESS DB.

create extension if not exists pgcrypto;

create table evaluators (
  evaluator_id text primary key check (evaluator_id in ('R1','R2','R3')),
  invite_token_hash text not null unique,
  display_label text not null,
  created_at timestamptz not null default now()
);

create table sessions (
  session_token_hash text primary key,
  evaluator_id text not null references evaluators(evaluator_id),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create table image_ratings (
  evaluator_id text not null references evaluators(evaluator_id),
  media_id text not null check (media_id ~ '^INDVAL-[0-9]{3}$'),
  status text not null default 'in_progress',
  ratings_json jsonb not null default '{}'::jsonb,
  notes text not null default '',
  updated_at timestamptz not null default now(),
  submitted_at timestamptz,
  primary key (evaluator_id, media_id)
);

create table rating_events (
  id bigserial primary key,
  evaluator_id text not null,
  media_id text not null default '',
  criterion text,
  rating int,
  event_type text not null,
  created_at timestamptz not null default now()
);

create table final_submissions (
  evaluator_id text primary key references evaluators(evaluator_id),
  submitted_at timestamptz not null default now(),
  summary_json jsonb not null
);

-- RLS: enable; policies assume JWT claim evaluator_id set by Edge/Worker.
alter table image_ratings enable row level security;
alter table sessions enable row level security;
alter table final_submissions enable row level security;
alter table rating_events enable row level security;
alter table evaluators enable row level security;

-- Evaluators table: no direct client read of invite hashes.
create policy evaluators_no_client_select on evaluators
  for select using (false);

create policy ratings_select_own on image_ratings
  for select using (evaluator_id = auth.jwt()->>'evaluator_id');

create policy ratings_upsert_own on image_ratings
  for all using (evaluator_id = auth.jwt()->>'evaluator_id')
  with check (evaluator_id = auth.jwt()->>'evaluator_id');

-- Prefer service-role-only access for sessions/events/facilitator export;
-- client JWT path optional if Worker uses user-scoped client.
```

Storage policies: **no** public read. Only service role creates signed URLs after session validation.

---

## 6. Backup / export procedures (proposed)

| Action | Method |
|---|---|
| Continuous | Supabase Postgres holds ratings (survives Worker redeploys) |
| Daily/manual | Facilitator `export.csv?evaluator_id=R#` → archive to Drive/repo-ignored folder |
| Consensus | Feed CSVs into `generate_phase6a_consensus.py` (unchanged columns) |
| Disaster | Supabase dashboard SQL dump / Table Editor export; Free plan has **no** automatic PITR backups |
| Images | Keep local Phase 6A pack as offline master; Storage is a deploy copy |

---

## 7. Step-by-step setup guide (for later implementation — not executed now)

1. Create a **new** Supabase Free org/project named e.g. `access-phase6b-research` (not production).
2. Create private Storage bucket `phase6b-indval`.
3. Apply SQL migration (Section 5) in SQL editor.
4. Generate invite + facilitator secrets locally (`scripts/generate_secrets.py`); store hashes in `evaluators`; store plaintext only in password manager / CF secrets.
5. Upload 100 INDVAL JPGs with service role (script to add in implementation phase).
6. Implement Worker/Edge API mirroring current routes; point static app `fetch` base URL to Worker.
7. Deploy static assets to Cloudflare Pages; set `PUBLIC_API_BASE`.
8. Configure CORS to Pages origin only.
9. Verify: health, invite exchange, image signed URL, autosave survives Worker redeploy, facilitator CSV, cross-evaluator isolation.
10. Only then share three `/r/<invite>` links (Pages URL + invite path or query handled by SPA).

---

## 8. Blockers, risks, and costs (before implementation)

| Item | Severity | Notes |
|---|---|---|
| FastAPI-on-Pages as-is | **Blocker** | Requires API redesign to Worker/Edge or paid/always-on host |
| Python Workers 10 ms CPU (Free) | **High risk** | Full FastAPI port may exceed CPU; prefer JS Worker / Edge Functions |
| Free project **pause after 7 days idle** | **High** | Mid-study pause locks raters out until manual unpause |
| Egress 5 GB | **Medium** | OK for careful 3-rater study; monitor reloads |
| No automated Free backups | **Medium** | Manual CSV exports required |
| Separate Supabase project needed | **Process** | Avoid sharing production service role / DB |
| Cloudflare account + Supabase account | **$0** if staying in Free quotas | |
| Optional Supabase Pro | **~$25/mo** | Removes pause + better backups if campaign is long |
| Optional Workers Paid | **~$5/mo** | Only if CPU/request limits bite |
| Facilitator time | Non-money cost | Seed upload, secret handling, weekly wake ping if Free |

**No monetary cost required to start Free**, but **pause + API rewrite** are the real blockers—not JPEG capacity.

---

## 9. What stays unchanged

- Finalized Modern Bisaya + English rubric (`criteria.py`)
- Circular 1–5 + N/A, zoom, autosave, resume, submission lock (UI)
- Phase 6A image IDs and consensus CSV schema
- Production ACCESS backend, Flutter, PROBE, WaveRep, `QUALITY_ENGINE`
- No fabricated ratings; no cloud resources created in this audit step

---

## 10. Audit verdict

| Question | Answer |
|---|---|
| Do 100 JPEGs fit Supabase Free storage? | **Yes (~52 MB / 1 GB)** |
| Can ratings persist across deploys on Free? | **Yes, if moved to Supabase Postgres** (not SQLite on Worker) |
| Can frontend live on Cloudflare Free? | **Yes (Pages)** |
| Can current FastAPI deploy unchanged to Cloudflare Free? | **No — needs API adapter** |
| Ready to implement next? | **Yes**, after facilitator accepts Worker/Edge rewrite + Free pause risk (or budget Pro) |
| Ready to tell raters “site is live”? | **No** — not deployed; no public HTTPS verified |

**Next phase (only after approval):** implement Postgres adapter + signed image URLs + Cloudflare Pages/Worker configs and migrations under `phase6b_rating_portal/`, still without fabricating ratings.
