[CmdletBinding()]
param(
  [int]$StopThick   = 12,
  [int]$BannerThick = 6
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$break = Join-Path $repoRoot "scripts\jp-break.ps1"
$stop  = Join-Path $repoRoot "scripts\jp-stop.ps1"
$gate  = Join-Path $repoRoot "scripts\jp-gate.ps1"

if (-not (Test-Path -LiteralPath $gate)) { throw "jp-gate.ps1 not found at $gate" }

if (Test-Path -LiteralPath $break) {
  & $break -Color -Bold -Thick $BannerThick -Label "⚪ JP SPRINT 1 — GATE CORE" | Out-Null
} else {
  Write-Host ""
  Write-Host "⚪ JP SPRINT 1 — GATE CORE"
}

# Gate = smoke + verify + clean-tree confirmation
& $gate -StopThick $StopThick -BannerThick $BannerThick | Out-Null

Write-Host "NEXT (Gate Core):"
Write-Host "  1) Standardize Green/Red command gates + expected output checks"
Write-Host "  2) Add a minimal 'gate step' helper (run/stop/paste cue) for all runners"
Write-Host ""

if (Test-Path -LiteralPath $stop) {
  & $stop -Thick $StopThick -Color -Bold -Label "STOP — PICK NEXT GATE-CORE STEP" | Out-Null
} else {
  Write-Host "==== STOP — PICK NEXT GATE-CORE STEP ===="
  Write-Host ""
}
