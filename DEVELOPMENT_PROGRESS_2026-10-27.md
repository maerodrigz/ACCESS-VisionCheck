# ACCESS VisionCheck — Development handoff (2026-10-27)

Non-sensitive session summary for resuming manual testing. **Git does not back up live PostgreSQL data.** Keep database dumps in a secure location outside GitHub.

## Completed features

- **Request Re-upload (submission chains):** Backend models, CRUD, media upload `replaces_media_id`, chain XP award, admin submission-chain API and React **SubmissionChainPanel**, Flutter replacement upload screen and chain history UI.
- **Submission Chains Phase 1 migration on original DB:** Applied to PostgreSQL **`postgres`** via guarded runner `access_backend/scripts/run_submission_chains_phase1_postgres.py` (refuses QA/UAT DB names). **47** chains backfilled after migration.
- **Admin Media Integrity:** Preview URL routing for LAN/Supabase refs via authenticated stream; Vitest coverage for preview helper.
- **Android backend connection:** Runtime migration from isolated QA port **3003** to original USB **`http://127.0.0.1:3001`**, QA session clearing on migration, bundled default no longer overwrites USB/QA overrides (`lib/shared/constants/api_config.dart`, `auth_controller.dart`, `main_mobile.dart`).
- **Integration tooling:** Backup verify, post-migration smoke, member connectivity verify scripts (PC-side).

## Database migration status

| Item | Status |
|------|--------|
| Target database | **`postgres`** (original) |
| `submission_chains` table | Present |
| Chain row count (post-migration) | **47** |
| Rerun migration tonight | **Do not** — already applied |

**Pre-migration backup (local, not in Git):**  
`access_backend/backups/integration/postgres_pre_submission_chains_20261027_135146.dump`

**Recommendation:** Before heavy manual re-upload testing, take a **new** `pg_dump` of `postgres` and store it securely (external drive or encrypted cloud). A Git commit only preserves **source code**, not DB rows, media, or XP.

## Current backend configuration (local only)

| Setting | Value |
|---------|--------|
| API port | **3001** |
| Database | **`postgres`** |
| `REPLACEMENT_UPLOAD_ENABLED` | **`true`** in `access_backend/.env` (local, not committed) |
| QA stack | **Not** modified; `.env.waverep_test` unchanged |

**When manual testing is finished:** Set `REPLACEMENT_UPLOAD_ENABLED=false` in `.env` and restart **only** the port **3001** process.

## Mobile / USB testing

| Item | Value |
|------|--------|
| Package | `com.accessvisioncheck.mobile` |
| USB backend URL | **`http://127.0.0.1:3001`** (compile: `config/api-usb.json`; device prefs migrated off `:3003`) |
| ADB reverse | `adb reverse tcp:3001 tcp:3001` |
| Release APK | **Not completed** this session; installed app + prefs fix used instead |
| Install/uninstall | **No** automatic install performed |

Sign in with a **real member account on `postgres`**, not isolated QA `@example.com` test users.

## Tests already passed (this integration arc)

- Guarded migration on `postgres` with pre-migration dump verify.
- Admin post-migration smoke on port **3001** (stats, AI list, submission-chain endpoint).
- Backend isolated tests (submission chains, replacement upload HTTP, admin media stream, Flutter replacement flow tests, React preview tests) during QA phase.
- Flutter unit test: `test/api_config_qa_backend_migration_test.dart`.

## Tests still pending (your manual pass)

- Member: request re-upload from evaluation / integrity flow on **physical device** + USB.
- Admin: verify chain timeline, approve/reject replacement, stream preview for replacement media.
- End-to-end XP / ranking behavior after replacement (no duplicate daily cap bypass abuse).
- Optional: finish release APK build with `--dart-define-from-file=config/api-usb.json` if you want in-app QA URL auto-migration without adb prefs edits.

## Known issues

- `.env.smoke.local` may still reference **QA** member credentials → **401** on `postgres` for automated member login smoke.
- Some legacy media rows may **404** on stream when files missing on disk/Supabase (expected; not a chain bug).
- Gradle **release APK** build was slow/incomplete; use debug build or existing install for tomorrow if needed.
- Startup banner may print a stale “Public” URL if shell env is polluted; bind and health on **3001** are authoritative.

## Resume tomorrow

1. Start original API:  
   `cd access_backend` → `python manage.py runserver --port 3001 --no-reload`
2. Confirm health: `GET http://127.0.0.1:3001/api/health` → `database=postgres`.
3. Phone: `adb reverse tcp:3001 tcp:3001`, force-stop app, open app, sign in as postgres member.
4. React admin: point Vite proxy at **3001** as usual.
5. Run manual Request Re-upload scenarios (member upload → admin integrity → chain panel).

## Manual Request Re-upload checklist

1. **Admin:** Media Integrity → open a flagged or needs-review practice eval → note media id and chain (if any).
2. **Member:** From evaluation result / integrity messaging → **Re-upload** → pick replacement media → submit with link to prior media.
3. **Admin:** Refresh submission chain panel → confirm `replacement_uploaded` event and linked media ids.
4. **Member:** Confirm updated status/score messaging without duplicate “daily limit” incorrectly blocking replacement.
5. **Admin:** Verify / reject as needed; confirm notifications and gallery behavior match policy.

## Feature flag reminder

`REPLACEMENT_UPLOAD_ENABLED=true` is **on for your testing**. Turn it **off** in `.env` and restart **3001** when you are done with re-upload experiments on the original database.
