<#
  07-validate.ps1 — صحت‌سنجی: مقایسهٔ خروجیِ MapReduce با مبنای تک‌رشته‌ایِ SQL/Dapper.
  گام‌ها:
    ۱) ادغامِ خروجیِ MR از HDFS به data\mr_out.txt
    ۲) اجرای Validator که داده را به SQL Server بار می‌کند، GROUP BY را با Dapper
       می‌گیرد، و با خروجیِ MR (و یک شمارشِ C#) مقایسه می‌کند.
  پارامترها: -File (نامِ CSV)، -MrOut (مسیرِ HDFSِ خروجیِ MR).
#>
param(
    [string]$File = "2019-Oct.csv",
    [string]$MrOut = "/out/mr_manual",
    [string]$SaPassword = "Hadoop!Dapper2024"
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

Write-Host "==> ادغامِ خروجیِ MapReduce به data\mr_out.txt ..." -ForegroundColor Cyan
docker exec namenode bash -c "rm -f /data-local/mr_out.txt; hdfs dfs -getmerge $MrOut /data-local/mr_out.txt"

$conn = "Server=localhost,14333;User Id=sa;Password=$SaPassword;TrustServerCertificate=True;Encrypt=False"
Write-Host "==> اجرای Validator (SqlBulkCopy → Dapper GROUP BY → مقایسه) ..." -ForegroundColor Cyan
Push-Location $Root
try {
    dotnet run --project src\Validator -c Release -- `
        --csv (Join-Path $Root "data\$File") `
        --mr  (Join-Path $Root "data\mr_out.txt") `
        --sql-conn $conn `
        --reset-table `
        --csharp-baseline `
        --report (Join-Path $Root "results\validation.md")
    $code = $LASTEXITCODE
} finally { Pop-Location }

if ($code -eq 0) { Write-Host "`n[OK] Correctness تأیید شد (ExitCode=0)." -ForegroundColor Green }
else { Write-Host "`n[خطا] اختلاف پیدا شد (ExitCode=$code)." -ForegroundColor Red }
exit $code
