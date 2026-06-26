<#
  04-ingest.ps1 — Ingest data into HDFS (Ingestion phase).
  Optimized with Strategy 2: Fast container-native I/O + HDFS tuning parameters.
#>
param([string]$File = "2019-Oct.csv", [string]$HdfsDir = "/data/ecommerce")
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_command-tools.ps1"

# Automatically ensure NameNode is out of safe mode before starting
Write-Host "==> Ensuring HDFS is out of Safe Mode..." -ForegroundColor Yellow
docker exec namenode hdfs dfsadmin -safemode leave

Write-Host "==> Preparing HDFS directory..." -ForegroundColor Cyan
Invoke-LoggedCommand "docker exec namenode hdfs dfs -mkdir -p $HdfsDir" { docker exec namenode hdfs dfs -mkdir -p $HdfsDir }
Invoke-LoggedCommand "docker exec namenode hdfs dfs -rm -f $HdfsDir/$File" { docker exec namenode hdfs dfs -rm -f $HdfsDir/$File }

# STRATEGY 2: Bypass Windows mount performance tax by copying to container storage first
Write-Host "`n==> Copying file into container filesystem for native Linux I/O speed..." -ForegroundColor Cyan
Invoke-LoggedCommand "docker exec namenode cp /data-local/$File /tmp/$File" { docker exec namenode cp /data-local/$File /tmp/$File }

# Ingest using an optimized 128KB buffer and set initial replication to 1 to bypass pipeline bottlenecks
# Note: Arguments are quoted explicitly to stop PowerShell from parsing the '-' and '.' characters
Write-Host "==> Pushing to HDFS with optimized buffer and pipeline settings..." -ForegroundColor Cyan
Invoke-LoggedCommand "docker exec namenode hdfs dfs `"-Ddfs.replication=1`" `"-Dio.file.buffer.size=131072`" -put -f /tmp/$File $HdfsDir/" { 
    docker exec namenode hdfs dfs "-Ddfs.replication=1" "-Dio.file.buffer.size=131072" -put -f /tmp/$File $HdfsDir/ 
}
if ($LASTEXITCODE) { throw "hdfs put failed" }

# Clean up container storage immediately so you don't run out of disk space inside Docker
Write-Host "==> Cleaning up container /tmp directory..." -ForegroundColor Cyan
Invoke-LoggedCommand "docker exec namenode rm /tmp/$File" { docker exec namenode rm /tmp/$File }

# Asynchronously tell HDFS to spin up the rest of the copies in the background while the script continues
Write-Host "==> Triggering background block replication up to 3..." -ForegroundColor Yellow
Invoke-LoggedCommand "docker exec -d namenode hdfs dfs -setrep -R 3 $HdfsDir/$File" { docker exec -d namenode hdfs dfs -setrep -R 3 $HdfsDir/$File }

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