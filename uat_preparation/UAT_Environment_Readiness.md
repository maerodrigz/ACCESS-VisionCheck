# UAT environment readiness

**Product:** ACCESS VisionCheck  
**Purpose:** Final User Acceptance Testing (separate from QA `access_waverep_test` and production)

## Implemented surfaces (what exists today)

### Admin Web (React, `admin-web/`)

| Area | Implemented? | Notes |
|------|--------------|-------|
| Login | Yes | `/login` |
| Dashboard | Yes | Stats, AI review queue, documenters |
| Documentation requests | Yes | Approve / decline / assign workflow |
| Event calendar | Yes | Campus events + assignment sync |
| Documentation team (members) | Yes | Member list and profiles |
| Media library | Yes | Event / gallery uploads |
| Media Integrity (AI review) | Yes | Admin verify / reject AI flags |
| Requester feedback | Yes | View org feedback |
| Competency management | Yes | Skill tiers, XP, overrides |
| Analytics | Yes | Overview, rankings, exports partial |
| Notification center | Yes | Admin inbox |
| Account management | Yes | User status |
| System configuration | Yes | Branding and settings |
| Dedicated “Evaluation review” page | **No** | `/evaluations` redirects to Media |
| Repository UI | **No** | API-only exclusion rules; no admin page |
| Facebook publish from admin | Config-dependent | **Off** in UAT env template |

### Flutter Mobile (`lib/mobile_app/`)

| Role | Implemented? | Notes |
|------|--------------|-------|
| Member login / home / profile | Yes | Profile from header avatar |
| Member calendar, rankings, gallery | Yes | Bottom nav |
| Practice media evaluation | Yes | Photo / video upload flow |
| Member notifications | Yes | In-app inbox + badge |
| Requestor login / home | Yes | |
| Requestor requests list + new request | Yes | Multi-step form |
| Requestor calendar, gallery, feedback | Yes | Bottom nav |

### Backend (FastAPI)

Core APIs for auth, service requests, events, media, evaluations, rankings, notifications, admin stats. External email / Facebook / FCM depend on `.env` and are **disabled** in UAT template.

---

## UAT stack (isolated)

| Component | Value |
|-----------|--------|
| Database | **`access_uat`** (new DB; QA `access_waverep_test` untouched) |
| API bind | `http://127.0.0.1:3005` |
| Admin Web | `http://127.0.0.1:5175` (proxy to 3005) |
| Mobile API | `--dart-define=API_PORT=3005 --dart-define=API_BASE_URL=http://127.0.0.1:3005` + `adb reverse tcp:3005 tcp:3005` on USB |
| Uploads | `access_backend/uploads_uat/` |
| Push / email / Facebook | Off in `.env.uat_nopush.example` |

**Do not use production port 3001 or QA port 3004 for UAT sessions.**

---

## Provision (one-time, facilitator)

```powershell
cd access_backend
copy .env.uat_nopush.example .env.uat.local
# Edit DB password in .env.uat.local if needed
$env:ACCESS_ENV_FILE = (Resolve-Path .env.uat.local).Path
python scripts/create_uat_database.py
python manage.py create_tables
python scripts/seed_uat_accounts.py
```

Passwords are written to **`access_backend/.env.uat.accounts.local`** (gitignored). Share that file only through a secure channel.

---

## Start UAT session

**Terminal 1 — API**

```powershell
cd access_backend
$env:ACCESS_ENV_FILE = (Resolve-Path .env.uat.local).Path
python manage.py runserver --host 127.0.0.1 --port 3005 --no-reload
```

Confirm: `GET http://127.0.0.1:3005/api/health` → 200.

**Terminal 2 — Admin Web**

```powershell
cd admin-web
.\scripts\dev-isolated-uat.ps1
```

Open `http://127.0.0.1:5175` (not 5173 / 5174).

**Mobile**

```powershell
adb reverse tcp:3005 tcp:3005
flutter run -d <device> -t lib/mobile_app/main_mobile.dart `
  --dart-define=API_PORT=3005 `
  --dart-define=API_BASE_URL=http://127.0.0.1:3005
```

---

## Readiness status

| Item | Status |
|------|--------|
| UAT DB `access_uat` | **Created** on facilitator machine (2026-10-23) |
| UAT accounts (1 admin, 2 members, 1 requestor) | **Created** (see `.env.uat.accounts.local`) |
| QA / production preserved | Yes (no reset of `access_waverep_test`) |
| Scenario pack | `UAT_Test_Scenarios.md` |
| Unverified items from integration | Listed in scenarios as **Not pre-verified** |

**Blockers before testers start:** Facilitator must distribute credentials, confirm health checks, and schedule scenarios that require **live media upload** or **new request submission** (not pre-passed in integration).
