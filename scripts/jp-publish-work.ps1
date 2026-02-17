param(
  [string]$ExpectedRepo = 'C:\Dev\JP_ENGINE\jp-engine',
  [string]$BaseBranch   = 'master',

  # If branch is empty (no commits ahead of base), auto-delete it.
  [bool]  $AutoCleanupEmptyBranch = $true,

  # Default PR title/body (used only when creating a PR)
  [string]$DefaultTitle = 'JP: work update',
  [string]$DefaultBody  = @"
### Summary
One-shot PR: push branch, create PR if needed, watch checks, squash-merge, delete branch, sync master.

### Notes
- Uses current branch as PR head.
- Refuses to run on master.
- Refuses (or cleans up) if branch has no commits ahead of master.
"@
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

# ====== GATE: repo root + tools ======
Set-Location -LiteralPath $ExpectedRepo

$top = (git rev-parse --show-toplevel 2>$null)
if (-not $top) { throw "Safety gate: not a git repo (git rev-parse failed)." }

$expectedNorm = Normalize-Path $ExpectedRepo
$topNorm      = Normalize-Path $top.Trim()
if ($topNorm -ne $expectedNorm) {
  throw "Safety gate: expected repo '$expectedNorm', got '$topNorm'"
}

# Refuse if working tree dirty (publish should be “clean + deterministic”)
$porc = @(git status --porcelain)
if ($porc.Count -gt 0) {
  Write-Host "Working tree is not clean. Refusing to publish/merge."
  $porc | ForEach-Object { Write-Host $_ }
  throw "Clean/stash your working tree first, then re-run."
}

$branch = (git branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($branch)) { throw "Safety gate: couldn't detect current branch." }
if ($branch -eq $BaseBranch) { throw "Safety gate: you are on '$BaseBranch'. Switch to a feature branch first." }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "gh not found on PATH." }
gh auth status | Out-Null

# Make sure base is up to date
git fetch origin $BaseBranch | Out-Null
Assert-GitOk "git fetch origin $BaseBranch"

# ====== EMPTY BRANCH CHECK (ahead commits) ======
$ahead = [int]((git rev-list --count "origin/$BaseBranch..$branch").Trim())
if ($ahead -le 0) {
  Write-Host ""
  Write-Host "Branch '$branch' has NO commits ahead of '$BaseBranch'."
  Write-Host "Nothing meaningful to PR/merge."
  Write-Host ""

  if (-not $AutoCleanupEmptyBranch) {
    throw "Refusing: empty branch (AutoCleanupEmptyBranch is OFF)."
  }

  Write-Host "Auto-cleanup is ON. Cleaning up branch '$branch'..."
  Write-Host ""

  try { git push origin --delete $branch | Out-Null } catch { }

  git switch $BaseBranch | Out-Null
  Assert-GitOk "git switch $BaseBranch"

  git pull --ff-only | Out-Null
  Assert-GitOk "git pull --ff-only"

  try { git branch -D $branch | Out-Null } catch { }

  Write-Host "Cleaned up. Now on: $(git branch --show-current) @ $(git rev-parse --short HEAD)"
  return
}

# ====== PR + MERGE ======
git push -u origin $branch | Out-Null
Assert-GitOk "git push -u origin $branch"

$prUrl = $null
try { $prUrl = (gh pr view $branch --json url -q .url 2>$null).Trim() } catch { }

if (-not $prUrl) {
  $prUrl = (gh pr create --base $BaseBranch --head $branch --title $DefaultTitle --body $DefaultBody).Trim()
}

Write-Host ""
Write-Host "Branch: $branch  (ahead of $BaseBranch by $ahead commit(s))"
Write-Host "PR:     $prUrl"
Write-Host ""

gh pr checks $prUrl --watch
gh pr merge  $prUrl --squash --delete-branch

Write-Host ""
Write-Host "Merged + deleted branch."
Write-Host ""

# Sync local base to merged result
git fetch origin $BaseBranch | Out-Null
git switch $BaseBranch | Out-Null
git pull --ff-only | Out-Null

Write-Host "Now on: $(git branch --show-current) @ $(git rev-parse --short HEAD)"
