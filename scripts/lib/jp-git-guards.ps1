Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GitHead {
  (git rev-parse HEAD).Trim()
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
