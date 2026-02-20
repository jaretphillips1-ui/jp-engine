[CmdletBinding()]
param(
  [string]$RepoRoot = (Get-Location).Path,
  [string]$ReleasePrefix = 'jp-save',
  [switch]$OpenRelease
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-LastExitCode {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Context)
  if ($global:LASTEXITCODE -ne 0) {
    throw ("{0} failed (exit code {1})." -f $Context, $global:LASTEXITCODE)
  }
}

function Step([string]$n,[scriptblock]$sb){
  Write-Host ""
  Write-Host ("=== {0} ===" -f $n) -ForegroundColor Cyan
  try { & $sb; Write-Host ("PASS: {0}" -f $n) -ForegroundColor Green }
  catch { Write-Host ("FAIL: {0}" -f $n) -ForegroundColor Red; throw }
}

function Normalize-Path([string]$p) {
  if (-not $p) { return '' }
  $p = $p.Trim().Replace('/','\')
  try { $p = (Resolve-Path -LiteralPath $p).Path } catch { }
  $p.TrimEnd('\')
}

function Get-ExistingSaveRoots {
  param([Parameter(Mandatory)][string]$RepoRoot)

  $roots = New-Object System.Collections.Generic.List[string]

  # Preferred: OneDrive AI_Workspace (primary save root today)
  $c1 = Join-Path $env:USERPROFILE 'OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST'
  $c2 = if ($env:OneDrive) { Join-Path $env:OneDrive 'AI_Workspace\_SAVES\JP_ENGINE\LATEST' } else { $null }

  foreach ($c in @($c1,$c2) | Where-Object { $_ }) {
    $n = Normalize-Path $c
    if ($n -and (Test-Path -LiteralPath $n)) { $roots.Add($n) }
  }

  # Also consider repo-adjacent layouts if they exist (future-proof)
  $repoN = Normalize-Path $RepoRoot
  $adj1  = Normalize-Path (Join-Path $repoN '..\_SAVES\JP_ENGINE\LATEST')
  $adj2  = Normalize-Path (Join-Path $repoN '..\..\_SAVES\JP_ENGINE\LATEST')
  foreach ($c in @($adj1,$adj2) | Where-Object { $_ }) {
    if (Test-Path -LiteralPath $c) { $roots.Add($c) }
  }

  # De-dupe
  $roots.ToArray() | Sort-Object -Unique
}

function Discover-LatestArtifacts {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$SaveRoot
  )

  $rootN = Normalize-Path $SaveRoot
  if (-not (Test-Path -LiteralPath $rootN)) {
    throw ("Save root does not exist: {0}" -f $rootN)
  }

  $files = Get-ChildItem -LiteralPath $rootN -File

  $zipLatest = $files | Where-Object { $_.Name -ieq 'JP_ENGINE_LATEST.zip' } | Select-Object -First 1

  # Prefer newest timestamped zip (JP_ENGINE_YYYYMMDD_HHMMSS.zip)
  $zipTimed = $files |
    Where-Object { $_.Name -match '^JP_ENGINE_\d{8}_\d{6}\.zip$' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  if (-not $zipTimed) {
    # fallback: newest JP_ENGINE_*.zip excluding LATEST.zip
    $zipTimed = $files |
      Where-Object { $_.Name -like 'JP_ENGINE_*.zip' -and $_.Name -ine 'JP_ENGINE_LATEST.zip' } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
  }

  $mark = $files | Where-Object { $_.Name -ieq 'JP_ENGINE_LATEST_CHECKPOINT.txt' } | Select-Object -First 1
  $sha  = $files | Where-Object { $_.Name -ieq 'JP_ENGINE_ZIP_SHA256.txt' } | Select-Object -First 1

  if (-not $zipTimed -and -not $zipLatest) {
    throw ("No JP_ENGINE zip artifacts found in: {0}" -f $rootN)
  }

  [pscustomobject]@{
    SaveRoot   = $rootN
    PrimaryZip = if ($zipTimed) { $zipTimed.FullName } else { $zipLatest.FullName }
    LatestZip  = if ($zipLatest) { $zipLatest.FullName } else { $null }
    Mark       = if ($mark) { $mark.FullName } else { $null }
    Sha        = if ($sha) { $sha.FullName } else { $null }
  }
}

$repoN = Normalize-Path $RepoRoot
Set-Location -LiteralPath $repoN

$saveScript = Join-Path $repoN 'scripts\jp-save.ps1'
if (-not (Test-Path -LiteralPath $saveScript)) { throw ("Missing: {0}" -f $saveScript) }

Step 'RUN jp-save.ps1 (produce artifacts)' {
  # IMPORTANT: jp-save prints to host; we do not try to parse captured output.
  & $saveScript | Out-Host
}

Step 'DISCOVER artifacts from save root (bulletproof)' {
  $roots = Get-ExistingSaveRoots -RepoRoot $repoN
  if (-not $roots -or $roots.Count -eq 0) {
    throw "No known save roots exist. Expected OneDrive AI_Workspace or repo-adjacent _SAVES."
  }

  $best = $null
  foreach ($r in $roots) {
    try {
      $cand = Discover-LatestArtifacts -SaveRoot $r
      if (-not $best) { $best = $cand; continue }

      $bestTime = (Get-Item -LiteralPath $best.PrimaryZip).LastWriteTime
      $candTime = (Get-Item -LiteralPath $cand.PrimaryZip).LastWriteTime
      if ($candTime -gt $bestTime) { $best = $cand }
    } catch {
      # ignore roots that don't contain artifacts
    }
  }

  if (-not $best) {
    throw ("No JP_ENGINE artifacts discovered in roots:`n - {0}" -f ($roots -join "`n - "))
  }

  foreach ($p in @($best.PrimaryZip,$best.LatestZip,$best.Mark,$best.Sha) | Where-Object { $_ }) {
    if (-not (Test-Path -LiteralPath $p)) { throw ("Artifact missing: {0}" -f $p) }
  }

  Write-Host ("JP SAVE ROOT: {0}" -f $best.SaveRoot) -ForegroundColor DarkCyan
  Write-Host ("PrimaryZip : {0}" -f $best.PrimaryZip) -ForegroundColor DarkCyan

  Get-ChildItem -LiteralPath $best.SaveRoot -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 15 Name,Length,LastWriteTime |
    Format-Table -AutoSize | Out-Host

  Set-Variable -Name JP_SAVE_DISCOVERED -Value $best -Scope Script
}

Step 'CREATE GitHub Release + UPLOAD assets' {
  $ts    = Get-Date -Format 'yyyyMMdd-HHmmss'
  $tag   = "{0}-{1}" -f $ReleasePrefix, $ts
  $title = "JP Engine Save {0}" -f $ts

  $assets = @($JP_SAVE_DISCOVERED.PrimaryZip)
  foreach ($opt in @($JP_SAVE_DISCOVERED.LatestZip,$JP_SAVE_DISCOVERED.Mark,$JP_SAVE_DISCOVERED.Sha)) {
    if ($opt) { $assets += $opt }
  }

  gh release create $tag --title $title --notes "Automated save snapshot from jp-save.ps1" | Out-Host
  Assert-LastExitCode -Context "gh release create"

  foreach ($a in $assets) {
    gh release upload $tag $a --clobber | Out-Host
    Assert-LastExitCode -Context ("gh release upload: {0}" -f $a)
  }

  Write-Host ("Release created: tag={0}" -f $tag) -ForegroundColor DarkCyan
  Set-Variable -Name JP_RELEASE_TAG -Value $tag -Scope Script
}

if ($OpenRelease) {
  Step 'OPEN Release in browser' {
    gh release view $JP_RELEASE_TAG --web | Out-Null
    Assert-LastExitCode -Context "gh release view --web"
  }
}

Write-Host ""
Write-Host "🟢 JP Save + Publish: COMPLETE (release created + assets uploaded)." -ForegroundColor Green
