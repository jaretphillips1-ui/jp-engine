param(
  [string]$ExpectedRepo = 'C:\dev\JP_ENGINE\jp-engine'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Normalize-Path([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return "" }
  try { $p = (Resolve-Path -LiteralPath $p).Path } catch { }
  $p = $p -replace '/', '\'
  $p = $p.TrimEnd('\')
  if ($IsWindows) { $p = $p.ToLowerInvariant() }
  return $p
}

function Require-RepoRoot {
  Set-Location -LiteralPath $ExpectedRepo

  $top = (git rev-parse --show-toplevel 2>$null)
  if (-not $top) { throw "Safety gate: not a git repo (git rev-parse failed)." }

  $expectedNorm = Normalize-Path $ExpectedRepo
  $topNorm      = Normalize-Path $top.Trim()
  if ($topNorm -ne $expectedNorm) {
    throw "Safety gate: expected repo '$expectedNorm', got '$topNorm'"
  }
}

function Write-Summary([string]$label) {
  $b = (git branch --show-current).Trim()
  $h = (git log -1 --oneline --decorate)
  $porc = @(git status --porcelain)
  ""
  "=== JP: SMOKE SUMMARY ($label) ==="
  ("Branch: " + $b)
  ("HEAD:   " + $h)
  ("Dirty:  " + $porc.Count + " change(s)")
  ""
}

# --------------------------------------------------------------------------------
# JP Smoke:
# - Purpose: a quick, deterministic go/no-go.
# - IMPORTANT: jp-doctor already runs jp-verify (baseline), so we do NOT run verify twice.
# --------------------------------------------------------------------------------
Require-RepoRoot

Write-Host "=== JP: SMOKE (doctor-only) ==="
Write-Host "Running: scripts\jp-doctor.ps1"
Write-Host ""

pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\jp-doctor.ps1
if ($LASTEXITCODE -ne 0) {
  Write-Summary -label 'FAIL'
  throw "jp-doctor.ps1 failed with exit code $LASTEXITCODE"
}

Write-Summary -label 'PASS'
Write-Host "STOP — NEXT COMMAND BELOW"
