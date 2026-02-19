Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "JP CLI SMOKE — START" -ForegroundColor Cyan

$cli = Join-Path $PSScriptRoot 'jp.ps1'
if (-not (Test-Path -LiteralPath $cli)) { throw "Missing CLI: $cli" }

Write-Host "1) --version" -ForegroundColor Cyan
pwsh -NoProfile -File $cli --version

Write-Host "2) verify" -ForegroundColor Cyan
pwsh -NoProfile -File $cli verify

Write-Host "3) doctor (optional)" -ForegroundColor Cyan
pwsh -NoProfile -File $cli doctor

Write-Host "JP CLI SMOKE — PASS" -ForegroundColor Green
