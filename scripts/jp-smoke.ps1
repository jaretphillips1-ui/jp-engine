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
      Write-Host "PASTE BELOW ↓ (copy only what’s below this line when asked)"
      Write-Host ""
    }
  }
}

try {
  if (-not (Test-Path -LiteralPath $step)) { throw "jp-step.ps1 not found." }
  . $step

  Invoke-JpStep -Label "VERIFY" -Command {
    if (-not (Test-Path -LiteralPath $verify)) { throw "jp-verify.ps1 not found." }
    & $verify -NoStop
  } | Out-Null

  Invoke-JpStep -Label "GIT STATUS" -Command { git status } -ShowOutputOnPass | Out-Null
  Invoke-JpStep -Label "GIT LOG"    -Command { git log -1 --oneline } -ShowOutputOnPass | Out-Null

  StopBar "STOP — NEXT COMMAND BELOW"
}
catch {
  Write-Host ("SMOKE FAIL: " + $_.Exception.Message)
  StopBar "CUT HERE — PASTE BELOW ONLY (FAIL)" -Fail -PasteCue
  throw
}
