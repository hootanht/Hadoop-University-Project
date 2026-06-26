<#
  07-validate.ps1 — Validation: Compare MapReduce output with single-threaded SQL/Dapper baseline.
  Steps:
    1) Merge MR output from HDFS to data\mr_out.txt
    2) Run Validator which loads data into SQL Server, gets GROUP BY with Dapper,
       and compares with MR output (and a C# count).
  Parameters: -File (CSV name), -MrOut (HDFS path of MR output).
#>
param(
    [string]$File = "2019-Oct.csv",
    [string]$MrOut = "/out/mr_manual",
    [string]$SaPassword = "Hadoop!Dapper2024"
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\_command-tools.ps1"

Write-Host "==> Merging MapReduce output to data\mr_out.txt ..." -ForegroundColor Cyan
Invoke-LoggedCommand "docker exec namenode bash -c \"rm -f /data-local/mr_out.txt; hdfs dfs -getmerge $MrOut /data-local/mr_out.txt\"" {
  docker exec namenode bash -c "rm -f /data-local/mr_out.txt; hdfs dfs -getmerge $MrOut /data-local/mr_out.txt"
}

$conn = "Server=localhost,14333;User Id=sa;Password=$SaPassword;TrustServerCertificate=True;Encrypt=False"
Write-Host "==> Running Validator (SqlBulkCopy → Dapper GROUP BY → comparison) ..." -ForegroundColor Cyan
Push-Location $Root
try {
  Invoke-LoggedCommand "dotnet run --project src\Validator -c Release -- --csv data\$File --mr data\mr_out.txt --sql-conn <redacted> --reset-table --csharp-baseline --report results\validation.md" {
    dotnet run --project src\Validator -c Release -- `
      --csv (Join-Path $Root "data\$File") `
      --mr  (Join-Path $Root "data\mr_out.txt") `
      --sql-conn $conn `
      --reset-table `
      --csharp-baseline `
      --report (Join-Path $Root "results\validation.md")
  }
    $code = $LASTEXITCODE
} finally { Pop-Location }

if ($code -eq 0) { Write-Host "`n[OK] Correctness verified (ExitCode=0)." -ForegroundColor Green }
else { Write-Host "`n[ERROR] Discrepancy found (ExitCode=$code)." -ForegroundColor Red }
exit $code
