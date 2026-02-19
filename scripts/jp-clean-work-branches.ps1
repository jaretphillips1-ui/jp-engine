# JP Engine - Cleanup local work/* branches safely
# Behavior:
#  - Fetch/prune
#  - Only consider local work/* branches that DO NOT have origin/work/* counterpart
#  - Before deleting, require: branch has 0 unique commits vs master
#  - If unique commits exist, skip + warn (false-positive protection)

param(
  [Parameter(Mandatory=$false)]
  [string]$RepoRoot = (Get-Location).Path,

  # Dry-run mode. Alias "WhatIf" provided for convenience, but we avoid $WhatIf name conflicts.
  [Parameter(Mandatory=$false)]
  [Alias('WhatIf')]
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section([string]$Text) {
  Write-Host ""
  Write-Host $Text -ForegroundColor Cyan
}

function Assert-RepoMaster([string]$RepoRoot) {
  if (-not (Test-Path -LiteralPath $RepoRoot)) { throw "Repo root not found: $RepoRoot" }
  Set-Location -LiteralPath $RepoRoot

  $top = (git rev-parse --show-toplevel).Trim()
  if (-not $top) { throw "Not a git repo (rev-parse failed)." }

  $current = (git branch --show-current).Trim()
  if ($current -ne 'master') { throw "Refusing: currently on '$current' (expected 'master')." }
}

function Get-LocalWorkBranches() {
  @(git branch --format='%(refname:short)' --list 'work/*' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Get-RemoteWorkBranchSet() {
  # Returns HashSet of "work/..." names (no origin/ prefix)
  $set = New-Object 'System.Collections.Generic.HashSet[string]'
  @(git branch -r --format='%(refname:short)' --list 'origin/work/*') | ForEach-Object {
    $name = ($_ -replace '^origin/','').Trim()
    if ($name) { $null = $set.Add($name) }
  }
  return $set
}

function Get-UniqueCommitCount([string]$Branch) {
  # Count commits reachable from Branch but not from master
  $n = (git rev-list --count "master..$Branch").Trim()
  if (-not $n) { return 0 }
  return [int]$n
}

function Show-BranchHint([string]$Branch) {
  Write-Host "  Unique commits detected; skipping delete to prevent false positives." -ForegroundColor Yellow
  Write-Host "  Inspect with:" -ForegroundColor Yellow
  Write-Host "    git log --oneline --decorate -n 12 master..$Branch" -ForegroundColor Yellow
  Write-Host "    git diff master..$Branch" -ForegroundColor Yellow
}

Assert-RepoMaster -RepoRoot $RepoRoot

Write-Section "== Fetch + prune =="
git fetch origin --prune | Out-Host
if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }

Write-Section "== Local work/* branches =="
$locals = Get-LocalWorkBranches
if (-not $locals -or $locals.Count -eq 0) {
  Write-Host "No local work/* branches found." -ForegroundColor Green
  return
}
$locals | ForEach-Object { Write-Host "  $_" }

Write-Section "== Remote-tracking origin/work/* branches =="
$remoteSet = Get-RemoteWorkBranchSet
if ($remoteSet.Count -eq 0) {
  Write-Host "No origin/work/* branches found." -ForegroundColor Yellow
} else {
  $remoteSet | Sort-Object | ForEach-Object { Write-Host "  origin/$_" }
}

Write-Section "== Decide deletions (no origin/work/* + 0 unique commits vs master) =="

$toConsider = @($locals | Where-Object { -not $remoteSet.Contains($_) })
if ($toConsider.Count -eq 0) {
  Write-Host "All local work/* branches still have origin/work/* counterparts. Nothing to delete." -ForegroundColor Green
  return
}

foreach ($b in $toConsider) {
  # Never delete current branch (shouldn't happen since we asserted master, but keep it explicit)
  $cur = (git branch --show-current).Trim()
  if ($cur -eq $b) { throw "Refusing: currently on '$b'." }

  $unique = Get-UniqueCommitCount -Branch $b
  if ($unique -gt 0) {
    Write-Host "SKIP: $b (origin missing, but $unique unique commits vs master)" -ForegroundColor Yellow
    Show-BranchHint -Branch $b
    continue
  }

  if ($DryRun) {
    Write-Host "DRYRUN delete: $b" -ForegroundColor Cyan
    continue
  }

  Write-Host "Deleting local branch: $b" -ForegroundColor Yellow
  git branch -D -- $b | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git branch -D failed for: $b" }
}

Write-Section "== Remaining local work/* branches =="
git branch --list 'work/*' | Out-Host
