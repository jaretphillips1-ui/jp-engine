param(
  [string]$Repo = 'C:\Users\lsphi\OneDrive\AI_Workspace\JP_ENGINE\jp-engine'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "=== JP: SYSTEM VALIDATION ==="
Write-Host ""

if (-not (Test-Path -LiteralPath $Repo)) {
  throw "JP Engine repo directory does not exist: $Repo"
}

Set-Location -LiteralPath $Repo
$pwdPath = (Get-Location).Path
if ($pwdPath -ne $Repo) {
  throw "PWD gate failed. Expected: $Repo  Actual: $pwdPath"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "Git command not found on PATH."
}

Write-Host "Repo OK: $pwdPath"
Write-Host ("Git OK:  " + ((git --version) -join ' '))
Write-Host ""
Write-Host "SYSTEM VALIDATION: PASS"
