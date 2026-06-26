<#
  06-run-hive.ps1 — Run the same query with Hive (HiveQL → MapReduce on YARN).
  Copies query.hql to hive-server container and executes with beeline.
  Console output is saved to data\hive_console.txt.
#>
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\_command-tools.ps1"

Write-Host "==> Copying query.hql to hive-server ..." -ForegroundColor Cyan
Invoke-LoggedCommand "docker cp $(Join-Path $Root 'hive\query.hql') hive-server:/query.hql" {
  docker cp (Join-Path $Root "hive\query.hql") hive-server:/query.hql
}

Write-Host "==> Running beeline (may take several minutes; Hive creates a MR job) ..." -ForegroundColor Cyan
Invoke-LoggedCommand "docker exec hive-server beeline -u jdbc:hive2://localhost:10000 --silent=true -f /query.hql" {
  docker exec hive-server beeline -u "jdbc:hive2://localhost:10000" --silent=true -f /query.hql 2>&1 |
  Tee-Object -FilePath (Join-Path $Root "data\hive_console.txt")
}

Write-Host "`n[OK] Hive output saved to data\hive_console.txt" -ForegroundColor Green
