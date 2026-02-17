[CmdletBinding()]
param(
  [string]$SaveRoot = "C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST",
  [switch]$NoZip,
  [switch]$NoVerify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Say([string]$m) { Write-Host $m }

# --- Resolve repo root robustly ---
$repoRoot = ""
try { $repoRoot = (git rev-parse --show-toplevel 2>$null).Trim() } catch { }
if (-not $repoRoot) { throw "jp-save: not inside a git repo. Run from within the repo (or ensure git is available)." }

# --- Preflight git info ---
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
$head1  = (git log -1 --oneline).Trim()

$commit = ""
try { $commit = (git rev-parse HEAD 2>$null).Trim() } catch { }
if (-not $commit) { $commit = "NO_COMMIT_YET" }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
New-Item -ItemType Directory -Force -Path $SaveRoot | Out-Null

$baseName   = "JP_ENGINE_LATEST"
$zipPath    = Join-Path $SaveRoot ($baseName + ".zip")
$zipTsPath  = Join-Path $SaveRoot ("JP_ENGINE_" + $ts + ".zip")
$markerPath = Join-Path $SaveRoot ($baseName + "_CHECKPOINT.txt")
$shaPath    = Join-Path $SaveRoot "JP_ENGINE_ZIP_SHA256.txt"

$status = (git status --porcelain) 2>$null
$dirty  = if ($status) { "DIRTY" } else { "CLEAN" }

# --- Optional verify (before save) ---
if (-not $NoVerify) {
  $verifyPath = Join-Path $repoRoot "scripts\jp-verify.ps1"
  if (Test-Path -LiteralPath $verifyPath) {
    Say "jp-save: running verify..."
    & $verifyPath
    Say "jp-save: verify PASS (or script completed)."
  } else {
    Say "jp-save: verify skipped (scripts\jp-verify.ps1 not found)."
  }
} else {
  Say "jp-save: verify skipped (NoVerify)."
}

# --- Write checkpoint marker (always) ---
$marker = @"
JP ENGINE — SAVE CHECKPOINT
Timestamp: $ts
Repo: $repoRoot
Branch: $branch
Head: $head1
Commit: $commit
Git: $dirty
"@
$marker | Set-Content -Encoding UTF8 -NoNewline -LiteralPath $markerPath

if ($NoZip) {
  Say "jp-save wrote checkpoint marker (NoZip requested)."
  Say "Marker: $markerPath"
  exit 0
}

# --- Stage to temp (exclude .git + common heavy dirs) ---
$tmp = Join-Path $env:TEMP ("jp_engine_pack_" + $ts)
if (Test-Path -LiteralPath $tmp) { Remove-Item -Recurse -Force -LiteralPath $tmp }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$exclude = @(
  ".git",
  ".next",
  "node_modules",
  ".venv",
  "__pycache__",
  ".pytest_cache",
  ".mypy_cache",
  ".ruff_cache",
  "dist",
  "build"
)

$items = Get-ChildItem -LiteralPath $repoRoot -Force
foreach ($it in $items) {
  if ($exclude -contains $it.Name) { continue }
  Copy-Item -Recurse -Force -LiteralPath $it.FullName -Destination (Join-Path $tmp $it.Name)
}

# --- Build zips (LATEST + timestamped) ---
if (Test-Path -LiteralPath $zipPath) { Remove-Item -Force -LiteralPath $zipPath }

Compress-Archive -Path (Join-Path $tmp "*") -DestinationPath $zipPath -Force
Compress-Archive -Path (Join-Path $tmp "*") -DestinationPath $zipTsPath -Force

# --- Hashes ---
$h1 = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash
$h2 = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipTsPath).Hash

@"
ZIP SHA256
$zipPath
$h1

$zipTsPath
$h2
"@ | Set-Content -Encoding UTF8 -NoNewline -LiteralPath $shaPath

# --- Cleanup ---
Remove-Item -Recurse -Force -LiteralPath $tmp

Say "jp-save complete."
Say "Repo: $repoRoot"
Say "Branch: $branch"
Say "Head: $head1"
Say "Zip:  $zipPath"
Say "Zip+: $zipTsPath"
Say "Mark: $markerPath"
Say "SHA:  $shaPath"
