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
    Write-Host "==== $label ===="
    Write-Host ""
    if ($PasteCue) {
      Write-Host "PASTE FROM HERE ↓ (copy only what’s below this line when asked)"
      Write-Host ""
    }
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

  # PASS: stop bar only (no paste cue)
  StopBar "STOP — NEXT COMMAND BELOW"
}
catch {
  Write-Host ("SMOKE FAIL: " + $_.Exception.Message)

  # FAIL: show paste cue so user knows what to paste
  StopBar "CUT HERE — PASTE BELOW ONLY (FAIL)" -Fail -PasteCue
  throw
}

