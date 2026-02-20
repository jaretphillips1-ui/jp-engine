Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GitHead {
  (git rev-parse HEAD).Trim()
}

function Assert-LastExitCode {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Context,
    [int]$Code = $global:LASTEXITCODE
  )
  if ($Code -ne 0) {
    throw ("{0} failed (exit code {1})." -f $Context, $Code)
  }
}

function Assert-GitClean {
  [CmdletBinding()]
  param([string]$Context = "git clean gate")
  $s = git status --porcelain
  if ($s) {
    throw ("{0}: working tree not clean.`n{1}" -f $Context, $s)
  }
}

function Assert-GitCommitHappened {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$BeforeHead,
    [string]$Context = "commit",
    [switch]$AllowNoop
  )

  $after = (git rev-parse HEAD).Trim()
  if ($after -ne $BeforeHead) { return }

  if ($AllowNoop) {
    Write-Host ("[NOOP] {0}: no new commit (HEAD unchanged)." -f $Context) -ForegroundColor Yellow
    return
  }

  $s = git status --porcelain
  if (-not $s) { $s = "(working tree clean; nothing to commit)" }

  throw ("{0} did not create a new commit (HEAD unchanged).`nStatus:`n{1}" -f $Context, $s)
}

function Get-GitUpstreamRef {
  try { (git rev-parse --abbrev-ref '@{u}').Trim() } catch { "" }
}

function Assert-GitUpstreamSet {
  [CmdletBinding()]
  param([string]$Context = "upstream gate")
  $u = Get-GitUpstreamRef
  if (-not $u) { throw ("{0}: no upstream set for current branch." -f $Context) }
}

function Assert-GitPushedToUpstream {
  [CmdletBinding()]
  param([string]$Context = "push gate")

  Assert-GitUpstreamSet -Context $Context

  $head = (git rev-parse HEAD).Trim()
  $uRef = (git rev-parse '@{u}').Trim()

  if ($head -ne $uRef) {
    $u = Get-GitUpstreamRef
    throw ("{0}: HEAD not pushed to upstream.`nHEAD: {1}`nUP  : {2} ({3})" -f $Context, $head, $uRef, $u)
  }
}
