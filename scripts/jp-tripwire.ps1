param(
  [switch]$AllowDirty = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
  Write-Host ""
  Write-Host ("TRIPWIRE: FAIL — " + $Message) -ForegroundColor Red
  exit 1
}

function Require-Path([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path)) { Fail ($Label + " missing: " + $Path) }
}

# Tripwire against param() drift: ensure first non-empty line starts with 'param('
try {
  $lines = Get-Content -LiteralPath $PSCommandPath
  $first = ($lines | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -First 1).Trim()
  if (-not $first.StartsWith("param(")) {
    Fail ("Script header invalid. First non-empty line must be param(...). Actual: " + $first)
  }
} catch {
  Fail ("Could not self-check script header: " + $_.Exception.Message)
}

Write-Host "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Write-Host "JP TRIPWIRE — START"
Write-Host ("time: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
Write-Host ("repo: " + (Get-Location).Path)
Write-Host "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Write-Host ""

# Canonical repo path guard (this machine)
$expectedRepo = "C:\Users\lsphi\OneDrive\AI_Workspace\JP_ENGINE\jp-engine"
$here = (Get-Location).Path
if ($here -ne $expectedRepo) {
  Fail ("Wrong repo location. Expected: " + $expectedRepo + " | Actual: " + $here)
}

# Required docs
Require-Path ".\docs\AI_REMINDERS.md" "AI_REMINDERS"
Require-Path ".\docs\JP_GUIDEBOOK.md" "JP_GUIDEBOOK"

# Required scripts
$reqScripts = @(
  ".\scripts\jp-start.ps1",
  ".\scripts\jp-validate.ps1",
  ".\scripts\jp-verify.ps1",
  ".\scripts\jp-commit.ps1",
  ".\scripts\jp-save.ps1",
  ".\scripts\jp-shutdown.ps1"
)
foreach ($s in $reqScripts) { Require-Path $s "Script" }

# Clean-tree guard
$porcelain = (git status --porcelain)
if (-not $AllowDirty -and $porcelain) {
  Fail "Working tree is dirty (clean required). Run: git status"
}

# SaveRoot guard (from blueprint)
$saveRoot = "C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST"
if (-not (Test-Path -LiteralPath $saveRoot)) {
  Fail ("SaveRoot missing: " + $saveRoot)
}

# Tools we rely on (verify checks most of this; tripwire is the fast front door)
$tools = @("git","pwsh")
foreach ($t in $tools) {
  $cmd = (Get-Command $t -ErrorAction SilentlyContinue)
  if (-not $cmd) { Fail ("Tool missing from PATH: " + $t) }
}

# Line endings expectations
try {
  $safecrlf = (git config --local core.safecrlf)
  $autocrlf = (git config --local core.autocrlf)
  if ($autocrlf -ne "false") { Fail ("core.autocrlf must be false (actual: " + $autocrlf + ")") }
  if ($safecrlf -ne "true") { Fail ("core.safecrlf must be true by default (actual: " + $safecrlf + ")") }
} catch {
  Fail ("Could not read git line-ending config: " + $_.Exception.Message)
}

Write-Host "TRIPWIRE: PASS" -ForegroundColor Green
Write-Host "JP TRIPWIRE — DONE"
