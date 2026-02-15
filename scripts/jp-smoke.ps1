[CmdletBinding()]
param(
  [int]$StopThick = 12
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$verify = Join-Path $repoRoot "scripts\jp-verify.ps1"
$stop   = Join-Path $repoRoot "scripts\jp-stop.ps1"

function StopBar([string]$label, [switch]$Fail, [switch]$PasteCue) {
  if (Test-Path -LiteralPath $stop) {
    if ($Fail) {
      if ($PasteCue) { & $stop -Thick $StopThick -Color -Fail -Bold -Label $label -PasteCue | Out-Null }
      else { & $stop -Thick $StopThick -Color -Fail -Bold -Label $label | Out-Null }
    } else {
      if ($PasteCue) { & $stop -Thick $StopThick -Color -Bold -Label $label -PasteCue | Out-Null }
      else { & $stop -Thick $StopThick -Color -Bold -Label $label | Out-Null }
    }
  } else {
    # Minimal fallback: delimiter only. Never print the canonical paste cue here.
    Write-Host "==== $label ===="
    Write-Host ""
  }
}

try {
  if (Test-Path -LiteralPath $verify) {
    & $verify -NoStop | Out-Null
  } else {
    throw "jp-verify.ps1 not found."
  }

  git status
  git log -1 --oneline

  StopBar "STOP — NEXT COMMAND BELOW"
}
catch {
  Write-Host ("SMOKE FAIL: " + $_.Exception.Message)
  StopBar "CUT HERE — PASTE BELOW ONLY (FAIL)" -Fail -PasteCue
  throw
}

