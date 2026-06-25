<#
  08-benchmark.ps1 — بخشِ اصلیِ پروژه: ماتریسِ بنچمارک.
  Benchmark (پروژهٔ .NET) را اجرا می‌کند که:
    • برای هر تعدادِ گره در {1,5,10} کلاستر را scale می‌کند،
    • برای هر اندازهٔ split در {64,128,256}MB، job را N بار اجرا و Wall-clock را با Stopwatch می‌گیرد،
    • results\results.csv و نمودارهای Mermaid را در results\charts.md می‌نویسد.
  پیشنهاد: قبل از اجرا، Hive و SQL Server را خاموش کنید تا RAM برای ۱۰ گره آزاد شود:
    docker compose -f docker\docker-compose.yml stop hive-server hive-metastore hive-metastore-postgresql sqlserver
#>
param(
    [string]$Nodes = "1,5,10",
    [string]$Splits = "128,256,512",   # ≥ اندازهٔ بلاک (۱۲۸MB) تا در API قدیمیِ streaming مؤثر باشد → ۸/۴/۲ split
    [int]$Repeats = 3,
    [string]$InputPath = "/data/ecommerce/2019-Oct.csv"   # نه $Input (متغیرِ خودکارِ PowerShell)
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
Push-Location $Root
try {
    dotnet run --project src\Benchmark -c Release -- `
        --nodes $Nodes --splits $Splits --repeats $Repeats `
        --input $InputPath `
        --compose (Join-Path $Root "docker\docker-compose.yml") `
        --out (Join-Path $Root "results\results.csv") `
        --charts (Join-Path $Root "results\charts.md")
} finally { Pop-Location }
Write-Host "`n[OK] نتایج در results\results.csv و نمودارها در results\charts.md" -ForegroundColor Green
