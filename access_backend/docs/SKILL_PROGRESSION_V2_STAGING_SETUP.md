# Skill progression v2 — isolated staging preparation (no activation)

Use this document to stand up a **separate** PostgreSQL database and API process so v2 validation cannot write to shared dev (`postgres` DB on this machine) or production.

**Current shared dev (verified):** `DB_NAME=postgres` on `localhost:5432`, `SKILL_PROGRESSION_ACTIVE_POLICY=v1`. Do not run grandfather `--apply` or enable v2 there.

## Phase 1 completed (local)

| Item | Value |
|------|--------|
| Database | `access_skillprogression_staging` |
| App role | `access_skillprogression_app` (CONNECT revoked on `postgres`, `access_uat`, `access_waverep_test`) |
| Env file | `access_backend/.env.skillprogression_staging` (gitignored; load via `ACCESS_ENV_FILE`) |
| API port | `3011` |
| Uploads | `uploads_staging_skillprogression/` |
| Policy | `v1` |
| Schema | `create_tables.py` + `migrate_skill_progression_grandfather.py` |
| Data | Synthetic only (`SEED_DEMO_DATA=true` on staging bootstrap) |

**Provision + bootstrap (repeatable):**

```powershell
cd access_backend
python scripts/provision_skillprogression_staging.py
python scripts/bootstrap_skillprogression_staging_schema.py
```

**Start staging API (does not use shared `.env`):**

```powershell
$env:ACCESS_ENV_FILE = (Resolve-Path .env.skillprogression_staging).Path
python manage.py runserver
```

**Rollback (drops staging only — requires postgres superuser):**

```powershell
# From access_backend with default .env (postgres superuser)
python -c "
import psycopg
from app.config import settings
from urllib.parse import quote_plus
u=f'postgresql://{quote_plus(settings.db_username)}:{quote_plus(settings.db_password)}@{settings.db_host}:{settings.db_port}/postgres'
with psycopg.connect(u, autocommit=True) as c:
    c.execute('SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = %s', ('access_skillprogression_staging',))
    c.execute('DROP DATABASE IF EXISTS access_skillprogression_staging')
    c.execute('DROP ROLE IF EXISTS access_skillprogression_app')
print('Staging DB and role dropped.')
"
Remove-Item -Recurse -Force uploads_staging_skillprogression -ErrorAction SilentlyContinue
Remove-Item .env.skillprogression_staging -ErrorAction SilentlyContinue
```

---

## 1. Recommended staging database name

| Database | Purpose |
|----------|---------|
| `postgres` | **Active local dev** (1 approved member today) — **protected** |
| `access_uat` | Existing UAT clone |
| `access_waverep_test` | Pytest isolated DB (`ACCESS_PYTEST_DB=access_waverep_test`) |
| **`access_skillprogression_staging`** | **New dedicated v2 staging** (create on approval) |

---

## 2. Isolated environment file (do not merge into `.env`)

Copy template after approval:

```bash
cd access_backend
copy .env.skillprogression_staging.example .env.skillprogression_staging
# Edit passwords and paths; never point DB_NAME at postgres or production.
```

Start API **only** with explicit env file:

**PowerShell**

```powershell
cd access_backend
$env:ACCESS_ENV_FILE = (Resolve-Path .env.skillprogression_staging).Path
$env:SKILL_PROGRESSION_ACTIVE_POLICY = "v1"
python manage.py runserver
```

Use a **different port** in staging env (example `API_PORT=3011`) so shared dev can keep `3001`.

**Physical phone on the same Wi-Fi:** staging must bind **`API_HOST=0.0.0.0`** (not `127.0.0.1`) and include your PC LAN IPv4 in `ALLOWED_HOSTS` (for example `192.168.8.99,192.168.8.99:3011`). Flutter:

```powershell
flutter run -t lib/mobile_app/main_mobile.dart --dart-define=API_BASE_URL=http://192.168.8.99:3011
```

Verify from the PC: `http://192.168.8.99:3011/api/health` returns 200.

**If the phone still times out (same Wi-Fi, correct IP):**

1. Confirm the PC Wi-Fi profile is **Private** (`Get-NetConnectionProfile`). Windows often marks home Wi-Fi as **Public**, which blocks inbound LAN traffic by default.
2. Run **as Administrator**: `scripts/allow_api_port_3011_firewall.ps1` (TCP **3011**, **LocalSubnet** only, Private + Domain profiles). If the network must stay Public, use the optional LAN-only Public rule documented in that script.
3. From the phone subnet, TCP to `192.168.8.99:3011` must succeed (PC ping may fail if ICMP is blocked; test health in the app or `adb shell toybox nc -w 5 192.168.8.99 3011`).
4. **USB fallback (no firewall change):** `adb reverse tcp:3011 tcp:3011` and `--dart-define=API_BASE_URL=http://127.0.0.1:3011` (127.0.0.1 on the phone is forwarded to the PC over USB).

---

## 3. Create staging database (requires approval — writes server catalog)

Run only when creating the empty staging DB (not against `postgres` dev):

```powershell
# Adjust path to your PostgreSQL bin if psql is not on PATH
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -h localhost -p 5432 -c "CREATE DATABASE access_skillprogression_staging OWNER postgres;"
```

**Schema bootstrap on staging only:**

```powershell
$env:ACCESS_ENV_FILE = (Resolve-Path access_backend\.env.skillprogression_staging).Path
cd access_backend
python create_tables.py
python migrate_skill_progression_grandfather.py
```

Optional synthetic members for override/v2 gate testing (staging only): use `SEED_DEMO_DATA=true` **only** on staging DB, or insert fixtures via approved scripts — **do not copy production PII without authorization.**

---

## 4. Backup and restore (PostgreSQL)

`pg_dump` / `psql` were not on PATH in the last validation session. Use the full path to PostgreSQL 16+ binaries or pgAdmin.

**Backup shared dev before any staging work that touches the same server:**

```powershell
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$pg = "C:\Program Files\PostgreSQL\16\bin\pg_dump.exe"
& $pg -U postgres -h localhost -p 5432 -Fc -f "backups\access_dev_postgres_$ts.dump" postgres
```

**Restore to a new database (never overwrite `postgres` in place without approval):**

```powershell
$pg = "C:\Program Files\PostgreSQL\16\bin\psql.exe"
& $pg -U postgres -h localhost -p 5432 -c "CREATE DATABASE access_skillprogression_staging_restore OWNER postgres;"
$pgRestore = "C:\Program Files\PostgreSQL\16\bin\pg_restore.exe"
& $pgRestore -U postgres -h localhost -p 5432 -d access_skillprogression_staging_restore "backups\access_dev_postgres_$ts.dump"
```

**Read-only verification (no writes):**

```powershell
cd access_backend
python -c "from sqlalchemy import inspect; from app.database import engine; from app.config import settings; print(settings.db_name); print([c['name'] for c in inspect(engine).get_columns('member_rankings') if 'grandfather' in c['name']])"
```

---

## 5. Safety guards before any `--apply`

Before grandfather `--apply` or v2 enable, confirm **all** of:

1. `settings.db_name` equals `access_skillprogression_staging` (or other approved staging name).
2. `ACCESS_ENV_FILE` resolves to `.env.skillprogression_staging`, not `.env`.
3. Dry-run output reviewed (`would_capture`, `members_with_admin_override`).
4. Separate API port/process from shared dev.

Suggested pre-apply one-liner (staging env loaded):

```powershell
python -c "from app.config import settings; assert settings.db_name == 'access_skillprogression_staging', settings.db_name; print('OK staging DB')"
```

---

## 6. Grandfather dry-run (read-only)

Against **shared dev** (current):

```powershell
cd access_backend
# Default .env — no ACCESS_ENV_FILE
python scripts/skill_progression_capture_grandfather.py
```

Against **staging** (after staging DB exists):

```powershell
$env:ACCESS_ENV_FILE = (Resolve-Path .env.skillprogression_staging).Path
python scripts/skill_progression_capture_grandfather.py
```

---

## 7. Staging smoke tests (after staging DB + API on 3011)

**Automated (no member JWT required for policy unit tests):**

```powershell
cd access_backend
python -m pytest tests/test_skill_progression_staging_readiness.py -q
```

**HTTP (member login on staging API):**

```powershell
$base = "http://127.0.0.1:3011/api"
# Login — use staging test member credentials only
$login = Invoke-RestMethod -Method Post -Uri "$base/auth/login" -ContentType "application/json" -Body '{"email":"...","password":"..."}'
$token = $login.token
$part = Invoke-RestMethod -Uri "$base/member/participation" -Headers @{ Authorization = "Bearer $token" }
$part.skill_progression_policy_version
$part.skill_progression_policy_configured
$part.skill_progression_v2_blocked_reason
```

**Expect before v2 activation:** `skill_progression_policy_version` = `v1`, configured = `v1`, blocked reason = `null`.

**Expect after staging v2 enable + complete snapshots:** version = `v2`, configured = `v2`, blocked reason = `null`.

---

## 8. Validate `users.skill_level_id` vs computed / effective tiers

Read-only SQL on staging (replace `:user_id`):

```sql
SELECT u.id,
       sl.level_name AS stored_skill_level,
       mr.competency_level_override,
       mr.skill_tier_grandfather_floor
FROM users u
LEFT JOIN skill_levels sl ON sl.id = u.skill_level_id
LEFT JOIN member_rankings mr ON mr.user_id = u.id
WHERE u.id = :user_id;
```

Compare to API (authoritative for mobile):

- `skill_effective_tier` — label shown to member (override wins).
- `skill_computed_tier` — active policy computed tier.
- `skill_computed_tier_v2_preview` — v2 preview while policy v1.

Python (single member, staging env):

```powershell
python -c "
from app.database import SessionLocal
from app.services.skill_progression import build_skill_progression_snapshot
db = SessionLocal()
uid = 1
s = build_skill_progression_snapshot(db, uid)
print('stored vs snapshot', s.effective_tier, s.computed_tier_active, s.computed_tier_v1, s.computed_tier_v2)
db.close()
"
```

Mismatch between `stored_skill_level` and `skill_effective_tier` is expected until optional recalc; participation/effective tier is source of truth for UI.

---

## 9. Commands reserved for later approval (do not run on shared dev)

**Grandfather apply (staging DB only):**

```powershell
$env:ACCESS_ENV_FILE = (Resolve-Path .env.skillprogression_staging).Path
python -c "from app.config import settings; assert settings.db_name == 'access_skillprogression_staging'"
python scripts/skill_progression_capture_grandfather.py --apply
```

**Enable v2 (staging only):**

```powershell
# In .env.skillprogression_staging only:
# SKILL_PROGRESSION_ACTIVE_POLICY=v2
$env:ACCESS_ENV_FILE = (Resolve-Path .env.skillprogression_staging).Path
python manage.py runserver
```

**Rollback staging:**

```powershell
# .env.skillprogression_staging: SKILL_PROGRESSION_ACTIVE_POLICY=v1
# Restart API on 3011; grandfather columns remain.
```

**Bulk recalc (separate approval):**

```powershell
# Only if scripts/skill_level_recalc_apply.py is approved for staging
python scripts/skill_level_recalc_apply.py
```

---

## 10. Database write-risk checklist

| Step | Writes | Approved for shared dev? | Approved for staging? |
|------|--------|--------------------------|------------------------|
| `CREATE DATABASE` | Server catalog | No | Yes (once) |
| `create_tables.py` | DDL/DML seed | No | Yes (empty staging) |
| `migrate_skill_progression_grandfather.py` | DDL columns | Already done on dev | Yes on new staging |
| `capture_grandfather.py` dry-run | None | Yes (read-only) | Yes |
| `capture_grandfather.py --apply` | `member_rankings` grandfather fields | **No** | After GO |
| `SKILL_PROGRESSION_ACTIVE_POLICY=v2` | Runtime behavior | **No** | After snapshots + GO |
| Eval pipeline / recalc | `users.skill_level_id`, milestones | Normal ops | Staging tests |
| Bulk recalc script | Many `users` rows | **No** | Separate GO |
