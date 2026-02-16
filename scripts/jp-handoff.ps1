[CmdletBinding()]
param(
  [int]$StopThick = 12
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot

$break = Join-Path $repoRoot "scripts\jp-break.ps1"
$stop  = Join-Path $repoRoot "scripts\jp-stop.ps1"

function BreakLine([string]$label, [switch]$Pass, [switch]$Fail, [int]$Thick = 3) {
  if (Test-Path -LiteralPath $break) {
    if ($Pass) { & $break -Color -Pass -Thick $Thick -Bold -Label $label | Out-Null }
    elseif ($Fail) { & $break -Color -Fail -Thick $Thick -Bold -Label $label | Out-Null }
    else { & $break -Color -Thick $Thick -Bold -Label $label | Out-Null }
  } else {
    Write-Host ""
    Write-Host "==== $label ===="
  }
}

function TryWrite([scriptblock]$sb) { try { & $sb } catch {} }

BreakLine ("⚪ JP HANDOFF — " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) -Thick 6
Write-Host ("pwsh: " + $PSVersionTable.PSVersion.ToString())
Write-Host ("pwd : " + (Get-Location).Path)

TryWrite { $top = (git rev-parse --show-toplevel 2>$null); if ($top) { Write-Host ("repo: " + $top) } }
TryWrite { $b = (git branch --show-current 2>$null); if ($b) { Write-Host ("git branch: " + $b.Trim()) } }

BreakLine "REPO STATE" -Thick 3
TryWrite { Write-Host ("git log -1: " + (git log -1 --oneline)) }
TryWrite { git status }

BreakLine "RUNNERS" -Thick 3
TryWrite {
  Get-ChildItem -LiteralPath (Join-Path (git rev-parse --show-toplevel) "scripts") -Filter "jp-*.ps1" |
    Sort-Object Name |
    ForEach-Object { Write-Host ("- " + $_.Name) }
}

BreakLine "LINE ENDINGS" -Thick 3
TryWrite {
  $safecrlf = (git config --local --get core.safecrlf 2>$null)
  $autocrlf = (git config --local --get core.autocrlf 2>$null)
  if ([string]::IsNullOrWhiteSpace($safecrlf)) { $safecrlf = "(unset)" }
  if ([string]::IsNullOrWhiteSpace($autocrlf)) { $autocrlf = "(unset)" }
  Write-Host ("core.safecrlf : {0}" -f $safecrlf)
  Write-Host ("core.autocrlf : {0}" -f $autocrlf)
  $ga = Join-Path (git rev-parse --show-toplevel) ".gitattributes"
  $gaState = if (Test-Path -LiteralPath $ga) { "PRESENT" } else { "MISSING" }
  Write-Host (".gitattributes: {0}" -f $gaState)
}

if (Test-Path -LiteralPath $stop) {
  & $stop -Thick $StopThick -Color -Bold -Label "CUT HERE — PASTE BELOW ONLY" -PasteCue | Out-Null
} else {
  BreakLine "CUT HERE — PASTE BELOW ONLY" -Thick 6
  Write-Host ""
  Write-Host "PASTE BELOW ↓ (copy only what’s below this line when asked)"
  Write-Host ""
}

# Minimal chat-ready payload (always AFTER the cut bar)
Write-Host ("PowerShell: {0}" -f $PSVersionTable.PSVersion.ToString())
Write-Host ("PWD: {0}" -f (Get-Location).Path)
TryWrite { Write-Host ("git log -1 --oneline: {0}" -f (git log -1 --oneline)) }

Write-Host ""
Write-Host "Next:"
Write-Host "- .\scripts\jp-start.ps1"
Write-Host "- .\scripts\jp-verify.ps1"
Write-Host "- If same failure repeats 3x: STOP and run read-pack before edits"

if (Test-Path -LiteralPath $stop) {
  & $stop -Thick $StopThick -Color -Bold -Label "STOP — HANDOFF COMPLETE" | Out-Null
} else {
  BreakLine "STOP — HANDOFF COMPLETE" -Thick 6
}
