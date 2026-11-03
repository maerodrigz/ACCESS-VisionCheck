# Phase 6: Physical Android → Staging Backend (3011)

Date: 2026-11-04

## What interrupted the prior session

1. **Gradle OOM** on `flutter run` (`java.lang.OutOfMemoryError` during `assembleDebug`).
2. **Long `flutter build apk`** was started to fix heap (`android/gradle.properties` → 4096m); the chat/tool session **timed out** while Gradle was still on `assembleDebug` (build may still be running in a background terminal).
3. **`config/api.skillprogression_staging.json`** was written successfully (`API_BASE_URL`: `http://192.168.8.99:3011`).

Backend and network diagnosis were **complete** before the interrupt; device login over Wi-Fi was **not** verified end-to-end.

---

## A. Root cause of timeout

| Factor | Status |
|--------|--------|
| Wrong phone URL (`192.168.1.10`) | User-side; correct subnet is `192.168.8.x` |
| Staging bound to `127.0.0.1` only | **Fixed** → `API_HOST=0.0.0.0` in `.env.skillprogression_staging` |
| Missing LAN in `ALLOWED_HOSTS` / CORS | **Fixed** → includes `192.168.8.99` |
| **Windows Firewall + Public Wi-Fi** | **Open blocker** — phone `192.168.8.100` cannot complete TCP to PC `192.168.8.99:3011` (nc timeout on 3001/3011); no VisionCheck firewall rules present; Wi-Fi profile is **Public** (Private-only rules would not apply) |

PC-to-PC tests on `http://192.168.8.99:3011/api/health` succeed; failure is **inbound to the PC from the LAN**, not staging app logic.

---

## B. Backend listening address and port

- **Bind:** `0.0.0.0:3011` (PID 20368, staging uvicorn)
- **Stale listeners:** extra `127.0.0.1:3011` entries in netstat (restart staging after env changes if behavior is odd)
- **DB (live SQL):** `access_skillprogression_staging` / `access_skillprogression_app`
- **Policy:** `SKILL_PROGRESSION_ACTIVE_POLICY=v2`
- **Shared dev:** port **3001** unchanged

---

## C. PC localhost health

**PASS** — `http://127.0.0.1:3011/api/health` → **200**

---

## D. PC LAN health (Wi-Fi IPv4)

**PASS** — PC Wi-Fi: **192.168.8.99/24**; `http://192.168.8.99:3011/api/health` → **200**

LAN login smoke (synthetic staging member, no secrets logged): login OK, participation **policy v2 / configured v2**.

---

## E. Firewall findings and changes

- **Finding:** No `ACCESS VisionCheck*` firewall rules; Wi-Fi **Public**; inbound LAN TCP blocked.
- **Scripts added (not executed as admin — Access denied):**
  - `scripts/allow_api_port_3011_firewall.ps1` — TCP 3011, **LocalSubnet**, Private + Domain
  - `scripts/allow_api_port_3011_firewall_public_lan.ps1` — same scope, **Public** profile (needed while Wi-Fi stays Public)
- **Required user action (Administrator PowerShell):**
  ```powershell
  Set-ExecutionPolicy -Scope Process Bypass -Force
  & "C:\Users\Dell\Desktop\access_mobile\scripts\allow_api_port_3011_firewall_public_lan.ps1"
  ```
  Optionally set Wi-Fi to **Private** and run `allow_api_port_3011_firewall.ps1` instead.

---

## F. Android network configuration

- **INTERNET** + `usesCleartextTraffic` + `network_security_config.xml` — OK for LAN HTTP
- **No hardcoded staging IP** in defaults; use compile-time or runtime URL
- **`config/api.skillprogression_staging.json`** — staging URL only (not default `config/api.json` which remains **3001**)
- **Device:** Infinix X695, `wlan0` **192.168.8.100/24** (same subnet as PC)
- **KnownLanHosts** includes `192.168.8.99` but **default port remains 3001** unless `API_PORT=3011` or `API_BASE_URL` override

---

## G. Files changed (Phase 6, uncommitted)

| File | Change |
|------|--------|
| `access_backend/.env.skillprogression_staging` | `API_HOST=0.0.0.0`, LAN hosts (gitignored) |
| `access_backend/.env.skillprogression_staging.example` | Document LAN bind |
| `access_backend/scripts/provision_skillprogression_staging.py` | Template `0.0.0.0` |
| `access_backend/docs/SKILL_PROGRESSION_V2_STAGING_SETUP.md` | Phone LAN + firewall + USB reverse |
| `config/api.skillprogression_staging.json` | `http://192.168.8.99:3011` |
| `scripts/allow_api_port_3011_firewall.ps1` | New |
| `scripts/allow_api_port_3011_firewall_public_lan.ps1` | New |
| `android/gradle.properties` | JVM heap 4096m (Gradle OOM mitigation) |

---

## H. Android build/run result

| Step | Result |
|------|--------|
| `flutter run` | **FAIL** — Gradle OOM |
| `flutter build apk --debug … --dart-define-from-file=config/api.skillprogression_staging.json` | **IN PROGRESS / NOT CONFIRMED** at last check (long `assembleDebug`) |
| Existing `app-debug.apk` timestamp | 2026-11-04 05:13 — may **not** embed staging URL |

**After build succeeds:**
```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
# or
flutter run -t lib/mobile_app/main_mobile.dart -d 077972522G102891 `
  --dart-define-from-file=config/api.skillprogression_staging.json
```

**USB workaround (firewall unchanged):**
```powershell
adb reverse tcp:3011 tcp:3011
flutter run ... --dart-define=API_BASE_URL=http://127.0.0.1:3011
```

---

## I. Physical phone connectivity (Wi-Fi)

**NOT VERIFIED** — TCP from device to `192.168.8.99:3011` does not return HTTP body (firewall). After admin firewall rule, retest login in app.

---

## J. Staging login and Profile on device

**NOT VERIFIED** on Infinix. Staging API verified from PC via LAN IP only.

---

## K. Remaining blockers

1. **Run firewall script as Administrator** (Public LAN rule while Wi-Fi is Public).
2. **Finish or retry debug APK build** if background Gradle failed again.
3. **Clear wrong runtime URL** on phone if saved: Profile → offline banner → Set backend URL → `http://192.168.8.99:3011`.
4. Confirm staging process: `$env:ACCESS_ENV_FILE = (Resolve-Path access_backend\.env.skillprogression_staging).Path`; `python manage.py runserver --no-reload` in `access_backend`.

**Primary success condition:** Infinix login succeeds against `http://192.168.8.99:3011` over Wi-Fi — pending firewall + on-device test.
