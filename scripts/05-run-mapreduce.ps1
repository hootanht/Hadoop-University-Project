<#
  05-run-mapreduce.ps1 — اجرای یک job از MapReduceِ .NET با Hadoop Streaming.
  باینری‌ها در ایمیجِ nodemanager در /opt/dotnet-mr بِیک شده‌اند.
  خروجی به data\mr_out.txt (روی میزبان) merge می‌شود تا Validator بخواند.
  پارامترها: -SplitMB (اندازهٔ split)، -Reduces، -Input، -Out (مسیرِ HDFS).

  نکته: از «bash -c» استفاده می‌کنیم نه «bash -lc»؛ شِلِ login (با -l) فایلِ
  /etc/profile را دوباره می‌خوانَد و PATH را ریست می‌کند و hadoop را گم می‌کند.
#>
param(
    [int]$SplitMB = 128,
    [int]$Reduces = 1,
    [string]$InputPath = "/data/ecommerce/2019-Oct.csv",   # نه $Input — آن یک متغیرِ خودکارِ PowerShell است!
    [string]$Out = "/out/mr_manual"
)
$ErrorActionPreference = 'Stop'
$bytes = $SplitMB * 1024 * 1024
$jar = "/opt/hadoop-2.7.4/share/hadoop/tools/lib/hadoop-streaming-2.7.4.jar"

docker exec namenode bash -c "hdfs dfs -rm -r -skipTrash $Out 2>/dev/null || true" | Out-Null

# فرمانِ تک‌خطی (بدونِ backtick) — همان دستورِ آزموده‌شدهٔ Streaming.
$cmd = "hadoop jar $jar" +
       " -D mapreduce.job.reduces=$Reduces" +
       " -D mapreduce.input.fileinputformat.split.maxsize=$bytes" +
       " -D mapreduce.input.fileinputformat.split.minsize=$bytes" +
       " -D mapreduce.job.name=dotnet_mr_manual" +
       " -input $InputPath -output $Out" +
       " -mapper /opt/dotnet-mr/Mapper/Mapper" +
       " -combiner /opt/dotnet-mr/Reducer/Reducer" +
       " -reducer /opt/dotnet-mr/Reducer/Reducer"

Write-Host "==> اجرای Streaming (split=$SplitMB MB, reduces=$Reduces) ..." -ForegroundColor Cyan
$sw = [System.Diagnostics.Stopwatch]::StartNew()
docker exec namenode bash -c $cmd
$code = $LASTEXITCODE
$sw.Stop()
Write-Host ("`n>>> Wall-clock: {0:N1} ثانیه (exit={1})" -f $sw.Elapsed.TotalSeconds, $code) -ForegroundColor Green
if ($code) { throw "streaming job failed" }

Write-Host "==> ادغامِ خروجی به data\mr_out.txt ..."
docker exec namenode bash -c "rm -f /data-local/mr_out.txt; hdfs dfs -getmerge $Out /data-local/mr_out.txt"
Write-Host "--- ۲۰ دستهٔ پرتکرار ---"
docker exec namenode bash -c "sort -t '	' -k2 -nr /data-local/mr_out.txt | head -20"
