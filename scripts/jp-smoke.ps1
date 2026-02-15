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
  if (Test-Path -LiteralPath $stop) {
    if ($Fail) {
      & $stop -Thick $StopThick -Color -Fail -Bold -Label $label -PasteCue | Out-Null
    } else {
      & $stop -Thick $StopThick -Color -Bold -Label $label -PasteCue | Out-Null
    }
  } else {
    Write-Host "==== $label ===="
    Write-Host ""
  }
}

try {
  if (Test-Path -LiteralPath $verify) {
    & $verify -NoStop | Out-Null
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

