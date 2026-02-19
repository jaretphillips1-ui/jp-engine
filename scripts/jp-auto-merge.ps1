param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$PrUrl,

  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [string]$Repo = 'jaretphillips1-ui/jp-engine',

  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

  # Enable GitHub Auto-merge server-side (default: ON)
  [Parameter(Mandatory=$false)]
  [bool]$EnableAutoMerge = $true,

  # Wait until merged (polls mergedAt). If not set, script can exit after enabling auto-merge.
  [Parameter(Mandatory=$false)]
  [switch]$WaitForMerge,

  # Run local post-merge steps (sync master + smoke + tag green)
  [Parameter(Mandatory=$false)]
  [switch]$PostMerge,

  # Open the PR in a browser once (confidence aid)
  [Parameter(Mandatory=$false)]
  [switch]$OpenWeb,

  # Polling controls
  [Parameter(Mandatory=$false)]
  [ValidateRange(3,300)]
  [int]$IntervalSeconds = 10,

  [Parameter(Mandatory=$false)]
  [ValidateRange(1,240)]
  [int]$TimeoutMinutes = 30,

  # Post-merge toggles
  [Parameter(Mandatory=$false)]
  [switch]$SkipSmoke,

  [Parameter(Mandatory=$false)]
  [switch]$SkipTagGreen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$m){ throw $m }

function Notify([string]$title, [string]$msg){
  try {
    if (Get-Module -ListAvailable -Name BurntToast) {
      Import-Module BurntToast -ErrorAction SilentlyContinue | Out-Null
      if (Get-Command -Name New-BurntToastNotification -ErrorAction SilentlyContinue) {
        New-BurntToastNotification -Text $title, $msg | Out-Null
      }
    }
  } catch {}

  try { [console]::Beep(900,200) } catch {}
  try { [console]::Beep(700,200) } catch {}
}

function Get-PrInfo {
  param([string]$PrUrl,[string]$Repo)

  # IMPORTANT: GitHub CLI does NOT support json field "merged".
  # We use mergedAt (non-null => merged), plus state as a safety check.
  $json = gh pr view $PrUrl --repo $Repo --json state,mergedAt,mergeStateStatus,autoMergeRequest,title,url,headRefName,baseRefName
  return ($json | ConvertFrom-Json)
}

Set-Location -LiteralPath $RepoPath
if (-not (Test-Path -LiteralPath (Join-Path $RepoPath '.git'))) { Fail "Not a git repo: $RepoPath" }

Write-Host "=== JP AUTO MERGE ==="
Write-Host "RepoPath: $RepoPath"
Write-Host "Repo:     $Repo"
Write-Host "PR:       $PrUrl"
Write-Host ""

if ($OpenWeb) {
  try { Start-Process $PrUrl | Out-Null } catch {}
}

$autoMergeRequested = $false

# 1) Enable GitHub auto-merge (server-side). This does NOT require a clean local repo.
if ($EnableAutoMerge) {
  Write-Host "=== ENABLE AUTO-MERGE (server-side) ==="
  $out = @()
  try {
    $out = & gh pr merge $PrUrl --repo $Repo --auto --squash --delete-branch 2>&1
    $out | Out-Host
  } catch {
    # native commands usually don't throw; keep catch anyway
    $_ | Out-Host
  }

  if ($LASTEXITCODE -eq 0) {
    Write-Host "Auto-merge requested (GitHub will merge when green)."
    $autoMergeRequested = $true
  } else {
    Write-Host "NOTE: Auto-merge could not be enabled (will use fallback if -WaitForMerge)."
    $autoMergeRequested = $false
  }

  # Double-check via PR fields (in case gh returned success but autoMergeRequest is already set)
  try {
    $chk = Get-PrInfo -PrUrl $PrUrl -Repo $Repo
    if ($chk.autoMergeRequest) { $autoMergeRequested = $true }
  } catch {}
}

# If we are NOT waiting, we're not acting as a watcher. Safe to close this window after requesting auto-merge.
if (-not $WaitForMerge) {
  Write-Host "NOTE: -WaitForMerge not set. Safe to close this window after enabling auto-merge."
}

# 2) Optional wait loop (uses mergedAt)
if ($WaitForMerge) {
  Write-Host ""
  Write-Host "=== WAIT FOR MERGE ==="
  Write-Host "=============================================" -ForegroundColor Yellow
  Write-Host " WAIT MODE ACTIVE — DO NOT CLOSE THIS WINDOW " -ForegroundColor Yellow
  Write-Host "=============================================" -ForegroundColor Yellow
  Write-Host ""

  $start = Get-Date
  $lastReminder = Get-Date

  # SMART FALLBACK (only in watcher mode):
  # If auto-merge couldn't be enabled, we watch checks then merge manually via gh.
  if ($EnableAutoMerge -and (-not $autoMergeRequested)) {
    Write-Host ""
    Write-Host "=== SMART FALLBACK: WATCH CHECKS + MERGE (auto-merge unavailable) ===" -ForegroundColor Yellow
    & gh pr checks $PrUrl --repo $Repo --watch --interval $IntervalSeconds | Out-Host
    if ($LASTEXITCODE -ne 0) {
      Notify "JP AUTO-MERGE (STOP)" "Checks watch failed. Not merging."
      Fail "gh pr checks failed (exit $LASTEXITCODE). STOP."
    }

    & gh pr merge $PrUrl --repo $Repo --squash --delete-branch 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
      Notify "JP AUTO-MERGE (STOP)" "Fallback merge failed. Check PR/branch protections."
      Fail "Fallback merge failed (exit $LASTEXITCODE). STOP."
    }
  }

  while ($true) {
    $state = ''
    $mergedAt = $null
    $mergeStateStatus = ''
    $auto = $null

    try {
      $o = Get-PrInfo -PrUrl $PrUrl -Repo $Repo
      $state = [string]$o.state
      $mergedAt = $o.mergedAt
      $mergeStateStatus = [string]$o.mergeStateStatus
      $auto = $o.autoMergeRequest
    } catch {
      Write-Host "WARN: Could not query PR state yet. Retrying..."
    }

    if ($mergedAt) {
      Write-Host "MergedAt: $mergedAt"
      break
    }

    if ($state -eq 'CLOSED') {
      Notify "JP AUTO-MERGE (STOP)" "PR is CLOSED but not merged. No local actions run."
      Fail "PR is CLOSED but mergedAt is empty. STOP."
    }

    if (((Get-Date) - $start).TotalMinutes -ge $TimeoutMinutes) {
      Notify "JP AUTO-MERGE (TIMEOUT)" "PR did not merge within $TimeoutMinutes minutes. Check GitHub."
      Fail "Timeout waiting for merge."
    }

    $secs = [int]((Get-Date) - $start).TotalSeconds
    $autoTxt = if ($auto) { 'AUTO=ON' } else { 'AUTO=OFF' }
    Write-Host ("…waiting  state={0}  mergeStateStatus={1}  {2}  t={3}s" -f $state,$mergeStateStatus,$autoTxt,$secs)

    if (((Get-Date) - $lastReminder).TotalSeconds -ge 30) {
      Write-Host "(REMINDER) Waiting for merge — keep this window open."
      $lastReminder = Get-Date
    }

    Start-Sleep -Seconds $IntervalSeconds
  }

  Notify "JP AUTO-MERGE (MERGED)" "PR merged. Ready for optional local post-merge steps."
}

# 3) Optional local post-merge steps (requires clean local repo)
if ($PostMerge) {
  Write-Host ""
  Write-Host "=== POST-MERGE (local) ==="

  if (@(git status --porcelain).Count -ne 0) {
    git status -sb
    git status --porcelain
    Notify "JP POST-MERGE (BLOCKED)" "Working tree not clean. Fix/stash and rerun with -PostMerge."
    Fail "Working tree not clean. STOP."
  }

  Write-Host ""
  Write-Host "=== SYNC MASTER ==="
  git checkout master | Out-Null
  git pull | Out-Null
  if (@(git status --porcelain).Count -ne 0) { Fail "Master not clean after pull (unexpected)." }

  if (-not $SkipSmoke) {
    Write-Host ""
    Write-Host "=== SMOKE ==="
    pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath 'scripts\jp-smoke.ps1')
    if ($LASTEXITCODE -ne 0) {
      Notify "JP POST-MERGE (FAILED)" "Smoke failed after merge. Investigate."
      Fail "Smoke failed (exit $LASTEXITCODE)."
    }
  } else {
    Write-Host ""
    Write-Host "=== SMOKE (skipped) ==="
  }

  if (-not $SkipTagGreen) {
    Write-Host ""
    Write-Host "=== TAG GREEN ==="
    pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath 'scripts\jp-tag-green.ps1') -RunSmoke
    if ($LASTEXITCODE -ne 0) {
      Notify "JP POST-MERGE (FAILED)" "jp-tag-green failed after merge. Investigate."
      Fail "jp-tag-green failed (exit $LASTEXITCODE)."
    }
  } else {
    Write-Host ""
    Write-Host "=== TAG GREEN (skipped) ==="
  }

  Write-Host ""
  Write-Host "=== DONE ==="
  git status -sb
  git log -1 --oneline --decorate
  git tag --list 'baseline/green-*' --sort=-creatordate | Select-Object -First 6

  Notify "JP DONE" "Post-merge complete (sync + smoke/tag as configured)."
}
