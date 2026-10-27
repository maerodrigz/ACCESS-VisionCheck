# Isolated QA launch (port 3003)

Production API remains **3001**. Use this flow only for `access_waverep_test`.

## Backend

```powershell
cd access_backend
python manage.py --env-file .env.waverep_test runserver --host 127.0.0.1 --port 3003 --no-reload
```

Confirm: `GET http://127.0.0.1:3003/api/health` → 200.

## Admin Web (proxy to 3003, session env only)

```powershell
cd admin-web
.\scripts\dev-isolated-3003.ps1
```

Or manually:

```powershell
$env:VITE_API_BASE_URL="/api"
$env:VITE_DEV_PROXY_TARGET="http://127.0.0.1:3003"
npm run dev
```

Confirm through Vite origin: `GET http://localhost:5173/api/health` → 200 (not 502).

Default `vite.config.ts` proxy target stays **3001** when `VITE_DEV_PROXY_TARGET` is unset.

## API smoke

```powershell
cd access_backend
copy .env.smoke.example .env.smoke.local
# Fill passwords in .env.smoke.local (never commit).
python scripts/api_connectivity_smoke.py
```

## Mobile

**Android emulator** (host PC runs API on `127.0.0.1:3003`):

```powershell
flutter run -t lib/mobile_app/main_mobile.dart --dart-define-from-file=config/api.waverep3003.json
```

That file sets `API_BASE_URL=http://10.0.2.2:3003` (emulator alias for the PC). Do not edit `config/api.json` for QA; it stays on your normal dev LAN/port.

**Physical phone:** same Wi-Fi as PC, then in-app **Set backend URL** → `http://<PC-LAN-IPv4>:3003` or:

```powershell
flutter run -t lib/mobile_app/main_mobile.dart --dart-define=API_PUBLIC_HOST=192.168.x.x --dart-define=API_PORT=3003
```

Cold restart after changing URL (not hot reload).

## Phase 5 manual UI checklist

**Admin (browser):** `admin-web\scripts\dev-isolated-3003.ps1` then open `http://127.0.0.1:5173`. Confirm `GET /api/health` shows `access_waverep_test`. Media Integrity: open Review modal, **Submission chain** tab, **Request Re-upload** (remarks ≥ 8 chars), verify/reject replacement when present.

**Member (emulator):** `flutter run -t lib/mobile_app/main_mobile.dart --dart-define-from-file=config/api.waverep3003.json`. Evaluations → report with **Re-upload required** → linked replacement screen → history panel. Use a Phase 4 fresh member or admin-created test account.

**After backend pytest:** `test_submission_chains_phase1` no longer downgrades schema (keeps QA UI working). If columns are missing, run `python -m app.migrations.run_submission_chains_phase1 upgrade` with `ACCESS_PYTEST_DB=access_waverep_test`.

Connectivity: `.\scripts\phase5_qa_connectivity.ps1`

## Calendar workflow

On **admin approve**, the API creates or updates one `EventCalendar` row per request (`sync_calendar_from_request`). **Assign** reuses that row and sets `assigned_member_id`. Requestor/member `GET /api/events` lists approved events via `list_member_events`.

## Flutter tests on Windows (Application Control)

If `flutter_tester.exe` is blocked by policy:

- Run `flutter test` on **GitHub Actions** / Linux CI (recommended).
- Ask IT to allowlist `C:\flutter\bin\cache\artifacts\engine\windows-x64\flutter_tester.exe` for dev machines.
- Use `dart test` only for pure Dart packages (not widget tests).
- Rely on backend pytest + API smoke + manual device QA for capstone demos.

Do not disable Application Control globally.

## Duplicate submit

`POST /service-requests` runs `find_recent_duplicate` **before** schedule validation. An identical pending retry (same requestor, title, date, start/end within 30 minutes) returns the existing row and does not send notifications again. Different titles at the same slot still receive schedule overlap **400**.
