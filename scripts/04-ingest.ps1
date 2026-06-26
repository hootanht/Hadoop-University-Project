<#
  04-ingest.ps1 — Ingest data into HDFS (Ingestion phase).
  File is read via bind-mount (/data-local in namenode) and loaded with hdfs dfs -put;
  then block distribution is reported.
#>
param([string]$File = "2019-Oct.csv", [string]$HdfsDir = "/data/ecommerce")
$ErrorActionPreference = 'Stop'

Write-Host "==> Creating HDFS path and putting file ..." -ForegroundColor Cyan
docker exec namenode hdfs dfs -mkdir -p $HdfsDir
docker exec namenode bash -c "hdfs dfs -rm -f $HdfsDir/$File 2>/dev/null || true"
docker exec namenode hdfs dfs -put -f /data-local/$File $HdfsDir/
if ($LASTEXITCODE) { throw "hdfs put failed" }

Write-Host "`n--- HDFS Listing ---"
docker exec namenode hdfs dfs -ls -h $HdfsDir

Write-Host "`n--- Block Distribution (fsck) ---"
docker exec namenode hdfs fsck "$HdfsDir/$File" -files -blocks -locations 2>$null |
    Select-String -Pattern "len=|Total blocks|Total size|Average block|replicated" | Select-Object -First 25

Write-Host "`n--- DataNode Summary ---"
docker exec namenode hdfs dfsadmin -report 2>$null |
    Select-String -Pattern "Live datanodes|Name:|DFS Used%|Configured Capacity" | Select-Object -First 20
Write-Host "`n[OK] Ingestion completed." -ForegroundColor Green
