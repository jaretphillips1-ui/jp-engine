[CmdletBinding()]
param(
  [string]$SaveRoot = "C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST",
  [int]$StopThick = 12
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$verify = Join-Path $repoRoot "scripts\jp-verify.ps1"
$save   = Join-Path $repoRoot "scripts\jp-save.ps1"
$stop   = Join-Path $repoRoot "scripts\jp-stop.ps1"

function StopBar([string]$label, [switch]$Fail) {
  if (Test-Path $stop) {
    if ($Fail) { & $stop -Thick $StopThick -Color -Fail -Bold -Label $label | Out-Null }
    else { & $stop -Thick $StopThick -Color -Bold -Label $label | Out-Null }
  } else {
    Write-Host "==== $label ===="
    Write-Host "PASTE FROM HERE ↓ (copy only what’s below this line when asked)"
    Write-Host ""
  }
}

try {
  Write-Host ""
  Write-Host ("JP SHUTDOWN — " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  Write-Host ("repo: " + $repoRoot)

  if (-not (Test-Path $verify)) { throw "jp-verify.ps1 not found at $verify" }
  if (-not (Test-Path $save))   { throw "jp-save.ps1 not found at $save" }

  & $verify | Out-Null
  & $save -SaveRoot $SaveRoot | Out-Null

  git status
  git log -1 --oneline

  StopBar "CUT HERE — PASTE BELOW ONLY"
}
catch {
  Write-Host ("JP SHUTDOWN FAIL: " + $_.Exception.Message)
  StopBar "CUT HERE — PASTE BELOW ONLY (FAIL)" -Fail
  throw
}