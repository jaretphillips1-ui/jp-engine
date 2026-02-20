Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-Path([string]$p) {
  if (-not $p) { return '' }
  $p = $p.Trim().Replace('/','\')
  try { $p = (Resolve-Path -LiteralPath $p).Path } catch { }
  $p.TrimEnd('\')
}

function Step([string]$n,[scriptblock]$sb){
  Write-Host ""
  Write-Host ("=== {0} ===" -f $n) -ForegroundColor Cyan
  try { & $sb; Write-Host ("PASS: {0}" -f $n) -ForegroundColor Green }
  catch { Write-Host ("FAIL: {0}" -f $n) -ForegroundColor Red; throw }
}

param(
  [string]$RepoRoot = (Get-Location).Path,
  [string]$Branch   = 'master',
  [switch]$SkipCIQuickLook
)

$repoN = Normalize-Path $RepoRoot
Set-Location -LiteralPath $repoN

$saveScript = Join-Path $repoN 'scripts\jp-save.ps1'

Step 'GATE (repo root + branch + clean)' {
  $topRaw = (git rev-parse --show-toplevel).Trim()
  $topN   = Normalize-Path $topRaw
  if ($topN -ne $repoN) {
    throw ("Wrong repo root.`nExpected: {0}`nGot     : {1}`n(raw git): {2}" -f $repoN, $topN, $topRaw)
  }

  $b = (git rev-parse --abbrev-ref HEAD).Trim()
  if ($b -ne $Branch) { throw ("Not on expected branch. Expected: {0}  Got: {1}" -f $Branch, $b) }

  $s = git status --porcelain
  if ($s) { throw ("Expected clean tree; got:`n{0}" -f $s) }

  git status -sb | Out-Host
}

Step 'SYNC (fetch + ff-only pull)' {
  git fetch --prune | Out-Host
  git pull --ff-only | Out-Host
  git status -sb | Out-Host
}

Step 'LOCAL OVERALL CHECK (verify / doctor / smoke if present)' {
  $runs = 0

  $verify = Join-Path $repoN 'scripts\jp-verify.ps1'
  if (Test-Path -LiteralPath $verify) { & $verify | Out-Host; $runs++ } else { Write-Host "Skip: scripts\jp-verify.ps1 not found." -ForegroundColor Yellow }

  $doctor = Join-Path $repoN 'scripts\jp-doctor.ps1'
  if (Test-Path -LiteralPath $doctor) { & $doctor | Out-Host; $runs++ } else { Write-Host "Skip: scripts\jp-doctor.ps1 not found." -ForegroundColor Yellow }

  $smoke = Join-Path $repoN 'scripts\jp-smoke.ps1'
  if (Test-Path -LiteralPath $smoke) { & $smoke | Out-Host; $runs++ } else { Write-Host "Skip: scripts\jp-smoke.ps1 not found." -ForegroundColor Yellow }

  if ($runs -eq 0) {
    Write-Host "NOTE: No local verify/doctor/smoke scripts found; overall check was git-only." -ForegroundColor Yellow
  }
}

if (-not $SkipCIQuickLook) {
  Step 'CI QUICK LOOK (latest master runs, if gh available)' {
    try { gh run list --branch $Branch --limit 10 | Out-Host }
    catch { Write-Host "Skip: gh not available/authenticated for run list." -ForegroundColor Yellow }
  }
}

Step 'FULL SAVE (jp-save.ps1) + auto-discover save root from output' {
  if (-not (Test-Path -LiteralPath $saveScript)) {
    throw ("Missing save script: {0}" -f $saveScript)
  }

  # Capture output so we can derive the real save folder from the script’s own printed paths.
  $out = & $saveScript 2>&1 | ForEach-Object { $_.ToString() }
  $out | ForEach-Object { Write-Host $_ }

  $zipLine  = $out | Where-Object { $_ -match '^\s*Zip:\s+' } | Select-Object -First 1
  $markLine = $out | Where-Object { $_ -match '^\s*Mark:\s+' } | Select-Object -First 1

  $path = $null
  if ($zipLine)  { $path = ($zipLine  -replace '^\s*Zip:\s+','').Trim() }
  if (-not $path -and $markLine) { $path = ($markLine -replace '^\s*Mark:\s+','').Trim() }

  if (-not $path) {
    throw "Could not parse save output for Zip:/Mark: lines. jp-save.ps1 must print at least one of them."
  }

  $saveDir = Normalize-Path (Split-Path -Parent $path)
  if (-not (Test-Path -LiteralPath $saveDir)) {
    throw ("Parsed save dir does not exist: {0}" -f $saveDir)
  }

  Write-Host ("JP SAVE ROOT (derived): {0}" -f $saveDir) -ForegroundColor DarkCyan

  Get-ChildItem -LiteralPath $saveDir -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 25 Name,Length,LastWriteTime |
    Format-Table -AutoSize | Out-Host
}

Write-Host ""
Write-Host "🟢 JP Overall Check + Full Save: COMPLETE." -ForegroundColor Green
