<#
  04-ingest.ps1 — Ingest data into HDFS (Ingestion phase).
  File is read via bind-mount (/data-local in namenode) and loaded with hdfs dfs -put;
  then block distribution is reported.
#>
param([string]$File = "2019-Oct.csv", [string]$HdfsDir = "/data/ecommerce")
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_command-tools.ps1"

# Automatically ensure NameNode is out of safe mode before starting
Write-Host "==> Ensuring HDFS is out of Safe Mode..." -ForegroundColor Yellow
docker exec namenode hdfs dfsadmin -safemode leave

Write-Host "==> Creating HDFS path and putting file ..." -ForegroundColor Cyan
Invoke-LoggedCommand "docker exec namenode hdfs dfs -mkdir -p $HdfsDir" { docker exec namenode hdfs dfs -mkdir -p $HdfsDir }
Invoke-LoggedCommand "docker exec namenode hdfs dfs -rm -f $HdfsDir/$File" { docker exec namenode hdfs dfs -rm -f $HdfsDir/$File }
Invoke-LoggedCommand "docker exec namenode hdfs dfs -put -f /data-local/$File $HdfsDir/" { docker exec namenode hdfs dfs -put -f /data-local/$File $HdfsDir/ }
if ($LASTEXITCODE) { throw "hdfs put failed" }

Write-Host "`n--- HDFS Listing ---"
Invoke-LoggedCommand "docker exec namenode hdfs dfs -ls -h $HdfsDir" { docker exec namenode hdfs dfs -ls -h $HdfsDir }

Write-Host "`n--- Block Distribution (fsck) ---"
Invoke-LoggedCommand "docker exec namenode hdfs fsck $HdfsDir/$File -files -blocks -locations" {
    docker exec namenode hdfs fsck $HdfsDir/$File -files -blocks -locations 2>$null |
    Select-String -Pattern "len=|Total blocks|Total size|Average block|replicated" | Select-Object -First 25
}

Write-Host "`n--- DataNode Summary ---"
Invoke-LoggedCommand "docker exec namenode hdfs dfsadmin -report" {
    docker exec namenode hdfs dfsadmin -report 2>$null |
    Select-String -Pattern "Live datanodes|Name:|DFS Used%|Configured Capacity" | Select-Object -First 20
}
Write-Host "`n[OK] Ingestion completed." -ForegroundColor Green