param(
  [Parameter(Mandatory=$true)]
  [string]$Message,

  [Parameter(Mandatory=$true)]
  [string[]]$Paths,

  [switch]$Push
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Say([string]$s) { Write-Host $s }

function Get-SafeCrlf() {
  try { git config --local --get core.safecrlf 2>$null } catch { $null }
}

function Set-SafeCrlf([string]$v) {
  if ([string]::IsNullOrWhiteSpace($v)) {
    git config --local --unset core.safecrlf 2>$null | Out-Null
  } else {
    git config --local core.safecrlf $v | Out-Null
  }
}

function Try-GitAdd([string[]]$paths) {
  try {
    git add -- $paths
    return $true
  } catch {
    $msg = ($_ | Out-String)
    if ($msg -match 'CRLF would be replaced by LF' -or $msg -match 'safecrlf') {
      return $false
    }
    throw
  }
}

# 0) Preflight
Say "jp-commit: staging paths..."
git status --porcelain

# 1) Stage with safecrlf SOP fallback
$safecrlfOriginal = Get-SafeCrlf
$changedSafecrlf = $false
try {
  if (-not (Try-GitAdd -paths $Paths)) {
    Say "jp-commit: safecrlf blocked staging; temporarily setting core.safecrlf=warn"
    Set-SafeCrlf 'warn'
    $changedSafecrlf = $true
    git add -- $Paths
  }

  Say "jp-commit: staged diff:"
  git diff --cached -- $Paths

  # 2) Commit attempt #1
  Say "jp-commit: committing (attempt 1)..."
  try {
    git commit -m $Message
  } catch {
    # If pre-commit modified files, the commit will fail; we re-stage and retry once.
    $msg = ($_ | Out-String)
    if ($msg -match 'files were modified by this hook' -or $msg -match 'end-of-file-fixer' -or $msg -match 'pre-commit') {
      Say "jp-commit: hooks modified files; re-staging and retrying commit (attempt 2)..."
      git add -- $Paths
      git diff --cached -- $Paths
      git commit -m $Message
    } else {
      throw
    }
  }

  if ($Push) {
    Say "jp-commit: pushing..."
    git push
  }

  Say "jp-commit: done."
  git status --porcelain
} finally {
  if ($changedSafecrlf) {
    Say "jp-commit: restoring core.safecrlf"
    Set-SafeCrlf $safecrlfOriginal
  }
}
