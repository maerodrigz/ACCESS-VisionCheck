# Create access_uat PostgreSQL database and bootstrap schema (does NOT touch access_waverep_test).
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$envExample = ".env.uat_nopush.example"
$envLocal = ".env.uat.local"
if (-not (Test-Path $envLocal)) {
    Copy-Item $envExample $envLocal
    Write-Host "[UAT] Created $envLocal from example. Review DATABASE_URL before continuing."
}

$env:ACCESS_ENV_FILE = (Resolve-Path $envLocal).Path
$dbUrl = (Get-Content $envLocal | Where-Object { $_ -match '^DATABASE_URL=' }) -replace '^DATABASE_URL=', ''
if ($dbUrl -notmatch 'access_uat') {
    throw "DATABASE_URL must use database name access_uat"
}

Write-Host "[UAT] Creating database access_uat if missing (PostgreSQL)..."
python scripts/create_uat_database.py

Write-Host "[UAT] create_tables..."
python manage.py create_tables

Write-Host "[UAT] seed UAT role accounts..."
python scripts/seed_uat_accounts.py

Write-Host "[UAT] Done. Start API: python manage.py runserver --host 127.0.0.1 --port 3005 --no-reload"
Write-Host "[UAT] Admin Web: cd admin-web; .\scripts\dev-isolated-uat.ps1"
