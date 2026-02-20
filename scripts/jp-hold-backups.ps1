[CmdletBinding()]
param(
  [string]$RepoRoot = (Get-Location).Path,

  # Optional override if needed later:
  [string]$ReleaseTag,

  # If you want to keep the restore folder for inspection
  [switch]$KeepRestoreDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Step([string]$n,[scriptblock]$sb){
  Write-Host ""
  Write-Host ("=== {0} ===" -f $n) -ForegroundColor Cyan
  try { & $sb; Write-Host ("PASS: {0}" -f $n) -ForegroundColor Green }
  catch { Write-Host ("FAIL: {0}" -f $n) -ForegroundColor Red; throw }
}

function Assert-LastExitCode([string]$Context) {
  if ($global:LASTEXITCODE -ne 0) {
    throw ("{0} failed (exit code {1})." -f $Context, $global:LASTEXITCODE)
  }
}

function Normalize-Path([string]$p) {
  if (-not $p) { return '' }
  $p = $p.Trim().Replace('/','\')
  try { $p = (Resolve-Path -LiteralPath $p).Path } catch { }
  $p.TrimEnd('\')
}

function Get-OneDriveSaveRoot {
  $c1 = Join-Path $env:USERPROFILE 'OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST'
  $c2 = if ($env:OneDrive) { Join-Path $env:OneDrive 'AI_Workspace\_SAVES\JP_ENGINE\LATEST' } else { $null }

  foreach ($c in @($c1,$c2) | Where-Object { $_ }) {
    $n = Normalize-Path $c
    if ($n -and (Test-Path -LiteralPath $n)) { return $n }
  }
  return $null
}

function Find-PrimaryLocalArtifacts {
  param([Parameter(Mandatory)][string]$SaveRoot)

  $files = Get-ChildItem -LiteralPath $SaveRoot -File

  $latestZip = $files | Where-Object { $_.Name -ieq 'JP_ENGINE_LATEST.zip' } | Select-Object -First 1
  $timedZip  = $files |
    Where-Object { $_.Name -match '^JP_ENGINE_\d{8}_\d{6}\.zip$' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  $mark = $files | Where-Object { $_.Name -ieq 'JP_ENGINE_LATEST_CHECKPOINT.txt' } | Select-Object -First 1
  $sha  = $files | Where-Object { $_.Name -ieq 'JP_ENGINE_ZIP_SHA256.txt' } | Select-Object -First 1

  if (-not $latestZip) { throw "Missing JP_ENGINE_LATEST.zip in save root." }
  if (-not $timedZip)  { throw "Missing timestamped JP_ENGINE_YYYYMMDD_HHMMSS.zip in save root." }
  if (-not $mark)      { throw "Missing JP_ENGINE_LATEST_CHECKPOINT.txt in save root." }
  if (-not $sha)       { throw "Missing JP_ENGINE_ZIP_SHA256.txt in save root." }

  [pscustomobject]@{
    SaveRoot   = $SaveRoot
    TimedZip   = $timedZip.FullName
    LatestZip  = $latestZip.FullName
    Mark       = $mark.FullName
    ShaFile    = $sha.FullName
  }
}

function Get-LatestReleaseTag {
  # Uses JSON (no brittle text parsing)
  $tag = (gh release list --limit 1 --json tagName,isLatest,name,publishedAt -q '.[0].tagName' 2>&1).ToString().Trim()
  Assert-LastExitCode "gh release list --json"
  if (-not $tag) { throw "Could not determine latest release tag (empty result)." }
  $tag
}

function Parse-ShaFile {
  param(
    [Parameter(Mandatory)][string]$ShaFilePath
  )

  # Supports common formats:
  # 1) "<hash>  <filename>"
  # 2) "SHA256(<filename>)= <hash>"
  $map = @{}

  $lines = Get-Content -LiteralPath $ShaFilePath -ErrorAction Stop
  foreach ($ln in $lines) {
    $t = $ln.Trim()
    if (-not $t) { continue }

    if ($t -match '^(?<hash>[0-9a-fA-F]{64})\s+\*?(?<file>.+)$') {
      $map[(Split-Path -Leaf $matches.file)] = $matches.hash.ToLowerInvariant()
      continue
    }

    if ($t -match '^SHA256\((?<file>.+)\)\s*=\s*(?<hash>[0-9a-fA-F]{64})$') {
      $map[(Split-Path -Leaf $matches.file)] = $matches.hash.ToLowerInvariant()
      continue
    }
  }

  if ($map.Count -eq 0) {
    throw "Could not parse any SHA entries from: $ShaFilePath"
  }

  $map
}

function Verify-FileSha {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [Parameter(Mandatory)][hashtable]$ShaMap
  )
  $leaf = Split-Path -Leaf $FilePath
  if (-not $ShaMap.ContainsKey($leaf)) {
    throw "SHA map does not contain an entry for: $leaf"
  }

  $want = $ShaMap[$leaf]
  $have = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($have -ne $want) {
    throw ("SHA mismatch for {0}`nWant: {1}`nHave: {2}" -f $leaf, $want, $have)
  }
  Write-Host ("SHA OK: {0}" -f $leaf) -ForegroundColor DarkCyan
}

function Find-RestoredRepoRoot {
  param([Parameter(Mandatory)][string]$ExtractRoot)

  # Identify repo root by locating scripts\jp-verify.ps1
  $verify = Get-ChildItem -LiteralPath $ExtractRoot -Recurse -File -Filter 'jp-verify.ps1' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '[\\/]scripts[\\/]jp-verify\.ps1$' } |
    Select-Object -First 1

  if (-not $verify) {
    throw "Could not find scripts\jp-verify.ps1 inside restored content."
  }

  # Repo root is parent of \scripts
  (Split-Path -Parent (Split-Path -Parent $verify.FullName))
}

$repoN = Normalize-Path $RepoRoot
Set-Location -LiteralPath $repoN

$restoreBase = Join-Path $env:TEMP ("jp-restore-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$downloadDir = Join-Path $restoreBase 'download'
$extractDir  = Join-Path $restoreBase 'extract'

Step "HOLD BACKUPS (LOCAL) — verify latest artifacts exist" {
  $saveRoot = Get-OneDriveSaveRoot
  if (-not $saveRoot) { throw "Save root not found under OneDrive AI_Workspace." }

  $a = Find-PrimaryLocalArtifacts -SaveRoot $saveRoot

  Write-Host ("SAVE ROOT : {0}" -f $a.SaveRoot) -ForegroundColor DarkCyan
  Write-Host ("Timed ZIP : {0}" -f (Split-Path -Leaf $a.TimedZip)) -ForegroundColor DarkCyan
  Write-Host ("Latest ZIP: {0}" -f (Split-Path -Leaf $a.LatestZip)) -ForegroundColor DarkCyan

  Get-ChildItem -LiteralPath $a.SaveRoot -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 10 Name,Length,LastWriteTime |
    Format-Table -AutoSize | Out-Host

  Set-Variable -Name JP_LOCAL_ARTIFACTS -Scope Script -Value $a
}

Step "HOLD BACKUPS (ONLINE) — confirm latest GitHub Release exists" {
  $tag = if ($ReleaseTag) { $ReleaseTag.Trim() } else { Get-LatestReleaseTag }
  Write-Host ("Latest tag: {0}" -f $tag) -ForegroundColor DarkCyan

  gh release view $tag | Out-Host
  Assert-LastExitCode "gh release view"

  Set-Variable -Name JP_RELEASE_TAG -Scope Script -Value $tag
}

Step "RESTORE TEST — download Release assets" {
  New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

  # Download exactly what we need
  gh release download $JP_RELEASE_TAG --dir $downloadDir --pattern 'JP_ENGINE_*.zip' | Out-Host
  Assert-LastExitCode "gh release download (zips)"

  gh release download $JP_RELEASE_TAG --dir $downloadDir --pattern 'JP_ENGINE_ZIP_SHA256.txt' | Out-Host
  Assert-LastExitCode "gh release download (sha)"

  $dlSha = Join-Path $downloadDir 'JP_ENGINE_ZIP_SHA256.txt'
  if (-not (Test-Path -LiteralPath $dlSha)) { throw "Missing downloaded sha file: $dlSha" }

  $zips = Get-ChildItem -LiteralPath $downloadDir -File -Filter '*.zip'
  if (-not $zips -or $zips.Count -eq 0) { throw "No zip assets downloaded to: $downloadDir" }

  # Prefer timestamped zip as restore target
  $primary = $zips | Where-Object { $_.Name -match '^JP_ENGINE_\d{8}_\d{6}\.zip$' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (-not $primary) { $primary = $zips | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }

  Write-Host ("Downloaded ZIPs: {0}" -f ($zips.Name -join ', ')) -ForegroundColor DarkCyan
  Write-Host ("Restore ZIP    : {0}" -f $primary.Name) -ForegroundColor DarkCyan

  Set-Variable -Name JP_DL_SHA -Scope Script -Value $dlSha
  Set-Variable -Name JP_DL_PRIMARY_ZIP -Scope Script -Value $primary.FullName
}

Step "RESTORE TEST — verify SHA256 for downloaded ZIP(s)" {
  $map = Parse-ShaFile -ShaFilePath $JP_DL_SHA

  # Verify primary zip
  Verify-FileSha -FilePath $JP_DL_PRIMARY_ZIP -ShaMap $map

  # If LATEST.zip is present in downloads, verify it too
  $latest = Join-Path (Split-Path -Parent $JP_DL_PRIMARY_ZIP) 'JP_ENGINE_LATEST.zip'
  if (Test-Path -LiteralPath $latest) {
    Verify-FileSha -FilePath $latest -ShaMap $map
  }
}

Step "RESTORE TEST — unzip + run restored jp-verify.ps1" {
  New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

  Expand-Archive -LiteralPath $JP_DL_PRIMARY_ZIP -DestinationPath $extractDir -Force

  $restoredRoot = Find-RestoredRepoRoot -ExtractRoot $extractDir
  Write-Host ("Restored repo root: {0}" -f $restoredRoot) -ForegroundColor DarkCyan

  $verify = Join-Path $restoredRoot 'scripts\jp-verify.ps1'
  if (-not (Test-Path -LiteralPath $verify)) { throw "Restored verify script missing: $verify" }

  # Run verify from restored repo
  pwsh -NoProfile -File $verify
  if ($LASTEXITCODE -ne 0) { throw ("Restored jp-verify.ps1 failed (exit code {0})." -f $LASTEXITCODE) }

  Write-Host "Restore verify PASS." -ForegroundColor Green
}

if (-not $KeepRestoreDir) {
  Step "RESTORE TEST — cleanup temp restore folder" {
    if (Test-Path -LiteralPath $restoreBase) {
      Remove-Item -LiteralPath $restoreBase -Recurse -Force
      Write-Host ("Removed: {0}" -f $restoreBase) -ForegroundColor DarkCyan
    }
  }
} else {
  Write-Host ("NOTE: Keeping restore folder: {0}" -f $restoreBase) -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🟢 BACKUPS HELD + RESTORE PROVEN: local artifacts present, online release present, restore verified." -ForegroundColor Green
