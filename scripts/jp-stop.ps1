[CmdletBinding()]
param(
  [int]$Thick = 12,
  [switch]$Color,
  [switch]$Pass,
  [switch]$Warn,
  [switch]$Fail,
  [switch]$Bold,
  [switch]$Ascii,
  [switch]$PasteCue,
  [string]$Label = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$break = Join-Path $repoRoot "scripts\jp-break.ps1"

if (Test-Path $break) {
  # Use a hashtable splat so named params bind correctly.
  $p = @{
    Thick = $Thick
    Label = $Label
  }

  if ($Color) { $p.Color = $true }
  if ($Bold)  { $p.Bold  = $true }
  if ($Ascii) { $p.Ascii = $true }

  if ($Pass)      { $p.Pass = $true }
  elseif ($Warn)  { $p.Warn = $true }
  elseif ($Fail)  { $p.Fail = $true }

  & $break @p | Out-Null
} else {
  Write-Host ("==== " + $Label + " ====")
}

Write-Host ""

if ($PasteCue) {
  Write-Host "PASTE FROM HERE ↓ (copy only what’s below this line when asked)"
  Write-Host ""
}
