# Administrator only. LAN subnet inbound on TCP 3011 when Wi-Fi is classified Public.
# Use only on trusted home/campus Wi-Fi (same as Private rule scope: LocalSubnet).
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   & "$PSScriptRoot\allow_api_port_3011_firewall_public_lan.ps1"

$ruleName = "ACCESS VisionCheck API 3011 (Public LAN subnet only)"
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Firewall rule already exists: $ruleName"
    exit 0
}

New-NetFirewallRule -DisplayName $ruleName `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 3011 `
    -RemoteAddress LocalSubnet `
    -Profile Public | Out-Null

Write-Host "Added Public-profile LAN-only inbound allow for TCP 3011."
