[CmdletBinding()]
param(
  [int]$StopThick = 8
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$verify = Join-Path $repoRoot "scripts\jp-verify.ps1"
$stop   = Join-Path $repoRoot "scripts\jp-stop.ps1"

function StopBar([string]$label) {
  if (Test-Path $stop) {
    & $stop -Thick $StopThick -Label $label | Out-Null
  } else {
    Write-Host "==== $label ===="
  }
}

try {
  if (Test-Path $verify) {
    & $verify | Out-Null
  } else {
    Write-Host "jp-verify.ps1 not found."
  }

  git status
  git log -1 --oneline

  StopBar "CUT HERE — PASTE BELOW ONLY"
}
catch {
  Write-Host ("SMOKE FAIL: " + $_.Exception.Message)
  StopBar "CUT HERE — PASTE BELOW ONLY (FAIL)"
  throw
}