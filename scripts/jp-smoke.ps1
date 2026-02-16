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
    $p = @{
      Thick = $StopThick
      Color = $true
      Bold  = $true
      Label = $label
    }
    if ($Fail)     { $p.Fail     = $true }
    if ($PasteCue) { $p.PasteCue = $true }
    & $stop @p | Out-Null
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
  } -ExpectRegex @("VERIFY — PASS","NO PASTE NEEDED") | Out-Null

  Invoke-JpStep -Label "GIT STATUS" -Command { git status } -ExpectRegex @("working tree clean") -ShowOutputOnPass | Out-Null
  Invoke-JpStep -Label "GIT LOG"    -Command { git log -1 --oneline } -ExpectRegex @("^[0-9a-f]{7,40}\s") -ShowOutputOnPass | Out-Null

  StopBar "STOP — NEXT COMMAND BELOW"
}
catch {
  Write-Host ("SMOKE FAIL: " + $_.Exception.Message)
  StopBar "CUT HERE — PASTE BELOW ONLY (FAIL)" -Fail -PasteCue
  throw
}
