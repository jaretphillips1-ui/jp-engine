<#
JP ENGINE — Publish-JPWork (one-button publish workflow)

Default behavior (safe, PR-only):
- Must run on a feature branch (not master)
- Requires clean working tree
- Pushes current branch to origin (sets upstream if needed)
- Creates PR if missing (or reuses existing)
- Waits for checks (unless -SkipWaitChecks)
- Squash-merges PR and deletes remote branch (unless -NoDeleteRemoteBranch)
- Syncs local master (fetch/prune + pull --ff-only)
- Runs scripts\jp-post-merge-cleanup.ps1 if present (unless -NoCleanup)
- Optionally deletes local feature branch (default: delete; use -NoDeleteLocalBranch to keep)

Notes:
- This script is designed to be safe to re-run.
- It never pushes directly to master.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$Title,

  [Parameter(Mandatory = $false)]
  [string]$Body,

  [Parameter(Mandatory = $false)]
  [switch]$Draft,

  [Parameter(Mandatory = $false)]
  [switch]$SkipVerify,

  [Parameter(Mandatory = $false)]
  [switch]$SkipDoctor,

  [Parameter(Mandatory = $false)]
  [switch]$SkipWaitChecks,

  [Parameter(Mandatory = $false)]
  [switch]$NoDeleteRemoteBranch,

  [Parameter(Mandatory = $false)]
  [switch]$NoDeleteLocalBranch,

  [Parameter(Mandatory = $false)]
  [switch]$NoCleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) { throw $Message }

function Find-RepoRootFromScript {
  $root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
  return $root.Path
}

function Assert-JPRepoRoot([string]$Root) {
  if (-not (Test-Path -LiteralPath (Join-Path $Root '.git'))) { Fail "JP guard: Not a git repo root: missing .git at '$Root'." }
  if (-not (Test-Path -LiteralPath (Join-Path $Root 'docs\00_JP_INDEX.md'))) { Fail "JP guard: Not jp-engine: missing docs\00_JP_INDEX.md at '$Root'." }
}

function Git-Run([string[]]$GitArgs) {
  & git @GitArgs | Out-Host
  if ($LASTEXITCODE -ne 0) { Fail ("Command failed: git " + ($GitArgs -join ' ')) }
}

function Git-Out([string[]]$GitArgs) {
  $out = & git @GitArgs 2>&1
  if ($LASTEXITCODE -ne 0) {
    if ($out) { Write-Host ($out | Out-String).TrimEnd() }
    Fail ("Command failed: git " + ($GitArgs -join ' '))
  }
  return ($out | Out-String)
}

function Assert-CleanTree {
  $s = (Git-Out @('status','--porcelain')).Trim()
  if (-not [string]::IsNullOrWhiteSpace($s)) {
    Write-Host $s
    Fail "JP guard: Working tree must be clean before Publish-JPWork."
  }
}

function Assert-OriginRemote {
  $remotes = (Git-Out @('remote')).Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
  if (-not ($remotes -contains 'origin')) { Fail "JP guard: Missing remote 'origin'. Configure origin before publish." }
}

function Get-Branch {
  return (Git-Out @('branch','--show-current')).Trim()
}

function Assert-FeatureBranch([string]$Branch) {
  if ([string]::IsNullOrWhiteSpace($Branch)) { Fail "JP guard: Could not determine current branch." }
  if ($Branch -eq 'master') { Fail "JP guard: Refusing to run on master. Switch to a feature branch." }
}

function Assert-GhReady {
  & gh --version | Out-Host
  if ($LASTEXITCODE -ne 0) { Fail "JP guard: gh CLI is required but failed to run." }

  # Auth check (does not print secrets; will fail if not logged in)
  & gh auth status 2>&1 | Out-Host
  if ($LASTEXITCODE -ne 0) { Fail "JP guard: gh is not authenticated. Run: gh auth login" }
}

function Run-IfExists([string]$PathFromRoot, [string]$Label) {
  $root = Find-RepoRootFromScript
  $full = Join-Path $root $PathFromRoot
  if (-not (Test-Path -LiteralPath $full)) {
    Write-Host ("Skipping {0} (missing: {1})" -f $Label, $PathFromRoot)
    return
  }
  Write-Host ("Running {0}: {1}" -f $Label, $PathFromRoot)
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $full | Out-Host
  if ($LASTEXITCODE -ne 0) { Fail ("Command failed: pwsh -File " + $full) }
}

function Ensure-BranchPushed([string]$Branch) {
  # If upstream exists, normal push. If not, set upstream.
  $up = (Git-Out @('rev-parse','--abbrev-ref','--symbolic-full-name','@{u}')).Trim()
  if ([string]::IsNullOrWhiteSpace($up)) {
    Git-Run @('push','-u','origin','HEAD')
  } else {
    Git-Run @('push')
  }
}

function Get-OrCreatePrUrl([string]$Branch) {
  # If PR exists, return URL. Otherwise create and return URL.
  $existingUrl = $null

  $json = & gh pr view $Branch --json url,state 2>$null
  if ($LASTEXITCODE -eq 0 -and $json) {
    try {
      $obj = $json | ConvertFrom-Json
      if ($obj -and $obj.url) { $existingUrl = [string]$obj.url }
    } catch { }
  }

  if (-not [string]::IsNullOrWhiteSpace($existingUrl)) {
    Write-Host ("PR exists: " + $existingUrl)
    return $existingUrl
  }

  $args = @('pr','create','--base','master','--head',$Branch)

  if ($Draft) { $args += '--draft' }
  if (-not [string]::IsNullOrWhiteSpace($Title)) { $args += @('--title', $Title) }
  if (-not [string]::IsNullOrWhiteSpace($Body))  { $args += @('--body',  $Body)  }

  # If user didn't provide title/body, gh will open an editor unless we use --fill.
  if ([string]::IsNullOrWhiteSpace($Title) -and [string]::IsNullOrWhiteSpace($Body)) {
    $args += '--fill'
  }

  $out = & gh @args 2>&1
  if ($LASTEXITCODE -ne 0) {
    if ($out) { Write-Host ($out | Out-String).TrimEnd() }
    Fail "Publish-JPWork: Failed to create PR."
  }

  # gh pr create prints the URL; capture it safely
  $text = ($out | Out-String)
  $m = [regex]::Match($text, 'https?://\S+')
  if ($m.Success) {
    $url = $m.Value.Trim()
    Write-Host ("Created PR: " + $url)
    return $url
  }

  # fallback: ask gh for URL now
  $json2 = & gh pr view $Branch --json url 2>$null
  if ($LASTEXITCODE -eq 0 -and $json2) {
    try {
      $obj2 = $json2 | ConvertFrom-Json
      if ($obj2 -and $obj2.url) { return [string]$obj2.url }
    } catch { }
  }

  Fail "Publish-JPWork: PR was created (likely) but URL could not be determined."
}

function Wait-Checks([string]$Branch) {
  if ($SkipWaitChecks) {
    Write-Host "Skipping PR checks wait (-SkipWaitChecks)."
    return
  }

  Write-Host "Waiting for PR checks (watch)…"
  & gh pr checks $Branch --watch | Out-Host
  if ($LASTEXITCODE -ne 0) { Fail "Publish-JPWork: PR checks failed or were cancelled." }
}

function Merge-Pr([string]$Branch) {
  $args = @('pr','merge',$Branch,'--squash')

  if (-not $NoDeleteRemoteBranch) {
    $args += '--delete-branch'
  }

  # Avoid interactive prompts where possible:
  $args += '--auto'  # if allowed, will merge when checks pass; safe with Wait-Checks already, but keeps it non-interactive

  $out = & gh @args 2>&1
  if ($LASTEXITCODE -ne 0) {
    if ($out) { Write-Host ($out | Out-String).TrimEnd() }
    Fail "Publish-JPWork: Merge failed."
  }
  Write-Host ($out | Out-String).TrimEnd()
}

function Sync-Master {
  Git-Run @('checkout','master')
  Git-Run @('fetch','--prune')
  Git-Run @('pull','--ff-only')
}

function Delete-LocalBranch([string]$Branch) {
  if ($NoDeleteLocalBranch) {
    Write-Host "Keeping local branch (-NoDeleteLocalBranch)."
    return
  }

  if ($Branch -eq 'master') { return }
  # After syncing master, it's safe to delete the feature branch.
  Git-Run @('branch','-D',$Branch)
}

# ---- main ----
$repoRoot = Find-RepoRootFromScript
Assert-JPRepoRoot -Root $repoRoot
Set-Location -LiteralPath $repoRoot

Write-Host "JP Publish-JPWork — repo root: $repoRoot"
& git --version | Out-Host
if ($LASTEXITCODE -ne 0) { Fail "JP guard: git is required but failed to run." }

Assert-OriginRemote
Assert-CleanTree

$branch = Get-Branch
Assert-FeatureBranch -Branch $branch

Assert-GhReady

# Optional preflight checks (recommended)
if (-not $SkipVerify) { Run-IfExists -PathFromRoot 'scripts\jp-verify.ps1' -Label 'verify' }
if (-not $SkipDoctor) { Run-IfExists -PathFromRoot 'scripts\jp-doctor.ps1' -Label 'doctor' }

# Ensure feature branch is pushed and tracking
Ensure-BranchPushed -Branch $branch

# PR create/reuse
$prUrl = Get-OrCreatePrUrl -Branch $branch

# Checks then merge
Wait-Checks -Branch $branch
Merge-Pr -Branch $branch

# Sync master + optional cleanup
Sync-Master
if (-not $NoCleanup) { Run-IfExists -PathFromRoot 'scripts\jp-post-merge-cleanup.ps1' -Label 'post-merge cleanup' }
Delete-LocalBranch -Branch $branch

Write-Host ""
Write-Host "DONE ✅"
Write-Host ("PR: " + $prUrl)
Write-Host "Master synced and clean (expected)."
Write-Host "Next: start a new branch with Start-JPWork when ready."
