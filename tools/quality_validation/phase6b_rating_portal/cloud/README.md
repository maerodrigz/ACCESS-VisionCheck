# Phase 6B cloud packaging (Cloudflare + Supabase)

Preserves the local FastAPI portal as the development reference. This folder adds:

| Path | Role |
|---|---|
| `pages/` | Cloudflare Pages static UI (synced from `../static`) |
| `worker/` | Cloudflare Worker API (Supabase Postgres + signed Storage URLs) |
| `supabase/migrations/` | Versioned SQL + RLS deny-by-default |
| `shared/rubric.json` | Locked rubric export from `app/criteria.py` |
| `DEPLOY_CLOUDFLARE_SUPABASE.md` | Windows PowerShell setup guide |
| `FACILITATOR_BACKUP.md` | CSV backup + Free pause guidance |

```powershell
# Tests (no cloud needed)
cd cloud
node --test tests/*.test.js
```

Worker auth: prefer `SUPABASE_SECRET_KEY` (`sb_secret_...`) via the `apikey` header only.
Do not put secret keys in Pages. Do not deploy until secrets are set via `wrangler secret put`.
