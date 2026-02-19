[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$Command = '',
  [switch]$Version,
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\jp-log.ps1"
. "$PSScriptRoot\lib\jp-exit.ps1"

function Get-JPRepoRoot {
  try { (git rev-parse --show-toplevel).Trim() } catch { "" }
}

function Get-JPVersionLine {
  $root = Get-JPRepoRoot
  $sha = ""
  if ($root) {
    try {
      Push-Location -LiteralPath $root
      $sha = (git rev-parse --short HEAD).Trim()
    } catch { $sha = "" }
    finally { Pop-Location }
  }
  if (-not $sha) { $sha = "unknown" }
  "jp-engine {0}" -f $sha
}

function Run-Verify {
  $v = Join-Path $PSScriptRoot 'jp-verify.ps1'
  if (-not (Test-Path -LiteralPath $v)) { JP-Exit -Code 3 -Message "Missing: $v" }
  JP-Log -Level STEP -Message "Running: jp-verify"
  & $v
  JP-Log -Level OK -Message "jp-verify PASS"
}

function Run-Doctor {
  $d = Join-Path $PSScriptRoot 'jp-doctor.ps1'
  if (Test-Path -LiteralPath $d) {
    JP-Log -Level STEP -Message "Running: jp-doctor"
    & $d
    JP-Log -Level OK -Message "jp-doctor PASS"
  } else {
    JP-Log -Level WARN -Message "SKIP: scripts\jp-doctor.ps1 not present"
  }
}

function Show-Help {
  param($Registry)

  Write-Host "JP Engine CLI (registry)"
  Write-Host ""
  Write-Host "Usage:"
  Write-Host "  pwsh -File .\scripts\jp.ps1 <command>"
  Write-Host ""
  Write-Host "Commands:"
  foreach ($k in ($Registry.Keys | Sort-Object)) {
    Write-Host ("  {0,-10} {1}" -f $k, $Registry[$k].Description)
  }
}

JP-Banner -Title "JP ENGINE — CLI"

$Commands = @{
  verify = @{
    Description = "Run jp-verify"
    Action = { Run-Verify }
  }
  doctor = @{
    Description = "Run jp-doctor (optional)"
    Action = { Run-Doctor }
  }
  version = @{
    Description = "Show version"
    Action = { Write-Host (Get-JPVersionLine) }
  }
  help = @{
    Description = "Show help"
    Action = { param($r) Show-Help -Registry $r }
  }
}

if ($Version) { $Command = "version" }
if ($Help)    { $Command = "help" }
if (-not $Command) { $Command = "help" }

if (-not $Commands.ContainsKey($Command)) {
  Show-Help -Registry $Commands
  JP-Exit -Code 2 -Message ("Unknown command: {0}" -f $Command)
}

& $Commands[$Command].Action
JP-Exit -Code 0
