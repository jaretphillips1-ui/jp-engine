[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

function Say([string]$msg) { if (-not $Quiet) { Write-Host $msg } }

function BreakLine([string]$label, [switch]$Pass, [switch]$Fail, [int]$Thick = 3) {
  $bp = Join-Path $repoRoot "scripts\jp-break.ps1"
  if (Test-Path $bp) {
    if ($Pass) { & $bp -Color -Pass -Thick $Thick -Bold -Label $label | Out-Null }
    elseif ($Fail) { & $bp -Color -Fail -Thick $Thick -Bold -Label $label | Out-Null }
    else { & $bp -Color -Thick $Thick -Bold -Label $label | Out-Null }
  } else {
    Say "==== $label ===="
  }
}

$failed  = $false
$failMsg = ""

try {
  BreakLine "VERIFY — START" -Thick 3
  Say ("pwsh: " + $PSVersionTable.PSVersion.ToString())
  Say ("repo: " + $repoRoot)

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git not found." }
  $branch = (git rev-parse --abbrev-ref HEAD) 2>$null
  if ($branch) { Say ("git branch: " + $branch.Trim()) }

  # Line ending drift signals (read-only)
  BreakLine "VERIFY — LINE ENDINGS" -Thick 3
  $ac = (git config --get core.autocrlf) 2>$null
  $eol = (git config --get core.eol) 2>$null
  if (-not $ac) { $ac = "(unset)" }
  if (-not $eol) { $eol = "(unset)" }
  Say ("git core.autocrlf: " + $ac.Trim())
  Say ("git core.eol:      " + $eol.Trim())

  BreakLine "VERIFY — PSScriptAnalyzer" -Thick 3
  if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Say "PSScriptAnalyzer not installed locally (OK). CI will install it."
  } else {
    $issues = Invoke-ScriptAnalyzer -Path (Join-Path $repoRoot "scripts") -Recurse -Severity @('Error','Warning') -ErrorAction Stop
    $errors = @($issues | Where-Object Severity -eq 'Error')
    if ($errors.Count -gt 0) {
      $errors | ForEach-Object { Write-Host ("ERROR: " + $_.RuleName + " — " + $_.Message + " (" + $_.ScriptName + ":" + $_.Line + ")") }
      throw "PSScriptAnalyzer errors: $($errors.Count)."
    }
    Say "PSScriptAnalyzer OK."
  }

  BreakLine "VERIFY — PASS" -Pass -Thick 3
  Say "NO PASTE NEEDED (verify pass)."
}
catch {
  $failed  = $true
  $failMsg = $_.Exception.Message
  BreakLine "VERIFY — FAIL" -Fail -Thick 3
  Say ("PASTE NEEDED (verify fail): " + $failMsg)
}
finally {
  BreakLine "STOP — NEXT COMMAND BELOW" -Thick 6
}
