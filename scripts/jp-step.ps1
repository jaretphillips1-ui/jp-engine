[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$stop  = Join-Path $repoRoot "scripts\jp-stop.ps1"

function Invoke-JpStep {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][scriptblock]$Command,
    [string[]]$ExpectRegex = @(),
    [switch]$ShowOutputOnPass
  )

  try {
    $out = & $Command 2>&1 | Out-String

    foreach ($rx in $ExpectRegex) {
      if ($out -notmatch $rx) {
        throw ("Expected output did not match regex: " + $rx)
      }
    }

    if ($ShowOutputOnPass -and $out.Trim()) {
      Write-Host $out.TrimEnd()
      Write-Host ""
    }

    return $out
  }
  catch {
    $msg = $_.Exception.Message

    if (Test-Path -LiteralPath $stop) {
      & $stop -Thick 12 -Color -Fail -Bold -Label ("CUT HERE — " + $Label + " (FAIL)") -PasteCue | Out-Null
    } else {
      Write-Host "==== CUT HERE — $Label (FAIL) ===="
      Write-Host ""
      Write-Host "PASTE BELOW ↓ (copy only what’s below this line when asked)"
      Write-Host ""
    }

    Write-Host ("STEP FAIL: " + $Label)
    Write-Host ("REASON:   " + $msg)
    Write-Host ""
    Write-Host $out.TrimEnd()

    throw
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  Write-Host "jp-step.ps1 loaded. Dot-source this file to use Invoke-JpStep."
}
