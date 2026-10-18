# ACCESS VisionCheck — System Test Checklist

Use this for formal system testing. Run **Preflight** the day before; execute **Scenarios** during the test session.

## Clean demo clutter (optional, before system test)

Clears **requests, media, events, notifications** and trims **accounts**:

- **Keeps:** admins, `KEEP_USER_EMAILS`, any **real** email (not `member@access.edu`, `org@access.edu`, or sample `@student.ustp.edu.ph` seeds), and any account **registered today** (UTC).
- **Removes:** demo seed accounts and their rows.

Use **`--keep-demo-users`** only if you also want to keep every demo login (no account trimming).

```powershell
cd access_backend
python scripts/reset_operational_data.py --dry-run
$env:RESET_ACCESS_DATA="YES"
python scripts/reset_operational_data.py --confirm
```

Restart the backend after a reset.

---

## Preflight (day before)

| Step | Action | Pass |
|------|--------|------|
| P1 | Postgres running; `cd access_backend && python create_tables.py` (no errors) | ☐ |
| P2 | `python manage.py runserver` on `API_PORT` (default 3001); only **one** process on that port | ☐ |
| P3 | `python scripts/api_connectivity_smoke.py` → all OK (admin, member, requestor) | ☐ |
| P4 | `GET http://127.0.0.1:3001/api/health` → 200 | ☐ |
| P5 | Admin web: `npm run dev` in `admin-web/`; login works | ☐ |
| P6 | Mobile: backend URL set (emulator `10.0.2.2:3001` or phone LAN IP via in-app dialog) | ☐ |
| P7 | `.env`: `EMAIL_ENABLED` + SMTP for registration and password-reset OTP emails | ☐ |
| P8 | SMTP off (dev): registration/reset OTP shows `dev_code` in app + backend console | ☐ |
| P9 | Optional push: Firebase service account + `google-services.json` on Android | ☐ |
| P10 | **Supabase:** `SUPABASE_STORAGE_ENABLED=true`, URL, bucket, service role key file; `SUPABASE_MAX_UPLOAD_MB` ≥ eval upload limit | ☐ |

### Seed accounts (after `create_tables.py`)

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@access.edu | admin123 |
| Member | member@access.edu | member123 |
| Requestor | org@access.edu | org123 |

---

## Scenario A — Admin web

| ID | Steps | Expected | Pass |
|----|-------|----------|------|
| A1 | Login as admin | Dashboard stats load (no 404 banner) | ☐ |
| A2 | Accounts → pending registration | Approve one member and one requestor (or use new registrations from B1) | ☐ |
| A3 | Documentation Requests | List loads; open one request; assign member(s) | ☐ |
| A4 | Member Management | Open profile; deactivate test member (optional: delete uploads) | ☐ |
| A5 | Account Management → Requestor → ⋮ | Deactivate; **Delete permanently** on disposable test account (type email to confirm) | ☐ |
| A6 | Media Integrity | Open flagged item; review metadata / actions | ☐ |
| A7 | Competency | Override skill tier; verify persists on rankings | ☐ |
| A8 | Notifications | Inbox loads; mark read | ☐ |

---

## Scenario B — Registration (mobile or shared login flow)

| ID | Steps | Expected | Pass |
|----|-------|----------|------|
| B1 | Register **member**: OTP → form → submit | Pending message; email received if SMTP on | ☐ |
| B2 | Register **faculty/staff requestor** | Requestor type stored; pending approval | ☐ |
| B3 | Register **organization** requestor | Adviser field; pending approval | ☐ |
| B4 | Admin approve B1–B3 | Approval email if SMTP; user can sign in | ☐ |
| B5 | Reject one pending user | Rejection reason shown on login attempt | ☐ |

---

## Scenario C — Member mobile

| ID | Steps | Expected | Pass |
|----|-------|----------|------|
| C1 | Login approved member | Home data loads; no orange offline banner | ☐ |
| C2 | Practice evaluation (photo or video ≤ max seconds in `.env`) | Score + feedback; no crash | ☐ |
| C3 | Evaluations list / report | Scores visible | ☐ |
| C4 | Remove file (keep score) on one practice eval | File gone; score unchanged | ☐ |
| C5 | Tasks | Accept/respond to assigned task | ☐ |
| C6 | Gallery / events | Media lists load | ☐ |
| C7 | Rankings / profile | Competency and profile load | ☐ |
| C8 | Change password (Account Settings) | Success | ☐ |
| C9 | Forgot password (login) | Email 6-digit OTP; dev code on screen if SMTP off | ☐ |
| C10 | Logout → login again | Server session cleared; login works | ☐ |

---

## Scenario D — Requestor mobile

| ID | Steps | Expected | Pass |
|----|-------|----------|------|
| D1 | Login approved requestor | Dashboard / requests load | ☐ |
| D2 | Create documentation request | Submitted; visible in admin | ☐ |
| D3 | Reschedule / coverage flow (if applicable) | No error | ☐ |
| D4 | Rate assigned members after event | Ratings saved; visible in admin | ☐ |
| D5 | Profile + change password | Works | ☐ |

---

## Scenario E — End-to-end documentation job

| ID | Steps | Expected | Pass |
|----|-------|----------|------|
| E1 | Requestor submits request | Admin sees new request | ☐ |
| E2 | Admin assigns team | Member sees task | ☐ |
| E3 | Member completes coverage | Requestor notified (in-app / push if FCM on) | ☐ |
| E4 | Event media published | Gallery visible to member/requestor as designed | ☐ |
| E5 | Requestor feedback + member ratings | Admin feedback pages show data | ☐ |

---

## Known dev vs production behavior

- **Email OTP (registration + forgot password):** With SMTP on, codes are emailed. With SMTP off, `dev_code` appears in the app and backend console.
- **Single backend instance:** If port 3001 is “in use”, do not start a second `runserver`; restart the existing one.
- **Practice video max length:** Backend `EVALUATION_MAX_VIDEO_SECONDS` (default 30); mobile reads limit from `/member/participation` after login.

---

## If something fails

1. Note **role**, **screen**, and **HTTP status** (mobile: tap offline banner → diagnostics).
2. Restart backend after `.env` or route changes.
3. Full **restart** Flutter app (not hot reload) after auth/API changes.
4. Re-run `python scripts/api_connectivity_smoke.py`.
