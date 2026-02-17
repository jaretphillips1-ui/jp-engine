<#
JP ENGINE — jp-verify-ci.ps1
CI-friendly verification (additive; does NOT replace jp-verify.ps1)

Goals:
- Run on GitHub Actions runners (Windows/Linux/macOS)
- Avoid requiring local-only tools (gh auth, vercel, netlify, etc.)
- Provide fast signal: repo gates + PowerShell lint + basic hygiene

This script:
- Gates to JP repo root
- Prints versions (pwsh, git)
- Ensures PSScriptAnalyzer is available (installed by workflow)
- Runs PSScriptAnalyzer over scripts/ and common PS entrypoints
- Ensures working tree is clean (CI expectation)
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) { throw $Message }

function Find-RepoRootFromScript {
  $root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
  return $root.Path
}

function Assert-JPRepoRoot([string]$Root) {
  if (-not (Test-Path -LiteralPath (Join-Path $Root '.git'))) { Fail "JP guard: Not a git repo root: missing .git at '$Root'." }
  if (-not (Test-Path -LiteralPath (Join-Path $Root 'docs\00_JP_INDEX.md'))) { Fail "JP guard: Not jp-engine: missing docs\00_JP_INDEX.md at '$Root'." }
}

function Git-Out([string[]]$GitArgs) {
  $out = & git @GitArgs 2>&1
  if ($LASTEXITCODE -ne 0) {
    if ($out) { Write-Host ($out | Out-String).TrimEnd() }
    Fail ("Command failed: git " + ($GitArgs -join ' '))
  }
  return ($out | Out-String)
}

function Assert-CleanTree {
  $s = (Git-Out @('status','--porcelain')).Trim()
  if (-not [string]::IsNullOrWhiteSpace($s)) {
    Write-Host $s
    Fail "JP guard: CI expects a clean working tree."
  }
}

# ---- main ----
$repoRoot = Find-RepoRootFromScript
Assert-JPRepoRoot -Root $repoRoot
Set-Location -LiteralPath $repoRoot

Write-Host "JP VERIFY (CI) — repo root: $repoRoot"
Write-Host ("pwsh: " + $PSVersionTable.PSVersion.ToString())
& git --version | Out-Host
if ($LASTEXITCODE -ne 0) { Fail "JP guard: git is required but failed to run." }

Assert-CleanTree

# PSScriptAnalyzer should be installed by the workflow step (Install-Module).
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
  Fail "PSScriptAnalyzer not found. CI must install it before running jp-verify-ci.ps1."
}

Import-Module PSScriptAnalyzer -ErrorAction Stop

# Analyze scripts/ plus any root *.ps1 (if you add them later)
$targets = @()
if (Test-Path -LiteralPath (Join-Path $repoRoot 'scripts')) {
  $targets += (Join-Path $repoRoot 'scripts')
}
$rootPs = Get-ChildItem -LiteralPath $repoRoot -Filter *.ps1 -File -ErrorAction SilentlyContinue
if ($rootPs) { $targets += $rootPs.FullName }

if ($targets.Count -eq 0) {
  Write-Host "No PowerShell targets found to analyze. (scripts/ missing?)"
} else {
  Write-Host ""
  Write-Host "Running PSScriptAnalyzer…"
  $results = Invoke-ScriptAnalyzer -Path $targets -Recurse -Severity @('Error','Warning') -ErrorAction Stop
  if ($results -and $results.Count -gt 0) {
    $results | Format-Table -AutoSize | Out-Host
    Fail ("PSScriptAnalyzer found " + $results.Count + " issue(s).")
  }
  Write-Host "PSScriptAnalyzer OK."
}

Write-Host ""
Write-Host "VERIFY (CI) — PASS ✅"
