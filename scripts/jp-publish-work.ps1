# JP Engine - One-button publish workflow
# Creates or updates a PR for the current work/* branch, watches checks, merges (squash + delete branch),
# syncs local master, then deletes the local feature branch.
#
# Examples:
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -Title "scripts: improve foo"
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -NoWatch
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -TagGreenBaseline
#
# Notes:
# - Refuses to run from master
# - Refuses if working tree is dirty
# - Refuses if there are no commits vs master

param(
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
  [switch]$TagGreenBaseline
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

function Assert-CleanTree() {
  $porc = @(git status --porcelain)
  if ($porc.Count -ne 0) { throw "Working tree not clean. Commit/stash first." }
}

function Get-CurrentBranch() {
  $b = (git branch --show-current).Trim()
  if (-not $b) { throw "Could not determine current branch." }
  return $b
}

function Assert-NotBase([string]$Branch, [string]$BaseBranch) {
  if ($Branch -eq $BaseBranch) { throw "Refusing: currently on '$BaseBranch'. Checkout a work/* branch first." }
}

function Assert-HasDiffVsBase([string]$BaseBranch, [string]$Branch) {
  $n = (git rev-list --count "$BaseBranch..$Branch").Trim()
  if (-not $n) { $n = '0' }
  if ([int]$n -le 0) { throw "Refusing: no commits between $BaseBranch and $Branch." }
}

function Ensure-GhAuth() {
  gh auth status | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "gh auth status failed." }
}

function Ensure-RemoteUpdated() {
  git fetch origin --prune | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }
}

function Get-OrCreatePR([string]$RepoFull, [string]$HeadBranch, [string]$BaseBranch, [string]$MaybeTitle, [string]$MaybeBody) {
  $existing = $null
  try {
    $existing = gh pr list --repo $RepoFull --head $HeadBranch --base $BaseBranch --state open --json number,url,title | ConvertFrom-Json
  } catch { $existing = $null }

  if ($existing -and $existing.Count -gt 0) {
    $pr = $existing[0]
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

  Write-Section "== Create PR =="
  $createdUrl = gh pr create --repo $RepoFull --base $BaseBranch --head $HeadBranch --title $t --body $b
  if ($LASTEXITCODE -ne 0) { throw "gh pr create failed." }

  $prNum = (gh pr view $createdUrl --repo $RepoFull --json number | ConvertFrom-Json).number
  if (-not $prNum) { throw "Could not resolve PR number after create." }

  Write-Host "Created PR: #$prNum $createdUrl" -ForegroundColor Green
  return [int]$prNum
}

function UpdatePRText([string]$RepoFull, [int]$PrNum, [string]$MaybeTitle, [string]$MaybeBody) {
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

function WatchChecks([string]$RepoFull, [int]$PrNum, [switch]$SkipWatch) {
  Write-Section "== PR checks =="
  if ($SkipWatch) {
    gh pr checks $PrNum --repo $RepoFull | Out-Host
  } else {
    gh pr checks $PrNum --repo $RepoFull --watch | Out-Host
  }
  if ($LASTEXITCODE -ne 0) { throw "PR checks failed." }
}

function MergePR([string]$RepoFull, [int]$PrNum) {
  Write-Section "== Merge (squash + delete branch) =="
  gh pr merge $PrNum --repo $RepoFull --squash --delete-branch | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "gh pr merge failed." }
}

function SyncBase([string]$BaseBranch) {
  Write-Section "== Sync $BaseBranch =="
  git checkout $BaseBranch | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git checkout $BaseBranch failed." }
  git pull --ff-only origin $BaseBranch | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git pull --ff-only failed." }
}

function DeleteLocalBranch([string]$Branch) {
  Write-Section "== Delete local branch =="
  $cur = (git branch --show-current).Trim()
  if ($cur -eq $Branch) { throw "Refusing: currently on '$Branch'." }
  git branch -D -- $Branch | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "git branch -D failed for: $Branch" }
}

function MaybeTagGreen([switch]$DoTag) {
  if (-not $DoTag) { return }
  $stamp = (Get-Date).ToString('yyyyMMdd-HHmm')
  $tag = "baseline/green-$stamp"
  Write-Section "== Tag green baseline: $tag =="
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
Assert-CleanTree
Assert-HasDiffVsBase -BaseBranch $Base -Branch $curBranch

Write-Section "== Push current branch (safe) =="
git push | Out-Host
if ($LASTEXITCODE -ne 0) { throw "git push failed." }

$prNum = Get-OrCreatePR -RepoFull $Repo -HeadBranch $curBranch -BaseBranch $Base -MaybeTitle $Title -MaybeBody $Body
UpdatePRText -RepoFull $Repo -PrNum $prNum -MaybeTitle $Title -MaybeBody $Body
WatchChecks -RepoFull $Repo -PrNum $prNum -SkipWatch:$NoWatch
MergePR -RepoFull $Repo -PrNum $prNum

SyncBase -BaseBranch $Base
DeleteLocalBranch -Branch $curBranch
MaybeTagGreen -DoTag:$TagGreenBaseline

Write-Section "== Final status =="
git status | Out-Host
git log -1 --oneline | Out-Host
Write-Host ""
Write-Host "Done." -ForegroundColor Green
