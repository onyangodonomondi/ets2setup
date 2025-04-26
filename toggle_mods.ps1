#!/usr/bin/env pwsh
# toggle_mods.ps1 - Toggle ETS2 server mods on/off
# Usage: 
#   .\toggle_mods.ps1 -Enable     # To enable mods
#   .\toggle_mods.ps1             # To disable mods

param([switch]$Enable)

$configFile = "ets2server\server_config.sii"
if (-not (Test-Path $configFile)) {
    Write-Host "Error: Could not find server config at $configFile" -ForegroundColor Red
    exit 1
}

$content = Get-Content $configFile -Raw

if ($Enable) {
    $content = $content -replace "mods_optioning: false", "mods_optioning: true"
    Write-Host "Mods have been ENABLED for the ETS2 server" -ForegroundColor Green
} else {
    $content = $content -replace "mods_optioning: true", "mods_optioning: false"
    Write-Host "Mods have been DISABLED for the ETS2 server" -ForegroundColor Yellow
}

Set-Content -Path $configFile -Value $content

# Create a backup of the modified config
Copy-Item $configFile "$configFile.bak"

Write-Host "Server configuration updated. Restart the server for changes to take effect." 