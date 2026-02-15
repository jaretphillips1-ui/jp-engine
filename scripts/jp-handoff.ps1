[CmdletBinding()]
param(
  [int]$StopThick = 12
)

$ErrorActionPreference = "Stop"

function Write-Banner([string]$title) {
  Write-Host ""
  Write-Host "════════════════════════════════════════════════════════════════════════════════"
  Write-Host ("JP ENGINE — {0}" -f $title)
  Write-Host ("Time: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  try {
    $root = (git rev-parse --show-toplevel 2>$null)
    if ($root) { Write-Host ("Repo: {0}" -f $root) }
  } catch {}
  Write-Host "════════════════════════════════════════════════════════════════════════════════"
  Write-Host ""
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot
$stop = Join-Path $repoRoot "scripts\jp-stop.ps1"

Write-Banner "HANDOFF PACK"

# Core repo state
Write-Host "=== REPO STATE ==="
try { Write-Host ("Branch: {0}" -f (git branch --show-current)) } catch {}
try { Write-Host ("Last commit: {0}" -f (git log -1 --oneline)) } catch {}
try { Write-Host ""; git status } catch {}

# Runner quick list (so the next chat knows what is available)
Write-Host ""
Write-Host "=== RUNNERS ==="
try {
  Get-ChildItem -LiteralPath (Join-Path (git rev-parse --show-toplevel) "scripts") -Filter "jp-*.ps1" |
    Sort-Object Name |
    ForEach-Object { Write-Host ("- {0}" -f $_.Name) }
} catch {}

# Line-ending enforcement snapshot
Write-Host ""
Write-Host "=== LINE ENDINGS ==="
try {
  $safecrlf = (git config --local --get core.safecrlf 2>$null)
  $autocrlf = (git config --local --get core.autocrlf 2>$null)
  if ([string]::IsNullOrWhiteSpace($safecrlf)) { $safecrlf = "(unset)" }
  if ([string]::IsNullOrWhiteSpace($autocrlf)) { $autocrlf = "(unset)" }
  Write-Host ("core.safecrlf : {0}" -f $safecrlf)
  Write-Host ("core.autocrlf : {0}" -f $autocrlf)
  $ga = Join-Path (git rev-parse --show-toplevel) ".gitattributes"
  $gaState = if (Test-Path -LiteralPath $ga) { "PRESENT" } else { "MISSING" }
  Write-Host (".gitattributes: {0}" -f $gaState)
} catch {}

# CUT HERE stop + paste cue (centralized)
if (Test-Path -LiteralPath $stop) {
  & $stop -Thick $StopThick -Color -Bold -Label "CUT HERE — PASTE BELOW ONLY" -PasteCue | Out-Null
} else {
  Write-Host "==== STOP BAR (jp-stop missing) ===="
  Write-Host ""
}

# Minimal chat-ready payload
Write-Host ("PowerShell: {0}" -f $PSVersionTable.PSVersion.ToString())
Write-Host ("PWD: {0}" -f (Get-Location).Path)
Write-Host ("git log -1 --oneline: {0}" -f (git log -1 --oneline))

Write-Host ""
Write-Host "Next action suggestion:"
Write-Host "- Run: .\scripts\jp-start.ps1"
Write-Host "- Then: .\scripts\jp-verify.ps1"
Write-Host "- If any failure repeats 3x: stop and run read-pack dump before more edits"

