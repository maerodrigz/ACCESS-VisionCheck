# Phase 5: verify isolated QA reachability (no production config changes).
$ErrorActionPreference = "Stop"
Write-Host "=== QA backend (3003) ==="
try {
  $h = Invoke-RestMethod -Uri "http://127.0.0.1:3003/api/health" -TimeoutSec 8
  Write-Host "OK 127.0.0.1:3003 database=$($h.database)"
} catch {
  Write-Host "FAIL 127.0.0.1:3003 $($_.Exception.Message)"
  exit 1
}

Write-Host "=== Admin Vite proxy (5173 -> 3003) ==="
try {
  $v = Invoke-RestMethod -Uri "http://127.0.0.1:5173/api/health" -TimeoutSec 8
  Write-Host "OK localhost:5173/api database=$($v.database)"
} catch {
  Write-Host "SKIP or FAIL Vite proxy: start admin-web with admin-web\scripts\dev-isolated-3003.ps1"
}

Write-Host "=== Flutter emulator URL (host maps 10.0.2.2 -> PC) ==="
Write-Host "Use config/api.waverep3003.json (API_BASE_URL=http://10.0.2.2:3003)"
