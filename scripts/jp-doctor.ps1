[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoRoot
$scriptsDir = Join-Path $repoRoot "scripts"

$break = Join-Path $repoRoot "scripts\jp-break.ps1"

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

$fail = $false
$warn = $false

BreakLine "JP DOCTOR — DIAGNOSE" -Thick 6
Write-Host ("repo: " + $repoRoot)

if (-not (Test-Path -LiteralPath $repoRoot)) {
  Write-Host "FAIL: Repo path missing"
  $fail = $true
} else {
  Write-Host "OK: Repo path exists"
}

$gitDir = Join-Path $repoRoot ".git"
if (-not (Test-Path -LiteralPath $gitDir)) {
  Write-Host "FAIL: .git folder missing"
  $fail = $true
} else {
  Write-Host "OK: .git present"
}

Set-Location $repoRoot

try {
  $branch = (git rev-parse --abbrev-ref HEAD 2>$null)
  if ([string]::IsNullOrWhiteSpace($branch)) {
    Write-Host "FAIL: Unable to read git branch"
    $fail = $true
  } elseif ($branch.Trim() -eq "HEAD") {
    Write-Host "WARN: Detached HEAD"
    $warn = $true
  } else {
    Write-Host ("OK: Branch " + $branch.Trim())
  }
}
catch {
  Write-Host "FAIL: Unable to read git branch"
  $fail = $true
}

try {
  $status = (git status --porcelain) 2>$null
  if ($status) {
    Write-Host "WARN: Working tree not clean"
    $warn = $true
  } else {
    Write-Host "OK: Working tree clean"
  }
}
catch {
  Write-Host "WARN: Unable to read git status"
  $warn = $true
}

$ga = Join-Path $repoRoot ".gitattributes"
if (-not (Test-Path -LiteralPath $ga)) {
  Write-Host "WARN: .gitattributes missing"
  $warn = $true
} else {
  Write-Host "OK: .gitattributes present"
}

$required = @(
  "jp-break.ps1",
  "jp-doctor.ps1",
  "jp-gate.ps1",
  "jp-handoff.ps1",
  "jp-remote.ps1",
  "jp-save.ps1",
  "jp-shutdown.ps1",
  "jp-smoke.ps1",
  "jp-start.ps1",
  "jp-stop.ps1",
  "jp-verify.ps1"
)

foreach ($file in $required) {
  if (-not (Test-Path -LiteralPath (Join-Path $scriptsDir $file))) {
    Write-Host ("FAIL: Missing scripts\" + $file)
    $fail = $true
  }
}

if ($fail) { BreakLine "🔴 DOCTOR — FAIL" -Fail -Thick 6 }
elseif ($warn) { BreakLine "🟡 DOCTOR — WARN" -Thick 6 }
else { BreakLine "🟢 DOCTOR — HEALTHY" -Pass -Thick 6 }
