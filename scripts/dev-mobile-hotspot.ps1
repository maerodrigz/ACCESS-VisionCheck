# Sync ACCESS VisionCheck dev URLs for phone hotspot / LAN testing.
# Detects the laptop IPv4 on the adapter with Internet access (not VirtualBox/VPN).
#
# Usage (from repo root):
#   .\scripts\dev-mobile-hotspot.ps1
#   .\scripts\dev-mobile-hotspot.ps1 -Port 3001 -SkipEnv
#   .\scripts\dev-mobile-hotspot.ps1 -AllowFirewall

param(
  [int]$Port = 3001,
  [switch]$SkipEnv,
  [switch]$AllowFirewall,
  [string]$InterfaceAlias = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

function Get-DevLanIPv4 {
  param([string]$PreferredAlias)

  if ($PreferredAlias) {
    $ips = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $PreferredAlias -ErrorAction SilentlyContinue |
      Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" }
    if ($ips) {
      return ($ips | Sort-Object -Property PrefixLength -Descending | Select-Object -First 1).IPAddress
    }
  }

  $online = Get-NetConnectionProfile | Where-Object { $_.IPv4Connectivity -eq "Internet" }
  foreach ($prof in $online) {
    $alias = $prof.InterfaceAlias
    if ($alias -match "VirtualBox|VMware|Hyper-V|Loopback|TAP|TUN|WSL") { continue }
    $ips = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $alias -ErrorAction SilentlyContinue |
      Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" }
    if ($ips) {
      return ($ips | Sort-Object -Property PrefixLength -Descending | Select-Object -First 1).IPAddress
    }
  }

  throw "No active IPv4 address found on an Internet-connected adapter. Connect the laptop to the phone hotspot first."
}

function Merge-CommaList {
  param([string]$Existing, [string[]]$Add)
  $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($part in ($Existing -split ",")) {
    $t = $part.Trim()
    if ($t) { [void]$set.Add($t) }
  }
  foreach ($a in $Add) {
    $t = $a.Trim()
    if ($t) { [void]$set.Add($t) }
  }
  return ($set | ForEach-Object { $_ }) -join ","
}

function Update-DotEnvKey {
  param([string]$Path, [string]$Key, [string]$Value)
  if (-not (Test-Path $Path)) { return $false }
  $lines = Get-Content $Path -Encoding UTF8
  $found = $false
  $out = foreach ($line in $lines) {
    if ($line -match "^\s*$([regex]::Escape($Key))\s*=") {
      $found = $true
      "$Key=$Value"
    } else { $line }
  }
  if (-not $found) { $out += "$Key=$Value" }
  Set-Content -Path $Path -Value $out -Encoding UTF8
  return $true
}

function Append-DotEnvCommaKey {
  param([string]$Path, [string]$Key, [string[]]$Entries)
  if (-not (Test-Path $Path)) { return $false }
  $lines = Get-Content $Path -Encoding UTF8
  $out = foreach ($line in $lines) {
    if ($line -match "^\s*$([regex]::Escape($Key))\s*=(.*)$") {
      $merged = Merge-CommaList -Existing $Matches[1] -Add $Entries
      "$Key=$merged"
    } else { $line }
  }
  Set-Content -Path $Path -Value $out -Encoding UTF8
  return $true
}

$ip = Get-DevLanIPv4 -PreferredAlias $InterfaceAlias
$base = "http://${ip}:$Port"
$apiJsonPath = Join-Path $root "config\api.json"
$examplePath = Join-Path $root "config\api.json.example"

Write-Host ""
Write-Host "ACCESS VisionCheck — mobile hotspot dev sync" -ForegroundColor Cyan
Write-Host "  Detected laptop IPv4: $ip"
Write-Host "  Backend base URL:     $base"
Write-Host ""

@{
  API_BASE_URL = $base
} | ConvertTo-Json | Set-Content -Path $apiJsonPath -Encoding UTF8
Write-Host "Updated $apiJsonPath"

if (-not $SkipEnv) {
  $envPath = Join-Path $root "access_backend\.env"
  if (Test-Path $envPath) {
    Update-DotEnvKey -Path $envPath -Key "API_PUBLIC_HOST" -Value $ip | Out-Null
    Update-DotEnvKey -Path $envPath -Key "API_HOST" -Value "0.0.0.0" | Out-Null
    Update-DotEnvKey -Path $envPath -Key "API_PORT" -Value "$Port" | Out-Null
    Append-DotEnvCommaKey -Path $envPath -Key "ALLOWED_HOSTS" -Entries @(
      $ip, "${ip}:$Port", "localhost", "127.0.0.1", "localhost:$Port", "127.0.0.1:$Port"
    ) | Out-Null
    Append-DotEnvCommaKey -Path $envPath -Key "CORS_ORIGINS" -Entries @(
      $base, "http://127.0.0.1:$Port", "http://localhost:$Port", "http://127.0.0.1", "http://localhost"
    ) | Out-Null
    Write-Host "Merged API_PUBLIC_HOST, ALLOWED_HOSTS, and CORS_ORIGINS in access_backend\.env"
    Write-Host "Restart the backend if it is already running."
  } else {
    Write-Host "No access_backend\.env — copy access_backend\.env.example first." -ForegroundColor Yellow
  }
}

if ($AllowFirewall) {
  $ruleName = "ACCESS VisionCheck API $Port (TCP inbound)"
  $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
  if (-not $existing) {
    New-NetFirewallRule `
      -DisplayName $ruleName `
      -Direction Inbound `
      -Action Allow `
      -Protocol TCP `
      -LocalPort $Port `
      -Profile Private,Public | Out-Null
    Write-Host "Created firewall rule: $ruleName (Private + Public profiles)"
  } else {
    Write-Host "Firewall rule already exists: $ruleName"
  }
} else {
  Write-Host "Tip: if the phone cannot connect, re-run with -AllowFirewall to allow TCP $Port inbound."
}

Write-Host ""
Write-Host "Start backend:" -ForegroundColor Green
Write-Host "  cd access_backend"
Write-Host "  python manage.py runserver"
Write-Host ""
Write-Host "Start Flutter on the physical phone:" -ForegroundColor Green
Write-Host "  flutter run -t lib/mobile_app/main_mobile.dart --dart-define-from-file=config/api.json"
Write-Host ""
Write-Host "Or set URL on device: Mobile offline banner -> Set backend URL -> $base"
Write-Host ""
Write-Host "Admin Web (laptop only, uses localhost proxy):" -ForegroundColor Green
Write-Host "  cd admin-web"
Write-Host "  npm run dev"
Write-Host ""

# Quick local reachability test (same machine; not a substitute for phone test).
try {
  $health = Invoke-RestMethod -Uri "$base/api/health" -TimeoutSec 5
  Write-Host "Health check via LAN IP: OK (status=$($health.status))" -ForegroundColor Green
} catch {
  Write-Host "Health check via LAN IP failed: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Ensure backend is running and bound to 0.0.0.0:$Port"
}

if (-not (Test-Path $examplePath)) {
  @{ API_BASE_URL = "http://<LAPTOP_LAN_IPV4>:3001" } | ConvertTo-Json | Set-Content $examplePath
}
