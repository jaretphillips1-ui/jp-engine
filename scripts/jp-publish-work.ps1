param(
  [string]$ExpectedRepo = 'C:\dev\JP_ENGINE\jp-engine',
  [string]$BaseBranch   = 'master',

  # If branch is empty (no commits ahead of base), auto-delete it (remote + local) and return.
  [bool]  $AutoCleanupEmptyBranch = $true,

  # Default PR title/body (used only when creating a PR, unless -ForceUpdatePrText is used)
  [string]$DefaultTitle = 'JP: work update',
  [string]$DefaultBody  = @"
### Summary
One-shot publish: push branch, create PR if needed, watch checks, squash-merge, delete branch, sync master.

### Notes
- Uses current branch as PR head.
- Refuses to run on master.
- Refuses (or cleans up) if branch has no commits ahead of master.
"@,

  # If true, updates PR title/body even if PR already exists.
  [bool]  $ForceUpdatePrText = $false,

  # Optional: if set (non-empty), tag current master after merge+sync and push tag.
  # Example: -TagGreen 'green-YYYY-MM-DD-latest'
  [string]$TagGreen = ''
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

function Assert-GitOk([string]$msg) {
  if ($LASTEXITCODE -ne 0) { throw "Git failed ($LASTEXITCODE): $msg" }
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

function Require-CleanTree {
  $porc = @(git status --porcelain)
  if ($porc.Count -gt 0) {
    Write-Host "Working tree is not clean. Refusing to publish/merge."
    $porc | ForEach-Object { Write-Host $_ }
    throw "Clean/stash your working tree first, then re-run."
  }
}

function Get-CurrentBranch {
  $b = (git branch --show-current).Trim()
  if ([string]::IsNullOrWhiteSpace($b)) { throw "Safety gate: couldn't detect current branch." }
  return $b
}

function Cleanup-EmptyBranch([string]$branch) {
  Write-Host ""
  Write-Host "Auto-cleanup is ON. Cleaning up empty branch '$branch'..."
  Write-Host ""

  try { git push origin --delete $branch | Out-Null } catch { }

  git switch $BaseBranch | Out-Null
  Assert-GitOk "git switch $BaseBranch"

  git pull --ff-only origin $BaseBranch | Out-Null
  Assert-GitOk "git pull --ff-only origin $BaseBranch"

  try { git branch -D $branch | Out-Null } catch { }

  Write-Host "Cleaned up. Now on: $(git branch --show-current) @ $(git rev-parse --short HEAD)"
}

function Ensure-Pr([string]$branch) {
  $prUrl = $null
  try { $prUrl = (gh pr view $branch --repo $Repo --json url -q .url 2>$null).Trim() } catch { }

  if (-not $prUrl) {
    $prUrl = (gh pr create --repo $Repo --base $BaseBranch --head $branch --title $DefaultTitle --body $DefaultBody).Trim()
    return @{ Url = $prUrl; Created = $true }
  }

  return @{ Url = $prUrl; Created = $false }
}

function Update-PrText([string]$prUrl) {
  gh pr edit $prUrl --repo $Repo --title $DefaultTitle --body $DefaultBody | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "gh pr edit failed ($LASTEXITCODE)." }
}

function Wait-Checks([string]$prUrl) {
  gh pr checks $prUrl --repo $Repo --watch
  if ($LASTEXITCODE -ne 0) { throw "Checks failed or did not complete cleanly (gh pr checks exit $LASTEXITCODE)." }
}

function Merge-Pr([string]$prUrl) {
  gh pr merge $prUrl --repo $Repo --squash --delete-branch --auto
  if ($LASTEXITCODE -ne 0) { throw "Merge failed (gh pr merge exit $LASTEXITCODE)." }
}

function Verify-Merged([string]$prUrl) {
  # IMPORTANT: this jq script is a DOUBLE-QUOTED here-string so it can't terminate the outer @' '@
  $jq = @"
"state=" + .state
+ " closed=" + (.closed|tostring)
+ " mergedAt=" + ((.mergedAt // "null")|tostring)
+ " mergeCommit=" + (.mergeCommit.oid // "null")
+ " url=" + .url
"@

  $j = gh pr view $prUrl --repo $Repo --json state,closed,mergedAt,mergeCommit,url --jq $jq
  $j
  if ($j -notmatch 'mergedAt=(?!null)') { throw "Publish did not complete (mergedAt is null)." }
}

function Sync-Base {
  git fetch --prune origin | Out-Null
  Assert-GitOk "git fetch --prune origin"

  git switch $BaseBranch | Out-Null
  Assert-GitOk "git switch $BaseBranch"

  git pull --ff-only origin $BaseBranch | Out-Null
  Assert-GitOk "git pull --ff-only origin $BaseBranch"
}

function Cleanup-LocalBranchIfExists([string]$branch) {
  $exists = git branch --list $branch
  if ($exists) {
    try { git branch -D $branch | Out-Null } catch { }
  }
}

function Maybe-TagGreen {
  if ([string]::IsNullOrWhiteSpace($TagGreen)) { return }
  $t = $TagGreen.Trim()
  if ($t -notmatch '^green-') { throw "TagGreen must start with 'green-' (got '$t')." }

  git tag -a $t -m "Known-green baseline (publish-work)" | Out-Null
  Assert-GitOk "git tag -a $t"

  git push origin $t | Out-Null
  Assert-GitOk "git push origin $t"

  Write-Host "Tagged + pushed: $t"
}

# ====== RUN ======
Require-RepoRoot
Require-CleanTree

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "gh not found on PATH." }
gh auth status | Out-Null

$Repo = (git config --get remote.origin.url)
if (-not $Repo) { throw "Could not read remote.origin.url" }
try { $Repo = (gh repo view --json nameWithOwner -q .nameWithOwner 2>$null).Trim() } catch { }

$branch = Get-CurrentBranch
if ($branch -eq $BaseBranch) { throw "Safety gate: you are on '$BaseBranch'. Switch to a feature branch first." }

git fetch origin $BaseBranch | Out-Null
Assert-GitOk "git fetch origin $BaseBranch"

$ahead = [int]((git rev-list --count "origin/$BaseBranch..$branch").Trim())
if ($ahead -le 0) {
  Write-Host ""
  Write-Host "Branch '$branch' has NO commits ahead of '$BaseBranch'."
  Write-Host "Nothing meaningful to PR/merge."
  Write-Host ""

  if (-not $AutoCleanupEmptyBranch) { throw "Refusing: empty branch (AutoCleanupEmptyBranch is OFF)." }
  Cleanup-EmptyBranch -branch $branch
  return
}

git push -u origin $branch | Out-Null
Assert-GitOk "git push -u origin $branch"

$pr = Ensure-Pr -branch $branch
$prUrl = $pr.Url

Write-Host ""
Write-Host "Branch: $branch  (ahead of $BaseBranch by $ahead commit(s))"
Write-Host "PR:     $prUrl"
Write-Host ""

if ($pr.Created -or $ForceUpdatePrText) { Update-PrText -prUrl $prUrl }

Wait-Checks   -prUrl $prUrl
Merge-Pr      -prUrl $prUrl

Write-Host ""
Write-Host "Merge requested (auto). Verifying..."
Verify-Merged -prUrl $prUrl

Write-Host ""
Write-Host "Merged + deleted remote branch."
Write-Host ""

Sync-Base
Cleanup-LocalBranchIfExists -branch $branch
Maybe-TagGreen

Write-Host ""
Write-Host "=== JP: PUBLISH COMPLETE ==="
Write-Host "Now on: $(git branch --show-current) @ $(git rev-parse --short HEAD)"
Write-Host "Status: 0 change(s)"
