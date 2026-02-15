[CmdletBinding()]
param(
  [int]$StopThick = 12,
  [int]$BannerThick = 6
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$break = Join-Path $repoRoot "scripts\jp-break.ps1"
if (Test-Path $break) {
  & $break -Color -Bold -Thick $BannerThick -Label "JP GATE — STANDARD RUNNER" | Out-Null
} else {
  Write-Host ""
  Write-Host "JP GATE — STANDARD RUNNER"
}

$smoke = Join-Path $repoRoot "scripts\jp-smoke.ps1"
if (-not (Test-Path $smoke)) { throw "jp-smoke.ps1 not found at $smoke" }

& $smoke -StopThick $StopThick