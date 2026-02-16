[CmdletBinding()]
param(
  [string]$SaveRoot = "C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST",
  [int]$StopThick = 12
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$verify = Join-Path $repoRoot "scripts\jp-verify.ps1"
$save   = Join-Path $repoRoot "scripts\jp-save.ps1"
$stop   = Join-Path $repoRoot "scripts\jp-stop.ps1"
$step   = Join-Path $repoRoot "scripts\jp-step.ps1"

try {
  Write-Host ""
  Write-Host ("JP SHUTDOWN — " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  Write-Host ("repo: " + $repoRoot)

  if (-not (Test-Path -LiteralPath $step))   { throw "jp-step.ps1 not found at $step" }
  if (-not (Test-Path -LiteralPath $verify)) { throw "jp-verify.ps1 not found at $verify" }
  if (-not (Test-Path -LiteralPath $save))   { throw "jp-save.ps1 not found at $save" }

  . $step

  Invoke-JpStep -Label "VERIFY" -Command {
    & $verify -NoStop
  } -ExpectRegex @("(?m)^\s*VERIFY — PASS\s*$","(?m)^\s*NO PASTE NEEDED") | Out-Null

  Invoke-JpStep -Label "SAVE" -Command {
    & $save -SaveRoot $SaveRoot
  } -ShowOutputOnPass | Out-Null

  Invoke-JpStep -Label "GIT STATUS" -Command { git status } -ExpectRegex @("working tree clean") -ShowOutputOnPass | Out-Null
  Invoke-JpStep -Label "GIT LOG"    -Command { git log -1 --oneline } -ExpectRegex @("^[0-9a-f]{7,40}\s") -ShowOutputOnPass | Out-Null

  if (Test-Path -LiteralPath $stop) {
    & $stop -Thick 6 -Color -Bold -Label "STOP — NEXT COMMAND BELOW" | Out-Null
  } else {
    Write-Host "==== STOP — NEXT COMMAND BELOW ===="
    Write-Host ""
  }
}
catch {
  Write-Host ("JP SHUTDOWN FAIL: " + $_.Exception.Message)

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
