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

try {
  Write-Host ""
  Write-Host ("JP SHUTDOWN — " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  Write-Host ("repo: " + $repoRoot)

  if (-not (Test-Path -LiteralPath $verify)) { throw "jp-verify.ps1 not found at $verify" }
  if (-not (Test-Path -LiteralPath $save))   { throw "jp-save.ps1 not found at $save" }

  & $verify -NoStop | Out-Null
  & $save -SaveRoot $SaveRoot | Out-Null

  git status
  git log -1 --oneline

  if (Test-Path -LiteralPath $stop) {
    & $stop -Thick $StopThick -Color -Bold -Label "CUT HERE — PASTE BELOW ONLY" -PasteCue | Out-Null
  } else {
    Write-Host "==== STOP BAR (jp-stop missing) ===="
    Write-Host ""
  }
}
catch {
  Write-Host ("JP SHUTDOWN FAIL: " + $_.Exception.Message)

  if (Test-Path -LiteralPath $stop) {
    & $stop -Thick $StopThick -Color -Fail -Bold -Label "CUT HERE — PASTE BELOW ONLY (FAIL)" -PasteCue | Out-Null
  } else {
    Write-Host "==== STOP BAR (FAIL) (jp-stop missing) ===="
    Write-Host ""
  }

  throw
}


