param(
  [Parameter(Mandatory=$true)]
  [int] $PrNumber,

  [Parameter()]
  [string] $Repo = 'jaretphillips1-ui/jp-engine',

  [Parameter()]
  [string] $BaseBranch = 'master'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$m) { throw $m }

function Assert-RepoRoot {
  $git = Join-Path (Get-Location) '.git'
  if (-not (Test-Path -LiteralPath $git)) { Fail "Run from repo root. Current: $((Get-Location).Path)" }
}

function Assert-CleanTree {
  $porc = git status --porcelain
  if ($porc) { Fail "Working tree not clean.`n$porc" }
}

function Get-RequiredChecksSafe {
  param([int]$Pr, [string]$Repo)
  # gh pr checks --required sometimes returns "no required checks reported..."
  # In that case, return $null to trigger fallback rollup validation.
  try {
    $out = gh pr checks $Pr --repo $Repo --required --json name,state,link 2>&1
    if ($out -match 'no required checks reported') { return $null }
    $json = $out | Out-String | ConvertFrom-Json
    return @($json)
  } catch {
    return $null
  }
}

function Get-StatusRollup {
  param([int]$Pr, [string]$Repo)
  # Use statusCheckRollup as authoritative fallback.
  $j = gh pr view $Pr --repo $Repo --json statusCheckRollup --jq '.statusCheckRollup' | ConvertFrom-Json
  return @($j)
}

function Assert-ChecksGreen {
  param([int]$Pr, [string]$Repo)

  $checks = Get-RequiredChecksSafe -Pr $Pr -Repo $Repo
  if ($null -ne $checks -and $checks.Count -gt 0) {
    $bad = @($checks | Where-Object { $_.state -notin @('SUCCESS','SKIPPED') })
    if ($bad.Count -gt 0) {
      "Required checks not green:"
      $bad | ForEach-Object { " - $($_.name): $($_.state)  $($_.link)" }
      Fail "Refusing to merge: required checks not green."
    }
    "All required checks are green."
    return
  }

  "No required checks reported; falling back to statusCheckRollup."

  $rollupRaw = Get-StatusRollup -Pr $Pr -Repo $Repo
  $rollup = @($rollupRaw | ForEach-Object { $_ })
  if ($rollup.Count -eq 0) { Fail "No checks found in statusCheckRollup; refusing to merge." }

  function Get-CheckState([object]$c) {
    $st = $null
    if ($null -ne $c.PSObject.Properties['conclusion']) { $st = $c.conclusion }
    if (-not $st -and $null -ne $c.PSObject.Properties['state']) { $st = $c.state }
    if (-not $st -and $null -ne $c.PSObject.Properties['status']) { $st = $c.status }
    if (-not $st) { $st = 'UNKNOWN' }
    return ($st.ToString().Trim().ToUpperInvariant())
  }

  $pending = @($rollup | Where-Object { (Get-CheckState $_) -in @('PENDING','IN_PROGRESS','QUEUED') })
  if ($pending.Count -gt 0) {
    "Pending checks:"
    $pending | ForEach-Object { " - $($_.name): $(Get-CheckState $_)  $($_.detailsUrl)" }
    Fail "Refusing to merge: checks still pending."
  }

  $failed = @($rollup | Where-Object { (Get-CheckState $_) -in @('FAILURE','CANCELLED','TIMED_OUT','ACTION_REQUIRED') })
  if ($failed.Count -gt 0) {
    "Failing checks:"
    $failed | ForEach-Object { " - $($_.name): $(Get-CheckState $_)  $($_.detailsUrl)" }
    Fail "Refusing to merge: failing checks present."
  }

  $unknown = @($rollup | Where-Object { (Get-CheckState $_) -notin @('SUCCESS','SKIPPED') })
  if ($unknown.Count -gt 0) {
    "Unknown checks:"
    $unknown | ForEach-Object { " - $($_.name): $(Get-CheckState $_)  $($_.detailsUrl)" }
    Fail "Refusing to merge: unknown check states present."
  }

  "All checks green via statusCheckRollup."
}

function Assert-Mergeable {
  param([int]$Pr, [string]$Repo)
  $m = gh pr view $Pr --repo $Repo --json mergeable --jq '.mergeable'
  if ($m -ne 'MERGEABLE') { Fail "PR not mergeable (mergeable=$m)." }
}

function Get-HeadRef {
  param([int]$Pr, [string]$Repo)
  $h = gh pr view $Pr --repo $Repo --json headRefName --jq '.headRefName'
  if (-not $h) { Fail "Could not determine headRefName." }
  return $h
}

Assert-RepoRoot
Assert-CleanTree
gh auth status | Out-Null

"=== JP: MERGE PR #$PrNumber ==="
Assert-ChecksGreen -Pr $PrNumber -Repo $Repo
Assert-Mergeable  -Pr $PrNumber -Repo $Repo

$headRef = Get-HeadRef -Pr $PrNumber -Repo $Repo
"PR head branch: $headRef"

"=== JP: SQUASH MERGE + DELETE REMOTE BRANCH ==="
gh pr merge $PrNumber --repo $Repo --squash --delete-branch --auto

"=== JP: SYNC LOCAL $BaseBranch ==="
git fetch origin $BaseBranch --prune | Out-Null
git switch $BaseBranch | Out-Null
git pull --ff-only origin $BaseBranch | Out-Null

"=== JP: DELETE LOCAL FEATURE BRANCH (if exists) ==="
$hasLocal = git branch --list $headRef
if ($hasLocal) {
  git branch -D $headRef | Out-Null
  "Deleted local branch: $headRef"
} else {
  "Local branch not present. OK."
}

"=== JP: DONE ==="
"On branch: " + (git branch --show-current).Trim()
"HEAD:      " + (git log -1 --oneline --decorate)
"Status:    " + ((git status --porcelain | Measure-Object).Count) + " change(s)"
