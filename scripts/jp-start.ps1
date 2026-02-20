param()

### SELF_GATE_INSTALLED_JP ###
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-gate to repo root based on THIS file's location (prevents wrong-PWD drift)
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir  = Split-Path -Parent $scriptPath
$repoRoot0  = Resolve-Path -LiteralPath (Join-Path $scriptDir '..')
Set-Location -LiteralPath $repoRoot0

# Ensure we're really in the expected git repo
git rev-parse --is-inside-work-tree | Out-Null

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Tripwire (front-door rails)
& .\scripts\jp-tripwire.ps1 -AllowDirty


function Say([string]$s) { Write-Host $s }

$repoRoot = 'C:\Users\lsphi\OneDrive\AI_Workspace\JP_ENGINE\jp-engine'
if (-not (Test-Path -LiteralPath $repoRoot)) { throw "RepoRoot not found: $repoRoot" }

Set-Location -LiteralPath $repoRoot

Say ""
Say "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Say "JP START — CONTEXT"
Say "repo: $repoRoot"
Say ("time: " + [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))
Say "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Say ""

$remindersPath = Join-Path $repoRoot 'docs\AI_REMINDERS.md'
$guidebookPath = Join-Path $repoRoot 'docs\JP_GUIDEBOOK.md'

if (Test-Path -LiteralPath $remindersPath) {
  Say "— AI REMINDERS (read at start) —"
  Get-Content -LiteralPath $remindersPath -Raw | Write-Host
} else {
  Say "WARNING: missing docs\AI_REMINDERS.md"
}

if (Test-Path -LiteralPath $guidebookPath) {
  Say ""
  Say "— GUIDEBOOK (TOC quick scan) —"
  # Print first ~60 lines as a quick TOC/context view
  (Get-Content -LiteralPath $guidebookPath -TotalCount 60) | ForEach-Object { Write-Host $_ }
} else {
  Say "WARNING: missing docs\JP_GUIDEBOOK.md"
}

Say ""
Say "— RUNNING VALIDATE —"
$validate = Join-Path $repoRoot 'scripts\jp-validate.ps1'
if (Test-Path -LiteralPath $validate) { & $validate } else { throw "Missing: $validate" }

Say ""
Say "— RUNNING VERIFY —"
$verify = Join-Path $repoRoot 'scripts\jp-verify.ps1'
if (Test-Path -LiteralPath $verify) { & $verify } else { throw "Missing: $verify" }

Say ""
Say "JP START — DONE"
