# ACCESS VisionCheck — Self-Annealing Guide

This document captures mistakes we already made and how to avoid repeating them. It mirrors `.cursor/rules/access-visioncheck-self-anneal.mdc` (Cursor reads that file automatically for the AI agent).

---

## What “self-annealing” means here

Each time something breaks in production or dev, we **write down the cause and a prevention rule**. Future you (and the AI) read this before large refactors so the same bug does not come back.

---

## Incident 1: Dashboard “Request failed (404)”

| | |
|---|---|
| **Symptom** | Orange “Request failed (404)” on admin dashboard; fake demo stats (12, 3, 8…) |
| **Cause** | Flutter called `GET /api/admin/stats` but `admin.router` was removed from `app/api/routes/__init__.py` during a database migration |
| **Fix** | Re-register `admin.router` and `documentation_requests.router`; implement `dashboard_stats()` against new tables |
| **Prevention** | Never merge backend model changes without checking every path in `lib/shared/api/admin_api_service.dart` |

---

## Incident 2: White screen after admin login (Chrome)

| | |
|---|---|
| **Symptom** | Login works; page is completely white |
| **Cause** | `adminBuilder: (_) => const SizedBox.shrink()` in mobile `AccessApp` |
| **Fix** | Use `WebAdminShell` when `kIsWeb`; route `main.dart` to web admin on web |
| **Prevention** | Never use `SizedBox.shrink()` as a placeholder for a real role route |

---

## Incident 3: API works on localhost but not on LAN IP

| | |
|---|---|
| **Symptom** | `10.0.22.98:3001` returns 404 for new routes; `127.0.0.1:3001` works |
| **Cause** | Old backend process still running without new code |
| **Fix** | Stop all Python/uvicorn instances; `python manage.py runserver` again |
| **Prevention** | After route changes, always restart backend and test `GET /api/admin/stats` on the same host Flutter uses |

---

## Incident 10: Mobile app shows empty data — wrong API host

| | |
|---|---|
| **Symptom** | Dashboard/Calendar/Rankings all empty on mobile, even though PostgreSQL has rows; `Cannot reach server at http://10.0.2.2:3001` banner on a **physical phone**. |
| **Cause** | Mobile defaulted to either a hardcoded LAN IP (`10.0.22.98`) or the emulator alias (`10.0.2.2`) when running on a real device. Physical phones cannot route either of those to the PC. |
| **Fix** | 1) Default Android emulator to `10.0.2.2`. 2) Add a runtime override (`ApiConfig.runtimeBaseUrl`) persisted via SharedPreferences. 3) Tappable `MobileOfflineBanner` now opens a dialog with a "Set backend URL" field where the user pastes the PC LAN IPv4 — no rebuild needed. 4) Request/response logging via `developer.log(name: 'ACCESS.api')`. |
| **Prevention** | NEVER hardcode a LAN IP as the Android default. Treat `10.0.2.2` as the emulator default; provide an in-app field for physical phones (and load it BEFORE `runApp`). Compile-time overrides still work via `--dart-define=API_PUBLIC_HOST=<PC LAN IPv4>` or `--dart-define-from-file=config/api.json`. |

### How a phone user fixes "Can't reach backend" without recompiling

1. Tap the orange banner at the top of the screen.
2. Tap **Set backend URL**.
3. Paste the PC's LAN IPv4 (run `ipconfig` on Windows, copy "IPv4 Address" from the Wi-Fi adapter), e.g. `192.168.1.42`.
4. Tap **Save & retry**. The new URL persists across app restarts; tap **Use default** to revert.

### Bootstrapping rule

`ApiConfig.runtimeBaseUrl.load()` MUST be awaited in both entry points before `runApp(...)`:

- `lib/mobile_app/main_mobile.dart`
- `lib/web_admin/main_web.dart`

If the load is skipped, the first request hits the old default and confuses the splash gate.

### Quick recipes

```powershell
# 1) Android emulator on the same PC as the backend (zero config)
flutter run -t lib/mobile_app/main_mobile.dart -d emulator-5554

# 2) Physical phone — first find PC LAN IPv4 with `ipconfig`
# (e.g. 192.168.1.42), then:
flutter run -t lib/mobile_app/main_mobile.dart `
  --dart-define=API_PUBLIC_HOST=192.168.1.42

# 3) Or use the config file (edit `API_PUBLIC_HOST` first):
flutter run -t lib/mobile_app/main_mobile.dart `
  --dart-define-from-file=config/api.json
```

If the mobile app shows the orange banner, tap it — the diagnostic dialog shows the current resolved API URL and platform.

---

## Incident 9: Share opens Facebook in browser (no `pages_manage_posts`)

| | |
|---|---|
| **Symptom** | User does not want Meta Page token / `pages_manage_posts`. |
| **Fix** | **Share to Facebook** opens `https://www.facebook.com/sharer/sharer.php?u=<image_url>` via `url_launcher`. Logs `opened_browser` in `facebook_posts`. Optional server auto-post only if `FACEBOOK_PAGE_ACCESS_TOKEN` is set and `mode=api`. |
| **Note** | Facebook must be able to fetch the image URL (LAN IP may not work off-campus; use public URL or ngrok for previews). |

---

## Incident 8: Share to Facebook shows “Browser blocked”

| | |
|---|---|
| **Symptom** | Gallery loads; Share to Facebook shows red “Browser blocked the request…”. |
| **Cause 1** | `facebook_posts` table missing `message` / `status` columns → POST `/api/facebook/share` returned 500. |
| **Cause 2** | Plain-text 500 body broke `jsonDecode` in Flutter → misreported as browser/CORS error. |
| **Cause 3** | `FACEBOOK_PAGE_ACCESS_TOKEN` empty in `.env` → share cannot call Graph API until set. |
| **Fix** | Run `python create_tables.py` (runs `upgrade_facebook_posts_schema`). Set `FACEBOOK_PAGE_ACCESS_TOKEN` in `.env`. Restart backend. Hot restart Flutter. ApiClient now parses non-JSON errors. |
| **Prevention** | After model changes, run migrations. Configure Facebook token before testing share. |

---

## Incident 7: Gallery error — `/api/admin/media` 500

| | |
|---|---|
| **Symptom** | Gallery shows connection/browser error; backend health OK; service-requests load. |
| **Cause** | `media_crud.list_media()` used `joinedload` on collections without `db.scalars(q).unique()` → SQLAlchemy `InvalidRequestError` → HTTP 500. |
| **Fix** | `return list(db.scalars(q).unique())` in `app/crud/media.py`. Restart backend after change. |
| **Prevention** | Any query with `joinedload` on one-to-many relations must call `.unique()` on the result. |

---

## Incident 6: Backend running but Gallery still “Cannot reach server” (Chrome)

| | |
|---|---|
| **Symptom** | `python manage.py runserver` shows Uvicorn on port 3001; PowerShell `curl http://127.0.0.1:3001/api/health` works; Flutter Web Gallery still red “Cannot reach server”. |
| **Cause** | On Windows, `localhost` often resolves to IPv6 `::1`, but uvicorn only listens on IPv4 — browser shows “failed to fetch” / “Browser blocked the request”. |
| **Fix** | Web admin `baseUrl` must be `http://127.0.0.1:3001` (not `localhost`). Run `flutter run -d chrome --dart-define-from-file=config/api.json`. Full restart (`R`), not hot reload. |
| **Prevention** | Web admin and API should use the same hostname (`localhost` in dev). Test in browser DevTools → Network when a call fails. |

---

## Incident 4: Facebook Integration — “Could not load settings” (backend offline)

| | |
|---|---|
| **Symptom** | Red banner on **System → Facebook Integration**: “Could not load settings” / “Cannot reach server at `http://127.0.0.1:3001`”. Page ID and **Save settings** fail. Share log empty. |
| **Cause** | Flutter Web admin uses `127.0.0.1:3001` (`api_config.dart` when `kIsWeb`). FastAPI (`access_backend`) was not running on port 3001. |
| **Fix** | Start the API before opening Chrome admin: `cd access_backend && python manage.py runserver` (or `scripts/start-backend.ps1` on Windows). Confirm `http://127.0.0.1:3001/api/health` returns `{"status":"ok"}`. Hot restart Flutter if needed; use **Retry** on the global red banner. |
| **Result** | Global **Backend offline** banner in `WebAdminShell` (`backend_offline_banner.dart`) polls `GET /api/health` and shows the start command. Facebook screen error text points to the same command. |
| **Prevention** | Start backend first in every dev session. After backend changes, restart server and hit health on `127.0.0.1` (web) and your LAN IP (phone). |

---

## Incident 5: Facebook — server-side posting only (no admin Integration page)

| | |
|---|---|
| **Symptom** | Admin had a manual Facebook Integration page (connect, page ID, save settings). Users wanted one **Share to Facebook** button only. |
| **Cause** | Earlier design used `flutter_facebook_auth` + `facebook_settings` table for OAuth in the browser. |
| **Fix** | Removed **Facebook Integration** from admin sidebar/routes. Posting uses `app/services/facebook_service.py` + Graph API. Set in `access_backend/.env`: `FACEBOOK_PAGE_ID`, `FACEBOOK_PAGE_ACCESS_TOKEN`. Frontend calls `POST /api/facebook/share` with `{ media_id, message? }`. Every attempt is logged in `facebook_posts` (`status`, `error_message`). Run `python create_tables.py` after schema change (or `RECREATE_DB=true` in dev). |
| **Prevention** | Never put Page Access Tokens in Flutter. Keep credentials in backend `.env` only. |

---

## API contract checklist (update when adding features)

Flutter prefix: `{ApiConfig.baseUrl}/api` (see `lib/shared/constants/api_config.dart`).

| Endpoint | Used by | Backend file |
|----------|---------|----------------|
| `POST /auth/login` | Login | `app/api/routes/auth.py` |
| `GET /admin/stats` | Dashboard | `app/api/routes/admin.py` |
| `GET /admin/service-requests` | Doc requests | `app/api/routes/admin.py` |
| `PATCH /service-requests/{id}` | Approve/reject | `app/api/routes/documentation_requests.py` |
| `GET /users` | Members admin | `app/api/routes/users.py` |
| `PATCH /users/{id}/status` | Member approval | `app/api/routes/users.py` |
| `GET /rankings` | Rankings | `app/api/routes/rankings.py` |
| `GET /admin/media` | Admin media grid | `app/api/routes/admin.py` |
| `GET /admin/evaluations` | Admin quality review | `app/api/routes/admin.py` |
| `GET /admin/ai-detection` | Admin AI queue | `app/api/routes/admin.py` |
| `GET /admin/tasks` | Admin assignments | `app/api/routes/admin.py` |
| `GET /admin/events` | Admin calendar | `app/api/routes/admin.py` |
| `GET /admin/feedback` | Admin feedback | `app/api/routes/admin.py` |
| `GET /member/profile` | Mobile profile | `app/api/routes/member.py` |
| `GET /member/participation` | Profile stats | `app/api/routes/member.py` |
| `GET /tasks` | Assigned tasks | `app/api/routes/tasks.py` |
| `PATCH /tasks/{id}` | Task status | `app/api/routes/tasks.py` |
| `GET /events` | Calendar | `app/api/routes/events.py` |
| `GET /notifications` | Alerts | `app/api/routes/notifications.py` |
| `GET/POST /media` | Gallery upload/list | `app/api/routes/media.py` |
| `GET /evaluations` | Quality scores | `app/api/routes/evaluations.py` |
| `GET/POST /feedback` | Service ratings | `app/api/routes/feedback.py` |
| `POST /facebook/share` | Post to Page via Graph API + log | `app/api/routes/facebook.py` |
| `GET /repository` | Media search | `app/api/routes/archives.py` |
| `GET /health` | Backend reachability | `app/api/routes/health.py` |
| `GET /admin/system-monitor` | System monitor | `app/api/routes/admin_integrations.py` |
| `POST /admin/notifications/broadcast` | Admin broadcast | `app/api/routes/admin_integrations.py` |

Mobile sync: `lib/shared/api/member_api_service.dart` → `member_data_controller.dart` → `app_state` lists refreshed on login and after writes.

---

## Standard workflow after backend changes

1. Edit models → CRUD → routes → register in `__init__.py`.
2. `python manage.py check`
3. Restart server: `python manage.py runserver` (Windows: `scripts/start-backend.ps1`)
4. Log in as `admin@access.edu` / `admin123`
5. Confirm dashboard loads **without** orange 404 text
6. Hot restart Flutter (`R`)

---

## How to extend this doc

When you hit a new bug:

1. Add a row to **Incident log** in `.cursor/rules/access-visioncheck-self-anneal.mdc`
2. Add a section here with symptom → cause → fix → prevention
3. Update the API contract table if a new endpoint was added

---

## Incident 11: Demo credentials shown on the login screen

|||
|---|---|
| **Symptom** | "Demo credentials" panel under the Sign In button listing `admin@access.edu / admin123`, `member@access.edu / member123`, `org@access.edu / org123`. Visible to end users on web admin AND on the mobile app (the screen is shared). |
| **Cause** | `lib/shared/screens/vision_login_screen.dart` had a hardcoded `Container` with the three test accounts and a "PC must run: python manage.py runserver" hint left over from local development. |
| **Fix** | Block removed entirely (lines under the Sign In button). Form column already uses `mainAxisAlignment: MainAxisAlignment.center` so the rest of the content stays vertically balanced — no gap. |
| **Prevention** | Do not commit visible test credentials to the login UI. Test recipes belong in `docs/` (internal). Email/password `TextEditingController`s must stay unseeded — never pass `text: 'admin@...'` to the controllers. |

---

## Incident 12: Mixed icon colors / per-feature accent palettes

|||
|---|---|
| **Symptom** | Profile stat cards (Avg Photo Score, Events Covered, Feedback Given, Completed Tasks) and the service-request type grid used 4–8 different icon colors (blue, cyan, purple, pink, green, amber, orange, red). The bottom nav also gave each tab its own color. Looked inconsistent. |
| **Cause** | Each card hand-rolled its own icon color via inline hex literals. `_NavItem` carried a per-item `Color`. |
| **Fix** | Unified all feature/stat card icons to `kAccent` (`Color(0xFF2563EB)`). Bottom nav uses `kAccent` active / `kIconInactive` (`Color(0xFF94A3B8)`) inactive — see `_MobileBottomNav` in `lib/mobile_app/controllers/app.dart`. `_NavItem` no longer carries a color. Service request tiles in `lib/mobile_app/screens/service_requests_screen.dart` all use `kAccent`. |
| **Prevention** | Always use `AccessStatCard` (`lib/mobile_app/widgets/stat_card.dart`) for any stat/feature card — it defaults to `kAccent`. Never inline a hex color for a card icon. Semantic colors (`kGreen`/`kYellow`/`kRed`) are reserved for status badges ("ACTIVE", "Meets standards"), not card icons. |

---

## Incident 13: Bottom-nav slot/screen index drift

|||
|---|---|
| **Symptom** | The "Profile" bottom-nav tab rendered the Analytics icon (`Icons.analytics_outlined`) under a "Profile" label, and the navigation order looked jumbled. |
| **Cause** | `_navItems` had 9 entries (Dashboard / Evaluations / Calendar / Gallery / Feedback / Rankings / Analytics / Guide / My Profile) but `_screen` in `_MainShellState` only mapped indices 0–6 (last one was `ProfileScreen`). The bottom nav used `_navItems[6]` (Analytics) but `_screen[6]` (Profile), so icon and destination disagreed. |
| **Fix** | Trimmed `_navItems` to exactly 7 entries in the same order as `_screen`: Home (`dashboard_rounded`), Evaluations (`analytics_rounded`), Calendar (`calendar_month_rounded`), Gallery (`photo_library_rounded`), Feedback (`rate_review_rounded`), Rankings (`emoji_events_rounded`), Profile (`person_rounded`). Removed the dead `_Sidebar` widget that referenced `_navItems[7]`. |
| **Prevention** | When adding/removing a mobile module, update `_navItems`, `_screen` (the switch in `_MainShellState`), AND the bottom-nav `slots` tuple in the same change. |

---

## Incident 14: AppCompat `abc_*` missing after `flutter clean`

| | |
|---|---|
| **Symptom** | `processDebugResources` / AAPT2 fails: `error: resource layout/abc_alert_dialog_material not found` (and other `abc_*` anim/layout refs). |
| **Cause** | Not a missing AppCompat dependency. `androidx.appcompat:appcompat:1.1.0` was present via Facebook Login / SharedPreferences. Cursor redirected `GRADLE_USER_HOME` to `Temp\cursor-sandbox-cache\...\gradle`; with `org.gradle.caching=true`, `mergeDebugResources` loaded a corrupt FROM-CACHE merge that kept AppCompat style refs without the matching layout/anim files. |
| **Fix** | Rebuild with real Gradle home (`GRADLE_USER_HOME=%USERPROFILE%\.gradle`) and `:app:processDebugResources --no-build-cache --rerun-tasks`, then `flutter build apk --debug`. Removed duplicate migrator flags in `android/gradle.properties`. |
| **Prevention** | Do not add AppCompat pins until `dependencyInsight` proves absence. Prefer invalidating the bad build-cache entry / using the real Gradle home over wiping the global cache or `flutter clean` loops. |

---

## Database reminders

- Database name: **`access`** (PostgreSQL on `localhost:5432`)
- Create tables: `python create_tables.py`
- Dev reset: `set RECREATE_DB=true` then `python create_tables.py`
- Full schema notes: `access_backend/DATABASE.md`
