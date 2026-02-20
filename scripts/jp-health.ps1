param(
  [switch]$SaveProof,
  [string]$Note = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
  Write-Host ""
  Write-Host ("JP HEALTH: FAIL — " + $Message) -ForegroundColor Red
  exit 1
}

Write-Host "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Write-Host "JP HEALTH — START"
Write-Host ("time: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
Write-Host ("repo: " + (Get-Location).Path)
Write-Host ("branch: " + (git branch --show-current))
Write-Host ("saveProof: " + ($SaveProof.IsPresent))
Write-Host "════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
Write-Host ""

# Fast front-door: allow dirty so health can run during active work
& .\scripts\jp-tripwire.ps1 -AllowDirty

Write-Host ""
Write-Host "— RUNNING VALIDATE —"
& .\scripts\jp-validate.ps1

Write-Host ""
Write-Host "— RUNNING VERIFY —"
& .\scripts\jp-verify.ps1

if ($SaveProof) {
  Write-Host ""
  Write-Host "— SAVE PROOF REQUESTED —"

  $porcelain = (git status --porcelain)
  if ($porcelain) {
    Fail "SaveProof requires clean working tree. Commit or stash changes, then rerun: scripts\jp-health.ps1 -SaveProof"
  }

  $note2 = $Note
  if ([string]::IsNullOrWhiteSpace($note2)) {
    $note2 = "JP health proof save"
  }

  & .\scripts\jp-save.ps1 -Note $note2
}

Write-Host ""
Write-Host "JP HEALTH: PASS" -ForegroundColor Green
Write-Host "JP HEALTH — DONE"
