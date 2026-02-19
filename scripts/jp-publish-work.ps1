. (Join-Path $PSScriptRoot 'lib\jp-gh-auth.ps1')

# JP Engine - One-button publish workflow
# Creates or updates a PR for the current work/* branch, watches checks, merges (squash + delete branch),
# syncs local master, then deletes the local feature branch.
#
# Examples:
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -Title "scripts: improve foo"
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -NoWatch
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -TagGreenBaseline
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -DryRun
#
# Notes:
# - Refuses to run from master
# - Refuses unless branch matches work/*
# - Refuses if working tree is dirty
# - Refuses if there are no commits vs base
# - DryRun prints intended actions without mutating anything
param(
  [switch]$ShowAuthStatus,

  [Parameter(Mandatory=$false)]
  [string]$Repo = 'jaretphillips1-ui/jp-engine',

  [Parameter(Mandatory=$false)]
  [string]$RepoRoot = (Get-Location).Path,

  [Parameter(Mandatory=$false)]
  [string]$Base = 'master',

  [Parameter(Mandatory=$false)]
  [string]$Title,

  [Parameter(Mandatory=$false)]
  [string]$Body,

  [Parameter(Mandatory=$false)]
  [switch]$NoWatch,

  [Parameter(Mandatory=$false)]
  [switch]$TagGreenBaseline,

  # Non-mutating preview mode
  [Parameter(Mandatory=$false)]
  [Alias('WhatIf')]
  [switch]$DryRun,

  # Explicit opt-in for live mutations (PR create/update/merge/branch delete).
  [Parameter(Mandatory=$false)]
  [switch]$Live
)

Set-StrictMode -Version Latest
. "$PSScriptRoot\lib\jp-assert.ps1"
$ErrorActionPreference = 'Stop'

# Require explicit mode selection
if ($DryRun -and $Live) { throw "Refusing: choose exactly one mode: -DryRun OR -Live (not both)." }
if (-not $DryRun -and -not $Live) { throw "Refusing: you must specify -DryRun (alias -WhatIf) OR -Live." }

$preview = $DryRun

function Write-Section([string]$Text) {
  Write-Host ""
  Write-Host $Text -ForegroundColor Cyan
}




function Get-CurrentBranch() {
  $b = (git branch --show-current).Trim()
  if (-not $b) { throw "Could not determine current branch." }
  return $b
}

function Assert-NotBase([string]$Branch, [string]$BaseBranch) {
  if ($Branch -eq $BaseBranch) { throw "Refusing: currently on '$BaseBranch'. Checkout a work/* branch first." }
}

function Assert-IsWorkBranch([string]$Branch) {
  if ($Branch -notlike 'work/*') {
    throw "Refusing: branch must match 'work/*' (current: '$Branch')."
  }
}

function Get-CommitCountVsBase([string]$BaseBranch, [string]$Branch) {
  $n = (git rev-list --count "$BaseBranch..$Branch").Trim()
  if (-not $n) { $n = '0' }
  return [int]$n
}

function Assert-HasDiffVsBase([string]$BaseBranch, [string]$Branch) {
  $n = Get-CommitCountVsBase -BaseBranch $BaseBranch -Branch $Branch
  if ($n -le 0) { throw "Refusing: no commits between $BaseBranch and $Branch." }
}
function Ensure-RemoteUpdated() {
  git fetch origin --prune | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }
}

function Find-OpenPR([string]$RepoFull, [string]$HeadBranch, [string]$BaseBranch) {
  $existing = $null
  try {
    $existing = gh pr list --repo $RepoFull --head $HeadBranch --base $BaseBranch --state open --json number,url,title | ConvertFrom-Json
  } catch { $existing = $null }

  if ($existing -and $existing.Count -gt 0) { return $existing[0] }
  return $null
}

function Get-OrCreatePR([string]$RepoFull, [string]$HeadBranch, [string]$BaseBranch, [string]$MaybeTitle, [string]$MaybeBody, [switch]$Preview) {
  $pr = Find-OpenPR -RepoFull $RepoFull -HeadBranch $HeadBranch -BaseBranch $BaseBranch
  if ($pr) {
    Write-Host "Found existing PR: #$($pr.number) $($pr.url)" -ForegroundColor Green
    return [int]$pr.number
  }

  $t = $MaybeTitle
  if (-not $t) { $t = "work: $HeadBranch" }

  $b = $MaybeBody
  if (-not $b) {
    $b = @"
Automated via jp-publish-work.ps1

- Branch: $HeadBranch
- Base:   $BaseBranch
"@
  }

  if ($Preview) {
    Write-Host "DRYRUN would create PR with:" -ForegroundColor Cyan
    Write-Host "  title: $t" -ForegroundColor Cyan
    Write-Host "  body : (omitted)" -ForegroundColor Cyan
    return 0
  }

  Write-Section "== Create PR =="
  $createdUrl = gh pr create --repo $RepoFull --base $BaseBranch --head $HeadBranch --title $t --body $b
  if ($LASTEXITCODE -ne 0) { throw "gh pr create failed." }

  $prNum = (gh pr view $createdUrl --repo $RepoFull --json number | ConvertFrom-Json).number
  if (-not $prNum) { throw "Could not resolve PR number after create." }

  Write-Host "Created PR: #$prNum $createdUrl" -ForegroundColor Green
  return [int]$prNum
}

function UpdatePRText([string]$RepoFull, [int]$PrNum, [string]$MaybeTitle, [string]$MaybeBody, [switch]$Preview) {
  if ($Preview) {
    if ($MaybeTitle) { Write-Host "DRYRUN would update PR title." -ForegroundColor Cyan }
    if ($MaybeBody)  { Write-Host "DRYRUN would update PR body."  -ForegroundColor Cyan }
    return
  }

  if ($MaybeTitle) {
    Write-Section "== Update PR title =="
    gh pr edit $PrNum --repo $RepoFull --title $MaybeTitle | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "gh pr edit --title failed." }
  }
  if ($MaybeBody) {
    Write-Section "== Update PR body =="
    gh pr edit $PrNum --repo $RepoFull --body $MaybeBody | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "gh pr edit --body failed." }
  }
}

function WatchChecks([string]$RepoFull, [int]$PrNum, [switch]$SkipWatch, [switch]$Preview) {
  Write-Section "== PR checks =="
  if ($Preview) {
    if ($SkipWatch) { Write-Host "DRYRUN: gh pr checks $PrNum --repo $RepoFull" -ForegroundColor Cyan }
    else { Write-Host "DRYRUN: gh pr checks $PrNum --repo $RepoFull --watch" -ForegroundColor Cyan }
    return
  }

  if ($SkipWatch) { gh pr checks $PrNum --repo $RepoFull | Out-Host }
  else { gh pr checks $PrNum --repo $RepoFull --watch | Out-Host }

  if ($LASTEXITCODE -ne 0) { throw "PR checks failed." }
}

function MergePR([string]$RepoFull, [int]$PrNum, [switch]$Preview) {
  Write-Section "== Merge (squash + delete branch) =="
  if ($Preview) {
    Write-Host "DRYRUN: gh pr merge $PrNum --repo $RepoFull --squash --delete-branch" -ForegroundColor Cyan
    return
  }
  gh pr merge $PrNum --repo $RepoFull --squash --delete-branch | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "gh pr merge failed." }
}

function SyncBase([string]$BaseBranch, [switch]$Preview) {
  Write-Section "== Sync $BaseBranch =="
  if ($Preview) {
    Write-Host "DRYRUN: git checkout $BaseBranch" -ForegroundColor Cyan
    Write-Host "DRYRUN: git pull --ff-only origin $BaseBranch" -ForegroundColor Cyan
    return
  }
  git checkout $BaseBranch | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git checkout $BaseBranch failed." }
  git pull --ff-only origin $BaseBranch | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git pull --ff-only failed." }
}

function DeleteLocalBranch([string]$Branch, [switch]$Preview) {
  Write-Section "== Delete local branch =="
  if ($Preview) {
    Write-Host "DRYRUN: git branch -D -- $Branch" -ForegroundColor Cyan
    return
  }
  $cur = (git branch --show-current).Trim()
  if ($cur -eq $Branch) { throw "Refusing: currently on '$Branch'." }
  git branch -D -- $Branch | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git branch -D failed for: $Branch" }
}

function MaybeTagGreen([switch]$DoTag, [switch]$Preview) {
  if (-not $DoTag) { return }
  $stamp = (Get-Date).ToString('yyyyMMdd-HHmm')
  $tag = "baseline/green-$stamp"
  Write-Section "== Tag green baseline: $tag =="
  if ($Preview) {
    Write-Host "DRYRUN: git tag -a $tag -m `"Green baseline after jp-publish-work merge/sync`"" -ForegroundColor Cyan
    Write-Host "DRYRUN: git push origin $tag" -ForegroundColor Cyan
    return
  }
  git tag -a $tag -m "Green baseline after jp-publish-work merge/sync" | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git tag failed." }
  git push origin $tag | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git push tag failed." }
}

# ---- main ----
Assert-RepoRoot -Root $RepoRoot
Ensure-GhAuth
Ensure-RemoteUpdated

$curBranch = Get-CurrentBranch
Assert-NotBase -Branch $curBranch -BaseBranch $Base
Assert-IsWorkBranch -Branch $curBranch
Assert-CleanTree
Assert-HasDiffVsBase -BaseBranch $Base -Branch $curBranch

$commitCount = Get-CommitCountVsBase -BaseBranch $Base -Branch $curBranch
Write-Section "== Summary =="
Write-Host "Branch: $curBranch" -ForegroundColor Cyan
Write-Host "Base:   $Base" -ForegroundColor Cyan
Write-Host "Commits vs base: $commitCount" -ForegroundColor Cyan
Write-Host ("Mode: " + ($(if ($preview) { "DRYRUN" } else { "LIVE" }))) -ForegroundColor Cyan

Write-Section "== Push current branch (safe) =="
if ($preview) {
  Write-Host "DRYRUN: git push" -ForegroundColor Cyan
} else {
  git push | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git push failed." }
}

$prFound = Find-OpenPR -RepoFull $Repo -HeadBranch $curBranch -BaseBranch $Base
if ($prFound) {
  Write-Host "PR: #$($prFound.number) $($prFound.url)" -ForegroundColor Green
}

$prNum = Get-OrCreatePR -RepoFull $Repo -HeadBranch $curBranch -BaseBranch $Base -MaybeTitle $Title -MaybeBody $Body -Preview:$preview
if ($prNum -eq 0 -and $preview) {
  Write-Host "DRYRUN: PR would be created (no number yet)." -ForegroundColor Cyan
  Write-Host "DRYRUN complete." -ForegroundColor Green
  return
}

UpdatePRText -RepoFull $Repo -PrNum $prNum -MaybeTitle $Title -MaybeBody $Body -Preview:$preview
WatchChecks -RepoFull $Repo -PrNum $prNum -SkipWatch:$NoWatch -Preview:$preview
MergePR -RepoFull $Repo -PrNum $prNum -Preview:$preview
SyncBase -BaseBranch $Base -Preview:$preview
DeleteLocalBranch -Branch $curBranch -Preview:$preview
MaybeTagGreen -DoTag:$TagGreenBaseline -Preview:$preview

Write-Section "== Final status =="
if ($preview) {
  Write-Host "DRYRUN: done (no mutations performed)." -ForegroundColor Green
} else {
  git status | Out-Host
  git log -1 --oneline | Out-Host
  Write-Host ""
  Write-Host "Done." -ForegroundColor Green
}
