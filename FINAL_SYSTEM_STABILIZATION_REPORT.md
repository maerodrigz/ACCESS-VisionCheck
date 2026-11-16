# ACCESS VisionCheck — Final System Stabilization Report

**Date:** 2026-10-23  
**Branch:** `feature/cakelens-video-detection`  
**Git checkpoint:** `stabilization/pre-capstone-2026-10-23` (points at last commit; uncommitted work preserved in working tree)  
**Scope:** Consolidate verified integration fixes, regression safety, release readiness. No production DB reset, no scoring/AI rule changes, no deploy.

---

## 1. Verified fixes already integrated (in working tree)

These match outcomes from isolated QA (`:3004`, `access_waverep_test`) and device UI testing. **Present in source** (modified vs last commit):

### Admin Web (`admin-web/`)

| Area | Fix |
|------|-----|
| Dashboard | Media “Awaiting Review” tile uses same **integrity needs action** count as Media Integrity (`countIntegrityNeedsActionRows`) |
| Dashboard | AI Review Queue loading/skeleton; rankings + AI data in first fetch wave |
| Dashboard | Active Documenters uses effective skill tier from rankings (no fake 100% Amateur) |
| Competency | Members with ranking/activity visible; XP column; sort by points |
| Analytics | Rankings tab shows participation leaderboard; completed events date logic; evaluations in first fetch wave |
| Supporting libs | `dashboard.ts`, `aiDetection.ts`, `competency.ts`, `teamMembers.ts`, `analytics.ts`, `analyticsOverview.ts`, panel/page wiring |

**Evidence:** `access_backend/evaluation_results/admin_web_ui_3004_report.md` — 44 PASS, 0 FAIL after retest.

### Flutter Mobile (`lib/`)

| Area | Fix |
|------|-----|
| `api_config.dart` | Web login/candidate URL fallbacks use compile-time **`port`** (respects `API_PORT=3004`) instead of hardcoded **3001** |
| `vision_login_screen.dart` | Short viewport: hide hero when height &lt; 560px; **SingleChildScrollView** on narrow web layout (280px overflow) |

**Evidence:** `access_backend/evaluation_results/flutter_mobile_3004_report.md` — 38 PASS on device (Infinix + adb reverse); login overflow fix in code.

### Backend

No business-logic changes in this stabilization pass. Prior integration verified APIs on QA without altering production schema on `postgres` / prod `.env`.

### UAT preparation (additive, isolated)

- `access_uat` database + seed scripts + `uat_preparation/*` (does not replace production or QA data).
- Scripts: `create_uat_database.py`, `seed_uat_accounts.py`, `provision_uat_database.ps1`, `dev-isolated-uat.ps1` (port **3005**).

---

## 2. Newly fixed bugs (this stabilization session)

| ID | Issue | Action |
|----|--------|--------|
| — | No new **FAIL** rows in latest Admin/Mobile QA reports | **No additional code fixes required** beyond items in §1 already in working tree |
| — | Ongoing capstone system testing (“minimal issues”) | **No specific defect IDs** supplied; treat as facilitator-tracked in `uat_preparation/UAT_Issue_Log.md` |

**Not duplicated:** Port fallback and Admin dashboard fixes were checked in tree before editing; no second copy applied.

---

## 3. Regression test results

| Check | Result | Notes |
|-------|--------|-------|
| `python manage.py check` (default `.env`, no `ACCESS_ENV_FILE`) | **PASS** | Connects to configured DB (`postgres` on facilitator machine) |
| `pytest tests/` (192 tests) | **PASS** | 192 passed, 1 skipped, ~93s; no failures |
| QA API `:3004` health | **Not run** | Server not listening at report time |
| UAT API `:3005` health | **Not run** | Server not listening at report time |
| Admin Web browser matrix | **Prior PASS** | See admin_web_ui_3004_report (5174 + 3004) |
| Flutter Mobile device matrix | **Prior PASS** | See flutter_mobile_3004_report |
| `flutter test` | **BLOCKED** | Application Control on Windows host (documented in `docs/ISOLATED_QA_LAUNCH.md`) |
| Live Facebook / FCM / email | **Not triggered** | UAT/QA env templates disable; no automated sends |

**API router:** `api_router` prefix `/api`, 26 route groups registered (integration checklist: auth, admin, events, media, etc.).

---

## 4. Remaining manual tests

From integration + UAT scenario packs (do **not** count as PASS until executed):

| Area | Item |
|------|------|
| Admin | Dashboard **date range** filters; **PDF/export** on analytics; `/evaluations` redirect-only (no dedicated eval UI); **Repository** (API-only, no admin page) |
| Mobile | **Live upload** (camera/gallery) on release APK with pinned `API_BASE_URL`; **notification deep links**; **assignment accept** when new task assigned; **confirmed-AI** detail + XP withhold UI; **Gallery** tab full walk |
| Mobile | Install **QA/UAT build** via Gradle (`--dart-define=API_PORT=3005/3004`) |
| UAT | Full **38 scenarios** in `uat_preparation/UAT_Test_Scenarios.md` on `access_uat` |
| Capstone | Current **Admin + Requestor system testing** — log issues in `UAT_Issue_Log.md` |

---

## 5. Known limitations (by design)

- **Media Awaiting Review** tile = **Media Integrity needs action** queue (not unevaluated-upload backlog).
- **Evaluation review route** in Admin Web redirects to Media library.
- **Repository** exclusion rules: backend/API only; no standalone Repository UI.
- **Physical phone** defaults: bundled `config/api.json` LAN URL + runtime URL dialog; use `--dart-define=API_BASE_URL` or in-app backend URL for QA/UAT.
- **Windows desktop** Flutter target requires Visual Studio toolchain (not required for Android/Web).
- **QA vs UAT vs prod ports:** 3004 QA, 3005 UAT, **3001** production default — do not mix proxies.

---

## 6. Production safety verification

| Rule | Status |
|------|--------|
| Production DB not reset | **Yes** — no `RECREATE_DB`, no drop scripts run |
| QA `access_waverep_test` not reset | **Yes** — UAT uses separate `access_uat` |
| Production `.env` not overwritten | **Yes** — only `.env.uat.local` / examples added; gitignored account files |
| Test accounts not hardcoded in app source | **Yes** — UAT seeds via `seed_uat_accounts.py` + local file only |
| Scoring / AI detection rules unchanged | **Yes** — no changes to probe thresholds or XP award logic in this pass |
| Local `config/api.json` | **Uncommitted LAN tweak** (`.97` → `.98:3001`) for dev phones — **do not merge** unless team standardizes IP; production API still from `.env` / server deploy |

**Checkpoint:** Branch `stabilization/pre-capstone-2026-10-23` created at HEAD for rollback reference. **Uncommitted changes remain** (15 tracked files + reports/UAT assets); commit when ready with explicit approval.

---

## 7. Files changed (working tree vs last commit)

**Application source (release candidate diff):**

- `admin-web/src/lib/dashboard.ts`, `aiDetection.ts`, `competency.ts`, `teamMembers.ts`, `analytics.ts`, `analyticsOverview.ts`
- `admin-web/src/components/dashboard/DashboardSep29Panels.tsx`, `analytics/AnalyticsPanels.tsx`, `competency/CompetencyMembersTable.tsx`
- `admin-web/src/pages/DashboardPage.tsx`, `AnalyticsPage.tsx`
- `lib/shared/constants/api_config.dart`, `lib/shared/screens/vision_login_screen.dart`
- `.gitignore` (UAT local env ignores)

**Local / ops (review before commit):**

- `config/api.json` — LAN IP for mobile bundle (environment-specific)
- `access_backend/.env.waverep_nopush_test` — untracked QA env (keep out of git if secrets)
- `access_backend/evaluation_results/*` — test evidence
- `uat_preparation/*`, `admin-web/scripts/dev-isolated-*.ps1`, UAT backend scripts

---

## 8. Final release readiness assessment

| Layer | Readiness | Comment |
|-------|-----------|---------|
| **Backend** | **Ready** | Pytest green; routes intact; no destabilizing changes in this pass |
| **Admin Web** | **Ready for capstone / UAT** | QA UI 44/44 PASS; use isolated dev script (5174/5175), not default 5173→3001 |
| **Flutter Mobile** | **Ready with manual gaps** | Core member/requestor flows verified on device; ship with correct API defines + release APK |
| **Production cutover** | **Not executed** | Requires explicit approval: merge commit, prod `.env`, DB migration plan, no QA data copy |

**Recommended next steps (facilitator):**

1. Commit stabilization diff (exclude `config/api.json` unless team agrees on IP).
2. Run capstone sessions on **UAT 3005** or **QA 3004**, not production **3001**.
3. Complete manual items in §4 and `uat_preparation/UAT_Test_Scenarios.md`.
4. Tag release candidate after sign-off: e.g. `v1.0.0-rc1` (no push without approval).

---

*This report consolidates automated regression, prior integration reports, and codebase inspection. It does not replace facilitator-led UAT sign-off.*
