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
. "$PSScriptRoot\_command-tools.ps1"
New-Item -ItemType Directory -Force $data | Out-Null
$target = Join-Path $data $File

if ($UseSynthetic) {
    Write-Host "==> Generating synthetic data (~$SizeGB GB) with DataGen ..." -ForegroundColor Cyan
    Invoke-LoggedCommand "dotnet run --project src\DataGen -c Release -- --out $target --size-gb $SizeGB" {
        dotnet run --project (Join-Path $Root "src\DataGen") -c Release -- --out $target --size-gb $SizeGB
    }
    return
}

# Read token
function Get-KaggleAuth {
    $configDir = if ($env:KAGGLE_CONFIG_DIR) { $env:KAGGLE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".kaggle" }

    if ($env:KAGGLE_API_TOKEN) {
        return @{ Mode = "Bearer"; Token = $env:KAGGLE_API_TOKEN.Trim() }
    }

    $accessTokenPath = Join-Path $configDir "access_token"
    if (Test-Path $accessTokenPath) {
        $token = (Get-Content $accessTokenPath -Raw).Trim()
        if ($token) {
            return @{ Mode = "Bearer"; Token = $token }
        }
    }

    if ($env:KAGGLE_USERNAME -and $env:KAGGLE_KEY) {
        return @{ Mode = "Basic"; Username = $env:KAGGLE_USERNAME; Key = $env:KAGGLE_KEY }
    }

    $legacyPath = Join-Path $configDir "kaggle.json"
    if (Test-Path $legacyPath) {
        $j = Get-Content $legacyPath -Raw | ConvertFrom-Json
        if ($j.username -and $j.key) {
            return @{ Mode = "Basic"; Username = $j.username; Key = $j.key }
        }
    }

    return $null
}

$auth = Get-KaggleAuth
if (-not $auth) {
    Write-Host "[ERROR] Kaggle token not found. Provide KAGGLE_API_TOKEN, ~/.kaggle/access_token, or legacy kaggle.json credentials. Use -UseSynthetic if you do not have Kaggle auth configured." -ForegroundColor Red
    exit 1
}

$zip = "$target.zip"
$url = "https://www.kaggle.com/api/v1/datasets/download/$Dataset/$File"
Write-Host "==> Downloading from Kaggle: $File ..." -ForegroundColor Cyan
if ($auth.Mode -eq "Bearer") {
    Invoke-LoggedCommand "curl.exe -L --fail -H `"Authorization: Bearer ***`" -o $zip $url" {
        & curl.exe -L --fail -H "Authorization: Bearer $($auth.Token)" -o $zip $url
    }
}
else {
    Invoke-LoggedCommand "curl.exe -L --fail -u `"$($auth.Username):***`" -o $zip $url" {
        & curl.exe -L --fail -u "$($auth.Username):$($auth.Key)" -o $zip $url
    }
}
if ($LASTEXITCODE) { throw "Kaggle download failed (check token/filename)." }

Write-Host "==> Extracting ..." -ForegroundColor Cyan
# Kaggle zips single files. If not zipped, it's already csv.
try {
    Write-CommandLine "Expand-Archive -Path $zip -DestinationPath $data -Force"
    Expand-Archive -Path $zip -DestinationPath $data -Force
    Write-CommandLine "Remove-Item $zip"
    Remove-Item $zip
}
catch {
    Write-CommandLine "Move-Item -Force $zip $target"
    Move-Item -Force $zip $target
}

$fi = Get-Item $target
Write-Host ("[OK] {0} — {1:N2} GB" -f $File, ($fi.Length / 1GB)) -ForegroundColor Green
Write-Host "First three lines:"
Get-Content $target -TotalCount 3
