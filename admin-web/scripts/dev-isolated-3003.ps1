# Session-only Admin Web dev against isolated API (port 3003). Does not change production defaults in vite.config.ts.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:VITE_API_BASE_URL = "/api"
$env:VITE_DEV_PROXY_TARGET = "http://127.0.0.1:3003"
Write-Host "[ACCESS] VITE_DEV_PROXY_TARGET=$env:VITE_DEV_PROXY_TARGET"
Write-Host "[ACCESS] Start backend: cd access_backend; python manage.py --env-file .env.waverep_test runserver --host 127.0.0.1 --port 3003"
npm run dev
