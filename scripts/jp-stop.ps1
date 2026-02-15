[CmdletBinding()]
param(
  [string]$Label = "STOP — NEXT COMMAND BELOW",
  [int]$Thick = 6
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$bp = Join-Path $repoRoot "scripts\jp-break.ps1"
if (Test-Path $bp) {
  & $bp -Thick $Thick -Bold -Label $Label | Out-Null
} else {
  Write-Host ("==== " + $Label + " ====")
}