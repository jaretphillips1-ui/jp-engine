[CmdletBinding()]
param(
  [string]$HandoffPath = "docs/JP_ENGINE_HANDOFF.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== JP ENGINE STARTUP ===" -ForegroundColor Cyan

if (-not (Test-Path ".git")) { throw "Not in repo root." }

git fetch --prune | Out-Null

Write-Host ""
if (-not (Test-Path -LiteralPath $HandoffPath)) {
  Write-Host "No handoff file found yet." -ForegroundColor Yellow
  Write-Host "Tip: run scripts/jp-shutdown.ps1 once to generate it." -ForegroundColor DarkCyan
  exit 0
}

Write-Host "Latest Handoff:" -ForegroundColor Green
Write-Host "------------------------------"
Get-Content -LiteralPath $HandoffPath
Write-Host "------------------------------"
