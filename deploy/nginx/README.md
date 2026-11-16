# Nginx — ACCESS API + admin SPA

Template: `deploy/nginx/access` (edit `server_name` and `root` before install).

## Copy to server

```powershell
scp deploy/nginx/access root@YOUR_SERVER:/etc/nginx/sites-available/access
```

Or on the server:

```bash
sudo cp /opt/access_mobile/deploy/nginx/access /etc/nginx/sites-available/access
# Edit server_name / root paths
sudo ln -sf /etc/nginx/sites-available/access /etc/nginx/sites-enabled/access
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

## Notes

- `client_max_body_size 400M` matches large practice video uploads.
- Practice media under `/uploads/images` and `/uploads/videos` is **not** publicly proxied. Streams go through authenticated `/api/...` routes.
- Admin SPA: build `admin-web` → copy `dist/` to `/var/www/access-admin`, then `try_files` fallback handles client routing.
- Prefer same-origin `/api` for admin (leave `VITE_API_BASE_URL` empty or `/api`).

## TLS

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.example.com -d admin.example.com
```

Update `CORS_ORIGINS` and `ALLOWED_HOSTS` in `access_backend/.env` to the HTTPS hostnames.
