[CmdletBinding()]
param(
  [int]$StopThick = 12,
  [int]$BannerThick = 6
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$break = Join-Path $repoRoot "scripts\jp-break.ps1"
if (Test-Path $break) {
  & $break -Color -Bold -Thick $BannerThick -Label ("JP START — " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) | Out-Null
} else {
  Write-Host ""
  Write-Host ("JP START — " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
}

Write-Host ("repo: " + $repoRoot)

if (Get-Command git -ErrorAction SilentlyContinue) {
  $branch = (git rev-parse --abbrev-ref HEAD) 2>$null
  if ($branch) { Write-Host ("git branch: " + $branch.Trim()) }
}

$gate = Join-Path $repoRoot "scripts\jp-gate.ps1"
if (-not (Test-Path $gate)) { throw "jp-gate.ps1 not found at $gate" }

& $gate -StopThick $StopThick