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
  & $Action
  Write-Host ("PASS: {0}" -f $Name) -ForegroundColor Green
}

function Step-Commit {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Message,
    [string]$Context = "commit step"
  )

  $before = Get-GitHead
  git commit -m $Message | Write-Host
  Assert-GitCommitHappened -BeforeHead $before -Context $Context
}
