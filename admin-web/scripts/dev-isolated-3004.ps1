# Session-only Admin Web dev against isolated QA API (port 3004). Does not change production defaults in vite.config.ts.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:VITE_API_BASE_URL = "/api"
$env:VITE_DEV_PROXY_TARGET = "http://127.0.0.1:3004"
Write-Host "[ACCESS] VITE_DEV_PROXY_TARGET=$env:VITE_DEV_PROXY_TARGET"
Write-Host "[ACCESS] Start backend: cd access_backend; `$env:ACCESS_ENV_FILE=(Resolve-Path .env.waverep_nopush_test).Path; python -c `"import uvicorn; uvicorn.run('main:app', host='127.0.0.1', port=3004)`""
npm run dev -- --port 5174 --host 127.0.0.1
