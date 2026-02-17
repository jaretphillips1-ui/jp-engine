[CmdletBinding()]
param(
  # Remote/local branch to delete after merge, e.g. "docs/jp-blueprint-20260217-1527"
  [string]$BranchToDelete,

  # Continue even if working tree is dirty (NOT recommended)
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Assert-RepoRoot {
  if (-not (Test-Path -LiteralPath (Join-Path (Get-Location).Path '.git'))) {
    throw "Gate failed: run from repo root."
  }
}

function Get-OwnerRepo {
  $origin = (git config --get remote.origin.url).Trim()
  if (-not $origin) { throw "Could not read remote.origin.url" }

  $m = [regex]::Match($origin, 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(?:\.git)?$')
  if (-not $m.Success) { throw "Could not parse owner/repo from origin: $origin" }

  [pscustomobject]@{
    Owner = $m.Groups['owner'].Value
    Repo  = $m.Groups['repo'].Value
  }
}

function Assert-CleanOrForce {
  if ($Force) { return }
  $dirty = (git status --porcelain)
  if ($dirty) {
    throw "Working tree is not clean. Commit/stash first or rerun with -Force."
  }
}

function Delete-RemoteBranchIfRequested {
  param([string]$Branch)

  if (-not $Branch) { return }

  # If gh isn't available, we still do the local parts safely.
  $gh = Get-Command gh -ErrorAction SilentlyContinue
  if (-not $gh) {
    Write-Warning "gh CLI not found. Skipping remote branch delete for '$Branch'."
    return
  }

  $or = Get-OwnerRepo

  # Branch names include '/', so encode safely for the API path segment
  $encoded = [System.Uri]::EscapeDataString($Branch)

  Write-Host ""
  Write-Host "Deleting remote branch (if it exists): origin/$Branch" -ForegroundColor Cyan

  # DELETE /repos/{owner}/{repo}/git/refs/heads/{ref}
  # If it doesn't exist, GitHub returns 422; we treat that as "already gone".
  $endpoint = "/repos/$($or.Owner)/$($or.Repo)/git/refs/heads/$encoded"

  $p = Start-Process -FilePath "gh" -ArgumentList @("api", $endpoint, "-X", "DELETE") -NoNewWindow -PassThru -Wait -ErrorAction SilentlyContinue
  if ($p.ExitCode -eq 0) {
    Write-Host "Remote branch deleted." -ForegroundColor Green
  } else {
    Write-Warning "Remote delete may have failed or branch already deleted (exit=$($p.ExitCode))."
    Write-Warning "If needed, delete it manually in GitHub later."
  }
}

function Delete-LocalBranchIfRequested {
  param([string]$Branch)

  if (-not $Branch) { return }

  # Never delete the current branch
  $current = (git branch --show-current).Trim()
  if ($current -eq $Branch) {
    throw "Refusing to delete the currently checked out branch: $Branch"
  }

  # Only delete if it exists locally
  $exists = $false
  git show-ref --verify --quiet ("refs/heads/{0}" -f $Branch)
  if ($LASTEXITCODE -eq 0) { $exists = $true }

  if ($exists) {
    Write-Host "Deleting local branch: $Branch" -ForegroundColor Cyan
    git branch -D -- $Branch
  } else {
    Write-Host "Local branch not present: $Branch (skipping)" -ForegroundColor DarkGray
  }
}

# ---- Main ----
Assert-RepoRoot
Assert-CleanOrForce

Write-Host ""
Write-Host "Fetch + prune..." -ForegroundColor Cyan
git fetch --prune origin

Write-Host ""
Write-Host "Switch to master + fast-forward..." -ForegroundColor Cyan
git checkout master
git pull --ff-only origin master

Delete-RemoteBranchIfRequested -Branch $BranchToDelete

Write-Host ""
Write-Host "Prune again (after possible remote delete)..." -ForegroundColor Cyan
git fetch --prune origin

Delete-LocalBranchIfRequested -Branch $BranchToDelete

Write-Host ""
Write-Host "Status + branches:" -ForegroundColor Cyan
git status
git branch -vv
