<#
  01-build.ps1 — ساختِ همهٔ اجزای .NET و ایمیجِ سفارشیِ NodeManager.
    • Mapper/Reducer → publish به‌صورتِ self-contained linux-x64 (netcoreapp3.1)
      در docker\nodemanager\bin تا داخلِ ایمیج کپی شوند.
    • ابزارهای میزبان (Validator/Benchmark/DataGen) → build معمولی (net8.0).
    • سپس ایمیجِ nodemanager با docker compose build ساخته می‌شود.
  پارامتر -NoImage: ساختِ ایمیج را رد می‌کند (وقتی Docker لازم نیست).
#>
param([switch]$NoImage)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
Push-Location $Root
try {
    $nmBin = Join-Path $Root "docker\nodemanager\bin"
    if (Test-Path $nmBin) { Remove-Item -Recurse -Force $nmBin }
    New-Item -ItemType Directory -Force $nmBin | Out-Null

    Write-Host "==> publish Mapper (self-contained linux-x64) ..." -ForegroundColor Cyan
    dotnet publish src\Mapper -c Release -r linux-x64 --self-contained true `
        -p:InvariantGlobalization=true -o "$nmBin\Mapper"
    if ($LASTEXITCODE) { throw "publish Mapper failed" }

    Write-Host "==> publish Reducer (self-contained linux-x64) ..." -ForegroundColor Cyan
    dotnet publish src\Reducer -c Release -r linux-x64 --self-contained true `
        -p:InvariantGlobalization=true -o "$nmBin\Reducer"
    if ($LASTEXITCODE) { throw "publish Reducer failed" }

    Write-Host "==> build host tools (net8.0) ..." -ForegroundColor Cyan
    dotnet build src\Validator -c Release | Out-Null
    dotnet build src\Benchmark -c Release | Out-Null
    dotnet build src\DataGen   -c Release | Out-Null

    if (-not $NoImage) {
        Write-Host "==> docker compose build nodemanager (بِیک‌کردنِ باینری‌ها در ایمیج) ..." -ForegroundColor Cyan
        docker compose -f docker\docker-compose.yml build nodemanager
        if ($LASTEXITCODE) { throw "docker build failed" }
    }
    Write-Host "`n[OK] build کامل شد." -ForegroundColor Green
} finally { Pop-Location }
