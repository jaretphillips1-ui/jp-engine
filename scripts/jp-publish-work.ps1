param(
  [Parameter(Mandatory=$false)]
  [string]$Title = '',

  [Parameter(Mandatory=$false)]
  [string]$Body  = '',

  [Parameter(Mandatory=$false)]
  [switch]$SkipChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$m) { throw $m }

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if ([string]::IsNullOrWhiteSpace($repoRoot)) { Fail "Not inside a git repo." }
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current 2>$null)
if ([string]::IsNullOrWhiteSpace($branch)) { Fail "Could not detect current branch (detached HEAD). Refusing publish." }
$branch = $branch.Trim()
if ($branch -eq 'master') { Fail "Refusing publish from master. Use a work/* branch." }

# Default title/body if not provided
if ([string]::IsNullOrWhiteSpace($Title)) {
  $Title = (git log -1 --pretty=%s).Trim()
  if ([string]::IsNullOrWhiteSpace($Title)) { $Title = "JP: update ($branch)" }
}
if ([string]::IsNullOrWhiteSpace($Body)) {
  $Body = @"
## What
Describe what changed.

## Why
Describe why it matters.

## How
- Key steps / logic

## Notes
(Any follow-ups.)
"@
}

# Create PR (or locate existing) and ensure title/body set via gh
$prUrl = $null
try {
  $prUrl = gh pr create --base master --head $branch --title $Title --body $Body
} catch {
  # If PR exists, gh will error; we locate it and continue.
}

if (-not $prUrl) {
  $prUrl = gh pr view --json url --jq .url
}
if ([string]::IsNullOrWhiteSpace($prUrl)) { Fail "Could not determine PR URL for branch '$branch'." }

gh pr edit $prUrl --title $Title --body $Body | Out-Null

"=== JP: PR ==="
$prUrl
""

if (-not $SkipChecks) {
  "=== JP: WATCH CHECKS ==="
  gh pr checks $prUrl --watch
  ""
}

"=== JP: MERGE (SQUASH + DELETE BRANCH) ==="
gh pr merge $prUrl --squash --delete-branch
""

"=== JP: SYNC MASTER (LOCAL) ==="
git checkout master | Out-Null
git pull | Out-Null
""

"=== JP: LOCAL BRANCH CLEANUP ==="
git branch -D $branch 2>$null | Out-Null
""

"=== JP: DONE ==="
git status --porcelain
git log -1 --oneline --decorate
