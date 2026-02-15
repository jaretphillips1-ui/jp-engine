[CmdletBinding()]
param(
  [int]$Thick = 12,
  [switch]$Color,
  [switch]$Pass,
  [switch]$Fail,
  [switch]$Bold,
  [string]$Label = "STOP"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$bp = Join-Path $repoRoot "scripts\jp-break.ps1"
if (Test-Path $bp) {
  if ($Pass) { & $bp -Color -Pass -Thick $Thick -Bold -Label $Label | Out-Null }
  elseif ($Fail) { & $bp -Color -Fail -Thick $Thick -Bold -Label $Label | Out-Null }
  elseif ($Color) { & $bp -Color -Thick $Thick -Bold -Label $Label | Out-Null }
  else { & $bp -Thick $Thick -Bold -Label $Label | Out-Null }
} else {
  Write-Host ("==== " + $Label + " ====")
}

# Eye-catcher line that stays readable even when selection whitening happens
Write-Host "PASTE FROM HERE ↓ (copy only what’s below this line when asked)"
Write-Host ""
