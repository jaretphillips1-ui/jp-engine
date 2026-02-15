[CmdletBinding()]
param(
  [int]$StopThick = 12
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$verify = Join-Path $repoRoot "scripts\jp-verify.ps1"
$stop   = Join-Path $repoRoot "scripts\jp-stop.ps1"

function StopBar([string]$label, [switch]$Fail) {
  if (Test-Path $stop) {
    if ($Fail) { & $stop -Thick $StopThick -Color -Fail -Bold -Label $label | Out-Null }
    else { & $stop -Thick $StopThick -Color -Bold -Label $label | Out-Null }
  } else {
    Write-Host "==== $label ===="
    Write-Host ""
  }

  # Eye-catcher line that stays readable even when selection whitening happens
  Write-Host "PASTE FROM HERE ↓ (copy only what’s below this line when asked)"
  Write-Host ""
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
  StopBar "CUT HERE — PASTE BELOW ONLY (FAIL)" -Fail
  throw
}