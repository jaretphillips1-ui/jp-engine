param(
  # Optional hard gate for local use. In CI leave empty (default) so we auto-detect.
  [string]$ExpectedRepo = ''
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

function Get-RepoRootFromScript {
  # scripts\ -> repo root is parent
  $root = Join-Path $PSScriptRoot '..'
  return (Resolve-Path -LiteralPath $root).Path
}

function Require-RepoRoot {
  $repoRoot = Get-RepoRootFromScript
  Set-Location -LiteralPath $repoRoot

  $top = (git rev-parse --show-toplevel 2>$null)
  if (-not $top) { throw "Safety gate: not a git repo (git rev-parse failed)." }

  if (-not [string]::IsNullOrWhiteSpace($ExpectedRepo)) {
    $expectedNorm = Normalize-Path $ExpectedRepo
    $topNorm      = Normalize-Path $top.Trim()
    if ($topNorm -ne $expectedNorm) {
      throw "Safety gate: expected repo '$expectedNorm', got '$topNorm'"
    }
  }
}

function Write-Summary([string]$label) {
  $b = (git branch --show-current)
if ([string]::IsNullOrWhiteSpace($b)) {
  # CI can be detached HEAD; try a symbolic ref, else label it clearly.
  $b = (git symbolic-ref --short -q HEAD 2>$null)
}
if ([string]::IsNullOrWhiteSpace($b)) { $b = 'DETACHED_HEAD' }
$b = $b.Trim()
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
# - Purpose: quick, deterministic go/no-go.
# - IMPORTANT: jp-doctor already runs jp-verify (baseline), so we do NOT run verify twice.
# - CI portability: repo root is derived from script location (no hard-coded paths).
# --------------------------------------------------------------------------------
Require-RepoRoot

Write-Host "=== JP: SMOKE (doctor-only) ==="
Write-Host "Running: scripts\jp-doctor.ps1"
Write-Host ""

pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'jp-doctor.ps1')
if ($LASTEXITCODE -ne 0) {
  Write-Summary -label 'FAIL'
  throw "jp-doctor.ps1 failed with exit code $LASTEXITCODE"
}

Write-Summary -label 'PASS'
Write-Host "STOP — NEXT COMMAND BELOW"
