param(
  [Parameter(Mandatory=$true)]
  [string]$Message,

  [Parameter(Mandatory=$true)]
  [string[]]$Paths,

  [switch]$Push
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Say([string]$s) {
  Write-Host $s
}

function Invoke-Git([string[]]$GitArgs) {
  if (-not $GitArgs -or $GitArgs.Count -lt 1) { throw "Invoke-Git called with empty args (bug)." }
  $out = & git @GitArgs 2>&1
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    $msg = ($out | Out-String).Trim()
    throw "git $($GitArgs -join ' ') failed (exit $code)`n$msg"
  }
  return $out
}

function Get-SafeCrlf() {
  try { (git config --local --get core.safecrlf 2>$null) } catch { $null }
}

function Set-SafeCrlf([string]$v) {
  if ([string]::IsNullOrWhiteSpace($v)) {
    git config --local --unset core.safecrlf 2>$null | Out-Null
  } else {
    git config --local core.safecrlf $v | Out-Null
  }
}

function Try-GitAdd([string[]]$paths) {
  $out  = & git add -- $paths 2>&1
  $code = $LASTEXITCODE
  if ($code -eq 0) { return $true }

  $msg = ($out | Out-String)
  if ($msg -match 'CRLF would be replaced by LF' -or $msg -match 'safecrlf') {
    return $false
  }

  throw "git add failed (exit $code)`n$msg"
}

# ---- repo-root gate (no-drift, write tool) ----
$__RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$__Here     = (Resolve-Path -LiteralPath (Get-Location).Path).Path
if ($__Here -ne $__RepoRoot) {
  Set-Location -LiteralPath $__RepoRoot
}

# ---- preflight ----
Say "jp-commit: repo=$__RepoRoot"
Invoke-Git @('rev-parse','--is-inside-work-tree') | Out-Null

if (-not $Paths -or $Paths.Count -lt 1) { throw "jp-commit: Paths is empty." }

# ---- stage with safecrlf fallback ----
$safecrlfOriginal = Get-SafeCrlf
$changedSafecrlf  = $false

try {
  Say "jp-commit: staging paths..."
  if (-not (Try-GitAdd -paths $Paths)) {
    Say "jp-commit: safecrlf blocked staging; temporarily setting core.safecrlf=warn"
    Set-SafeCrlf 'warn'
    $changedSafecrlf = $true
    Invoke-Git ( @('add','--') + $Paths ) | Out-Null
  }

  Say "jp-commit: staged diff (cached) ..."
  Invoke-Git ( @('diff','--cached','--') + $Paths ) | Out-Null

  # ---- commit attempt #1 ----
  $headBefore = (Invoke-Git @('rev-parse','HEAD') | Out-String).Trim()
  Say "jp-commit: committing (attempt 1)..."
  $out1  = & git commit -m $Message 2>&1
  $code1 = $LASTEXITCODE

  if ($code1 -ne 0) {
    $msg1 = ($out1 | Out-String)

    # If hooks modified files, re-stage + retry once.
    if ($msg1 -match 'files were modified by this hook' -or
        $msg1 -match 'end-of-file-fixer' -or
        $msg1 -match 'pre-commit') {

      Say "jp-commit: hooks modified files; re-staging and retrying commit (attempt 2)..."
      if (-not (Try-GitAdd -paths $Paths)) {
        Say "jp-commit: safecrlf blocked restage; temporarily setting core.safecrlf=warn"
        Set-SafeCrlf 'warn'
        $changedSafecrlf = $true
        Invoke-Git ( @('add','--') + $Paths ) | Out-Null
      }

      Invoke-Git ( @('diff','--cached','--') + $Paths ) | Out-Null
      Invoke-Git @('commit','-m',$Message) | Out-Null
    } else {
      throw "git commit failed (exit $code1)`n$msg1"
    }
  }

  # ---- verify commit actually happened ----
  $headAfter = (Invoke-Git @('rev-parse','HEAD') | Out-String).Trim()
  if ($headAfter -eq $headBefore) {
    throw "jp-commit: commit did not advance HEAD. Stop and inspect: git status --porcelain; git log -1 --oneline"
  }

  if ($Push) {
    Say "jp-commit: pushing..."
    Invoke-Git @('push') | Out-Null
  }

  Say "jp-commit: done."
  Invoke-Git @('status','--porcelain') | Out-Null
}
finally {
  if ($changedSafecrlf) {
    Say "jp-commit: restoring core.safecrlf"
    Set-SafeCrlf $safecrlfOriginal
  }
}
