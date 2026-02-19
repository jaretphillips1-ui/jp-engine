param(
  [string]$ExpectedRepo = 'C:\dev\JP_ENGINE\jp-engine',
  [string]$BaseBranch   = 'master',
  [string]$BranchPrefix = 'work',
  [bool]  $AutoStash    = $true
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

function Get-LastGreenTag {
  # Prefer newest tag that matches green-* by creator date; falls back gracefully.
  $t = $null
  try {
    $t = (git for-each-ref --sort=-creatordate --format="%(refname:short)" "refs/tags/green-*" 2>$null | Select-Object -First 1)
  } catch { }
  if ($t) { return $t.Trim() }
  return ""
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
  $msg   = "AUTO-STASH before start-work ($stamp)"
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
Write-Host "=== JP: START WORK ==="
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
if ($LASTEXITCODE -ne 0) { throw "jp-verify.ps1 failed with exit code $LASTEXITCODE" }

pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\jp-doctor.ps1
if ($LASTEXITCODE -ne 0) { throw "jp-doctor.ps1 failed with exit code $LASTEXITCODE" }

# ====== SUMMARY (handoff-ready) ======
$head = (git log -1 --oneline --decorate)
$porc2 = @(git status --porcelain)
$green = Get-LastGreenTag

Write-Host ""
Write-Host "=== JP: SUMMARY ==="
Write-Host ("Branch: " + (git branch --show-current).Trim())
Write-Host ("HEAD:   " + $head)
Write-Host ("Dirty:  " + $porc2.Count + " change(s)")
if ($green) { Write-Host ("Green:  " + $green) } else { Write-Host "Green:  (none)" }
Write-Host ""
Write-Host "Next:"
Write-Host " - Make your edits/commits intentionally"
Write-Host " - Then use scripts\jp-publish-work.ps1 to PR/merge (separate step)"
