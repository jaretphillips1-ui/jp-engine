[CmdletBinding()]
param(
  [int]$Thick = 12,
  [switch]$Color,
  [switch]$Pass,
  [switch]$Fail,
  [switch]$Bold,
  [string]$Label = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$break = Join-Path $repoRoot "scripts\jp-break.ps1"

if (Test-Path $break) {
  if ($Fail) { & $break -Thick $Thick -Color -Fail -Bold:$Bold -Label $Label | Out-Null }
  elseif ($Pass) { & $break -Thick $Thick -Color -Pass -Bold:$Bold -Label $Label | Out-Null }
  else { & $break -Thick $Thick -Color -Bold:$Bold -Label $Label | Out-Null }
} else {
  Write-Host "==== $Label ===="
}

# small blank spacer for readability
Write-Host ""