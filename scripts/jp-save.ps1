param(
  [string]$Note = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Tripwire (front-door rails)
& .\scripts\jp-tripwire.ps1


function Say([string]$s) { Write-Host $s }

$repoRoot = 'C:\Users\lsphi\OneDrive\AI_Workspace\JP_ENGINE\jp-engine'
if (-not (Test-Path -LiteralPath $repoRoot)) { throw "RepoRoot not found: $repoRoot" }
Set-Location -LiteralPath $repoRoot

$saveRoot = 'C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST'
if (-not (Test-Path -LiteralPath $saveRoot)) { New-Item -ItemType Directory -Path $saveRoot | Out-Null }

$desktop = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop)) {
  throw "Desktop path resolution failed."
}

# 0) Require clean repo (professional rule: archive tracked state only)
$porc = (git status --porcelain) 2>$null
if ($porc) {
  Say "ERROR: repo is not clean. Save requires clean working tree."
  Say $porc
  throw "Save aborted: dirty working tree."
}

# 1) Verify must PASS
$verify = Join-Path $repoRoot 'scripts\jp-verify.ps1'
if (-not (Test-Path -LiteralPath $verify)) { throw "Missing: $verify" }
& $verify

# 2) Snapshot identifiers
$nowStamp = [DateTime]::Now.ToString('yyyyMMdd_HHmmss')
$nowPretty = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
$branch = ((git rev-parse --abbrev-ref HEAD) 2>$null).Trim()
$commit = ((git rev-parse HEAD) 2>$null).Trim()

if ([string]::IsNullOrWhiteSpace($commit)) { throw "Could not read git commit hash." }

# 3) Build zips using git archive (tracked files only, reproducible)
$latestZip = Join-Path $saveRoot 'JP_ENGINE_LATEST.zip'
$timeZip   = Join-Path $saveRoot ("JP_ENGINE_" + $nowStamp + ".zip")

# create timestamped zip
& git archive --format=zip --output $timeZip HEAD 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $timeZip)) {
  throw "git archive failed to produce $timeZip"
}

# refresh LATEST zip from timestamped
Copy-Item -LiteralPath $timeZip -Destination $latestZip -Force

# mirror to Desktop
$desktopLatest = Join-Path $desktop 'JP_ENGINE_LATEST.zip'
Copy-Item -LiteralPath $latestZip -Destination $desktopLatest -Force

# 4) Write checkpoint + handoff
$checkpointPath = Join-Path $saveRoot 'JP_ENGINE_LATEST_CHECKPOINT.txt'
$handoffPath    = Join-Path $saveRoot ("JP_HANDOFF_" + $nowStamp + ".txt")

$hashLatest = (Get-FileHash -LiteralPath $latestZip -Algorithm SHA256).Hash
$hashDesk   = (Get-FileHash -LiteralPath $desktopLatest -Algorithm SHA256).Hash

$checkpoint = @"
JP ENGINE — SAVE CHECKPOINT
time:   $nowPretty
repo:   $repoRoot
branch: $branch
commit: $commit

SAVE ROOT:
$saveRoot

ARTIFACTS:
LATEST:      $latestZip
TIMESTAMP:   $timeZip
DESKTOP:     $desktopLatest

SHA256:
LATEST:  $hashLatest
DESKTOP: $hashDesk

NOTE:
$Note
"@

$handoff = @"
JP ENGINE — HANDOFF
time:   $nowPretty
branch: $branch
commit: $commit

What changed:
- (fill this in)

Next step:
- (fill this in)

Notes:
$Note
"@

# Write with trailing newline to avoid EOF fixer churn
Set-Content -LiteralPath $checkpointPath -Value ($checkpoint + "`r`n") -Encoding utf8
Set-Content -LiteralPath $handoffPath    -Value ($handoff + "`r`n")    -Encoding utf8

Say ""
Say "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Say "JP SAVE — DONE"
Say ("LATEST ZIP:    " + $latestZip)
Say ("TIMESTAMP ZIP: " + $timeZip)
Say ("DESKTOP ZIP:   " + $desktopLatest)
Say ("CHECKPOINT:    " + $checkpointPath)
Say ("HANDOFF:       " + $handoffPath)
Say "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Say ""
