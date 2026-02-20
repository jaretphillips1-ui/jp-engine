# JP Engine - One-button start workflow
# Creates a new work/* branch, pushes it, and optionally runs verify/doctor.
#
# Examples:
#   pwsh -NoProfile -File scripts/jp-start-work.ps1 -Slug auto-merge-tweaks -DryRun
#   pwsh -NoProfile -File scripts/jp-start-work.ps1 -Slug cleanup -Live -SkipChecks
#   pwsh -NoProfile -File scripts/jp-start-work.ps1 -Slug feature-x -Live -AutoStash
#
# Notes:
# - Refuses unless starting from master
# - Refuses if working tree dirty (unless -AutoStash)
# - You MUST explicitly choose -DryRun (alias -WhatIf) OR -Live
# - DryRun prints intended actions and NEVER creates/changes branches, stashes, or runs verify/doctor

param(
  [Parameter(Mandatory=$true)]
  [string]$Slug,

  [Parameter(Mandatory=$false)]
  [string]$RepoRoot = (Get-Location).Path,

  [Parameter(Mandatory=$false)]
  [switch]$AutoStash,

  [Parameter(Mandatory=$false)]
  [switch]$SkipChecks,

  # Non-mutating preview mode (safe). Alias "WhatIf" for convenience.
  [Parameter(Mandatory=$false)]
  [Alias('WhatIf')]
  [switch]$DryRun,

  # Explicit opt-in for live mutations (branch creation / push / etc).
  [Parameter(Mandatory=$false)]
  [switch]$Live
)

Set-StrictMode -Version Latest
. "$PSScriptRoot\lib\jp-assert.ps1"
$ErrorActionPreference = 'Stop'

function Write-Section([string]$Text) {
  Write-Host ""
  Write-Host $Text -ForegroundColor Cyan
}




function Assert-OnMaster() {
  $current = (git branch --show-current).Trim()
  if ($current -ne 'master') { throw "Refusing: must start from 'master' (current: '$current')." }
}

function Get-PorcCount() {
  $porc = @(git status --porcelain)
  return $porc.Count
}

function Assert-CleanOrExplain([switch]$AllowDirty) {
  $n = Get-PorcCount
  if ($n -ne 0 -and -not $AllowDirty) {
    throw "Working tree not clean. Commit/stash first (or use -AutoStash)."
  }
  return $n
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

function Run-IfExists([string]$File, [string]$Label, [switch]$Preview) {
  if (-not (Test-Path -LiteralPath $File)) {
    Write-Host "SKIP: $Label (missing: $File)" -ForegroundColor Yellow
    return
  }
  if ($Preview) {
    Write-Host "DRYRUN: would run $Label ($File)" -ForegroundColor Cyan
    return
  }
  Write-Section "== $Label =="
  pwsh -NoProfile -File $File | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "$Label failed: $File" }
}

# ---- main ----
Assert-RepoRoot -RepoRoot $RepoRoot
Assert-OnMaster

# Require explicit mode selection
if ($DryRun -and $Live) { throw "Refusing: choose exactly one mode: -DryRun OR -Live (not both)." }
if (-not $DryRun -and -not $Live) { throw "Refusing: you must specify -DryRun (alias -WhatIf) OR -Live." }

$preview = $DryRun

$slugSafe = Sanitize-Slug -S $Slug
$stamp = (Get-Date).ToString('yyyyMMdd-HHmm')
$newBranch = "work/$stamp-$slugSafe"

Write-Section "== Summary =="
Write-Host "RepoRoot: $RepoRoot" -ForegroundColor Cyan
Write-Host "Branch (current): master" -ForegroundColor Cyan
Write-Host "New branch: $newBranch" -ForegroundColor Cyan
Write-Host ("Mode: " + ($(if ($preview) { "DRYRUN" } else { "LIVE" }))) -ForegroundColor Cyan

# Cleanliness logic:
# - LIVE: require clean unless -AutoStash, and if -AutoStash, actually stash only if needed.
# - DRYRUN: NEVER stash; just report what would happen.
$dirtyCount = Assert-CleanOrExplain -AllowDirty:$AutoStash
if ($dirtyCount -ne 0) {
  if ($preview) {
    if ($AutoStash) {
      Write-Host "DRYRUN: working tree is dirty ($dirtyCount entries); would git stash push -u" -ForegroundColor Cyan
    } else {
      throw "Refusing: working tree is dirty ($dirtyCount entries). Use -AutoStash or clean it first."
    }
  } else {
    if ($AutoStash) {
      Write-Section "== Auto-stash dirty tree =="
      git stash push -u -m "jp-start-work auto-stash" | Out-Host
      if ($LASTEXITCODE -ne 0) { throw "git stash failed." }
    }
  }
}

Write-Section "== Sync master (ff-only) =="
if ($preview) {
  Write-Host "DRYRUN: git fetch origin --prune" -ForegroundColor Cyan
  Write-Host "DRYRUN: git checkout master" -ForegroundColor Cyan
  Write-Host "DRYRUN: git pull --ff-only origin master" -ForegroundColor Cyan
} else {
  git fetch origin --prune | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }

  git checkout master | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git checkout master failed." }

  git pull --ff-only origin master | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git pull --ff-only failed." }
}

Write-Section "== Create + push work branch =="
if ($preview) {
  Write-Host "DRYRUN: git checkout -b $newBranch" -ForegroundColor Cyan
  Write-Host "DRYRUN: git push -u origin $newBranch" -ForegroundColor Cyan
} else {
  git checkout -b $newBranch | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git checkout -b failed." }

  git push -u origin $newBranch | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git push -u failed." }
}

if (-not $SkipChecks) {
  $verify = Join-Path $RepoRoot 'scripts\jp-verify.ps1'
  $doctor = Join-Path $RepoRoot 'scripts\jp-doctor.ps1'
  Run-IfExists -File $verify -Label 'Run jp-verify' -Preview:$preview
  Run-IfExists -File $doctor -Label 'Run jp-doctor' -Preview:$preview
} else {
  Write-Host "SkipChecks: true (not running verify/doctor)" -ForegroundColor Yellow
}

Write-Section "== Status =="
if ($preview) {
  Write-Host "DRYRUN: done (no mutations performed)." -ForegroundColor Green
} else {
  git status | Out-Host
  Write-Host ""
  Write-Host "Next (typical):" -ForegroundColor Cyan
  Write-Host "  # make changes, commit, push" -ForegroundColor Cyan
  Write-Host "  pwsh -NoProfile -File scripts/jp-publish-work.ps1" -ForegroundColor Cyan
}
