[CmdletBinding()]
param(
  [int]$StopThick = 4,
  [int]$BannerThick = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$break = Join-Path $repoRoot "scripts\jp-break.ps1"
if (Test-Path -LiteralPath $break) {
  & $break -Color -Bold -Thick $BannerThick -Label ("⚪ JP GATE — " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) | Out-Null
} else {
  Write-Host ""
  Write-Host ("⚪ JP GATE — " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
}

Write-Host ("repo: " + $repoRoot)

if (Get-Command git -ErrorAction SilentlyContinue) {
  $branch = (git rev-parse --abbrev-ref HEAD) 2>$null
  if ($branch) { Write-Host ("git branch: " + $branch.Trim()) }
}

$smoke = Join-Path $repoRoot "scripts\jp-smoke.ps1"
if (-not (Test-Path -LiteralPath $smoke)) { throw "jp-smoke.ps1 not found at $smoke" }

& $smoke -StopThick $StopThick
