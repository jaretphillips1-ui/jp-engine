param(
  [Parameter(Mandatory=$false)]
  [string]$Slug = 'work',

  [Parameter(Mandatory=$false)]
  [switch]$RunSmoke,

  [Parameter(Mandatory=$false)]
  [switch]$AllowDirty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if ([string]::IsNullOrWhiteSpace($repoRoot)) { throw "Not inside a git repo." }
Set-Location -LiteralPath $repoRoot

$target = Join-Path $repoRoot 'scripts\jp-start-work.ps1'
if (-not (Test-Path -LiteralPath $target)) { throw "Missing canonical: scripts/jp-start-work.ps1" }

& pwsh -NoProfile -ExecutionPolicy Bypass -File $target -Slug $Slug -RunSmoke:$RunSmoke -AllowDirty:$AllowDirty
exit $LASTEXITCODE
