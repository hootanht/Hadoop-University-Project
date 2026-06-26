<#
  02-cluster-up.ps1 — Bring up the cluster and report status.
  Parameters:
    -DataNodes    Number of DataNodes (default 2 — per project specification)
    -NodeManagers Number of NodeManagers (compute nodes; default 1)
#>
param([int]$DataNodes = 2, [int]$NodeManagers = 1)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$compose = Join-Path $Root "docker\docker-compose.yml"
. "$PSScriptRoot\_command-tools.ps1"

Write-Host "==> docker compose up (datanodes=$DataNodes, nodemanagers=$NodeManagers)" -ForegroundColor Cyan
Invoke-LoggedCommand "docker compose -f $compose up -d --scale datanode=$DataNodes --scale nodemanager=$NodeManagers" {
    docker compose -f $compose up -d --scale datanode=$DataNodes --scale nodemanager=$NodeManagers
}
if ($LASTEXITCODE) { throw "compose up failed" }

Write-Host "==> Waiting for NameNode Web UI at http://localhost:50070 ..." -ForegroundColor Cyan
$ok = $false
for ($i = 0; $i -lt 60; $i++) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:50070" -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $ok = $true; break }
    }
    catch { Start-Sleep 3 }
}
if ($ok) { Write-Host "[OK] NameNode UI is up." -ForegroundColor Green }
else { Write-Host "[WARNING] Still not responding; wait a moment and check again." -ForegroundColor Yellow }

Write-Host "`n--- HDFS Report (dfsadmin -report) ---"
Invoke-LoggedCommand "docker exec namenode hdfs dfsadmin -report" {
    docker exec namenode hdfs dfsadmin -report 2>$null |
    Select-String -Pattern "Live datanodes|Configured Capacity|DFS Used|Name:|Decommission" | Select-Object -First 20
}

Write-Host "`n--- YARN Nodes ---"
try {
    Write-CommandLine "Invoke-RestMethod http://localhost:8088/ws/v1/cluster/nodes"
    $nodes = Invoke-RestMethod "http://localhost:8088/ws/v1/cluster/nodes" -TimeoutSec 5
    $running = @($nodes.nodes.node | Where-Object { $_.state -eq 'RUNNING' })
    Write-Host ("RUNNING NodeManagers: {0}" -f $running.Count)
}
catch { Write-Host "(YARN REST not ready yet)" }

Write-Host "`nWeb UIs:" -ForegroundColor Cyan
Write-Host "  HDFS NameNode : http://localhost:50070"
Write-Host "  YARN RM       : http://localhost:8088"
Write-Host "  History       : http://localhost:8188"
Write-Host "  HiveServer2   : http://localhost:10002  (jdbc: localhost:10000)"
