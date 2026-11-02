# Run once as Administrator so phones on the same Wi-Fi can reach the API.
# Right-click PowerShell → Run as administrator, then:
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   & "C:\Users\Dell\Desktop\access_mobile\scripts\allow_api_port_3001_firewall.ps1"

$ruleName = "ACCESS VisionCheck API 3001"
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Firewall rule already exists: $ruleName"
    exit 0
}

New-NetFirewallRule -DisplayName $ruleName `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 3001 `
    -Profile Private, Domain | Out-Null

Write-Host "Added inbound allow for TCP 3001 (Private + Domain profiles)."
