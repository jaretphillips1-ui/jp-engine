[CmdletBinding()]
param(
  [string]$SaveRoot = "C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST",
  [switch]$NoZip
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$commit = ""
try { $commit = (git rev-parse HEAD) 2>$null } catch { }
if (-not $commit) { $commit = "NO_COMMIT_YET" }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
New-Item -ItemType Directory -Force -Path $SaveRoot | Out-Null

$baseName   = "JP_ENGINE_LATEST"
$zipPath    = Join-Path $SaveRoot ($baseName + ".zip")
$zipTsPath  = Join-Path $SaveRoot ("JP_ENGINE_" + $ts + ".zip")
$markerPath = Join-Path $SaveRoot ($baseName + "_CHECKPOINT.txt")

$status = (git status --porcelain) 2>$null
$dirty  = if ($status) { "DIRTY" } else { "CLEAN" }

$marker = @"
JP ENGINE — SAVE CHECKPOINT
Timestamp: $ts
Repo: $repoRoot
Commit: $commit
Git: $dirty
"@
$marker | Set-Content -Encoding UTF8 -NoNewline -LiteralPath $markerPath

if ($NoZip) {
  Write-Host "jp-save wrote checkpoint marker (NoZip requested)."
  Write-Host "Marker: $markerPath"
  exit 0
}

$tmp = Join-Path $env:TEMP ("jp_engine_pack_" + $ts)
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$items = Get-ChildItem -LiteralPath $repoRoot -Force
foreach ($it in $items) {
  if ($it.Name -eq ".git") { continue }
  Copy-Item -Recurse -Force -LiteralPath $it.FullName -Destination (Join-Path $tmp $it.Name)
}

if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path (Join-Path $tmp "*") -DestinationPath $zipPath -Force
Compress-Archive -Path (Join-Path $tmp "*") -DestinationPath $zipTsPath -Force

$h1 = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash
$h2 = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipTsPath).Hash

@"
ZIP SHA256
$zipPath
$h1

$zipTsPath
$h2
"@ | Set-Content -Encoding UTF8 -NoNewline -LiteralPath (Join-Path $SaveRoot "JP_ENGINE_ZIP_SHA256.txt")

Remove-Item -Recurse -Force $tmp

Write-Host "jp-save complete."
Write-Host "Zip:  $zipPath"
Write-Host "Zip+: $zipTsPath"
Write-Host "Mark: $markerPath"