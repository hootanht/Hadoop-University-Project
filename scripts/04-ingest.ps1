<#
  04-ingest.ps1 — واردکردنِ داده به HDFS (مرحلهٔ Ingestion).
  فایل از طریقِ bind-mount (/data-local در namenode) خوانده و با hdfs dfs -put
  وارد می‌شود؛ سپس توزیعِ بلاک‌ها گزارش می‌گردد.
#>
param([string]$File = "2019-Oct.csv", [string]$HdfsDir = "/data/ecommerce")
$ErrorActionPreference = 'Stop'

Write-Host "==> ساختِ مسیرِ HDFS و put ..." -ForegroundColor Cyan
docker exec namenode hdfs dfs -mkdir -p $HdfsDir
docker exec namenode bash -c "hdfs dfs -rm -f $HdfsDir/$File 2>/dev/null || true"
docker exec namenode hdfs dfs -put -f /data-local/$File $HdfsDir/
if ($LASTEXITCODE) { throw "hdfs put failed" }

Write-Host "`n--- فهرستِ HDFS ---"
docker exec namenode hdfs dfs -ls -h $HdfsDir

Write-Host "`n--- توزیعِ بلاک‌ها (fsck) ---"
docker exec namenode hdfs fsck "$HdfsDir/$File" -files -blocks -locations 2>$null |
    Select-String -Pattern "len=|Total blocks|Total size|Average block|replicated" | Select-Object -First 25

Write-Host "`n--- خلاصهٔ DataNodeها ---"
docker exec namenode hdfs dfsadmin -report 2>$null |
    Select-String -Pattern "Live datanodes|Name:|DFS Used%|Configured Capacity" | Select-Object -First 20
Write-Host "`n[OK] Ingestion کامل شد." -ForegroundColor Green
