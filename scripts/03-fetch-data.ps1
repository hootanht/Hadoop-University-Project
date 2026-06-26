<#
  03-fetch-data.ps1 — Fetch Kaggle dataset (or generate synthetic as fallback).
  Default: 2019-Oct.csv (~5.3 GB) from dataset
    mkechinov/ecommerce-behavior-data-from-multi-category-store
  Requires Kaggle token (kaggle.json or KAGGLE_USERNAME/KAGGLE_KEY).
  Parameters:
    -UseSynthetic   Instead of downloading, DataGen creates a 5 GB synthetic file.
    -SizeGB         Size of synthetic file (default 5).
#>
param(
    [string]$File = "2019-Oct.csv",
    [string]$Dataset = "mkechinov/ecommerce-behavior-data-from-multi-category-store",
    [switch]$UseSynthetic,
    [double]$SizeGB = 5
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$data = Join-Path $Root "data"
New-Item -ItemType Directory -Force $data | Out-Null
$target = Join-Path $data $File

if ($UseSynthetic) {
    Write-Host "==> Generating synthetic data (~$SizeGB GB) with DataGen ..." -ForegroundColor Cyan
    dotnet run --project (Join-Path $Root "src\DataGen") -c Release -- --out $target --size-gb $SizeGB
    return
}

# Read token
$user = $env:KAGGLE_USERNAME; $key = $env:KAGGLE_KEY
if (-not $user -or -not $key) {
    $kp = Join-Path $env:USERPROFILE ".kaggle\kaggle.json"
    if (Test-Path $kp) {
        $j = Get-Content $kp -Raw | ConvertFrom-Json
        $user = $j.username; $key = $j.key
    }
}
if (-not $user -or -not $key) {
    Write-Host "[ERROR] Kaggle token not found. Either place kaggle.json or use -UseSynthetic." -ForegroundColor Red
    exit 1
}

$zip = "$target.zip"
$url = "https://www.kaggle.com/api/v1/datasets/download/$Dataset/$File"
Write-Host "==> Downloading from Kaggle: $File ..." -ForegroundColor Cyan
curl.exe -L --fail -u "$($user):$($key)" -o $zip $url
if ($LASTEXITCODE) { throw "Kaggle download failed (check token/filename)." }

Write-Host "==> Extracting ..." -ForegroundColor Cyan
# Kaggle zips single files. If not zipped, it's already csv.
try { Expand-Archive -Path $zip -DestinationPath $data -Force; Remove-Item $zip }
catch { Move-Item -Force $zip $target }

$fi = Get-Item $target
Write-Host ("[OK] {0} — {1:N2} GB" -f $File, ($fi.Length / 1GB)) -ForegroundColor Green
Write-Host "First three lines:"
Get-Content $target -TotalCount 3
