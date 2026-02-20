[CmdletBinding()]
param(
  [string]$HandoffPath = "docs/JP_ENGINE_HANDOFF.md",
  [string]$SaveRoot = "C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ throw $m }

function Require-Tool([string]$name){
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if (-not $cmd) { Die ("Missing required tool: {0}" -f $name) }
}

function Get-RepoSlug {
  # Derive owner/repo from origin remote (supports https + ssh)
  $u = (git remote get-url origin 2>$null)
  if (-not $u) { throw 'Cannot read origin remote URL.' }
  $u = $u.Trim()

  # https://github.com/owner/repo.git OR https://github.com/owner/repo
  if ($u -match '^https?://github\.com/([^/]+)/([^/]+?)(?:\.git)?$') {
    return ("{0}/{1}" -f $Matches[1], $Matches[2])
  }

  # git@github.com:owner/repo.git
  if ($u -match '^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$') {
    return ("{0}/{1}" -f $Matches[1], $Matches[2])
  }

  throw ("Unrecognized origin URL format: {0}" -f $u)
}

function Try-GhJson([string[]]$args){
  try {
    $useArgs = [string[]]$args

    # Inject --repo OWNER/REPO in the correct position (right after "release view|list")
    if ((-not ($useArgs -contains '--repo')) -and $script:RepoSlug) {
      if ($useArgs.Count -ge 2 -and $useArgs[0] -eq 'release' -and ($useArgs[1] -eq 'view' -or $useArgs[1] -eq 'list')) {
        $prefix = @($useArgs[0], $useArgs[1], '--repo', $script:RepoSlug)
        $rest = @()
        if ($useArgs.Count -gt 2) { $rest = $useArgs[2..($useArgs.Count-1)] }
        $useArgs = @($prefix + $rest)
      } else {
        # Fallback: append if we do not recognize the shape
        $useArgs = @($useArgs + @('--repo', $script:RepoSlug))
      }
    }

    # Capture stdout (PowerShell may return string[]); ignore stderr noise
    $raw = & gh @useArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    if ($null -eq $raw) { return $null }

    # Normalize to a single string
    $s = ($raw -join "`n").Trim()
    if (-not $s) { return $null }

    # If anything non-JSON sneaks into stdout, extract the JSON object/array
    $json = $s
    $iObj = $s.IndexOf('{')
    $iArr = $s.IndexOf('[')
    if ($iObj -ge 0 -or $iArr -ge 0) {
      $startIx = if ($iObj -ge 0 -and $iArr -ge 0) { [Math]::Min($iObj,$iArr) } elseif ($iObj -ge 0) { $iObj } else { $iArr }
      $endObj = $s.LastIndexOf('}')
      $endArr = $s.LastIndexOf(']')
      $endIx = [Math]::Max($endObj,$endArr)
      if ($endIx -gt $startIx) {
        $json = $s.Substring($startIx, ($endIx - $startIx + 1))
      }
    }

    return ($json | ConvertFrom-Json)
  } catch {
    return $null
  }
}

if (-not (Test-Path ".git")) { Die "Not in repo root." }

Require-Tool git
Require-Tool gh

$script:RepoSlug = Get-RepoSlug

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
$commit = (git rev-parse --short HEAD).Trim()
$msg    = (git log -1 --pretty=%s).Trim()
$stamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# --- Latest Release (via gh --json) ---
# Prefer: `gh release view --json ...` (latest by default; avoids list-flag drift)
$rel = Try-GhJson @(
  'release','view',
  '--json','tagName,name,url,isDraft,isPrerelease,createdAt,publishedAt,author,assets'
)

# If latest is a draft (or view returned null), fallback:
# - list a handful
# - pick first non-draft by publishedAt/createdAt
if (-not $rel -or $rel.isDraft) {
  $list = Try-GhJson @(
    'release','list',
    '--limit','20',
    '--json','tagName,isDraft,publishedAt,createdAt'
  )

  if ($list) {
    $pick = $list |
      Where-Object { $_.isDraft -ne $true } |
      Sort-Object @{Expression = { if ($_.publishedAt) { $_.publishedAt } else { $_.createdAt } }; Descending = $true } |
      Select-Object -First 1

    if ($pick -and $pick.tagName) {
      $rel = Try-GhJson @(
        'release','view', $pick.tagName,
        '--json','tagName,name,url,isDraft,isPrerelease,createdAt,publishedAt,author,assets'
      )
    }
  }
}

# --- Local artifacts snapshot ---
$local = @{
  saveRoot  = $SaveRoot
  exists    = $false
  latestZip = $null
  timedZip  = $null
  shaFile   = $null
  checkpoint = $null
}

if (Test-Path -LiteralPath $SaveRoot) {
  $local.exists = $true
  $files = Get-ChildItem -LiteralPath $SaveRoot -File -ErrorAction Stop |
    Sort-Object LastWriteTime -Descending

  $latest = $files | Where-Object Name -ieq 'JP_ENGINE_LATEST.zip' | Select-Object -First 1
  if ($latest) { $local.latestZip = $latest }

  $timed = $files | Where-Object Name -match '^JP_ENGINE_\d{8}_\d{6}\.zip$' | Select-Object -First 1
  if ($timed) { $local.timedZip = $timed }

  $sha = $files | Where-Object Name -ieq 'JP_ENGINE_ZIP_SHA256.txt' | Select-Object -First 1
  if ($sha) { $local.shaFile = $sha }

  $cp = $files | Where-Object Name -ieq 'JP_ENGINE_LATEST_CHECKPOINT.txt' | Select-Object -First 1
  if ($cp) { $local.checkpoint = $cp }
}

# --- Build markdown ---
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('# JP Engine Handoff')
[void]$md.AppendLine('')
[void]$md.AppendLine(('Generated: {0}' -f $stamp))
[void]$md.AppendLine('')

[void]$md.AppendLine('## Repo State')
[void]$md.AppendLine(('- Branch: {0}' -f $branch))
[void]$md.AppendLine(('- Commit: {0}' -f $commit))
[void]$md.AppendLine(('- Message: {0}' -f $msg))
[void]$md.AppendLine('')

[void]$md.AppendLine('## Latest GitHub Release')
if (-not $rel) {
  [void]$md.AppendLine('- (unavailable) Could not fetch latest release via gh.')
} else {
  [void]$md.AppendLine(('- Tag: {0}' -f $rel.tagName))
  if ($rel.url)         { [void]$md.AppendLine(('- URL: {0}' -f $rel.url)) }
  if ($rel.publishedAt) { [void]$md.AppendLine(('- Published: {0}' -f $rel.publishedAt)) }
  [void]$md.AppendLine(('- Draft: {0}' -f $rel.isDraft))
  [void]$md.AppendLine(('- Prerelease: {0}' -f $rel.isPrerelease))

  if ($rel.assets -and $rel.assets.Count -gt 0) {
    [void]$md.AppendLine('')
    [void]$md.AppendLine('### Assets')
    foreach ($a in $rel.assets) {
      [void]$md.AppendLine(('- {0} ({1} bytes)' -f $a.name, $a.size))
    }
  }
}
[void]$md.AppendLine('')

[void]$md.AppendLine('## Local Save Artifacts')
[void]$md.AppendLine(('- Save root: {0}' -f $SaveRoot))
if (-not $local.exists) {
  [void]$md.AppendLine('- Status: (missing) Save root not found.')
} else {
  if ($local.latestZip) { [void]$md.AppendLine(('- Latest ZIP: {0} ({1} bytes, {2})' -f $local.latestZip.Name, $local.latestZip.Length, $local.latestZip.LastWriteTime)) }
  if ($local.timedZip)  { [void]$md.AppendLine(('- Timed ZIP: {0} ({1} bytes, {2})' -f $local.timedZip.Name, $local.timedZip.Length, $local.timedZip.LastWriteTime)) }
  if ($local.shaFile)   { [void]$md.AppendLine(('- SHA file: {0} ({1} bytes, {2})' -f $local.shaFile.Name, $local.shaFile.Length, $local.shaFile.LastWriteTime)) }
  if ($local.checkpoint){ [void]$md.AppendLine(('- Checkpoint: {0} ({1} bytes, {2})' -f $local.checkpoint.Name, $local.checkpoint.Length, $local.checkpoint.LastWriteTime)) }
}
[void]$md.AppendLine('')

[void]$md.AppendLine('## Work Context')
[void]$md.AppendLine('- What I was doing:')
[void]$md.AppendLine('- What''s next:')
[void]$md.AppendLine('- Housekeeping:')

$md.ToString() | Set-Content -LiteralPath $HandoffPath -Encoding utf8
Write-Host ("Handoff written -> {0}" -f $HandoffPath) -ForegroundColor Green
