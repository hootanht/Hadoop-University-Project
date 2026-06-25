<#
  00-prereqs.ps1 — بررسیِ پیش‌نیازها.
  چک می‌کند: Docker در حالِ اجرا، .NET SDK، curl، فضای دیسک، و وجودِ توکنِ Kaggle.
#>
$ErrorActionPreference = 'Continue'
$Root = Split-Path $PSScriptRoot -Parent
Write-Host "===== بررسیِ پیش‌نیازها =====" -ForegroundColor Cyan

# Docker
try {
    $info = docker info --format '{{.OSType}} NCPU={{.NCPU}} MemBytes={{.MemTotal}}' 2>$null
    Write-Host "[OK] Docker در حالِ اجرا: $info"
} catch { Write-Host "[خطا] Docker در دسترس نیست؛ Docker Desktop را روشن کنید." -ForegroundColor Red }

# .NET
$dn = (dotnet --version) 2>$null
if ($dn) { Write-Host "[OK] dotnet $dn" } else { Write-Host "[خطا] .NET SDK نصب نیست." -ForegroundColor Red }

# curl
if (Get-Command curl.exe -ErrorAction SilentlyContinue) { Write-Host "[OK] curl موجود است (برای دانلودِ Kaggle)." }
else { Write-Host "[هشدار] curl پیدا نشد." -ForegroundColor Yellow }

# Disk
Get-PSDrive C, D -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host ("[disk] {0}: free={1:N1} GB" -f $_.Name, ($_.Free / 1GB))
}
Write-Host "      توجه: کلاسترِ ۱۰‌گره + داده + SQL Server به ~۴۰ گیگ فضای آزاد نیاز دارد."

# Kaggle token
$kagglePath = Join-Path $env:USERPROFILE ".kaggle\kaggle.json"
if ($env:KAGGLE_USERNAME -and $env:KAGGLE_KEY) {
    Write-Host "[OK] توکنِ Kaggle از متغیرهای محیطی خوانده می‌شود."
} elseif (Test-Path $kagglePath) {
    Write-Host "[OK] فایلِ توکنِ Kaggle یافت شد: $kagglePath"
} else {
    Write-Host "[نیاز] توکنِ Kaggle یافت نشد." -ForegroundColor Yellow
    Write-Host "      راه ۱: در https://www.kaggle.com/settings → Create New Token، فایلِ kaggle.json را در $env:USERPROFILE\.kaggle\ قرار دهید."
    Write-Host "      راه ۲: `$env:KAGGLE_USERNAME='...'; `$env:KAGGLE_KEY='...'"
    Write-Host "      جایگزین: اگر توکن ندارید، 03-fetch-data.ps1 -UseSynthetic یک فایلِ ۵ گیگِ مصنوعی می‌سازد."
}
Write-Host "`nآماده. ترتیبِ اجرا: 01-build → 02-cluster-up → 03-fetch-data → 04-ingest → 05-run-mapreduce → 06-run-hive → 07-validate → 08-benchmark"
