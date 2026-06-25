<#
  03-fetch-data.ps1 — دریافتِ دیتاستِ Kaggle (یا تولیدِ مصنوعی به‌عنوانِ fallback).
  پیش‌فرض: فایلِ 2019-Oct.csv (~۵٫۳ گیگ) از دیتاستِ
    mkechinov/ecommerce-behavior-data-from-multi-category-store
  نیازمندِ توکنِ Kaggle (kaggle.json یا KAGGLE_USERNAME/KAGGLE_KEY).
  پارامترها:
    -UseSynthetic   به‌جای دانلود، با DataGen یک فایلِ ۵ گیگِ مصنوعی می‌سازد.
    -SizeGB         حجمِ فایلِ مصنوعی (پیش‌فرض ۵).
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
    Write-Host "==> تولیدِ دادهٔ مصنوعی (~$SizeGB GB) با DataGen ..." -ForegroundColor Cyan
    dotnet run --project (Join-Path $Root "src\DataGen") -c Release -- --out $target --size-gb $SizeGB
    return
}

# خواندنِ توکن
$user = $env:KAGGLE_USERNAME; $key = $env:KAGGLE_KEY
if (-not $user -or -not $key) {
    $kp = Join-Path $env:USERPROFILE ".kaggle\kaggle.json"
    if (Test-Path $kp) {
        $j = Get-Content $kp -Raw | ConvertFrom-Json
        $user = $j.username; $key = $j.key
    }
}
if (-not $user -or -not $key) {
    Write-Host "[خطا] توکنِ Kaggle یافت نشد. یا kaggle.json را قرار دهید یا -UseSynthetic بزنید." -ForegroundColor Red
    exit 1
}

$zip = "$target.zip"
$url = "https://www.kaggle.com/api/v1/datasets/download/$Dataset/$File"
Write-Host "==> دانلود از Kaggle: $File ..." -ForegroundColor Cyan
curl.exe -L --fail -u "$($user):$($key)" -o $zip $url
if ($LASTEXITCODE) { throw "دانلودِ Kaggle ناموفق بود (توکن/نام فایل را بررسی کنید)." }

Write-Host "==> استخراج ..." -ForegroundColor Cyan
# Kaggle فایلِ تکی را zip می‌کند. اگر zip نبود، همان csv است.
try { Expand-Archive -Path $zip -DestinationPath $data -Force; Remove-Item $zip }
catch { Move-Item -Force $zip $target }

$fi = Get-Item $target
Write-Host ("[OK] {0} — {1:N2} GB" -f $File, ($fi.Length / 1GB)) -ForegroundColor Green
Write-Host "نمونهٔ سه خطِ اول:"
Get-Content $target -TotalCount 3
