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
  $args = @()

  $args += @("-Thick", $Thick)
  $args += @("-Label", $Label)

  if ($Color) { $args += "-Color" }
  if ($Bold)  { $args += "-Bold" }
  if ($Ascii) { $args += "-Ascii" }

  if ($Pass) { $args += "-Pass" }
  elseif ($Warn) { $args += "-Warn" }
  elseif ($Fail) { $args += "-Fail" }

  & $break @args | Out-Null
} else {
  Write-Host ("==== " + $Label + " ====")
}

Write-Host ""

if ($PasteCue) {
  Write-Host "PASTE FROM HERE ↓ (copy only what’s below this line when asked)"
  Write-Host ""
}
