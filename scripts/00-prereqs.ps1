<#
  00-prereqs.ps1 — Prerequisites check.
  Checks: Docker running, .NET SDK, curl, disk space, and Kaggle token presence.
#>
$ErrorActionPreference = 'Continue'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\_command-tools.ps1"
Write-Host "===== Prerequisites Check =====" -ForegroundColor Cyan

# Docker
try {
    $info = Invoke-LoggedCommand "docker info --format '{{.OSType}} NCPU={{.NCPU}} MemBytes={{.MemTotal}}'" {
        docker info --format '{{.OSType}} NCPU={{.NCPU}} MemBytes={{.MemTotal}}' 2>$null
    }
    Write-Host "[OK] Docker is running: $info"
}
catch { Write-Host "[ERROR] Docker is not available; start Docker Desktop." -ForegroundColor Red }

# .NET
$dn = Invoke-LoggedCommand "dotnet --version" { (dotnet --version) 2>$null }
if ($dn) { Write-Host "[OK] dotnet $dn" } else { Write-Host "[ERROR] .NET SDK not installed." -ForegroundColor Red }

# curl
if (Get-Command curl.exe -ErrorAction SilentlyContinue) { Write-Host "[OK] curl is available (for Kaggle downloads)." }
else { Write-Host "[WARNING] curl not found." -ForegroundColor Yellow }

# Disk
Get-PSDrive C, D -ErrorAction SilentlyContinue | ForEach-Object {
    Write-CommandLine ("Get-PSDrive {0}" -f $_.Name)
    Write-Host ("[disk] {0}: free={1:N1} GB" -f $_.Name, ($_.Free / 1GB))
}
Write-Host "      Note: 10-node cluster + data + SQL Server requires ~40 GB free disk space."

# Kaggle token
$kaggleConfigDir = if ($env:KAGGLE_CONFIG_DIR) { $env:KAGGLE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".kaggle" }
$kaggleAccessTokenPath = Join-Path $kaggleConfigDir "access_token"
$kaggleLegacyTokenPath = Join-Path $kaggleConfigDir "kaggle.json"
if ($env:KAGGLE_API_TOKEN) {
    Write-Host "[OK] Kaggle API token read from KAGGLE_API_TOKEN."
}
elseif (Test-Path $kaggleAccessTokenPath) {
    Write-Host "[OK] Kaggle API token file found: $kaggleAccessTokenPath"
}
elseif ($env:KAGGLE_USERNAME -and $env:KAGGLE_KEY) {
    Write-Host "[OK] Kaggle legacy token read from environment variables."
}
elseif (Test-Path $kaggleLegacyTokenPath) {
    Write-Host "[OK] Kaggle legacy token file found: $kaggleLegacyTokenPath"
}
else {
    Write-Host "[REQUIRED] Kaggle token not found." -ForegroundColor Yellow
    Write-Host "      Method 1: At https://www.kaggle.com/settings/api, copy the API token and set `$env:KAGGLE_API_TOKEN='...' or save it to $kaggleAccessTokenPath"
    Write-Host "      Method 2: Legacy auth still works with `$env:KAGGLE_USERNAME='...'; `$env:KAGGLE_KEY='...' or by placing kaggle.json in $kaggleLegacyTokenPath"
    Write-Host "      Alternative: If you don't have a token, 03-fetch-data.ps1 -UseSynthetic creates a 5 GB synthetic file."
}
Write-Host "`nReady. Execution order: 01-build → 02-cluster-up → 03-fetch-data → 04-ingest → 05-run-mapreduce → 06-run-hive → 07-validate → 08-benchmark"
