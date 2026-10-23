# UAT test scenarios

Use one row per test in **`UAT_Results_Template.md`**.  
**Environment:** UAT API `3005`, Admin Web `5175`, DB `access_uat`.

Legend for pre-integration status:

- **Verified in integration:** Covered by QA reports (behavior expected to work).
- **Not pre-verified:** Must be executed during UAT; do not assume PASS from API-only tests.

---

## Admin scenarios (16)

| Test ID | User role | Task | Expected result | Actual result | PASS/FAIL | Remarks |
|---------|-----------|------|-----------------|---------------|-----------|---------|
| ADM-001 | Admin | Open Admin Web login and sign in with UAT admin account | Dashboard loads; no connection error | | | Verified in integration (Admin Web QA) |
| ADM-002 | Admin | Review dashboard tiles (requests, media integrity, documenters) | Numbers load; no “request failed” banner | | | Verified in integration |
| ADM-003 | Admin | Open **Documentation requests**; filter pending | List loads; can open a request detail | | | |
| ADM-004 | Admin | Approve a **new synthetic** pending request (create via requestor first) | Status becomes approved; calendar row created | | | Requires REQ-003 first |
| ADM-005 | Admin | Assign an approved event to **UAT Member 1** | Assignment saved; member sees event on mobile calendar | | | End-to-end UAT |
| ADM-006 | Admin | Open **Event calendar**; locate assigned event | Event visible with correct date/time | | | |
| ADM-007 | Admin | Open **Media Integrity**; review “Needs action” item | Can open media; verify / reject actions available | | | Do not re-test PATCH on QA AI items |
| ADM-008 | Admin | Open **Media library**; preview an event photo | Image or placeholder loads | | | |
| ADM-009 | Admin | Open **Competency**; search UAT members | Members listed with skill / XP fields | | | |
| ADM-010 | Admin | Open **Analytics** → Overview and Rankings | Charts/tables load; rankings table shows members | | | Verified in integration |
| ADM-011 | Admin | Open **Requester feedback** | Feedback list loads for completed events | | | |
| ADM-012 | Admin | Open **Notification center** | Inbox loads | | | **Not pre-verified** (deep links) |
| ADM-013 | Admin | Open **Account management**; view member status | User list loads | | | |
| ADM-014 | Admin | Try **System configuration** (view branding) | Page loads without error | | | |
| ADM-015 | Admin | Navigate `/evaluations` route | Redirects to Media (no separate eval UI) | | | Known limitation |
| ADM-016 | Admin | Dashboard date filters (if visible) | Changing range updates widgets | | | **Not pre-verified** (MANUAL in QA) |

---

## Member scenarios (12)

| Test ID | User role | Task | Expected result | Actual result | PASS/FAIL | Remarks |
|---------|-----------|------|-----------------|---------------|-----------|---------|
| MEM-001 | Member 1 | Sign in on mobile (UAT API) | Home dashboard loads | | | Use UAT build + port 3005 |
| MEM-002 | Member 1 | Open **Profile** (header avatar) | Name, skill tier, XP visible | | | Verified in integration (QA device) |
| MEM-003 | Member 1 | Open **Rankings** tab | Leaderboard loads; your row visible | | | |
| MEM-004 | Member 1 | Open **Calendar** | Month view; assigned UAT event appears after ADM-005 | | | Depends on ADM-005 |
| MEM-005 | Member 1 | **Accept assignment** for assigned event (if prompted) | Status shows accepted | | | **Not pre-verified** if no pending assign |
| MEM-006 | Member 1 | Open **Evaluate**; upload a **synthetic test photo** | Upload succeeds; evaluation result appears | | | **Not pre-verified** (live upload) |
| MEM-007 | Member 1 | View quality score and AI / review label on new eval | Score or status shown (Good, Needs review, etc.) | | | |
| MEM-008 | Member 1 | Open **Recent evaluations** history | Prior items listed | | | Verified in integration (list labels) |
| MEM-009 | Member 1 | Open **Notifications** (badge) | Inbox opens | | | **Not pre-verified** (deep tap) |
| MEM-010 | Member 2 | Sign in; check **Rankings** and **Profile** | Second member data distinct from Member 1 | | | |
| MEM-011 | Member 1 | Sign out from Profile | Returns to login screen | | | Verified in integration |
| MEM-012 | Member 1 | View eval flagged for AI review (if present) | Withheld / review messaging consistent; XP not inflated | | | **Not pre-verified** (detail screen) |

---

## Requestor scenarios (10)

| Test ID | User role | Task | Expected result | Actual result | PASS/FAIL | Remarks |
|---------|-----------|------|-----------------|---------------|-----------|---------|
| REQ-001 | Requestor | Sign in on mobile | Requestor home loads with overview counts | | | Verified in integration (QA device) |
| REQ-002 | Requestor | Open **Requests** tab; view list filters | Pending / approved / completed tabs work | | | |
| REQ-003 | Requestor | Submit **new synthetic** documentation request (photo coverage) | Validation passes; request appears as pending | | | **Not pre-verified** (full form submit on UAT DB) |
| REQ-004 | Requestor | Open pending request detail | Status and event fields match submission | | | After REQ-003 |
| REQ-005 | Requestor | After admin approval (ADM-004), view **approved** request | Status approved; event on calendar | | | |
| REQ-006 | Requestor | Open **Calendar** | Approved / campus events visible | | | Verified in integration |
| REQ-007 | Requestor | Open completed event detail (after workflow) | Shows completed tracking | | | |
| REQ-008 | Requestor | Open **Feedback**; submit rating for completed event | Feedback saved; appears under submissions | | | Use synthetic text only |
| REQ-009 | Requestor | Open **Gallery** (if event has media) | Gallery loads or empty state | | | |
| REQ-010 | Requestor | Sign out | Login screen shown | | | |

---

## Scenario totals

| Role | Count |
|------|------:|
| Admin | 16 |
| Member | 12 |
| Requestor | 10 |
| **Total** | **38** |

---

## Remaining risks (not pre-verified — do not mark PASS without UAT execution)

From `access_backend/evaluation_results/admin_web_ui_3004_report.md`, `flutter_mobile_3004_report.md`, and integration summaries:

1. **Mobile:** Live **photo/video upload** through full pipeline on UAT build with `API_BASE_URL` pinned.
2. **Mobile:** **Notification** open / deep link behavior.
3. **Mobile:** **Assignment accept** when admin assigns during UAT.
4. **Mobile:** **Confirmed AI** evaluation detail and XP withholding on UI.
5. **Mobile:** **Gallery** tab walkthrough on member and requestor.
6. **Mobile:** QA **APK** with `--dart-define=API_PORT=3005` (Gradle install on facilitator PC).
7. **Admin:** Dashboard **date range filters** (ADM-016).
8. **Admin:** **PDF / export** buttons on analytics (if shown).
9. **Admin:** **Repository** policy (API only; no UI page).
10. **Requestor:** Full **new request** submit on empty UAT DB (REQ-003).
11. **External:** FCM, email, SMS, Facebook remain **disabled** in UAT env unless explicitly approved and configured.

**QA environment (`access_waverep_test`, port 3004):** Preserved for regression; **not** the UAT database. WaveRep **307 XP / Advanced** and AI integrity decisions on QA were not copied to UAT by design (synthetic UAT data only).
