<#
.SYNOPSIS
    Detects this PC's current LAN IPv4 address and writes it into
    wild_cat/.env as API_URL=http://<IP>:8000/api/

.DESCRIPTION
    Run this whenever you switch Wi-Fi networks so the Flutter app points at
    the correct backend address. The .env file is bundled at BUILD time, so
    after running this you must rebuild the app (flutter run) for the change
    to take effect.

.PARAMETER Run
    If supplied, launches `flutter run` after updating .env.

.EXAMPLE
    .\set-api-url.ps1
    .\set-api-url.ps1 -Run
#>

param(
    [switch]$Run
)

$ErrorActionPreference = 'Stop'

$envPath = Join-Path $PSScriptRoot 'wild_cat\.env'
if (-not (Test-Path $envPath)) {
    Write-Error "Cannot find $envPath"
    exit 1
}

# --- Detect the active LAN IPv4 address --------------------------------------
# Prefer a Wi-Fi adapter that is Up and has a default gateway; fall back to any
# Up adapter with a gateway (e.g. Ethernet).
$candidate = Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
    Sort-Object { $_.InterfaceAlias -notlike '*Wi-Fi*' } |   # Wi-Fi adapters first
    Select-Object -First 1

if (-not $candidate) {
    Write-Error "No active network adapter with a gateway found. Are you connected to Wi-Fi?"
    exit 1
}

$ip = $candidate.IPv4Address.IPAddress
$adapter = $candidate.InterfaceAlias
$newUrl = "http://${ip}:8000/api/"

Write-Host "Detected adapter : $adapter"
Write-Host "Detected LAN IP  : $ip"
Write-Host "New API_URL      : $newUrl"

# --- Update (or insert) the API_URL line, preserving everything else ---------
$lines = Get-Content $envPath
$found = $false
$updated = foreach ($line in $lines) {
    if ($line -match '^\s*API_URL\s*=') {
        $found = $true
        "API_URL=$newUrl"
    } else {
        $line
    }
}
if (-not $found) {
    $updated = @("API_URL=$newUrl") + $updated
}

Set-Content -Path $envPath -Value $updated -Encoding UTF8
Write-Host "Updated $envPath" -ForegroundColor Green

# --- Optionally rebuild ------------------------------------------------------
if ($Run) {
    Write-Host "Launching flutter run (0.0.0.0 backend must be running)..." -ForegroundColor Cyan
    Push-Location (Join-Path $PSScriptRoot 'wild_cat')
    try { flutter run } finally { Pop-Location }
} else {
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Start the backend so the phone can reach it:"
    Write-Host "       cd backend; python manage.py runserver 0.0.0.0:8000"
    Write-Host "  2. Rebuild the app (the .env is baked in at build time):"
    Write-Host "       cd wild_cat; flutter run"
    Write-Host "  3. Phone and PC must be on the SAME Wi-Fi network."
}
