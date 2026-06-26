<#
  01-build.ps1 — Build all .NET components and custom NodeManager image.
    • Mapper/Reducer → publish as self-contained linux-x64 (netcoreapp3.1)
      to docker\nodemanager\bin for copying into the image.
    • Host tools (Validator/Benchmark/DataGen) → normal build (net8.0).
    • Then nodemanager image is built with docker compose build.
  Parameter -NoImage: skip image build (when Docker is not needed).
#>
param([switch]$NoImage)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\_command-tools.ps1"
Push-Location $Root
try {
  $nmBin = Join-Path $Root "docker\nodemanager\bin"
  if (Test-Path $nmBin) { Remove-Item -Recurse -Force $nmBin }
  New-Item -ItemType Directory -Force $nmBin | Out-Null

  Write-Host "==> publish Mapper (self-contained linux-x64) ..." -ForegroundColor Cyan
  Invoke-LoggedCommand "dotnet publish src\Mapper -c Release -r linux-x64 --self-contained true -p:InvariantGlobalization=true -o `"$nmBin\Mapper`"" {
    dotnet publish src\Mapper -c Release -r linux-x64 --self-contained true `
      -p:InvariantGlobalization=true -o "$nmBin\Mapper"
  }
  if ($LASTEXITCODE) { throw "publish Mapper failed" }

  Write-Host "==> publish Reducer (self-contained linux-x64) ..." -ForegroundColor Cyan
  Invoke-LoggedCommand "dotnet publish src\Reducer -c Release -r linux-x64 --self-contained true -p:InvariantGlobalization=true -o `"$nmBin\Reducer`"" {
    dotnet publish src\Reducer -c Release -r linux-x64 --self-contained true `
      -p:InvariantGlobalization=true -o "$nmBin\Reducer"
  }
  if ($LASTEXITCODE) { throw "publish Reducer failed" }

  Write-Host "==> build host tools (net8.0) ..." -ForegroundColor Cyan
  Invoke-LoggedCommand "dotnet build src\Validator -c Release" { dotnet build src\Validator -c Release | Out-Null }
  Invoke-LoggedCommand "dotnet build src\Benchmark -c Release" { dotnet build src\Benchmark -c Release | Out-Null }
  Invoke-LoggedCommand "dotnet build src\DataGen -c Release" { dotnet build src\DataGen -c Release | Out-Null }

  if (-not $NoImage) {
    Write-Host "==> docker compose build nodemanager (baking binaries into image) ..." -ForegroundColor Cyan
    Invoke-LoggedCommand "docker compose -f docker\docker-compose.yml build nodemanager" {
      docker compose -f docker\docker-compose.yml build nodemanager
    }
    if ($LASTEXITCODE) { throw "docker build failed" }
  }
  Write-Host "`n[OK] Build completed." -ForegroundColor Green
}
finally { Pop-Location }
