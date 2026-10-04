---
inclusion: always
---

# ACCESS VisionCheck — Self-Annealing Notes (Agent)

Read this before changing backend models, routes, or Flutter navigation. These rules exist because we already hit these bugs once.

## 1. Never “temporarily” unregister API routes

**Mistake:** Refactored SQLAlchemy models and left `app/api/routes/__init__.py` with only `auth`, `health`, `users`, `rankings`. Flutter still called `/api/admin/stats` → **404** → dashboard showed “Request failed (404)” and fake demo numbers.

**Rule:** If you change models/CRUD, you must either:
- Keep every route the Flutter app calls **registered** in `api_router`, or
- Update Flutter (`lib/shared/api/*.dart`) in the **same change**, or
- Stub the endpoint with a clear `501` and update the UI — never silent 404.

**Before finishing backend work, run this checklist:**
1. Open `lib/shared/api/admin_api_service.dart` and `auth_service.dart` — list every path.
2. Open `access_backend/app/api/routes/__init__.py` — confirm each path has a router included.
3. Restart server and hit `GET /api/health` plus one authenticated admin route.
4. Tell the user to restart `python manage.py runserver` after route changes.

## 2. Flutter ↔ FastAPI route contract (prefix `/api`)

| Flutter call | Must exist on backend |
|--------------|----------------------|
| `POST /auth/login` | `auth.router` |
| `POST /auth/register` | `auth.router` |
| `GET /admin/stats` | `admin.router` → `/admin/stats` |
| `GET /admin/service-requests` | `admin.router` |
| `PATCH /service-requests/{id}` | `documentation_requests.router` |
| `GET /users` | `users.router` |
| `PATCH /users/{id}/status` | `users.router` |
| `GET /rankings` | `rankings.router` |
| `GET /events` | ⚠️ not registered yet — add before using Events UI |
| `GET /admin/evaluations` | ⚠️ not registered yet |
| `GET /feedback` | ⚠️ not registered yet |

When adding a new screen that calls the API, add the row to this table and implement the route same PR.

## 3. Schema migration ≠ delete old behavior

**Mistake:** New tables (`users.fullname`, `roles`, `documentation_requests`) but CRUD still used `password_hash`, `UserRole` enum, `user_id` → login broke or 500’d.

**Rule:** After changing `app/models/*`:
- Update `app/crud/*`, `app/api/routes/*`, `app/schemas/*` in the same pass.
- Map legacy Flutter field names in API responses when needed (`user_id` → `id`, `name` → `fullname`, `Pending` vs `pending`).
- Run `python create_tables.py` only when schema changes; use `RECREATE_DB=true` only in dev.

## 4. Web admin white screen after login

**Mistake:** `adminBuilder: (_) => const SizedBox.shrink()` in `lib/mobile_app/controllers/app.dart` → admin login succeeded but UI was empty.

**Rule:** On `kIsWeb`, admin must use `WebAdminShell`. Root `lib/main.dart` should route web → `web_admin/main_web.dart`.

## 5. Network / CORS / API host

- Flutter API base: `lib/shared/constants/api_config.dart` → `API_PUBLIC_HOST` in `.env` (default `10.0.22.98`).
- Backend bind: `API_HOST=0.0.0.0`, `API_PORT=3001`.
- CORS must allow Flutter Web dev origins (`localhost:<random_port>`) — see `access_backend/main.py`.
- **404 on LAN IP but 200 on 127.0.0.1** usually means an **old uvicorn process** — restart backend.

## 6. Post-change verification (required)

```bash
# Backend
cd access_backend
python manage.py check
python -c "from main import app; print([r.path for r in app.routes if r.path.startswith('/api')])"

# Login + stats (PowerShell)
# POST /api/auth/login then GET /api/admin/stats with Bearer token
```

Do not mark backend tasks “done” without confirming `/api/admin/stats` returns 200 when logged in as admin.

## 7. When you discover a new failure mode

Add a short bullet to this file (or `docs/SELF_ANNEALING.md`) under **Incident log** so the next session does not repeat it.

### Incident log

- **2025-05:** Disabled routers during DB refactor → dashboard 404.
- **2025-05:** `SizedBox.shrink()` for admin on web → white screen after login.
- **2025-05:** Stale uvicorn on `10.0.22.98` after adding routes → restart required.
- **2026-05:** Facebook admin page red error — `access_backend` not running on `127.0.0.1:3001` → start `manage.py runserver`; global health banner added.
- **2026-05:** Facebook Connect disabled — empty `FacebookConfig.webAppId` → set Meta App ID for web or `--dart-define=FACEBOOK_APP_ID`.
- **2026-05:** Mobile dashboard empty on Android — `api_config.dart` defaulted to a hardcoded LAN IP. Fixed by defaulting Android to the emulator alias `10.0.2.2` and requiring `--dart-define=API_PUBLIC_HOST=<PC LAN IPv4>` for physical phones. Added structured request logging (`developer.log(name: 'ACCESS.api')`) and a tappable mobile offline banner with diagnostics.
- **2026-05:** Login screen leaked demo credentials (admin@access.edu / admin123 etc.) — block removed from `lib/shared/screens/vision_login_screen.dart`. The screen is shared across web admin and mobile, so the credentials were visible to end users on both platforms. Email/password `TextEditingController`s are intentionally not prefilled.
- **2026-05:** Mobile bottom-nav showed "Profile" label with the analytics icon — `_navItems` had 9 entries but `_screen` only mapped 0..6, so slot 6 displayed `_navItems[6].icon` (Analytics) under the "Profile" label. Fixed by trimming `_navItems` to exactly the 7 screens in order (Home, Evaluations, Calendar, Gallery, Feedback, Rankings, Profile) and deleting the dead `_Sidebar` widget.
- **2026-08:** Every member practice eval pinged all admins — `media_pipeline.run_pipeline` called `notify_media_uploaded` on every upload and `notify_ai_detection_alert` when `ai_prob >= 0.18` (human scans store prob up to 0.35). Admins now alert only when detection is `suspicious` or `ai_generated` above `ai_confidence_threshold`, gated by `auto_generate_review_alerts`.
- **2026-08:** Admin competency override lost on next member eval — `recalculate_skill_level` ignored `member_rankings.competency_level_override`. Fixed via `resolve_member_skill_level()`; rankings `skill_level` now returns effective tier; React + Flutter admin read/write override via API only.
- **2026-09:** Facebook bulk publish error (#3) on `POST /{page-id}/albums` — Meta blocks creating Page albums via API for most apps. Bulk publish now uploads into an **existing** Page album (auto-detects "Photos" or set `FACEBOOK_PAGE_ALBUM_ID` in `.env`). Falls back to individual posts if album upload is also blocked.
- **2026-09:** Mobile app opened wrong Facebook Page (`61590008614900` Nono gaming) while admin Graph API posts to ACCESS Page (`1202339146306816`). Keep `FacebookConfig.defaultPageId`, `admin-web/facebookShare.ts`, and `.env FACEBOOK_PAGE_ID` in sync.
- **2026-08:** Every practice eval pinged the member with "Media evaluation completed". Removed; members see score in-app. Member notifications only for AI/suspicious flags + admin review outcomes (verify, reject, policy violation, reupload).

## 10. User-facing copy — plain punctuation

- Do **not** use em dashes (`—`) in strings shown to members or admins. Use commas, periods, or colons instead.
- Missing table/stat values: use `N/A` or `-`, not `—`.
- Number ranges keep en dash (`75–89`) — that is normal typography, not prose style.

## 9. Design tokens — do NOT regress

These tokens live in `lib/shared/themes/theme.dart` and define the entire mobile + web design system. Any UI change MUST use them; no inline hex values for these slots.

| Token | Hex | Purpose |
|----|----|----|
| `kBg` | `0xFFF8FAFC` | Page background |
| `kSurface` | `0xFFFFFFFF` | Card surface |
| `kAccent` | `0xFF0052D4` | Primary icon color — ALL stat/feature card icons + active bottom-nav |
| `kCyan` | `0xFF00C4E8` | ACCESS logo cyan — branding accents, eval heroes |
| `kIconInactive` | `0xFF94A3B8` | Inactive bottom-nav icons + label |
| `kTextPrimary` | `0xFF1E293B` | Main text |
| `kTextSecondary` | `0xFF64748B` | Secondary text |
| `kBorder` | `0xFFE2E8F0` | Card / input borders |

- Feature/stat cards: use `AccessStatCard` from `lib/mobile_app/widgets/stat_card.dart`. Never hand-roll another card body — the radius/padding/shadow/icon-tile contract must stay identical across screens.
- Bottom nav: icons must all be the rounded variants (`Icons.dashboard_rounded`, `Icons.analytics_rounded`, etc.). Active = `kAccent`, inactive = `kIconInactive`. No per-item colors.
- No mixed icon colors (green/purple/orange/brown) on cards. Semantic colors (`kGreen`/`kYellow`/`kRed`) are only for status badges (e.g. "ACTIVE", "Meets standards"), not for card icons.

## 8. Mobile API base URL — DO NOT regress

- `lib/shared/constants/api_config.dart`:
  - Web → `127.0.0.1` (override: `API_WEB_HOST`).
  - Android default → `10.0.2.2` (emulator alias — DO NOT change to a LAN IP).
  - Physical phone → user pastes PC LAN IPv4 from the in-app "Set backend URL" dialog (`ApiConfig.runtimeBaseUrl`, persisted via SharedPreferences) OR developer passes `--dart-define=API_PUBLIC_HOST=192.168.x.x` (or full `API_BASE_URL`).
- NEVER write `localhost` / `127.0.0.1` into the Android default — those resolve to the phone itself.
- `ApiConfig.runtimeBaseUrl.load()` MUST be awaited in `main_mobile.dart` and `main_web.dart` BEFORE `runApp(...)`. Otherwise the first API call uses the wrong default.
- After changing the API host, restart the app (not just hot reload) so the http client picks up the new `baseUrl`.
- Before claiming "mobile shows data": confirm the orange `MobileOfflineBanner` is NOT visible after login. Tap it → "Set backend URL" lets the phone user fix it on-device.
