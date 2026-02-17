[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (git rev-parse --show-toplevel).Trim()
if ([string]::IsNullOrWhiteSpace($repoRoot)) { throw "jp-resume: not inside a git repo." }

Write-Host "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Write-Host "═══════════════════════════════════════════════════  RESUME — START  ════════════════════════════════════════════════════"
Write-Host "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Write-Host ("pwsh: {0}" -f $PSVersionTable.PSVersion.ToString())
Write-Host ("repo: {0}" -f $repoRoot)
Write-Host ("git branch: {0}" -f (git rev-parse --abbrev-ref HEAD))
Write-Host ("head: {0}" -f (git log -1 --oneline))
Write-Host ""

Write-Host "=== git status ==="
git status
Write-Host ""

Write-Host "=== verify ==="
& (Join-Path $repoRoot "scripts\jp-verify.ps1")
