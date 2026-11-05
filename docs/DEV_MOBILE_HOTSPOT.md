# Local development over a phone mobile hotspot

Use this when the **laptop** joins the **phone’s Wi‑Fi hotspot** and the **Flutter app** runs on that same phone. PostgreSQL stays on `localhost` on the laptop only.

## 1. Detect the laptop IPv4 (hotspot)

On Windows, the active adapter is usually **Wi‑Fi** with **Internet** connectivity (ignore VirtualBox Host-Only, VPN, or WSL adapters).

From the repo root:

```powershell
.\scripts\dev-mobile-hotspot.ps1
```

This script:

- Picks the IPv4 on the Internet-connected adapter (example: `10.122.180.169/24`).
- Writes `config/api.json` for Flutter (`--dart-define-from-file`).
- Merges `API_PUBLIC_HOST`, `ALLOWED_HOSTS`, and `CORS_ORIGINS` into `access_backend/.env` (if present).
- Optionally creates a narrow firewall rule with `-AllowFirewall`.

Manual check:

```powershell
Get-NetConnectionProfile | Format-Table InterfaceAlias, IPv4Connectivity, NetworkCategory
Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Wi-Fi |
  Where-Object { $_.IPAddress -notlike '169.254*' } |
  Select-Object IPAddress, PrefixLength
```

Do **not** use `127.0.0.1` on the phone. That address is the phone itself, not the laptop.

## 2. Backend

Ensure `access_backend/.env` includes:

```env
API_HOST=0.0.0.0
API_PORT=3001
DB_HOST=localhost
```

Start (no Flask; FastAPI via uvicorn):

```powershell
cd access_backend
python manage.py runserver
```

`manage.py` prints **Local** (`127.0.0.1`) and **Phone** (`http://<detected-lan-ip>:3001/api/health`).

Restart the server after changing `.env`.

## 3. Flutter (physical Android)

All API calls go through `lib/shared/constants/api_config.dart` (runtime URL, bundled `config/api.json`, or `--dart-define`).

After running the sync script:

```powershell
flutter run -t lib/mobile_app/main_mobile.dart --dart-define-from-file=config/api.json
```

Without recompiling, users can tap the orange **Mobile offline banner** → **Set backend URL** → `http://<laptop-ip>:3001`.

Production URLs are unchanged unless you pass compile-time defines.

## 4. Admin Web (laptop)

Vite proxies `/api` to `http://127.0.0.1:3001` by default (`admin-web/vite.config.ts`). No LAN IP required on the browser.

```powershell
cd admin-web
npm run dev
```

Open `http://127.0.0.1:5173` (or the port Vite prints).

## 5. Windows Firewall

If the phone cannot reach the laptop but `http://<laptop-ip>:3001/api/health` works **on the laptop**, inbound traffic from the hotspot is likely blocked.

Run once (narrow rule, TCP 3001 only):

```powershell
.\scripts\dev-mobile-hotspot.ps1 -AllowFirewall
```

Or manually:

```powershell
New-NetFirewallRule `
  -DisplayName "ACCESS VisionCheck API 3001 (TCP inbound)" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalPort 3001 `
  -Profile Private,Public
```

Do not disable the firewall.

Hotspot networks often show as **Public** in Windows. The rule above includes the Public profile.

## 6. Connection tests

On the **laptop** (after backend is running):

```powershell
$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Wi-Fi |
  Where-Object { $_.IPAddress -notlike '169.254*' }).IPAddress | Select-Object -First 1
Invoke-RestMethod "http://${ip}:3001/api/health"
```

Login smoke test:

```powershell
Invoke-RestMethod -Uri "http://${ip}:3001/api/auth/login" -Method POST `
  -ContentType "application/json" `
  -Body '{"email":"YOUR_ADMIN_EMAIL","password":"YOUR_PASSWORD"}'
```

On the **phone** (Chrome or the app): open `http://<laptop-ip>:3001/api/health` or sign in in the app.

**Verified on this machine (same laptop):** health and login responded with HTTP 200 via the hotspot Wi‑Fi IPv4 while bound to `0.0.0.0:3001`. A test from the physical phone browser was not automated here; run that step locally.

### Hotspot client isolation

Some carriers/phones **block the hotspot host from talking to connected clients** (or vice versa). Symptoms: laptop and phone both online, but the phone cannot open `http://<laptop-ip>:3001`.

Mitigations:

- Enable **USB tethering** and use `adb reverse tcp:3001 tcp:3001` with `API_BASE_URL=http://127.0.0.1:3001` on the device (see `ApiConfig.originalUsbDevBaseUrl`).
- Use a small travel router or home Wi‑Fi where client-to-client traffic is allowed.
- Use the in-app backend URL dialog after any network change.

## 7. PostgreSQL, Supabase, and AI

- **PostgreSQL:** `DB_HOST=localhost` only. Never bind Postgres to `0.0.0.0` for this workflow.
- **Supabase / external APIs:** The laptop uses the phone’s mobile data through the hotspot for outbound HTTPS; keep existing Supabase keys in `access_backend/.env`.

## Quick start checklist

1. Phone hotspot on; laptop connected to it (Wi‑Fi shows Internet).
2. `.\scripts\dev-mobile-hotspot.ps1 -AllowFirewall` (first time on a new network if needed).
3. `cd access_backend; python manage.py runserver`
4. Confirm health on laptop using the printed **Phone** URL.
5. `flutter run -t lib/mobile_app/main_mobile.dart --dart-define-from-file=config/api.json`
6. Confirm sign-in on the phone; check that the offline banner is hidden.
