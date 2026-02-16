[CmdletBinding()]
param(
  [switch]$Quiet,
  [switch]$NoStop
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$stopScript = Join-Path $repoRoot "scripts\jp-stop.ps1"

function Say([string]$msg)  { if (-not $Quiet) { Write-Host   $msg } }
function Emit([string]$msg) { Write-Output $msg }

function BreakLine([string]$label, [switch]$Pass, [switch]$Fail, [int]$Thick = 4) {
  $bp = Join-Path $repoRoot "scripts\jp-break.ps1"
  if (Test-Path -LiteralPath $bp) {
    if ($Pass) { & $bp -Color -Pass -Thick $Thick -Bold -Label $label | Out-Null }
    elseif ($Fail) { & $bp -Color -Fail -Thick $Thick -Bold -Label $label | Out-Null }
    else { & $bp -Color -Thick $Thick -Bold -Label $label | Out-Null }
  } else {
    Say "==== $label ===="
  }
}

$didFail = $false

try {
  BreakLine "VERIFY — START" -Thick 4
  Say ("pwsh: " + $PSVersionTable.PSVersion.ToString())
  Say ("repo: " + $repoRoot)

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git not found." }
  $branch = (git rev-parse --abbrev-ref HEAD) 2>$null
  if ($branch) { Say ("git branch: " + $branch.Trim()) }

  BreakLine "VERIFY — TOOLS" -Thick 4

  $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
  if (-not $ghCmd) { throw "gh not found (GitHub CLI). Install or add to PATH." }
  $ghLine = (& gh --version 2>$null | Select-Object -First 1)
  if ($ghLine) { Say ("gh: " + $ghLine.Trim()) } else { Say "gh: (version unknown)" }

  $osslCmd = Get-Command openssl -ErrorAction SilentlyContinue
  if (-not $osslCmd) { throw "openssl not found. Install or add to PATH." }
  $osslLine = (& openssl version 2>$null | Select-Object -First 1)
  if ($osslLine) { Say ("openssl: " + $osslLine.Trim()) } else { Say "openssl: (version unknown)" }

  BreakLine "VERIFY — LINE ENDINGS" -Thick 4
  $ac  = (git config --get core.autocrlf) 2>$null
  $eol = (git config --get core.eol) 2>$null
  if (-not $ac)  { $ac  = "(unset)" }
  if (-not $eol) { $eol = "(unset)" }
  Say ("git core.autocrlf: " + $ac.Trim())
  Say ("git core.eol:      " + $eol.Trim())

  BreakLine "VERIFY — PSScriptAnalyzer" -Thick 4
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

  try { $top = (git rev-parse --show-toplevel 2>$null) } catch { $top = $null }
  $ga = if ($top) { Join-Path $top ".gitattributes" } else { ".gitattributes" }
  $hasGA = Test-Path -LiteralPath $ga
  try { $safecrlf = (git config --local --get core.safecrlf 2>$null) } catch { $safecrlf = $null }
  try { $autocrlf = (git config --local --get core.autocrlf 2>$null) } catch { $autocrlf = $null }
  if ([string]::IsNullOrWhiteSpace($safecrlf)) { $safecrlf = "(unset)" }
  if ([string]::IsNullOrWhiteSpace($autocrlf)) { $autocrlf = "(unset)" }

  Write-Host ""
  Write-Host "=== GIT LINE-ENDINGS ==="
  Write-Host ("core.safecrlf : {0}" -f $safecrlf)
  Write-Host ("core.autocrlf : {0}" -f $autocrlf)
  $gaState = if ($hasGA) { "PRESENT" } else { "MISSING" }
  Write-Host (".gitattributes: {0}" -f $gaState)

  BreakLine "VERIFY — PASS" -Pass -Thick 4
  Say "NO PASTE NEEDED (verify pass)."

  Emit "VERIFY — PASS"
  Emit "NO PASTE NEEDED (verify pass)."
}
catch {
  $didFail = $true
  BreakLine "VERIFY — FAIL" -Fail -Thick 4
  Say ("ERROR: " + $_.Exception.Message)

  Emit "VERIFY — FAIL"
  Emit ("ERROR: " + $_.Exception.Message)

  throw
}
finally {
  if (-not $NoStop) {
    if (Test-Path -LiteralPath $stopScript) {
      if ($didFail) {
        & $stopScript -Thick 4 -Color -Fail -Bold -Label "CUT HERE — PASTE BELOW ONLY (VERIFY FAIL)" -PasteCue | Out-Null
      } else {
        & $stopScript -Thick 4 -Color -Bold -Label "STOP — NEXT COMMAND BELOW" | Out-Null
      }
    } else {
      if ($didFail) {
        Write-Host "==== CUT HERE — PASTE BELOW ONLY (VERIFY FAIL) ===="
        Write-Host ""
        Write-Host "PASTE BELOW ↓ (copy only what’s below this line when asked)"
        Write-Host ""
      } else {
        Write-Host "==== STOP — NEXT COMMAND BELOW ===="
        Write-Host ""
      }
    }
  }
}
