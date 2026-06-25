<#
  06-run-hive.ps1 — اجرای همان کوئری با Hive (HiveQL → MapReduce روی YARN).
  فایلِ query.hql را به کانتینرِ hive-server کپی و با beeline اجرا می‌کند.
  خروجیِ کنسول در data\hive_console.txt ذخیره می‌شود.
#>
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

Write-Host "==> کپیِ query.hql به hive-server ..." -ForegroundColor Cyan
docker cp (Join-Path $Root "hive\query.hql") hive-server:/query.hql

Write-Host "==> اجرای beeline (ممکن است چند دقیقه طول بکشد؛ Hive یک job از MR می‌سازد) ..." -ForegroundColor Cyan
docker exec hive-server beeline -u "jdbc:hive2://localhost:10000" --silent=true -f /query.hql 2>&1 |
    Tee-Object -FilePath (Join-Path $Root "data\hive_console.txt")

Write-Host "`n[OK] خروجیِ Hive در data\hive_console.txt ذخیره شد." -ForegroundColor Green
