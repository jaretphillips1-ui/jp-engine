Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\jp-git-guards.ps1"

function Step {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][scriptblock]$Action
  )

  Write-Host ""
  Write-Host ("=== {0} ===" -f $Name) -ForegroundColor Cyan
  try {
    & $Action
    Write-Host ("PASS: {0}" -f $Name) -ForegroundColor Green
  } catch {
    Write-Host ("FAIL: {0}" -f $Name) -ForegroundColor Red
    throw
  }
}

function Step-Commit {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Message,
    [string]$Context = "commit step"
  )

  $before = Get-GitHead
  git commit -m $Message | Write-Host
  Assert-LastExitCode -Context ("git commit ({0})" -f $Context)
  Assert-GitCommitHappened -BeforeHead $before -Context $Context
}

function Step-Push {
  [CmdletBinding()]
  param(
    [string]$Context = "push step"
  )

  git push | Write-Host
  Assert-LastExitCode -Context ("git push ({0})" -f $Context)
  Assert-GitPushedToUpstream -Context $Context
}
