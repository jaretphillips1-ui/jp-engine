Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-JpRepoRoot {
  $candidates = @(
    'C:\Users\lsphi\OneDrive\AI_Workspace\JP_ENGINE\jp-engine',
    'C:\dev\JP_ENGINE\jp-engine'
  )
  $hit = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $hit) {
    throw ("JP Engine repo not found. Checked:`n - " + ($candidates -join "`n - "))
  }
  return $hit
}

$repoRoot = Resolve-JpRepoRoot

# Guard: refuse container-root drift
$container = 'C:\Users\lsphi\OneDrive\AI_Workspace\JP_ENGINE'
if ((Resolve-Path -LiteralPath $repoRoot).Path -notlike (Resolve-Path -LiteralPath $container).Path + '*') {
  # repo might be under C:\dev; that's fine
} else {
  $containerGit = Join-Path $container '.git'
  if (Test-Path -LiteralPath $containerGit) {
    Write-Warning "DRIFT RISK: Found a .git folder in the JP_ENGINE container root: $containerGit"
    Write-Warning "This can cause the exact permission-warning / ?? ../../../ spam you just saw."
    Write-Warning "Recommendation: remove/rename that .git folder (after verifying it's not needed)."
  }
}

Set-Location -LiteralPath $repoRoot

Write-Host ""
Write-Host "=== JP ENGINE : RESUME (ENTRYPOINT) ===" -ForegroundColor Cyan
Write-Host "PWD: $(Get-Location)"
Write-Host ""

# Guard: must be a real git repo with at least one commit
git rev-parse --is-inside-work-tree | Out-Null
$headOk = $true
try { git rev-parse --verify HEAD | Out-Null } catch { $headOk = $false }
if (-not $headOk) { throw "Repo appears to have no commits (HEAD missing). Wrong repo root? PWD=$repoRoot" }

# Guard: jp-start must exist
$jpStart = Join-Path $repoRoot 'scripts\jp-start.ps1'
if (-not (Test-Path -LiteralPath $jpStart)) {
  throw "Missing required script: $jpStart"
}

Write-Host "=== git status ===" -ForegroundColor Yellow
git status --short
Write-Host ""
Write-Host "=== Running jp-start.ps1 ===" -ForegroundColor Yellow
& $jpStart

Write-Host ""
Write-Host "=== JP ENGINE RESUME COMPLETE ===" -ForegroundColor Green
