# JP Engine - One-button start workflow
# Creates a new work/* branch, pushes it, and optionally runs verify/doctor.
#
# Examples:
#   pwsh -NoProfile -File scripts/jp-start-work.ps1 -Slug auto-merge-tweaks
#   pwsh -NoProfile -File scripts/jp-start-work.ps1 -Slug cleanup -SkipChecks
#   pwsh -NoProfile -File scripts/jp-start-work.ps1 -Slug feature-x -AutoStash
#
# Notes:
# - Refuses unless starting from master
# - Refuses if working tree dirty (unless -AutoStash)

param(
  [Parameter(Mandatory=$true)]
  [string]$Slug,

  [Parameter(Mandatory=$false)]
  [string]$RepoRoot = (Get-Location).Path,

  [Parameter(Mandatory=$false)]
  [switch]$AutoStash,

  [Parameter(Mandatory=$false)]
  [switch]$SkipChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section([string]$Text) {
  Write-Host ""
  Write-Host $Text -ForegroundColor Cyan
}

function Assert-RepoRoot([string]$Root) {
  if (-not (Test-Path -LiteralPath $Root)) { throw "Repo root not found: $Root" }
  Set-Location -LiteralPath $Root
  $top = (git rev-parse --show-toplevel).Trim()
  if (-not $top) { throw "Not a git repo (rev-parse failed)." }
}

function Assert-OnMaster() {
  $current = (git branch --show-current).Trim()
  if ($current -ne 'master') { throw "Refusing: must start from 'master' (current: '$current')." }
}

function Assert-Clean() {
  $porc = @(git status --porcelain)
  if ($porc.Count -ne 0) { throw "Working tree not clean. Commit/stash first (or use -AutoStash)." }
}

function Sanitize-Slug([string]$S) {
  $s2 = $S.Trim().ToLowerInvariant()
  $s2 = $s2 -replace '\s+','-'
  $s2 = $s2 -replace '[^a-z0-9\-]','-'
  $s2 = $s2 -replace '\-+','-'
  $s2 = $s2.Trim('-')
  if (-not $s2) { throw "Slug became empty after sanitize." }
  return $s2
}

function Run-IfExists([string]$File, [string]$Label) {
  if (Test-Path -LiteralPath $File) {
    Write-Section "== $Label =="
    pwsh -NoProfile -File $File | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "$Label failed: $File" }
  } else {
    Write-Host "SKIP: $Label (missing: $File)" -ForegroundColor Yellow
  }
}

Assert-RepoRoot -Root $RepoRoot

Write-Section "== Sync master (ff-only) =="
git fetch origin --prune | Out-Host
if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }

git checkout master | Out-Host
if ($LASTEXITCODE -ne 0) { throw "git checkout master failed." }

git pull --ff-only origin master | Out-Host
if ($LASTEXITCODE -ne 0) { throw "git pull --ff-only failed." }

Assert-OnMaster

if ($AutoStash) {
  $porc2 = @(git status --porcelain)
  if ($porc2.Count -ne 0) {
    Write-Section "== Auto-stash dirty tree =="
    git stash push -u -m "jp-start-work auto-stash" | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "git stash failed." }
  }
}

Assert-Clean

$slugSafe = Sanitize-Slug -S $Slug
$stamp = (Get-Date).ToString('yyyyMMdd-HHmm')
$newBranch = "work/$stamp-$slugSafe"

Write-Section "== Create branch: $newBranch =="
git checkout -b $newBranch | Out-Host
if ($LASTEXITCODE -ne 0) { throw "git checkout -b failed." }

Write-Section "== Push branch (set upstream) =="
git push -u origin $newBranch | Out-Host
if ($LASTEXITCODE -ne 0) { throw "git push -u failed." }

if (-not $SkipChecks) {
  $verify = Join-Path $RepoRoot 'scripts\jp-verify.ps1'
  $doctor = Join-Path $RepoRoot 'scripts\jp-doctor.ps1'
  Run-IfExists -File $verify -Label 'Run jp-verify'
  Run-IfExists -File $doctor -Label 'Run jp-doctor'
} else {
  Write-Host "SkipChecks: true (not running verify/doctor)" -ForegroundColor Yellow
}

Write-Section "== Status =="
git status | Out-Host

Write-Host ""
Write-Host "Next (typical):" -ForegroundColor Cyan
Write-Host "  # make changes, commit, push" -ForegroundColor Cyan
Write-Host "  pwsh -NoProfile -File scripts/jp-publish-work.ps1" -ForegroundColor Cyan
