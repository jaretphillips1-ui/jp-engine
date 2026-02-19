param(
  [Parameter(Mandatory=$true)][string]$PrUrl,
  [string]$Repo = 'jaretphillips1-ui/jp-engine',
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

  [bool]$EnableAutoMerge = $true,
  [switch]$WaitForMerge,
  [switch]$PostMerge,
  [switch]$OpenWeb,

  [ValidateRange(3,300)][int]$IntervalSeconds = 10,
  [ValidateRange(1,240)][int]$TimeoutMinutes = 30,

  [switch]$SkipSmoke,
  [switch]$SkipTagGreen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$m){ throw $m }

function Notify([string]$title,[string]$msg){
  try {
    if (Get-Module -ListAvailable -Name BurntToast) {
      Import-Module BurntToast -ErrorAction SilentlyContinue | Out-Null
      if (Get-Command New-BurntToastNotification -ErrorAction SilentlyContinue) {
        New-BurntToastNotification -Text $title,$msg | Out-Null
      }
    }
  } catch {}
  try { [console]::Beep(900,200) } catch {}
  try { [console]::Beep(700,200) } catch {}
}

function Get-PrInfo {
  param([string]$PrUrl,[string]$Repo)
  (gh pr view $PrUrl --repo $Repo --json state,mergedAt,mergeStateStatus,autoMergeRequest |
    ConvertFrom-Json)
}

Set-Location -LiteralPath $RepoPath

Write-Host "=== JP AUTO MERGE ==="
Write-Host "RepoPath: $RepoPath"
Write-Host "Repo:     $Repo"
Write-Host "PR:       $PrUrl"
Write-Host ""

if ($OpenWeb) { try { Start-Process $PrUrl | Out-Null } catch {} }

$autoMergeRequested = $false

if ($EnableAutoMerge) {
  Write-Host "=== ENABLE AUTO-MERGE (server-side) ==="
  try {
    gh pr merge $PrUrl --repo $Repo --auto --squash --delete-branch | Out-Host
    Write-Host "Auto-merge requested."
    $autoMergeRequested = $true
  }
  catch {
    Write-Host "Auto-merge unavailable. Smart fallback will handle merge."
  }
}

if (-not $WaitForMerge) {
  Write-Host "NOTE: -WaitForMerge not set. Safe to close this window."
}

if ($WaitForMerge) {

  Write-Host ""
  Write-Host "=== WAIT FOR MERGE ==="
  Write-Host "=============================================" -ForegroundColor Yellow
  Write-Host " WAIT MODE ACTIVE — DO NOT CLOSE THIS WINDOW " -ForegroundColor Yellow
  Write-Host "=============================================" -ForegroundColor Yellow
  Write-Host ""

  $start = Get-Date
  $lastReminder = Get-Date

  if (-not $autoMergeRequested -and $EnableAutoMerge) {
    Write-Host "=== SMART FALLBACK: WATCH + MANUAL MERGE ==="
    gh pr checks $PrUrl --repo $Repo --watch --interval $IntervalSeconds
    gh pr merge $PrUrl --repo $Repo --squash --delete-branch | Out-Host
  }

  while ($true) {

    $o = Get-PrInfo -PrUrl $PrUrl -Repo $Repo

    if ($o.mergedAt) {
      Write-Host "MergedAt: $($o.mergedAt)"
      break
    }

    if (((Get-Date)-$start).TotalMinutes -ge $TimeoutMinutes) {
      Notify "JP AUTO-MERGE (TIMEOUT)" "Timeout waiting for merge."
      Fail "Timeout waiting for merge."
    }

    $secs = [int]((Get-Date)-$start).TotalSeconds
    Write-Host ("…waiting state={0} mergeStateStatus={1} t={2}s" -f $o.state,$o.mergeStateStatus,$secs)

    if (((Get-Date)-$lastReminder).TotalSeconds -ge 30) {
      Write-Host "(REMINDER) Waiting for merge — keep this window open."
      $lastReminder = Get-Date
    }

    Start-Sleep -Seconds $IntervalSeconds
  }

  Notify "JP AUTO-MERGE (MERGED)" "PR merged."
}

if ($PostMerge) {

  Write-Host ""
  Write-Host "=== POST-MERGE (local) ==="

  if (@(git status --porcelain).Count -ne 0) {
    Fail "Working tree not clean."
  }

  Write-Host ""
  Write-Host "=== SYNC MASTER ==="
  git checkout master | Out-Null
  git pull | Out-Null

  if (-not $SkipSmoke) {
    Write-Host ""
    Write-Host "=== SMOKE ==="
    pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath 'scripts\jp-smoke.ps1')
  }

  if (-not $SkipTagGreen) {
    Write-Host ""
    Write-Host "=== TAG GREEN ==="
    pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath 'scripts\jp-tag-green.ps1') -RunSmoke
  }

  Write-Host ""
  Write-Host "=== DONE ==="
  git status -sb
  git log -1 --oneline --decorate

  Notify "JP DONE" "Post-merge complete."
}
