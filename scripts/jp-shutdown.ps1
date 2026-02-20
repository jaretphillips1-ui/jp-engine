[CmdletBinding()]
param(
  [string]$RepoRoot = (Get-Location).Path,

  # Skip these only if you know what you're doing
  [switch]$SkipBackups,
  [switch]$KeepRestoreDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

$repoN = Normalize-Path $RepoRoot
Set-Location -LiteralPath $repoN
# --- OPERATIONAL SCRIPT GATE (master must contain required ops scripts) ---
# Reason: shutdown switches to master; ops scripts must exist there or shutdown will fail.
$need = @(
  'scripts/jp-hold-backups.ps1',
  'scripts/jp-handoff-write.ps1'
)

foreach ($p in $need) {
  $onMaster = git show "master:$p" 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $onMaster) {
    throw "Operational script missing on master: $p
Fix: merge the ops scripts PR into master, then rerun shutdown."
  }
}
# --- END OPERATIONAL SCRIPT GATE ---


Step "GATE (master clean + synced)" {
  git fetch --prune | Out-Host
  git checkout master | Out-Host
  git pull --ff-only | Out-Host

  $s = git status --porcelain
  if ($s) { throw ("Working tree NOT clean:`n{0}" -f $s) }

  git status -sb | Out-Host
  git log -1 --oneline | Out-Host
}

Step "STOP node/npm dev processes (if any)" {
  Get-Process node -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
}

Step "REMOVE common dev locks (safe if missing)" {
  $lock = Join-Path $repoN '.next\dev\lock'
  if (Test-Path -LiteralPath $lock) {
    Remove-Item -LiteralPath $lock -Force
    Write-Host ("Removed: {0}" -f $lock) -ForegroundColor DarkCyan
  } else {
    Write-Host "No Next.js lock found." -ForegroundColor DarkCyan
  }
}

if (-not $SkipBackups) {
  Step "HOLD BACKUPS + RESTORE TEST" {
    $hold = Join-Path $repoN 'scripts\jp-hold-backups.ps1'
    if (-not (Test-Path -LiteralPath $hold)) { throw "Missing: scripts\jp-hold-backups.ps1" }

    if ($KeepRestoreDir) {
      pwsh -NoProfile -File $hold -KeepRestoreDir
    } else {
      pwsh -NoProfile -File $hold
    }

    if ($LASTEXITCODE -ne 0) { throw ("jp-hold-backups.ps1 failed (exit code {0})." -f $LASTEXITCODE) }
  }
} else {
  Write-Host "WARNING: SkipBackups was set — backups not held." -ForegroundColor Yellow
}

Step "FINAL STATUS CHECK" {
  git status -sb | Out-Host
}

Step "WRITE HANDOFF (docs/JP_ENGINE_HANDOFF.md)" {
  $w = Join-Path $repoN 'scripts\jp-handoff-write.ps1'
  if (-not (Test-Path -LiteralPath $w)) { throw "Missing: scripts\jp-handoff-write.ps1" }
  pwsh -NoProfile -File $w
  if ($LASTEXITCODE -ne 0) { throw ("jp-handoff-write.ps1 failed (exit code {0})." -f $LASTEXITCODE) }
}

Write-Host ""
Write-Host "🟢 JP ENGINE FULL SHUTDOWN COMPLETE (with backups held + restore proven)." -ForegroundColor Green
