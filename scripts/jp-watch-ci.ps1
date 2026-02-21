<#
JP ENGINE — Watch CI Runs (toast + ding)

Why this exists:
- gh `run view --json` uses field `url` (not `htmlURL` on some gh versions)
- When you’re alt-tabbed or sound is off, a toast + log is the least-friction signal
- Additive helper: does not modify other scripts

Usage:
  # Watch latest runs on master (auto)
  .\scripts\jp-watch-ci.ps1

  # Watch specific run ids (from `gh run list`)
  .\scripts\jp-watch-ci.ps1 -RunId 22245236946,22245236963

Notes:
- Uses BurntToast if available; falls back to console beep only
- Writes a log to _DROP\jp-watch-ci_*.log.txt
#>

param(
  [string]$Branch = 'master',
  [string[]]$RunId,
  [int]$PollSeconds = 15,
  [int]$MaxMinutes = 30,
  [switch]$OpenOnFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Have-Cmd([string]$name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Notify([string]$title, [string]$body, [int]$beepHz = 880, [int]$beepMs = 200) {
  try {
    $bt = Get-Command New-BurntToastNotification -ErrorAction SilentlyContinue
    if ($bt) {
      New-BurntToastNotification -Text $title, $body | Out-Null
    }
  } catch { }

  try { [Console]::Beep($beepHz, $beepMs) } catch { }
}

function Get-RepoRoot() {
  $root = (git rev-parse --show-toplevel).Trim()
  if (-not $root) { throw "Could not resolve repo root (git rev-parse failed)." }
  return $root
}

function Get-LatestRunIds([string]$branch) {
  # Get newest runs first; pick the most recent set (limit 10) and return their IDs
  $json = gh run list --branch $branch --limit 10 --json databaseId,status,workflowName,createdAt 2>$null
  if (-not $json) { throw "gh run list returned no JSON (auth?)" }
  $runs = $json | ConvertFrom-Json
  if (-not $runs -or $runs.Count -lt 1) { throw "No runs found for branch: $branch" }

  function Get-MinuteKey($v) {
    if ($null -eq $v) { return '' }

    if ($v -is [datetime]) {
      return $v.ToString('yyyy-MM-ddTHH:mm')
    }

    # gh sometimes returns createdAt as string; normalize to yyyy-MM-ddTHH:mm when possible
    $s = [string]$v
    $dt = $null
    if ([datetime]::TryParse($s, [ref]$dt)) {
      return $dt.ToString('yyyy-MM-ddTHH:mm')
    }

    if ($s.Length -ge 16) { return $s.Substring(0,16) }
    return $s
  }

  # Return IDs for the newest push batch (same createdAt minute window is good enough)
  $firstKey = Get-MinuteKey $runs[0].createdAt

  $ids = @()
  foreach ($r in $runs) {
    if ((Get-MinuteKey $r.createdAt) -eq $firstKey) {
      $ids += $r.databaseId.ToString()
    }
  }

  if (-not $ids -or $ids.Count -lt 1) {
    $ids = @($runs[0].databaseId.ToString())
  }
  return $ids
}

if (-not (Have-Cmd 'git')) { throw "git not found on PATH" }
if (-not (Have-Cmd 'gh'))  { throw "gh not found on PATH" }

$RepoRoot = Get-RepoRoot
Set-Location -LiteralPath $RepoRoot

$Drop = Join-Path $RepoRoot '_DROP'
if (-not (Test-Path -LiteralPath $Drop)) { New-Item -ItemType Directory -Path $Drop | Out-Null }
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$Log   = Join-Path $Drop ("jp-watch-ci_{0}.log.txt" -f $Stamp)

"JP WATCH CI — START  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Set-Content -LiteralPath $Log -Encoding utf8
("repo:   {0}" -f $RepoRoot) | Add-Content -LiteralPath $Log -Encoding utf8
("branch: {0}" -f $Branch)   | Add-Content -LiteralPath $Log -Encoding utf8
"" | Add-Content -LiteralPath $Log -Encoding utf8

if (-not $RunId -or $RunId.Count -lt 1) {
  $RunId = Get-LatestRunIds -branch $Branch
}

("watching run ids: {0}" -f ($RunId -join ', ')) | Add-Content -LiteralPath $Log -Encoding utf8


  # Startup banner (console) — prints once so you instantly see log path + config
  Write-Host "`nJP WATCH CI — STARTED" -ForegroundColor Cyan
  Write-Host ("  Log: {0}" -f $Log) -ForegroundColor Cyan
  Write-Host ("  Poll: {0}s  Max: {1}m" -f $PollSeconds, $MaxMinutes) -ForegroundColor Cyan
  Write-Host ("  OpenOnFailure: {0}  OpenOnTimeout: {1}" -f $OpenOnFailure, $OpenOnTimeout) -ForegroundColor Cyan
  Write-Host ("  RunIds: {0}" -f ($RunId -join ', ')) -ForegroundColor Cyan
"" | Add-Content -LiteralPath $Log -Encoding utf8

Notify "JP Engine" ("Watching CI ({0})..." -f $Branch) 660 140

$deadline = (Get-Date).AddMinutes($MaxMinutes)

while ($true) {
  if ((Get-Date) -gt $deadline) {
    Notify "JP Engine" ("CI watch timed out after {0} minutes." -f $MaxMinutes) 330 300
    throw ("CI watch timeout. See log: {0}" -f $Log)
  }

  $allCompleted = $true
  $anyFailed = $false
  $failedUrl = $null

  foreach ($id in $RunId) {
    # IMPORTANT: gh run view uses JSON field `url` (not htmlURL on your version)
    $j = gh run view $id --json url,workflowName,status,conclusion,updatedAt 2>$null | ConvertFrom-Json
    if (-not $j) { throw ("Could not read run id {0} (auth?)" -f $id) }

    $line = ("{0} | {1}/{2} | {3} | {4}" -f $j.workflowName,$j.status,$j.conclusion,$j.updatedAt,$j.url)
    $line | Add-Content -LiteralPath $Log -Encoding utf8

    if ($j.status -ne 'completed') { $allCompleted = $false }

    if ($j.status -eq 'completed' -and $j.conclusion -ne 'success') {
      $anyFailed = $true
      if (-not $failedUrl) { $failedUrl = $j.url }
    }
  }

  if ($anyFailed) {
    Notify "JP Engine" "CI FAILED — open log / run page." 220 350
    if ($OpenOnFailure -and $failedUrl) { try { Start-Process $failedUrl } catch { } }
    throw ("CI FAILED. See log: {0}" -f $Log)
  }

  if ($allCompleted) {
    Notify "JP Engine" "CI complete — success." 880 200
    Notify "JP Engine" "CI complete — success." 988 200
    ("JP WATCH CI — SUCCESS  {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) | Add-Content -LiteralPath $Log -Encoding utf8
    Write-Host ("`nCI GREEN. Log: {0}" -f $Log) -ForegroundColor Green
    break
  }

  Start-Sleep -Seconds $PollSeconds
}
