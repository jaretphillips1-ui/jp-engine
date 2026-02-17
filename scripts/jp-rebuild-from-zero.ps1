param(
  [switch]$CreateRestorePoint,
  [string]$RestoreNote = "Rebuild-from-zero: initial restore point",
  [string]$ArtifactRoot = "C:\Dev\_JP_ENGINE\RECOVERY"
)

$ErrorActionPreference = 'Stop'

function Write-Section([string]$t) {
  Write-Host ""
  Write-Host $t -ForegroundColor Cyan
  Write-Host ("-" * $t.Length) -ForegroundColor DarkGray
}

function Assert-RepoRoot {
  $here = (Get-Location).Path
  if (-not (Test-Path -LiteralPath (Join-Path $here '.git'))) {
    throw "Gate failed: run from JP Engine repo root (folder that contains .git). PWD=$here"
  }
}

function Try-Run([string]$label, [scriptblock]$sb) {
  try {
    & $sb | Out-Host
    return $true
  } catch {
    Write-Host "FAILED: $label" -ForegroundColor Yellow
    Write-Host ("  " + $_.Exception.Message) -ForegroundColor Yellow
    return $false
  }
}

function Test-Cmd([string]$name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

Assert-RepoRoot

$repoRoot = (Get-Location).Path
$docsToolchain = Join-Path $repoRoot 'docs\JP_TOOLCHAIN.md'
$docsRecovery  = Join-Path $repoRoot 'docs\JP_RECOVERY.md'
$verifyScript  = Join-Path $repoRoot 'scripts\jp-verify.ps1'
$restoreScript = Join-Path $repoRoot 'scripts\jp-restore-point.ps1'

Write-Section "JP Engine Rebuild-from-Zero (Guided Bootstrap)"
Write-Host "Repo root: $repoRoot"
Write-Host ""
Write-Host "Canonical docs:"
Write-Host " - $docsToolchain"
Write-Host " - $docsRecovery"

if (-not (Test-Path -LiteralPath $docsToolchain)) {
  Write-Host "" ; Write-Host "WARNING: Missing docs/JP_TOOLCHAIN.md (toolchain source-of-truth)" -ForegroundColor Yellow
}
if (-not (Test-Path -LiteralPath $docsRecovery)) {
  Write-Host "" ; Write-Host "WARNING: Missing docs/JP_RECOVERY.md (recovery source-of-truth)" -ForegroundColor Yellow
}

Write-Section "Tooling smoke checks"
$checks = @(
  @{ name = "git";  cmd = "git";  args = @("--version") },
  @{ name = "node"; cmd = "node"; args = @("--version") },
  @{ name = "npm";  cmd = "npm";  args = @("--version") }
)

foreach ($c in $checks) {
  $n = $c.name
  if (-not (Test-Cmd $c.cmd)) {
    Write-Host "MISSING: $n" -ForegroundColor Yellow
    continue
  }
  Try-Run "$n version" { & $c.cmd @($c.args) } | Out-Null
}

Write-Section "Run JP verify (if present)"
if (Test-Path -LiteralPath $verifyScript) {
  Try-Run "jp-verify.ps1" { & $verifyScript } | Out-Null
} else {
  Write-Host "Not found: $verifyScript" -ForegroundColor Yellow
  Write-Host "Next: implement/restore scripts/jp-verify.ps1 and align it with docs/JP_TOOLCHAIN.md" -ForegroundColor Yellow
}

if ($CreateRestorePoint) {
  Write-Section "Optional: Create restore point"
  if (-not (Test-Path -LiteralPath $restoreScript)) {
    throw "Requested -CreateRestorePoint but missing: $restoreScript"
  }

  # Enforce clean tree (restore script will also enforce; this keeps intent obvious)
  $status = & git status --porcelain 2>&1
  if ($LASTEXITCODE -ne 0) { throw "git status failed: $status" }
  if ($status) {
    throw "Working tree is dirty; refusing to create restore point during rebuild-from-zero."
  }

  & $restoreScript -ArtifactRoot $ArtifactRoot -Note $RestoreNote
}

Write-Section "Next actions (recommended)"
Write-Host "1) Open docs/JP_TOOLCHAIN.md and ensure it matches what jp-verify.ps1 checks."
Write-Host "2) Run CI (one-track loop): fix only the first red step, commit, rerun."
Write-Host "3) After verify is stable, extend this script with OS-specific installers (Phase 1B)."
