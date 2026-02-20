<#
JP ENGINE — Overall Check + Save
- StrictMode-safe
- Re-runnable ("green by default")
- Optional CI quick look
#>

param(
  [switch]$SkipCIQuickLook,
  [switch]$SkipSave
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Step {
  param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][scriptblock]$Action
  )
  Write-Host "`n=== JP: $Title ===" -ForegroundColor Cyan
  & $Action
}

# Repo root from this script's location (/scripts -> repo root)
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) { throw "Repo root not found (no .git): $RepoRoot" }
Set-Location -LiteralPath $RepoRoot

Invoke-Step 'sanity (clean tree before running checks)' {
  if (git status --porcelain) { throw "Working tree not clean. Stop and inspect before overall check/save." }
}

# Prefer resume if it exists (it re-aligns repo-root + guardrails), otherwise do verify+doctor
if (Test-Path -LiteralPath (Join-Path $RepoRoot 'scripts\jp-resume.ps1')) {
  Invoke-Step 'resume (repo-root + guardrails)' { & .\scripts\jp-resume.ps1 }
} else {
  if (Test-Path -LiteralPath (Join-Path $RepoRoot 'scripts\jp-verify.ps1')) {
    Invoke-Step 'verify' { & .\scripts\jp-verify.ps1 }
  } else {
    throw "Missing scripts\jp-verify.ps1"
  }

  if (Test-Path -LiteralPath (Join-Path $RepoRoot 'scripts\jp-doctor.ps1')) {
    Invoke-Step 'doctor' { & .\scripts\jp-doctor.ps1 }
  }
}

if (-not $SkipCIQuickLook) {
  Invoke-Step 'CI quick look (latest runs on master)' {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
      Write-Host "[WARN] gh not found; skipping CI quick look." -ForegroundColor Yellow
      return
    }

    gh run list --branch master --limit 5

    $json = gh run list --branch master --limit 1 --json status,conclusion,workflowName,updatedAt,htmlURL,event 2>$null
    if ($json) {
      $r = $json | ConvertFrom-Json
      if ($r -and $r.Count -ge 1) {
        $one = $r[0]
        Write-Host ("Latest: {0} | {1}/{2} | {3} | {4}" -f $one.workflowName,$one.status,$one.conclusion,$one.updatedAt,$one.htmlURL)
      }
    }
  }
}

if (-not $SkipSave) {
  if (Test-Path -LiteralPath (Join-Path $RepoRoot 'scripts\jp-save.ps1')) {
    Invoke-Step 'save (LATEST + timestamp + checkpoint + desktop mirror)' { & .\scripts\jp-save.ps1 }
  } else {
    throw "Missing scripts\jp-save.ps1"
  }
} else {
  Write-Host "`n[SKIP] Save skipped by -SkipSave." -ForegroundColor Yellow
}

Invoke-Step 'final status + last commit' {
  git status -sb
  git log -1 --oneline
}
