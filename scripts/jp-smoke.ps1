[CmdletBinding()]
param(
  [int]$StopThick = 12
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$verify = Join-Path $repoRoot "scripts\jp-verify.ps1"
$stop   = Join-Path $repoRoot "scripts\jp-stop.ps1"
$step   = Join-Path $repoRoot "scripts\jp-step.ps1"

try {
  if (-not (Test-Path -LiteralPath $step)) { throw "jp-step.ps1 not found." }
  . $step

  Invoke-JpStep -Label "VERIFY" -Command {
    if (-not (Test-Path -LiteralPath $verify)) { throw "jp-verify.ps1 not found." }
    & $verify -NoStop
  } -ExpectRegex @("(?m)^\s*VERIFY — PASS\s*$","(?m)^\s*NO PASTE NEEDED") | Out-Null

  Invoke-JpStep -Label "GIT STATUS" -Command { git status } -ExpectRegex @("working tree clean") -ShowOutputOnPass | Out-Null
  Invoke-JpStep -Label "GIT LOG"    -Command { git log -1 --oneline } -ExpectRegex @("^[0-9a-f]{7,40}\s") -ShowOutputOnPass | Out-Null

  if (Test-Path -LiteralPath $stop) {
    & $stop -Thick $StopThick -Color -Bold -Label "STOP — NEXT COMMAND BELOW" | Out-Null
  } else {
    Write-Host "==== STOP — NEXT COMMAND BELOW ===="
    Write-Host ""
  }
}
catch {
  Write-Host ("SMOKE FAIL: " + $_.Exception.Message)

  if (Test-Path -LiteralPath $stop) {
    & $stop -Thick $StopThick -Color -Fail -Bold -Label "CUT HERE — PASTE BELOW ONLY (FAIL)" -PasteCue | Out-Null
  } else {
    Write-Host "==== CUT HERE — PASTE BELOW ONLY (FAIL) ===="
    Write-Host ""
    Write-Host "PASTE BELOW ↓ (copy only what’s below this line when asked)"
    Write-Host ""
  }

  throw
}
