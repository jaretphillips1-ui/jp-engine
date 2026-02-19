param(
  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [string]$Repo = 'jaretphillips1-ui/jp-engine',

  [Parameter(Mandatory=$false)]
  [switch]$SkipSmoke
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$m){ throw $m }

$repoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $repoPath

if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) { Fail "Not a git repo: $repoPath" }

$branch = (git branch --show-current).Trim()
if ($branch -notlike 'work/*') { Fail "Publish must run on a work/* branch. Current: '$branch'." }

if (@(git status --porcelain).Count -ne 0) { Fail "Working tree not clean. Commit/stash first." }

# Hard-stop empty PR condition
if (@(git log --oneline master..HEAD).Count -eq 0) {
  Fail "No commits between master and $branch. STOP (empty PR)."
}

# Create PR if missing; otherwise reuse existing
$prUrl = ''
try {
  $prUrl = (gh pr view --repo $Repo $branch --json url --jq .url 2>$null)
} catch {}

if ([string]::IsNullOrWhiteSpace($prUrl)) {
  $title = "work: $branch"
  $body  = "Automated publish from $branch.

- Hard-stops empty PRs
- Watches checks
- Squash merges + deletes branch
- Syncs master + smoke + tags baseline green"
  $prUrl = (gh pr create --repo $Repo --base master --head $branch --title $title --body $body)
  if ([string]::IsNullOrWhiteSpace($prUrl)) { Fail "PR creation did not return a URL." }
}

Write-Host "PR: $prUrl"

Write-Host "Watching checks..."
gh pr checks $prUrl --repo $Repo --watch --interval 10

Write-Host "Merging (squash + delete branch)..."
gh pr merge $prUrl --repo $Repo --squash --delete-branch

Write-Host "Syncing master..."
git checkout master | Out-Null
git pull | Out-Null
if (@(git status --porcelain).Count -ne 0) { Fail "Master not clean after pull (unexpected)." }

if (-not $SkipSmoke) {
  Write-Host "Smoke..."
  pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath 'scripts\jp-smoke.ps1')
  if ($LASTEXITCODE -ne 0) { Fail "Smoke failed (exit $LASTEXITCODE)." }
}

Write-Host "Tag green baseline..."
pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath 'scripts\jp-tag-green.ps1') -RunSmoke
if ($LASTEXITCODE -ne 0) { Fail "jp-tag-green failed (exit $LASTEXITCODE)." }

Write-Host "DONE"
git status -sb
git log -1 --oneline --decorate
