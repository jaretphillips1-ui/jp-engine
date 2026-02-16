[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo       = "C:\Users\lsphi\OneDrive\AI_Workspace\JP_ENGINE\jp-engine"
$scriptsDir = Join-Path $repo "scripts"

$fail = $false
$warn = $false

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════"
Write-Host "JP DOCTOR — DIAGNOSE"
Write-Host "════════════════════════════════════════════════════════════════════════"
Write-Host ""

if (-not (Test-Path -LiteralPath $repo)) {
    Write-Host "FAIL: Repo path missing"
    $fail = $true
}
else {
    Write-Host "OK: Repo path exists"
}

if (-not (Test-Path -LiteralPath (Join-Path $repo ".git"))) {
    Write-Host "FAIL: .git folder missing"
    $fail = $true
}
else {
    Write-Host "OK: .git present"
}

Set-Location $repo

try {
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if ($branch -eq "HEAD") {
        Write-Host "WARN: Detached HEAD"
        $warn = $true
    }
    else {
        Write-Host "OK: Branch $branch"
    }
}
catch {
    Write-Host "FAIL: Unable to read git branch"
    $fail = $true
}

$status = git status --porcelain
if ($status) {
    Write-Host "WARN: Working tree not clean"
    $warn = $true
}
else {
    Write-Host "OK: Working tree clean"
}

if (-not (Test-Path -LiteralPath (Join-Path $repo ".gitattributes"))) {
    Write-Host "WARN: .gitattributes missing"
    $warn = $true
}
else {
    Write-Host "OK: .gitattributes present"
}

$required = @(
    "jp-start.ps1",
    "jp-verify.ps1",
    "jp-shutdown.ps1",
    "jp-smoke.ps1",
    "jp-stop.ps1"
)

foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $scriptsDir $file))) {
        Write-Host "FAIL: Missing $file"
        $fail = $true
    }
}

Write-Host ""

if ($fail) {
    Write-Host "🔴 DOCTOR — FAIL"
}
elseif ($warn) {
    Write-Host "🟡 DOCTOR — WARN"
}
else {
    Write-Host "🟢 DOCTOR — HEALTHY"
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════"
