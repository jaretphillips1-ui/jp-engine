param(
  [string]$ExpectedRepo   = 'C:\Dev\JP_ENGINE\jp-engine',
  [string]$BaseBranch     = 'master',
  [string]$BranchPrefix   = 'work',
  [bool]  $AutoStash      = $true,

  # If there are staged changes, commit with this message; otherwise do NOT create noise commits.
  [string]$CommitMessage  = 'work: update',

  # If there is nothing to commit, do NOT push an empty branch to origin.
  [bool]  $PushOnlyIfCommit = $true
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

# ====== GATE: repo root ======
Set-Location -LiteralPath $ExpectedRepo

$top = (git rev-parse --show-toplevel 2>$null)
if (-not $top) { throw "Safety gate: not a git repo (git rev-parse failed)." }

$expectedNorm = Normalize-Path $ExpectedRepo
$topNorm      = Normalize-Path $top.Trim()

if ($topNorm -ne $expectedNorm) {
  throw "Safety gate: expected repo '$expectedNorm', got '$topNorm'"
}

# ====== DIRTY CHECK + OPTIONAL STASH ======
$dirty = @(git status --porcelain)
$didStash = $false

if ($dirty.Count -gt 0) {
  Write-Host "=== DIRTY WORKING TREE DETECTED ==="
  $dirty | ForEach-Object { Write-Host $_ }
  Write-Host ""

  if (-not $AutoStash) {
    throw "Safety gate: working tree dirty. Commit/stash first (AutoStash is OFF)."
  }

  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $msg   = "AUTO-STASH before feature branch ($stamp)"
  git stash push -u -m $msg | Out-Null
  Assert-GitOk "git stash push"
  $didStash = $true

  Write-Host "Stashed changes: $msg"
  Write-Host ""
}

# ====== UPDATE BASE + CREATE BRANCH ======
git fetch origin | Out-Null
Assert-GitOk "git fetch origin"

git switch $BaseBranch | Out-Null
Assert-GitOk "git switch $BaseBranch"

git pull --ff-only | Out-Null
Assert-GitOk "git pull --ff-only"

$stamp2 = Get-Date -Format 'yyyyMMdd-HHmm'
$branch = "$BranchPrefix/$stamp2"
git switch -c $branch | Out-Null
Assert-GitOk "git switch -c $branch"

Write-Host ""
Write-Host "Now on: $branch @ $(git rev-parse --short HEAD)"
Write-Host ""

if ($didStash) {
  Write-Host "Re-applying stashed work onto this new branch..."
  git stash pop | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "git stash pop had conflicts or failed. Resolve, then continue manually."
  }
  Write-Host "Stash applied."
  Write-Host ""
}

# ====== RUN VERIFY + DOCTOR ======
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\jp-verify.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\jp-doctor.ps1

# ====== STAGE + PRE-COMMIT + COMMIT ======
git add -A
Assert-GitOk "git add -A"

if (Get-Command pre-commit -ErrorAction SilentlyContinue) {
  pre-commit run --all-files
  git add -A
  Assert-GitOk "git add -A (after pre-commit)"
} else {
  Write-Host "pre-commit not found (ok) ΓÇö skipping explicit run."
}

$didCommit = $false
if (git diff --cached --quiet) {
  Write-Host ""
  Write-Host "No staged changes to commit."
} else {
  # Guard: only commit if there is a staged diff
  & git diff --cached --quiet
  if ($LASTEXITCODE -eq 0) {
    Write-Host "No staged diff -> skipping git commit."
  } else {
    git commit -m $CommitMessage | Out-Null
    Assert-GitOk "git commit"
    $didCommit = $true
  }

  Assert-GitOk "git commit"
  $didCommit = $true
}

# ====== PUSH (optional) ======
if ($PushOnlyIfCommit -and (-not $didCommit)) {
  Write-Host ""
  Write-Host "No commit was created, so NOT pushing this branch (PushOnlyIfCommit = true)."
  Write-Host "If you still want to push it, run:"
  Write-Host "  git push -u origin $branch"
  Write-Host ""
} else {
  git push -u origin $branch | Out-Null
  Assert-GitOk "git push -u origin $branch"
}

Write-Host ""
Write-Host "Done."
Write-Host "Branch: $branch"
Write-Host "Next: run scripts\jp-publish-work.ps1 (separate step)."
