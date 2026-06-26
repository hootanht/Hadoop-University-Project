<#
  08-benchmark.ps1 — Main project section: benchmark matrix.
  Runs Benchmark (.NET project) which:
    • For each node count in {1,5,10}, scales the cluster,
    • For each split size in {64,128,256}MB, runs job N times and measures Wall-clock with Stopwatch,
    • Writes results\results.csv and Mermaid charts to results\charts.md.
  Recommendation: Before running, stop Hive and SQL Server to free RAM for 10 nodes:
    docker compose -f docker\docker-compose.yml stop hive-server hive-metastore hive-metastore-postgresql sqlserver
#>
param(
  [string]$Nodes = "1,5,10",
  [string]$Splits = "128,256,512",   # ≥ block size (128MB) to be effective in old streaming API → 8/4/2 splits
  [int]$Repeats = 3,
  [string]$InputPath = "/data/ecommerce/2019-Oct.csv"   # not $Input (PowerShell automatic variable)
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\_command-tools.ps1"
Push-Location $Root
try {
  Invoke-LoggedCommand "dotnet run --project src\Benchmark -c Release -- --nodes $Nodes --splits $Splits --repeats $Repeats --input $InputPath --compose docker\docker-compose.yml --out results\results.csv --charts results\charts.md" {
    dotnet run --project src\Benchmark -c Release -- `
      --nodes $Nodes --splits $Splits --repeats $Repeats `
      --input $InputPath `
      --compose (Join-Path $Root "docker\docker-compose.yml") `
      --out (Join-Path $Root "results\results.csv") `
      --charts (Join-Path $Root "results\charts.md")
  }
}
finally { Pop-Location }
Write-Host "`n[OK] Results in results\results.csv and charts in results\charts.md" -ForegroundColor Green
