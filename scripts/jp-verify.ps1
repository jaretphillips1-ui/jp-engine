[CmdletBinding()]
param(
  [switch]$Quiet,
  [switch]$NoStop
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve repo root robustly (works even if launched from a different cwd)
$repoRoot = ""
try { $repoRoot = (git rev-parse --show-toplevel 2>$null).Trim() } catch { }
if (-not $repoRoot) {
  # Fallback to script location if git isn't available yet (but we'll fail shortly anyway)
  $repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
  $repoRoot = Split-Path -Parent $repoRoot
}

$stopScript = Join-Path $repoRoot "scripts\jp-stop.ps1"

function Say([string]$msg)  { if (-not $Quiet) { Write-Host $msg } }
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

function Require-Cmd([string]$name, [string]$hint) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if (-not $cmd) { throw "$name not found. $hint" }
  return $cmd
}

function Try-Line([scriptblock]$sb, [string]$fallback = "(version unknown)") {
  try {
    $x = & $sb 2>$null | Select-Object -First 1
    if ($null -ne $x -and -not [string]::IsNullOrWhiteSpace([string]$x)) { return ([string]$x).Trim() }
  } catch { }
  return $fallback
}

$didFail = $false

try {
  BreakLine "VERIFY — START" -Thick 4
  Say ("pwsh: " + $PSVersionTable.PSVersion.ToString())
  Say ("repo: " + $repoRoot)

  # Warn (do not fail) if run under OneDrive
  if ($repoRoot -match '\\OneDrive\\' -or $repoRoot -match '/OneDrive/') {
    Say "WARNING: repo path looks like OneDrive. JP Engine working repo should be under C:\Dev\JP_ENGINE\jp-engine"
  }

  Require-Cmd "git" "Install Git and ensure it's on PATH." | Out-Null
  $branch = Try-Line { git rev-parse --abbrev-ref HEAD } ""
  if ($branch) { Say ("git branch: " + $branch) }

  BreakLine "VERIFY — TOOLS" -Thick 4

  # Core tools
  $gitLine = Try-Line { git --version }
  Say ("git: " + $gitLine)

  Require-Cmd "gh" "Install GitHub CLI (gh) and ensure it's on PATH." | Out-Null
  $ghLine = Try-Line { gh --version }
  Say ("gh: " + $ghLine)

  Require-Cmd "openssl" "Install OpenSSL and ensure it's on PATH." | Out-Null
  $osslLine = Try-Line { openssl version }
  Say ("openssl: " + $osslLine)

  Require-Cmd "node" "Install Node.js and ensure it's on PATH." | Out-Null
  $nodeLine = Try-Line { node --version }
  Say ("node: " + $nodeLine)

  Require-Cmd "npm" "npm should come with Node.js. Ensure it's on PATH." | Out-Null
  $npmLine = Try-Line { npm --version }
  Say ("npm: " + $npmLine)

  # Deployment CLIs
  Require-Cmd "vercel" "Install Vercel CLI (npm i -g vercel) and ensure it's on PATH." | Out-Null
  $vercelLine = Try-Line { vercel --version }
  Say ("vercel: " + $vercelLine)

  Require-Cmd "netlify" "Install Netlify CLI (npm i -g netlify-cli) and ensure it's on PATH." | Out-Null
  $netlifyLine = Try-Line { netlify --version }
  Say ("netlify: " + $netlifyLine)

  # Python tooling
  Require-Cmd "pipx" "Install pipx and ensure it's on PATH." | Out-Null
  $pipxLine = Try-Line { pipx --version }
  Say ("pipx: " + $pipxLine)

  Require-Cmd "pre-commit" "Install pre-commit (pipx install pre-commit) and ensure it's on PATH." | Out-Null
  $pcLine = Try-Line { pre-commit --version }
  Say ("pre-commit: " + $pcLine)

  BreakLine "VERIFY — LINE ENDINGS" -Thick 4
  $ac  = Try-Line { git config --get core.autocrlf } "(unset)"
  $eol = Try-Line { git config --get core.eol } "(unset)"
  Say ("git core.autocrlf: " + $ac)
  Say ("git core.eol:      " + $eol)

  BreakLine "VERIFY — PSScriptAnalyzer" -Thick 4
  if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Say "PSScriptAnalyzer not installed locally (OK). CI will install it."
  } else {
    $scriptsPath = Join-Path $repoRoot "scripts"
    $psFiles = Get-ChildItem -LiteralPath $scriptsPath -Recurse -Filter "*.ps1" -File | Sort-Object FullName

    $issues = @()
    foreach ($f in $psFiles) {
      try {
        $issues += Invoke-ScriptAnalyzer -Path $f.FullName -Severity @('Error','Warning') -Recurse:$false -ErrorAction Stop
      } catch {
        throw ("Invoke-ScriptAnalyzer crashed on file: {0}`n{1}" -f $f.FullName, $_.Exception.Message)
      }
    }
    $errors = @($issues | Where-Object Severity -eq 'Error')
    if ($errors.Count -gt 0) {
      $errors | ForEach-Object { Write-Host ("ERROR: " + $_.RuleName + " — " + $_.Message + " (" + $_.ScriptName + ":" + $_.Line + ")") }
      throw "PSScriptAnalyzer errors: $($errors.Count)."
    }
    Say "PSScriptAnalyzer OK."
  }

  # Extra line-endings info (local overrides + .gitattributes)
  $ga = Join-Path $repoRoot ".gitattributes"
  $hasGA = Test-Path -LiteralPath $ga
  $safecrlf = Try-Line { git config --local --get core.safecrlf } "(unset)"
  $autocrlf = Try-Line { git config --local --get core.autocrlf } "(unset)"

  Write-Host ""
  Write-Host "=== GIT LINE-ENDINGS ==="
  Write-Host ("core.safecrlf : {0}" -f $safecrlf)
  Write-Host ("core.autocrlf : {0}" -f $autocrlf)
  Write-Host (".gitattributes: {0}" -f ($(if ($hasGA) { "PRESENT" } else { "MISSING" })))

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
