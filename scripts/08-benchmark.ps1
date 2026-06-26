<#
  08-benchmark.ps1 — Automated Benchmarking across multiple scales.
  Optimized: Protects cluster stability during dynamic node scaling.
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

# AUTOMATED TUNING LAYER: Synchronizes high-density config slots before scaling begins
Write-Host "==> Ensuring high-concurrency slot tuning is applied for benchmark matrix..." -ForegroundColor Yellow
$envFile = Join-Path $Root "docker\hadoop-hive.env"
if (Test-Path $envFile) {
  $content = Get-Content $envFile
  $optimizedSettings = @(
    "YARN_NODEMANAGER_RESOURCE_MEMORY_MB=3072",
    "YARN_NODEMANAGER_RESOURCE_CPU_VCORES=6",
    "YARN_SCHEDULER_MINIMUM_ALLOCATION_MB=256",
    "YARN_SCHEDULER_MAXIMUM_ALLOCATION_MB=3072",
    "MAPREDUCE_MAP_MEMORY_MB=512",
    "MAPREDUCE_MAP_JAVA_OPTS=-Xmx400m",
    "MAPREDUCE_REDUCE_MEMORY_MB=512",
    "MAPREDUCE_REDUCE_JAVA_OPTS=-Xmx400m",
    "YARN_APP_MAPREDUCE_AM_RESOURCE_MB=512",
    "YARN_APP_MAPREDUCE_AM_COMMAND_OPTS=-Xmx400m"
  )
  $filteredContent = $content | Where-Object {
    $_ -notmatch "^(YARN_NODEMANAGER_RESOURCE_MEMORY_MB|YARN_NODEMANAGER_RESOURCE_CPU_VCORES|YARN_SCHEDULER_MINIMUM_ALLOCATION_MB|YARN_SCHEDULER_MAXIMUM_ALLOCATION_MB|MAPREDUCE_MAP_MEMORY_MB|MAPREDUCE_MAP_JAVA_OPTS|MAPREDUCE_REDUCE_MEMORY_MB|MAPREDUCE_REDUCE_JAVA_OPTS|YARN_APP_MAPREDUCE_AM_RESOURCE_MB|YARN_APP_MAPREDUCE_AM_COMMAND_OPTS)="
  }
  $filteredContent + $optimizedSettings | Set-Content $envFile -Force
}

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