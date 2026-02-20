param(
  [Parameter(Mandatory=$true)]
  [string]$Note
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Say([string]$s) { Write-Host $s }

$repoRoot = 'C:\Users\lsphi\OneDrive\AI_Workspace\JP_ENGINE\jp-engine'
if (-not (Test-Path -LiteralPath $repoRoot)) { throw "RepoRoot not found: $repoRoot" }
Set-Location -LiteralPath $repoRoot

$saveScript = Join-Path $repoRoot 'scripts\jp-save.ps1'
if (-not (Test-Path -LiteralPath $saveScript)) { throw "Missing: $saveScript" }

$saveRoot = 'C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST'
if (-not (Test-Path -LiteralPath $saveRoot)) { New-Item -ItemType Directory -Path $saveRoot | Out-Null }

Say ""
Say "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Say "JP SHUTDOWN — START"
Say ("repo: " + $repoRoot)
Say ("time: " + [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))
Say "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Say ""

# 0) Hard-stop if dirty (professional rule: save tracked state only)
$porc = (git status --porcelain) 2>$null
if ($porc) {
  Say "ERROR: repo is not clean. Shutdown requires clean working tree."
  Say ""
  Say $porc
  throw "Shutdown aborted: dirty working tree."
}

# 1) Prove validate+verify before saving (belt + suspenders)
$validate = Join-Path $repoRoot 'scripts\jp-validate.ps1'
if (-not (Test-Path -LiteralPath $validate)) { throw "Missing: $validate" }
& $validate

$verify = Join-Path $repoRoot 'scripts\jp-verify.ps1'
if (-not (Test-Path -LiteralPath $verify)) { throw "Missing: $verify" }
& $verify

# 2) Save (creates zips + checkpoint + handoff + desktop mirror)
& $saveScript -Note $Note

# 3) Print most recent handoff/checkpoint paths for quick pickup
$handoff = Get-ChildItem -LiteralPath $saveRoot -Filter 'JP_HANDOFF_*.txt' -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

$checkpointPath = Join-Path $saveRoot 'JP_ENGINE_LATEST_CHECKPOINT.txt'

Say ""
Say "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Say "JP SHUTDOWN — DONE"
if ($handoff) { Say ("HANDOFF (latest): " + $handoff.FullName) } else { Say "HANDOFF (latest): (not found)" }
if (Test-Path -LiteralPath $checkpointPath) { Say ("CHECKPOINT:      " + $checkpointPath) } else { Say "CHECKPOINT:      (not found)" }
Say "NOTE:"
Say $Note
Say "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Say ""
