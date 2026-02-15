[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

function Say([string]$msg) { if (-not $Quiet) { Write-Host $msg } }

function BreakLine([string]$label, [switch]$Pass, [switch]$Fail) {
  $bp = Join-Path $repoRoot "scripts\jp-break.ps1"
  if (Test-Path $bp) {
    if ($Pass) { & $bp -Color -Pass -Thick 4 -Bold -Label $label | Out-Null }
    elseif ($Fail) { & $bp -Color -Fail -Thick 4 -Bold -Label $label | Out-Null }
    else { & $bp -Color -Thick 4 -Bold -Label $label | Out-Null }
  } else {
    Say "==== $label ===="
  }
}

$failed = $false
$failMsg = ""

try {
  BreakLine "VERIFY — START"
  Say ("pwsh: " + $PSVersionTable.PSVersion.ToString())

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git not found." }
  $branch = (git rev-parse --abbrev-ref HEAD) 2>$null
  if ($branch) { Say ("git branch: " + $branch.Trim()) }

  BreakLine "VERIFY — PSScriptAnalyzer"
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

  BreakLine "VERIFY — PASS" -Pass
  Say "NO PASTE NEEDED (verify pass)."
}
catch {
  $failed = $true
  $failMsg = $_.Exception.Message
  BreakLine "VERIFY — FAIL" -Fail
  Say ("PASTE NEEDED (verify fail): " + $failMsg)
}
finally {
  $stop = Join-Path $repoRoot "scripts\jp-stop.ps1"
  if (Test-Path $stop) { & $stop -Thick 6 -Label "STOP — NEXT COMMAND BELOW" | Out-Null }
  else { BreakLine "STOP — NEXT COMMAND BELOW" }
}