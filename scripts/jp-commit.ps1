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
  try { (git config --local --get core.safecrlf 2>$null) } catch { $null }
}

function Set-SafeCrlf([string]$v) {
  if ([string]::IsNullOrWhiteSpace($v)) {
    git config --local --unset core.safecrlf 2>$null | Out-Null
  } else {
    git config --local core.safecrlf $v | Out-Null
  }
}

function Invoke-Git([string[]]$GitArgs) {
  if (-not $GitArgs -or $GitArgs.Count -lt 1) {
    throw "Invoke-Git called with empty args (bug)."
  }

  $out  = & git @GitArgs 2>&1
  $code = $LASTEXITCODE

  if ($code -ne 0) {
    $msg = ($out | Out-String).Trim()
    throw "git $($GitArgs -join ' ') failed (exit $code)`n$msg"
  }

  return $out
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

# 0) Preflight
Say "jp-commit: staging paths..."
Invoke-Git @('status','--porcelain') | Out-Null

# 1) Stage with safecrlf SOP fallback
$safecrlfOriginal = Get-SafeCrlf
$changedSafecrlf  = $false

try {
  if (-not (Try-GitAdd -paths $Paths)) {
    Say "jp-commit: safecrlf blocked staging; temporarily setting core.safecrlf=warn"
    Set-SafeCrlf 'warn'
    $changedSafecrlf = $true
    Invoke-Git ( @('add','--') + $Paths ) | Out-Null
  }

  Say "jp-commit: staged diff:"
  Invoke-Git ( @('diff','--cached','--') + $Paths ) | Out-Null

  # 2) Commit attempt #1 (native-aware)
  Say "jp-commit: committing (attempt 1)..."
  $out  = & git commit -m $Message 2>&1
  $code = $LASTEXITCODE

  if ($code -ne 0) {
    $msg = ($out | Out-String)

    # If hooks modified files, re-stage + retry once.
    if ($msg -match 'files were modified by this hook' -or $msg -match 'end-of-file-fixer' -or $msg -match 'pre-commit') {
      Say "jp-commit: hooks modified files; re-staging and retrying commit (attempt 2)..."
      Invoke-Git ( @('add','--') + $Paths ) | Out-Null
      Invoke-Git ( @('diff','--cached','--') + $Paths ) | Out-Null
      Invoke-Git @('commit','-m',$Message) | Out-Null
    } else {
      throw "git commit failed (exit $code)`n$msg"
    }
  }

  if ($Push) {
    Say "jp-commit: pushing..."
    Invoke-Git @('push') | Out-Null
  }

  Say "jp-commit: done."
  Invoke-Git @('status','--porcelain') | Out-Null
} finally {
  if ($changedSafecrlf) {
    Say "jp-commit: restoring core.safecrlf"
    Set-SafeCrlf $safecrlfOriginal
  }
}
