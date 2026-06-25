<#
  02-cluster-up.ps1 — بالا آوردنِ کلاستر و گزارشِ وضعیت.
  پارامترها:
    -DataNodes    تعداد DataNode (پیش‌فرض ۲ — مطابقِ صورتِ پروژه)
    -NodeManagers تعداد NodeManager (گرهٔ پردازشی؛ پیش‌فرض ۱)
#>
param([int]$DataNodes = 2, [int]$NodeManagers = 1)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$compose = Join-Path $Root "docker\docker-compose.yml"

Write-Host "==> docker compose up (datanode=$DataNodes, nodemanager=$NodeManagers)" -ForegroundColor Cyan
docker compose -f $compose up -d --scale datanode=$DataNodes --scale nodemanager=$NodeManagers
if ($LASTEXITCODE) { throw "compose up failed" }

Write-Host "==> انتظار برای NameNode Web UI روی http://localhost:50070 ..." -ForegroundColor Cyan
$ok = $false
for ($i = 0; $i -lt 60; $i++) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:50070" -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $ok = $true; break }
    } catch { Start-Sleep 3 }
}
if ($ok) { Write-Host "[OK] NameNode UI بالا است." -ForegroundColor Green }
else { Write-Host "[هشدار] هنوز پاسخ نمی‌دهد؛ کمی صبر کنید و دوباره چک کنید." -ForegroundColor Yellow }

Write-Host "`n--- گزارشِ HDFS (dfsadmin -report) ---"
docker exec namenode hdfs dfsadmin -report 2>$null |
    Select-String -Pattern "Live datanodes|Configured Capacity|DFS Used|Name:|Decommission" | Select-Object -First 20

Write-Host "`n--- گره‌های YARN ---"
try {
    $nodes = Invoke-RestMethod "http://localhost:8088/ws/v1/cluster/nodes" -TimeoutSec 5
    $running = @($nodes.nodes.node | Where-Object { $_.state -eq 'RUNNING' })
    Write-Host ("NodeManagerهای RUNNING: {0}" -f $running.Count)
} catch { Write-Host "(YARN REST هنوز آماده نیست)" }

Write-Host "`nUI ها:" -ForegroundColor Cyan
Write-Host "  HDFS NameNode : http://localhost:50070"
Write-Host "  YARN RM       : http://localhost:8088"
Write-Host "  History       : http://localhost:8188"
Write-Host "  HiveServer2   : http://localhost:10002  (jdbc: localhost:10000)"
