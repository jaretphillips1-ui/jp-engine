<#
JP ENGINE — jp-post-merge-cleanup.ps1
Post-merge housekeeping (lightweight, safe, re-runnable)

Goals:
- Keep repo tidy without creating “extra mess”
- Remove stale local branches that are merged or have gone upstream
- Prune remotes
- Confirm master is clean

Notes:
- Never deletes master
- Only deletes local branches that are:
  - merged into master, OR
  - tracking a remote that is marked as gone
- Designed to be safe to re-run
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [switch]$NoDeleteMerged,

  [Parameter(Mandatory = $false)]
  [switch]$NoDeleteGone,

  [Parameter(Mandatory = $false)]
  [switch]$NoPrune
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

function Assert-OnMaster {
  $b = (Git-Out @('branch','--show-current')).Trim()
  if ($b -ne 'master') { Fail ("JP guard: Post-merge cleanup must run on master. Current: " + $b) }
}

function Assert-CleanTree {
  $s = (Git-Out @('status','--porcelain')).Trim()
  if (-not [string]::IsNullOrWhiteSpace($s)) {
    Write-Host $s
    Fail "JP guard: Working tree must be clean for post-merge cleanup."
  }
}

function Get-LocalMergedBranches {
  $raw = Git-Out @('branch','--merged')
  $lines = $raw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  $branches = foreach ($l in $lines) {
    $name = $l -replace '^\*\s+', ''
    $name = $name.Trim()
    if ($name) { $name }
  }
  return $branches | Select-Object -Unique
}

function Get-LocalGoneBranches {
  $raw = Git-Out @('branch','-vv')
  $lines = $raw -split "`r?`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ }
  $gone = foreach ($l in $lines) {
    $t = $l.TrimStart()
    if ($t.StartsWith('* ')) { $t = $t.Substring(2) }
    $parts = $t -split '\s+'
    if ($parts.Count -ge 1) {
      $branch = $parts[0]
      if ($l -match '\[.*:\s*gone\]') { $branch }
    }
  }
  return $gone | Where-Object { $_ } | Select-Object -Unique
}

function Delete-LocalBranchSafe([string]$Branch) {
  if ([string]::IsNullOrWhiteSpace($Branch)) { return }
  if ($Branch -eq 'master') { return }
  $exists = (Git-Out @('branch','--list',$Branch)).Trim()
  if ([string]::IsNullOrWhiteSpace($exists)) { return }

  Write-Host ("Deleting local branch: " + $Branch)
  Git-Run @('branch','-D',$Branch)
}

# ---- main ----
$repoRoot = Find-RepoRootFromScript
Assert-JPRepoRoot -Root $repoRoot
Set-Location -LiteralPath $repoRoot

Write-Host "JP Post-Merge Cleanup — repo root: $repoRoot"
& git --version | Out-Host
if ($LASTEXITCODE -ne 0) { Fail "JP guard: git is required but failed to run." }

Assert-OnMaster
Assert-CleanTree

if (-not $NoPrune) {
  Write-Host "Pruning remotes…"
  Git-Run @('fetch','--prune')
}

$deleted = @()

if (-not $NoDeleteGone) {
  $gone = Get-LocalGoneBranches | Where-Object { $_ -ne 'master' }
  foreach ($b in $gone) {
    Delete-LocalBranchSafe -Branch $b
    $deleted += $b
  }
} else {
  Write-Host "Skipping delete of 'gone' branches (-NoDeleteGone)."
}

if (-not $NoDeleteMerged) {
  $merged = Get-LocalMergedBranches | Where-Object { $_ -ne 'master' }
  foreach ($b in $merged) {
    Delete-LocalBranchSafe -Branch $b
    $deleted += $b
  }
} else {
  Write-Host "Skipping delete of merged branches (-NoDeleteMerged)."
}

Assert-OnMaster
Assert-CleanTree

Write-Host ""
Write-Host "DONE ✅"
if ($deleted.Count -gt 0) {
  $uniq = $deleted | Where-Object { $_ } | Select-Object -Unique
  Write-Host ("Deleted local branches: " + ($uniq -join ', '))
} else {
  Write-Host "Deleted local branches: (none)"
}
Write-Host "Master is clean."

Write-Host ""
Write-Host "Next:"
Write-Host "  git status --porcelain"
Write-Host "  # If this script was just added/changed, commit it once. Otherwise you're done."
Write-Host "  # When ready: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/jp-start-work.ps1"
