<#
  05-run-mapreduce.ps1 — Run a MapReduce job with .NET Hadoop Streaming.
  Binaries are baked in nodemanager image at /opt/dotnet-mr.
  Output is merged to data\mr_out.txt (on host) for Validator to read.
  Parameters: -SplitMB (split size), -Reduces, -Input, -Out (HDFS path).

  Note: We use 'bash -c' not 'bash -lc'; login shell (-l) re-reads
  /etc/profile, resets PATH, and loses hadoop.
#>
param(
  [int]$SplitMB = 128,
  [int]$Reduces = 1,
  [string]$InputPath = "/data/ecommerce/2019-Oct.csv",   # not $Input — that's a PowerShell automatic variable!
  [string]$Out = "/out/mr_manual"
)
$ErrorActionPreference = 'Stop'
$bytes = $SplitMB * 1024 * 1024
$jar = "/opt/hadoop-2.7.4/share/hadoop/tools/lib/hadoop-streaming-2.7.4.jar"
. "$PSScriptRoot\_command-tools.ps1"

# Cleaned up to use native HDFS -f flag, avoiding Windows path errors
Write-Host "==> Cleaning up previous output directory..." -ForegroundColor Cyan
Invoke-LoggedCommand "docker exec namenode hdfs dfs -rm -r -f -skipTrash $Out" {
  docker exec namenode hdfs dfs -rm -r -f -skipTrash $Out
}

# One-line command (without backtick) — same tested Streaming command.
$cmd = "hadoop jar $jar" +
" -D mapreduce.job.reduces=$Reduces" +
" -D mapreduce.input.fileinputformat.split.maxsize=$bytes" +
" -D mapreduce.input.fileinputformat.split.minsize=$bytes" +
" -D mapreduce.job.name=dotnet_mr_manual" +
" -input $InputPath -output $Out" +
" -mapper /opt/dotnet-mr/Mapper/Mapper" +
" -combiner /opt/dotnet-mr/Reducer/Reducer" +
" -reducer /opt/dotnet-mr/Reducer/Reducer"

Write-Host "==> Running Streaming (split=$SplitMB MB, reduces=$Reduces) ..." -ForegroundColor Cyan
$sw = [System.Diagnostics.Stopwatch]::StartNew()
# Wrapped $cmd in quotes so bash executes the entire command string safely
Invoke-LoggedCommand "docker exec namenode bash -c `"$cmd`"" { docker exec namenode bash -c "$cmd" }
$code = $LASTEXITCODE
$sw.Stop()
Write-Host ("`n>>> Wall-clock: {0:N1} seconds (exit={1})" -f $sw.Elapsed.TotalSeconds, $code) -ForegroundColor Green
if ($code) { throw "streaming job failed" }

Write-Host "==> Merging output to data\mr_out.txt ..."
# Separated commands to prevent PowerShell from misinterpreting internal string quotes
Invoke-LoggedCommand "docker exec namenode rm -f /data-local/mr_out.txt" {
  docker exec namenode rm -f /data-local/mr_out.txt
}
Invoke-LoggedCommand "docker exec namenode hdfs dfs -getmerge $Out /data-local/mr_out.txt" {
  docker exec namenode hdfs dfs -getmerge $Out /data-local/mr_out.txt
}

Write-Host "--- Top 20 frequent categories ---"
Invoke-LoggedCommand "docker exec namenode bash -c `"sort -t ' ' -k2 -nr /data-local/mr_out.txt | head -20`"" {
  docker exec namenode bash -c "sort -t ' ' -k2 -nr /data-local/mr_out.txt | head -20"
}