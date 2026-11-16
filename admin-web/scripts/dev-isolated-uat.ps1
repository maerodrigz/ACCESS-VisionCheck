# Admin Web dev against UAT API (port 3005). Does not change production Vite defaults.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:VITE_API_BASE_URL = "/api"
$env:VITE_DEV_PROXY_TARGET = "http://127.0.0.1:3005"
Write-Host "[ACCESS UAT] VITE_DEV_PROXY_TARGET=$env:VITE_DEV_PROXY_TARGET"
Write-Host "[ACCESS UAT] Backend: cd access_backend; `$env:ACCESS_ENV_FILE=(Resolve-Path .env.uat.local).Path; python manage.py runserver --host 127.0.0.1 --port 3005 --no-reload"
npm run dev -- --port 5175 --host 127.0.0.1
