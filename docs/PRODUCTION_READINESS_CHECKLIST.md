# Production readiness checklist

## Secrets and environment

- [ ] `APP_ENV=production`
- [ ] Strong `JWT_SECRET` (≥32 chars, not a placeholder)
- [ ] Strong `DB_PASSWORD`; DB not exposed publicly
- [ ] `CORS_ORIGINS` = explicit HTTPS origins (no `*`)
- [ ] `ALLOWED_HOSTS` = explicit hostnames (no `*`)
- [ ] `SMS_PROVIDER` ≠ `log`; TextBee (or equivalent) credentials set
- [ ] `EMAIL_ENABLED=true` with working SMTP
- [ ] Supabase service role only on server (file or env); never in Flutter/admin-web
- [ ] Facebook / Gemini / SMS keys not committed

## TLS and reverse proxy

- [ ] HTTPS certificates installed (certbot or equivalent)
- [ ] HTTP → HTTPS redirect
- [ ] `client_max_body_size` ≥ evaluation upload limit (~400M)
- [ ] Long timeouts on `/api/media/`
- [ ] Practice media not publicly mounted; streams use JWT routes
- [ ] Admin SPA `try_files` fallback configured

## AI / quality

- [ ] `AI_DETECTOR_BACKEND=probe`
- [ ] PROBE checkpoint on disk; `/api/ready` returns ready (or documented degraded mode)
- [ ] `QUALITY_ENGINE=musiq_worker`; worker URL + token set
- [ ] WaveRep enabled only on supported hosts after verify script
- [ ] Thresholds unchanged from approved research values

## Clients

- [ ] Admin built with production API base / same-origin `/api`
- [ ] Flutter release signed with upload keystore (`android/key.properties`)
- [ ] Flutter `--dart-define=API_BASE_URL=https://...`
- [ ] Cleartext HTTP disabled in release (debug LAN still OK)

## Verification

- [ ] `python manage.py check`
- [ ] Backend pytest suite green
- [ ] `npm run build` in admin-web
- [ ] `flutter analyze` / `flutter test` / release build
- [ ] Smoke: login, upload, stream, admin stats, health/ready
