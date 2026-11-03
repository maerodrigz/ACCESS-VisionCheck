# Run once as Administrator so phones on the same Wi-Fi can reach staging (port 3011).
# Right-click PowerShell -> Run as administrator, then:
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   & "$PSScriptRoot\allow_api_port_3011_firewall.ps1"
#
# Wi-Fi must be "Private" for the Private-profile rule to apply. If Get-NetConnectionProfile
# shows Public, either set the network to Private in Windows Settings, or run the optional
# Public + LocalSubnet block at the bottom of this script (still LAN-only, not internet-wide).

$ruleName = "ACCESS VisionCheck API 3011 (Private LAN)"
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
    -Profile Private, Domain | Out-Null

Write-Host "Added inbound allow for TCP 3011 from LocalSubnet (Private + Domain profiles)."

$profile = Get-NetConnectionProfile -InterfaceAlias "Wi-Fi" -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty NetworkCategory -First 1
if ($profile -eq "Public") {
    Write-Host ""
    Write-Host "NOTE: Wi-Fi is currently Public. The rule above does not apply until the network"
    Write-Host "is Private, OR you add a LAN-only Public rule (uncomment in this script)."
}

# Optional — only if Wi-Fi stays Public and you accept LAN-only inbound on 3011:
# $publicRule = "ACCESS VisionCheck API 3011 (Public LAN subnet only)"
# if (-not (Get-NetFirewallRule -DisplayName $publicRule -ErrorAction SilentlyContinue)) {
#     New-NetFirewallRule -DisplayName $publicRule -Direction Inbound -Action Allow `
#         -Protocol TCP -LocalPort 3011 -RemoteAddress LocalSubnet -Profile Public | Out-Null
#     Write-Host "Added Public-profile LAN-only rule for TCP 3011."
# }
