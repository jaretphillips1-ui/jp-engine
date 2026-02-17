param(
  [string]$ArtifactRoot = 'C:\Dev\_JP_ENGINE\RECOVERY',
  [string]$Note = '',
  [switch]$AllowDirty,
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Normalize-Path([string]$p) {
  if (-not $p) { return $null }
  $p = $p -replace '/', '\'
  try { return (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path } catch { return $p }
}

function Assert-NotBadArtifactRoot([string]$p) {
  $pN = (Normalize-Path $p)
  if (-not $pN) { throw "ArtifactRoot is empty." }

  $bad = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('MyDocuments'),
    [Environment]::GetFolderPath('UserProfile'),
    (Join-Path $env:USERPROFILE 'OneDrive'),
    (Join-Path $env:USERPROFILE 'OneDrive\AI_Workspace')
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | ForEach-Object { (Normalize-Path $_).TrimEnd('\') }

  $pTrim = $pN.TrimEnd('\')
  foreach ($b in $bad) {
    if ($pTrim -ieq $b) { throw "Refusing ArtifactRoot='$pN' (bad root: $b). Choose a dedicated folder like C:\Dev\_JP_ENGINE\RECOVERY." }
    if ($pTrim -like ($b + '\*')) { throw "Refusing ArtifactRoot='$pN' (inside bad root: $b). Choose a dedicated folder like C:\Dev\_JP_ENGINE\RECOVERY." }
  }
}

function Get-Git([string[]]$GitArgs) {
  if (-not $GitArgs -or $GitArgs.Count -lt 1) { throw "Internal error: Get-Git called with no arguments." }
  $out = & git @GitArgs 2>&1
  $code = $LASTEXITCODE
  $text = ($out | Out-String).Trim()
  if ($code -ne 0) {
    $argText = ($GitArgs -join ' ')
    if (-not $text) { $text = '(no stderr/stdout captured)' }
    throw "git $argText failed ($code): $text"
  }
  return $text
}

function Should-IncludeFile([string]$fullPath, [string]$repoRoot, [hashtable]$excludeDirSet) {
  # Convert to repo-relative segments and reject if any segment equals an excluded dir name.
  $rel = $fullPath.Substring($repoRoot.Length).TrimStart('\')
  $segs = $rel -split '\\'
  foreach ($s in $segs) {
    if ($excludeDirSet.ContainsKey($s.ToLowerInvariant())) { return $false }
  }
  return $true
}

# ---- Gates ----
if (-not (Test-Path -LiteralPath (Join-Path (Get-Location).Path '.git'))) {
  throw "Gate failed: run from repo root (folder that contains .git)."
}

Assert-NotBadArtifactRoot $ArtifactRoot

$artifactRootN = Normalize-Path $ArtifactRoot
if (-not (Test-Path -LiteralPath $artifactRootN)) {
  if ($WhatIf) {
    Write-Host "[WhatIf] Would create ArtifactRoot: $artifactRootN"
  } else {
    New-Item -ItemType Directory -Path $artifactRootN | Out-Null
  }
}

$repoRoot = (Get-Location).Path
$repoName = Split-Path -Leaf $repoRoot
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$rpRoot = Join-Path $artifactRootN 'RESTORE_POINTS'
$rpDir  = Join-Path $rpRoot "$ts`_$repoName"
$latestDir = Join-Path $artifactRootN 'LATEST_GREEN'

# Ensure git state
$branch = Get-Git @('rev-parse','--abbrev-ref','HEAD')
$commit = Get-Git @('rev-parse','HEAD')
$status = Get-Git @('status','--porcelain')

if (-not $AllowDirty -and $status) {
  throw "Working tree is dirty. Commit/stash first, or rerun with -AllowDirty. (Refusing to snapshot unknown state.)"
}

# ---- Build file list for zip (exclude heavy/volatile dirs) ----
$excludeDirs = @(
  '.git','node_modules','.next','dist','build','.turbo','.cache','coverage','out'
)

$excludeDirSet = @{}
foreach ($d in $excludeDirs) { $excludeDirSet[$d.ToLowerInvariant()] = $true }

$files = Get-ChildItem -LiteralPath $repoRoot -File -Recurse -Force |
  Where-Object {
    Should-IncludeFile -fullPath $_.FullName -repoRoot $repoRoot -excludeDirSet $excludeDirSet
  }

if ($files.Count -lt 1) { throw "No files found to snapshot (unexpected)." }

# ---- Prepare output paths ----
$zipPath = Join-Path $rpDir 'repo.zip'
$manifestPath = Join-Path $rpDir 'manifest.json'

$manifest = [ordered]@{
  timestamp = (Get-Date).ToString('o')
  repoRoot  = $repoRoot
  repoName  = $repoName
  branch    = $branch
  commit    = $commit
  machine   = $env:COMPUTERNAME
  user      = $env:USERNAME
  allowDirty = [bool]$AllowDirty
  note      = $Note
}

# ---- Write restore point ----
if ($WhatIf) {
  Write-Host "[WhatIf] Would create: $rpDir"
  Write-Host "[WhatIf] Would write:  $manifestPath"
  Write-Host "[WhatIf] Would create: $zipPath (files: $($files.Count))"
} else {
  New-Item -ItemType Directory -Path $rpDir -Force | Out-Null
  ($manifest | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $manifestPath -Encoding utf8

  Push-Location $repoRoot
  try {
    $relPaths = $files | ForEach-Object {
      $_.FullName.Substring($repoRoot.Length).TrimStart('\')
    }
    Compress-Archive -Path $relPaths -DestinationPath $zipPath -CompressionLevel Optimal -Force
  }
  finally {
    Pop-Location
  }

  if (Test-Path -LiteralPath $latestDir) {
    Remove-Item -LiteralPath $latestDir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $latestDir -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $rpDir '*') -Destination $latestDir -Recurse -Force

  Write-Host ""
  Write-Host "Restore point created:" -ForegroundColor Cyan
  Write-Host " - $rpDir"
  Write-Host "LATEST_GREEN updated:" -ForegroundColor Cyan
  Write-Host " - $latestDir"
  Write-Host ""
  Write-Host "Zip:" -ForegroundColor Cyan
  Write-Host " - $zipPath"
  Write-Host "Manifest:" -ForegroundColor Cyan
  Write-Host " - $manifestPath"
}
