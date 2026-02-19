[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$Command = '',
  [switch]$Version,
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Dot-source libs AFTER strict mode.
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
    } catch {
      $sha = ""
    } finally {
      if ($root) { Pop-Location }
    }
  }
  if (-not $sha) { $sha = "unknown" }
  "jp-engine {0}" -f $sha
}

function Show-Help {
  @"
JP Engine CLI (skeleton)

Usage:
  pwsh -File .\scripts\jp.ps1 --version
  pwsh -File .\scripts\jp.ps1 doctor
  pwsh -File .\scripts\jp.ps1 verify
  pwsh -File .\scripts\jp.ps1 help

Notes:
- doctor: runs scripts\jp-doctor.ps1 if present
- verify: runs scripts\jp-verify.ps1 (required)
"@ | Write-Host
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

JP-Banner -Title "JP ENGINE — CLI"

if ($Help -or $Command -eq 'help') {
  Show-Help
  JP-Exit -Code 0
}

if ($Version -or $Command -eq '--version' -or $Command -eq 'version') {
  Write-Host (Get-JPVersionLine)
  JP-Exit -Code 0
}

switch ($Command) {
  '' {
    Show-Help
    JP-Exit -Code 2 -Message "No command provided."
  }
  'verify' { Run-Verify; JP-Exit -Code 0 }
  'doctor' { Run-Doctor; JP-Exit -Code 0 }
  default  {
    Show-Help
    JP-Exit -Code 2 -Message ("Unknown command: {0}" -f $Command)
  }
}
