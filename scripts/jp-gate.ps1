[CmdletBinding()]
param(
  [int]$StopThick = 12
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$smoke = Join-Path $repoRoot "scripts\jp-smoke.ps1"
if (-not (Test-Path $smoke)) { throw "jp-smoke.ps1 not found at $smoke" }

& $smoke -StopThick $StopThick
