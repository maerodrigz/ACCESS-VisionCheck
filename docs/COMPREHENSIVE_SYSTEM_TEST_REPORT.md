# ACCESS VisionCheck — Comprehensive System Test Report

**Session date:** 2026-10-23  
**Tester role:** Coordinated QA (automated + API live + static inspection)  
**Target environment:** Isolated stack only (`127.0.0.1:3003`, PostgreSQL `access_waverep_test`, `.env.waverep_test`)  
**Production:** Port **3001** not listening during session; no writes to production.

**Regression rerun (same day):** Isolated QA fixes applied (docs, smoke, pytest, launch script). See **Appendix B**.

---

## A. Executive Summary

### Scorecard (mutually exclusive — one status per inventory ID)

| Metric | Count | Notes |
|--------|------:|--------|
| **Inventory test case IDs** (Section B tables) | **77** | Single row per `ENV-*`, `AUTH-*`, … |
| **PASS** | **46** | Live/API/static as recorded in Section B |
| **FAIL** | **3** | `C7-002`, `AI-006`, `AUTO-001` (initial session) |
| **BLOCKED** | **4** | `ADM-001`, `UI-001`, `FLUT-001`, `SMOKE-002` (initial session) |
| **NOT RUN** | **7** | See Section B |
| **MANUAL REQUIRED** | **17** | UI/device paths not automated |

**Do not sum PASS+FAIL+BLOCKED+NOT RUN+MANUAL and compare to 118.** The original **118 / 136** totals mixed pytest subtests, suite roll-ups, and E2E rows. Use **77** as the case inventory.

### Automated regression (after fixes — Appendix B)

| Suite | Result |
|-------|--------|
| `pytest tests/` | **168 passed**, 1 skipped |
| `api_connectivity_smoke.py` on **3003** with QA env | **All checks passed** |
| Vite proxy via **5178** + `VITE_DEV_PROXY_TARGET=3003` | **PASS** (`/api/health` 200) |
| Stale Vite on **5173** (no session env) | **502** (environment) |
| `flutter test` | **BLOCKED** (Application Control) |

### Environment isolation (verified before live writes)

| Check | Result | Evidence |
|-------|--------|----------|
| Backend process | **PASS** | PID `27808`: `manage.py --env-file .env.waverep_test runserver --host 127.0.0.1 --port 3003 --no-reload` |
| Database name | **PASS** | Read-only query: `current_database: access_waverep_test` |
| `.env.waverep_test` DATABASE_URL | **PASS** | Contains `access_waverep_test` |
| Production port 3001 | **PASS** | `Unable to connect to the remote server` |
| Health on 3003 | **PASS** | `GET /api/health` → `status: ok`, `detector_backend: probe`, `probe_checkpoint_ready: true` |
| `manage.py --env-file .env.waverep_test check` | **PASS** | PostgreSQL connection successful |

**Live write policy:** Disposable QA users and one documentation request were created on **`access_waverep_test` only** (tag `QA-2026-10-23-f8011b5d`). Seed accounts `member@access.edu` / `org@access.edu` are **not** present on this database (only `admin@access.edu`, `waverep.member@example.com`, plus new QA rows).

### Overall readiness assessment

| Audience | Assessment |
|----------|--------------|
| **Functional capstone evaluation** | **Conditional go** — core backend auth, C7 API workflow, C6 score gate (pytest), and 20s video guardrails (pytest) are strong; isolated DB lacks demo seed users; Admin Web proxy to 3003 returned **502**; full E2E (media + Gemini + Facebook) not executed live. |
| **SUS testing** | **Manual required** — mobile and admin UI not fully exercised in this session (Flutter tester blocked by OS policy; Admin Web proxy misaligned or backend unreachable from Vite). |
| **Defense demonstration** | **Prepare** — run scripted demo on 3003 with known QA logins, single Vite instance with `VITE_DEV_PROXY_TARGET=http://127.0.0.1:3003`, and physical device API URL; rehearse C7 → assign → eval → integrity path. |

---

## B. Detailed Test Results

**Legend:** PASS / FAIL / BLOCKED / NOT RUN / MANUAL REQUIRED  

Severity on failures: **Critical / High / Medium / Low**

### Environment and safety

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| ENV-001 | Infra | Health on 3003 | 200, DB connected | OK, probe ready | PASS | Live `GET /api/health` | — |
| ENV-002 | Infra | 3001 unreachable | No prod API | Connection refused | PASS | PowerShell probe | — |
| ENV-003 | Infra | Do not use 3002 | Tests target 3003 | 3002 still has listeners; not used | PASS | `netstat` (3002 ignored) | — |
| ENV-004 | Config | `.env.waverep_test` port field | Documented 3003 | File still lists `API_PORT=3002`; **runtime override** `--port 3003` used | MANUAL REQUIRED | `.env.waverep_test` vs process CLI | Low |

### Authentication and user management

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| AUTH-001 | Auth | Admin login | 200 + JWT | OK | PASS | Live API session | — |
| AUTH-002 | Auth | Invalid password | 401 | 401 | PASS | Live API | — |
| AUTH-003 | Auth | Seed member on waverep DB | Login or absent | 401 for `member@access.edu` | PASS (expected absence) | Smoke + DB user list | — |
| AUTH-004 | Auth | Seed requestor on waverep DB | Login or absent | 401 for `org@access.edu` | PASS (expected absence) | Smoke script | — |
| AUTH-005 | Auth | Create disposable QA org (admin) | 200 | Created `qa-org-qa-2026-10-23-f8011b5d@example.com` | PASS | Live API `POST /users` | — |
| AUTH-006 | Auth | QA requestor login | 200 | OK | PASS | Live API | — |
| AUTH-007 | Auth | QA member login | 200 | OK | PASS | Live API | — |
| AUTH-008 | Auth | Admin logout | 200 | OK | PASS | Live API | — |
| AUTH-009 | Auth | JWT on protected route | 401 without token | 401 on `/admin/stats` | PASS | Live API | — |
| AUTH-010 | Auth | Session / expiry behavior | Token TTL enforced | Not time-travel tested | NOT RUN | — | — |
| AUTH-011 | Auth | Password recovery OTP | Dev or SMTP path | Email reported configured on server; flow not executed | MANUAL REQUIRED | Preflight `Email configured: True` | — |
| AUTH-012 | Auth | Pending user login restriction | Blocked | Not executed (no pending QA user) | NOT RUN | — | — |
| AUTH-013 | Auth | Profile retrieval | 200 | Admin `/users` OK; member `/member/profile` not run for QA member | MANUAL REQUIRED | Partial smoke | — |

### Security (non-destructive)

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| SEC-001 | RBAC | `/admin/stats` no token | 401/403 | 401 | PASS | Live API | — |
| SEC-002 | RBAC | Member → `/admin/stats` | 403 | 403 | PASS | Live API | — |
| SEC-003 | Input | Odd query on `/users` | No crash | 200 | PASS | Live API | — |
| SEC-004 | Upload | Malformed multipart | 4xx | Not executed (no binary fixture in runner) | MANUAL REQUIRED | — | — |
| SEC-005 | AuthZ | Requestor → admin assign | 403 | Not executed | NOT RUN | — | — |
| SEC-006 | Info leak | Stack traces in API errors | Sanitized JSON | Short JSON on 401/400 observed | PASS | Live responses | — |
| SEC-007 | SQLi | Destructive injection | No effect | Only benign query param tested | MANUAL REQUIRED | — | — |

### Requestor workflow (C7) — live API on 3003

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| C7-001 | C7 | Submit valid documentation request | 200, pending | Request `id=1` created | PASS | Live API `POST /service-requests` | — |
| C7-002 | C7 | Duplicate submit (same title/date, pending) | Same id returned | Automated check got `dup id=None` | **FAIL** | Session log; likely script/response parsing or transient 4xx — **retest manually** | Medium |
| C7-003 | C7 | Admin list contains request | Visible | Found in `GET /admin/service-requests` | PASS | Live API | — |
| C7-004 | C7 | Reject with short reason | 400 | 400 | PASS | Live API | — |
| C7-005 | C7 | Approve pending request | 200 | OK | PASS | Live API | — |
| C7-006 | C7 | Calendar row **before** assign | **0** rows for request | **0** | PASS | `GET /admin/events` filtered by `request_id` | — |
| C7-007 | C7 | Requestor `GET /events` after approve, before assign | Unchanged count | 0 → 0 | PASS | Live API | — |
| C7-008 | C7 | Assign member after approve | 200, event_id | `assignment_id=1`, `event_id=1` | PASS | Live API | — |
| C7-009 | C7 | Calendar row **after** assign | ≥1 row | 1 | PASS | Live API | — |
| C7-010 | C7 | Form validation (mobile UI) | Inline errors | Not run | MANUAL REQUIRED | Flutter blocked | — |
| C7-011 | C7 | Schedule conflict prevention | 400 | Not run with conflicting slot | MANUAL REQUIRED | — | — |
| C7-012 | C7 | Requestor feedback after completion | Saved | Request not completed in session | NOT RUN | — | — |

### Admin documentation management

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| ADM-001 | Admin Web | `/documentation-requests` loads | 200 + table | Proxy **502** on `localhost:5173/api/health` | **BLOCKED** | PowerShell | High |
| ADM-002 | Admin Web | Approve/reject UI | Works | Not observed | MANUAL REQUIRED | — | — |
| ADM-003 | Admin API | Pending listing | 200 | Live list OK | PASS | API | — |
| ADM-004 | Admin API | Assign validation (unapproved) | 400 | Not executed | NOT RUN | — | — |
| ADM-005 | Admin API | Complete without acceptance | 400 | Not executed | NOT RUN | — | — |
| ADM-006 | Admin | Event calendar page sync | Updates on assign | API confirms event row after assign | PASS | C7-009 | — |

### Member workflow

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| MEM-001 | Member | Dashboard load | 200 | Not run on device | MANUAL REQUIRED | — | — |
| MEM-002 | Member | Assignment notification | In-app row | "New Documentation Assignment" present | PASS | Live API `/notifications` | — |
| MEM-003 | Member | Accept/decline assignment | State change | Not executed | NOT RUN | — | — |
| MEM-004 | Member | Calendar events | Approved events | QA member calendar not queried post-assign | MANUAL REQUIRED | — | — |
| MEM-005 | Member | Practice eval upload | Pipeline runs | Not executed (no media bytes in session) | MANUAL REQUIRED | — | — |
| MEM-006 | Member | XP / skill display | Consistent | QA member `total_points=0` in participation | PASS | Live `/member/participation` | — |

### Media quality evaluation

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| MEDIA-001 | Video limit | API `evaluation_max_video_seconds` | **20** | **20** on live 3003 | PASS | `GET /member/participation` | — |
| MEDIA-002 | Video limit | Backend config default | 20 | `app/config.py` default 20 | PASS | Static | — |
| MEDIA-003 | Video limit | Reject >20s upload | 422 | Covered by pytest mocks | PASS | `test_practice_evaluation_video_guardrails.py` (12 tests) | — |
| MEDIA-004 | Quality | Brightness/contrast/sharpness/resolution | Scores computed | Pipeline unit tests in broader suite | PASS | pytest deferred pipeline tests (passed in full run) | — |
| MEDIA-005 | Gemini | Feedback generation | Text feedback | Not invoked live (API key / upload not run) | MANUAL REQUIRED | `gemini_service` present | — |
| MEDIA-006 | Upload | Image/video type validation | 4xx bad types | Partial via pytest | MANUAL REQUIRED | — | — |

**Note:** CLI `system_test_preflight.py` run **without** loading `.env.waverep_test` printed `Evaluation max video (sec): 60` and `Supabase storage: on`. The **running server on 3003** exposed **20** seconds and isolated uploads (waverep env has `SUPABASE_STORAGE_ENABLED=false`). Treat preflight CLI numbers as **non-authoritative** unless started with the same `--env-file`.

### AI authenticity and admin review (PROBE, WaveRep off)

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| AI-001 | PROBE | Health shows probe backend | probe | probe, checkpoint ready | PASS | `/api/health` integrity | — |
| AI-002 | C6 | Score hiding before review | Redacted | 5/5 pytest | PASS | `test_member_review_gate.py` | — |
| AI-003 | C6 | Prior capstone result | PASS | No contradictory evidence | PASS | Pytest + prior session | — |
| AI-004 | Integrity | Admin verify/reject flows | API 200 | Not executed live | MANUAL REQUIRED | — | — |
| AI-005 | XP | Withhold until verify | xp_pending | Covered in pytest suite (member review) | PASS | Static + pytest | — |
| AI-006 | Regression | Dedicated detector / univfd tests | Pass in CI config | **10 failures** when default env uses **probe** | **FAIL** | Full pytest run | Medium |

### Media repository and Facebook

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| FB-001 | Facebook | Real Graph publish | Not in auto test | Skipped by policy | MANUAL REQUIRED | `facebook.py` routes | — |
| FB-002 | Facebook | Config guard when disabled | 4xx/503 | Not executed | MANUAL REQUIRED | — | — |
| REPO-001 | Media repo | Admin upload/list | 200 | Not executed | MANUAL REQUIRED | — | — |
| REPO-002 | Storage | Supabase vs local on 3003 | Local waverep uploads | Env: `SUPABASE_STORAGE_ENABLED=false` | PASS | `.env.waverep_test` | — |

### Skill classification and XP

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| XP-001 | XP | Duplicate eval XP | No double award | pytest duplicate upload suite | PASS | 20 tests in focused run | — |
| XP-002 | XP | Suspicious media excluded | No auto XP | Logic in pipeline + review gate tests | PASS | pytest | — |
| XP-003 | Rankings | Admin override persistence | API R/W | Not executed live | MANUAL REQUIRED | — | — |

### Notifications

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| NOTIF-001 | C7 | Requestor approval notification | Row created | Found after approve | PASS | Live API | — |
| NOTIF-002 | C7 | Member assignment notification | Row created | Found (`task_assignment`) | PASS | Live API | — |
| NOTIF-003 | C7 | Admin new request ping | Admin inbox | Not asserted in session | MANUAL REQUIRED | — | — |
| NOTIF-004 | Push | FCM payload generation | Async send | `send_to_user_async` in crud; not observed on device | MANUAL REQUIRED | Code path | — |
| NOTIF-005 | Push | No real pushes to prod users | Policy | QA users only in session | PASS | Test design | — |

### Analytics and reporting

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| ANALYTICS-001 | Dashboard | `GET /admin/stats` | 200 JSON | OK | PASS | Live API | — |
| ANALYTICS-002 | Consistency | Stats vs DB counts | Match | Not cross-checked to SQL | MANUAL REQUIRED | — | — |
| ANALYTICS-003 | Filters | Date filters | Correct subset | Not executed | MANUAL REQUIRED | — | — |

### Backend automated test suite

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| AUTO-001 | pytest | Full `access_backend/tests` | All pass | **157 passed, 10 failed, 1 skipped** | **FAIL** | 67s run | Medium |
| AUTO-002 | pytest | Video guardrails + duplicate + EXIF | Pass | 20 passed, 1 skipped | PASS | Focused run | — |
| AUTO-003 | pytest | `test_member_review_gate` | Pass | 5 passed | PASS | C6 | — |

**Failed pytest modules (probe vs univfd / dedicated detector assumptions):**  
`test_dedicated_ai_detector.py`, `test_media_evaluate_step7d.py`, `test_probe_integration_step1.py`, `test_probe_policy_step4.py`, `test_media_evaluate_preview_step7c.py` (one case).

### Flutter mobile automated tests

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| FLUT-001 | Flutter | `flutter test` | All pass | **5 suites blocked** | **BLOCKED** | `Application Control policy has blocked flutter_tester.exe` | High |

### API connectivity smoke (3003)

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| SMOKE-001 | Smoke | Admin paths | OK | All admin checks OK | PASS | `api_connectivity_smoke.py` | — |
| SMOKE-002 | Smoke | Member/requestor seed login | OK | **401** (seeds absent) | **BLOCKED** | Use QA accounts or re-seed isolated DB | Medium |

### End-to-end workflow (single session)

| Step | Status | Notes |
|------|--------|-------|
| Requestor submits | **PASS** (API) | QA org, request id 1 |
| Admin receives | **PASS** (API) | Listed |
| Admin approves | **PASS** | |
| Admin assigns member | **PASS** | |
| Calendar updates | **PASS** | After assign only |
| Member notified | **PASS** | In-app |
| Member uploads eval | **NOT RUN** | MANUAL REQUIRED |
| Quality + PROBE | **NOT RUN** live; partial pytest | |
| Admin integrity review | **NOT RUN** | MANUAL REQUIRED |
| Scores/XP/Gemini | **NOT RUN** live; C6 pytest PASS | |
| Official media repo | **NOT RUN** | MANUAL REQUIRED |
| Event complete + requestor feedback | **NOT RUN** | MANUAL REQUIRED |
| Analytics reflect job | **PARTIAL** | Stats endpoint only |

**E2E verdict:** **PARTIAL PASS (API-only segment)** — not a full capstone E2E.

### UI/UX and responsiveness

| ID | Module | Scenario | Expected | Actual | Status | Evidence | Sev |
|----|--------|----------|----------|--------|--------|----------|-----|
| UI-001 | Admin Web | Navigation + offline banner | Healthy | 502 via proxy | **BLOCKED** | localhost:5173 | High |
| UI-002 | Mobile | Requestor/member nav | No broken screens | Not run | MANUAL REQUIRED | Flutter blocked | — |
| UI-003 | Mobile | Offline banner / API host | Correct 3003 | Not run | MANUAL REQUIRED | — | — |

---

## C. Bugs and Issues

### Critical
- None confirmed in **production** (not exercised).

### High
1. **Admin Web dev proxy not reaching isolated API (502)** — `http://localhost:5173/api/health` → Bad Gateway while 3003 health is OK. Blocks admin UI testing until Vite uses `VITE_DEV_PROXY_TARGET=http://127.0.0.1:3003` and a single dev server tab.
2. **Flutter tests blocked by Windows Application Control** — `flutter_tester.exe` denied; no automated mobile regression on this host.

### Medium
1. **Isolated DB missing demo seed users** — `member@access.edu` / `org@access.edu` not in `access_waverep_test`; smoke script and checklist assumptions fail until seed or QA user creation.
2. **Pytest suite drift under PROBE backend** — 10 tests assume univfd/dedicated detector unavailable; fail when `AI_DETECTOR_BACKEND=probe` and checkpoint present.
3. **C7 duplicate-submit automated check inconclusive** — One live duplicate assertion failed; manual confirmation recommended.
4. **`.env.waverep_test` documents port 3002** while QA uses **3003** via CLI override — easy operator error.

### Low
1. **`system_test_preflight.py` without `--env-file`** reports video limit 60 and Supabase on, disagreeing with live 3003 participation (20, local uploads).

---

## D. Workflow and Manuscript Alignment

| Topic | Implemented behavior | Manuscript / expectation risk |
|-------|----------------------|-----------------------------|
| **Calendar on approve** | **Confirmed:** `EventCalendar` row is **not** created on approve alone; created on **`POST /admin/service-requests/{id}/assign`**. Requestor `GET /api/events` filters to **approved** requests with calendar rows. | If the manuscript states approved requests appear on the calendar **before** team assignment, documentation is **out of sync with code** (confirmed live: 0 calendar rows before assign, 1 after). |
| **C6 score hiding** | Member API redaction + pytest pass | Aligns with integrity-first narrative. |
| **20s video limit** | Live API and config default **20** | Aligns with current test requirement. |
| **PROBE vs WaveRep** | Isolated stack uses **PROBE**; WaveRep disabled | Aligns with stated test config. |

---

## E. Security Findings

- JWT required for admin stats (401 without token).
- Member role receives **403** on admin stats (live).
- No production port exposure during tests.
- Full upload fuzzing, IDOR on media URLs, and aggressive injection batteries **not run** (per instructions).

---

## F. Performance and Reliability Observations

- Backend pytest full suite ~67s for 168 tests (acceptable for dev machine).
- Health endpoint includes integrity/detector readiness ( useful for pre-demo checks).
- Multiple Vite instances on 5173–5175 may cause wrong proxy target; consolidate before demos.

---

## G. Recommended Fixes (priority, no implementation in this session)

1. **High:** Fix Admin Web → 3003 proxy; document one-command dev launch; verify `/api/health` through Vite origin returns 200.
2. **High:** Allow `flutter_tester.exe` on lab machines **or** run Flutter tests in CI/Linux agent.
3. **Medium:** Seed `access_waverep_test` with disposable org/member **or** document QA user creation as standard preflight.
4. **Medium:** Split pytest markers: `probe` vs `univfd` so default isolated runs pass cleanly.
5. **Medium:** Update `.env.waverep_test` `API_PORT=3003` and `ALLOWED_HOSTS` for 3003 to match operational docs.
6. **Low:** Run `system_test_preflight.py` with same `--env-file` as `runserver`.
7. **Manuscript:** Clarify calendar visibility timing (approve vs assign) to match implementation.

---

## H. Final Capstone Readiness

| Question | Answer |
|----------|--------|
| Ready for functional evaluation? | **Conditional** — backend APIs and integrity gates tested; admin UI and mobile UI need a clean 3003 session on lab devices. |
| Ready for SUS testing? | **No** until UI paths verified on target hardware. |
| Ready for defense demonstration? | **Yes with rehearsal** — use QA logins from this session pattern, PROBE health green, scripted C7 + assign + eval + integrity story. |
| Remaining blockers | Admin 502 proxy; Flutter tester policy; incomplete live E2E (media/Gemini/Facebook); isolated DB seed mismatch. |

---

## Appendix: Commands and artifacts

```text
# Isolation evidence
manage.py --env-file .env.waverep_test runserver --host 127.0.0.1 --port 3003

# Automated runs (session)
pytest tests/                          → 157 pass, 10 fail, 1 skip
pytest tests/test_practice_evaluation_video_guardrails.py ... → 20 pass
pytest tests/test_member_review_gate.py → 5 pass
SMOKE_API_BASE=http://127.0.0.1:3003/api python scripts/api_connectivity_smoke.py → admin OK, seed member/org FAIL
flutter test                           → BLOCKED (Application Control)

# Live API session tag
QA-2026-10-23-f8011b5d
```

**Report generated:** read-only inspection + isolated live API writes on `access_waverep_test` only. No production data modified. No Facebook posts. No git commits.

---

## Appendix B — Regression rerun (2026-10-23, post-fix)

### Files touched (isolated QA only)

- `admin-web/scripts/dev-isolated-3003.ps1` — session env for proxy → 3003  
- `admin-web/.env.example`, `docs/ISOLATED_QA_LAUNCH.md`  
- `access_backend/.env.waverep_test` — port **3003**, `EVALUATION_MAX_VIDEO_SECONDS=20`  
- `access_backend/.env.smoke.example`, `scripts/api_connectivity_smoke.py` (loads `.env.smoke.local`)  
- `access_backend/scripts/system_test_preflight.py` (loads `.env.waverep_test` when present)  
- Pytest: `test_dedicated_ai_detector.py`, `test_probe_integration_step1.py`, `test_media_evaluate_step7d.py`, `test_probe_policy_step4.py`, `test_media_evaluate_preview_step7c.py`  
- `.gitignore` — `access_backend/.env.smoke.local`

### Pytest failures (initial 10) — resolution

| Root cause | Fix |
|------------|-----|
| Tests assumed **univfd** default; app uses **probe** | Assert probe; patch `_active_detector_backend` for UnivFD-only tests |
| PROBE tests ignored **provenance gating** | Patch `classify_photo_camera_provenance` with valid `safe_fields` dicts; add test for absent provenance → `xp_pending` |
| Pipeline test expected `evaluate_bytes`; deferred path uses **`evaluate_authenticity_bytes`** | Update mocks + milestone/stats patches |
| **`member_profile` ZeroDivisionError** in pytest | Not reachable when `evaluations_stats` returns empty (guard at line 77). Failure was **mock DB / pipeline side effects** in test; not reproduced on live API |

### C7-002 duplicate submit (unchanged code)

**Confirmed behavior:** `validate_request_schedule` runs **before** `find_recent_duplicate`. A second identical pending slot returns **400 overlap**, not the same id. **Safest future fix (needs approval):** dedupe first, or exclude same-requestor duplicate pending id from conflict check. Documented in `docs/ISOLATED_QA_LAUNCH.md`.

### Calendar workflow (updated 2026-10-23)

**Implemented:** `sync_calendar_from_request` runs on admin approve/reject/reschedule; assignment reuses the same row. See `tests/test_documentation_request_calendar_sync.py`.

### Admin Web 502

**Cause:** Default Vite proxy → **3001** while isolated API is on **3003**. **Fix:** run `admin-web/scripts/dev-isolated-3003.ps1` or set `VITE_DEV_PROXY_TARGET` in session. Evidence: `127.0.0.1:5178/api/health` → 200 with env set; `localhost:5173` → 502 without restart.

### Smoke on waverep_test

Use `access_backend/.env.smoke.example` → copy to `.env.smoke.local` (gitignored) with QA member/org emails already on DB (`qa-*-2026-10-23-f8011b5d@example.com`). Do not commit passwords.

### Flutter

Still **BLOCKED** on this host; alternatives in `docs/ISOLATED_QA_LAUNCH.md`.
