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
- Runs PSScriptAnalyzer over scripts/ and root *.ps1 (if any)
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

function Get-AnalyzerTargets([string]$RepoRoot) {
  $targets = @()

  $scriptsDir = Join-Path $RepoRoot 'scripts'
  if (Test-Path -LiteralPath $scriptsDir) { $targets += $scriptsDir }

  $rootPs = Get-ChildItem -LiteralPath $RepoRoot -Filter *.ps1 -File -ErrorAction SilentlyContinue
  if ($rootPs) {
    foreach ($f in $rootPs) { $targets += $f.FullName }
  }

  # Normalize to strings
  $targets = @($targets | Where-Object { $_ } | ForEach-Object { [string]$_ })
  return $targets
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

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
  Fail "PSScriptAnalyzer not found. CI must install it before running jp-verify-ci.ps1."
}

Import-Module PSScriptAnalyzer -ErrorAction Stop

$targets = Get-AnalyzerTargets -RepoRoot $repoRoot
$targetCount = ($targets | Measure-Object).Count   # safe even if $targets is $null

if ($targetCount -eq 0) {
  Write-Host "No PowerShell targets found to analyze. (scripts/ missing?)"
  Write-Host ""
  Write-Host "VERIFY (CI) — PASS ✅"
  return
}

Write-Host ""
Write-Host "Running PSScriptAnalyzer…"

$all = @()

foreach ($t in @($targets)) {
  if (Test-Path -LiteralPath $t -PathType Container) {
    $r = Invoke-ScriptAnalyzer -Path $t -Recurse -Severity @('Error','Warning') -ErrorAction Stop
    if ($r) { $all += $r }
  }
  elseif (Test-Path -LiteralPath $t -PathType Leaf) {
    $r = Invoke-ScriptAnalyzer -Path $t -Severity @('Error','Warning') -ErrorAction Stop
    if ($r) { $all += $r }
  }
}

if (($all | Measure-Object).Count -gt 0) {
  $all | Sort-Object RuleName, ScriptName, Line | Format-Table -AutoSize | Out-Host
  Fail ("PSScriptAnalyzer found " + ($all | Measure-Object).Count + " issue(s).")
}

Write-Host "PSScriptAnalyzer OK."
Write-Host ""
Write-Host "VERIFY (CI) — PASS ✅"
