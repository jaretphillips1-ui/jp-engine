param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$PrUrl,

  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [string]$Repo = 'jaretphillips1-ui/jp-engine',

  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

  [Parameter(Mandatory=$false)]
  [switch]$SkipSmoke
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$m){ throw $m }

function Notify([string]$title, [string]$msg, [string]$kind = 'Info'){
  try {
    if (Get-Module -ListAvailable -Name BurntToast) {
      Import-Module BurntToast -ErrorAction SilentlyContinue | Out-Null
      if (Get-Command -Name New-BurntToastNotification -ErrorAction SilentlyContinue) {
        New-BurntToastNotification -Text $title, $msg | Out-Null
      }
    }
  } catch {}

  # Audible fallback
  try { [console]::beep(900,200) } catch {}
  try { [console]::beep(700,200) } catch {}
}

Set-Location -LiteralPath $RepoPath
if (-not (Test-Path -LiteralPath (Join-Path $RepoPath '.git'))) { Fail "Not a git repo: $RepoPath" }

Write-Host "=== JP AUTO MERGE ==="
Write-Host "RepoPath: $RepoPath"
Write-Host "Repo:     $Repo"
Write-Host "PR:       $PrUrl"
Write-Host ""

# Gate: working tree must be clean before we start doing destructive operations
if (@(git status --porcelain).Count -ne 0) {
  Notify "JP AUTO MERGE (BLOCKED)" "Working tree not clean. Fix/stash and rerun." "Error"
  Fail "Working tree not clean. STOP."
}

# 1) Watch checks — if anything fails, STOP (no merge)
Write-Host "=== CHECKS (watch) ==="
$checksOut = $null
try {
  gh pr checks $PrUrl --repo $Repo --watch --interval 10
} catch {
  Notify "JP AUTO MERGE (FAILED)" "Checks command failed. No merge performed." "Error"
  throw
}

# 2) Merge (squash + delete branch) — only after checks succeed
Write-Host ""
Write-Host "=== MERGE (squash + delete branch) ==="
try {
  gh pr merge $PrUrl --repo $Repo --squash --delete-branch
} catch {
  Notify "JP AUTO MERGE (FAILED)" "Merge failed. No further steps run." "Error"
  throw
}

# 3) Sync master locally
Write-Host ""
Write-Host "=== SYNC MASTER ==="
git checkout master | Out-Null
git pull | Out-Null
if (@(git status --porcelain).Count -ne 0) {
  Notify "JP AUTO MERGE (FAILED)" "Master not clean after pull. STOP." "Error"
  Fail "Master not clean after pull (unexpected)."
}

# 4) Smoke
if (-not $SkipSmoke) {
  Write-Host ""
  Write-Host "=== SMOKE ==="
  pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath 'scripts\jp-smoke.ps1')
  if ($LASTEXITCODE -ne 0) {
    Notify "JP AUTO MERGE (FAILED)" "Smoke failed after merge. Investigate." "Error"
    Fail "Smoke failed (exit $LASTEXITCODE)."
  }
}

# 5) Tag green baseline (runs smoke again if that script does so)
Write-Host ""
Write-Host "=== TAG GREEN (new baseline) ==="
pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath 'scripts\jp-tag-green.ps1') -RunSmoke
if ($LASTEXITCODE -ne 0) {
  Notify "JP AUTO MERGE (FAILED)" "jp-tag-green failed after merge. Investigate." "Error"
  Fail "jp-tag-green failed (exit $LASTEXITCODE)."
}

Write-Host ""
Write-Host "=== DONE ==="
git status -sb
git log -1 --oneline --decorate
$tags = git tag --list 'baseline/green-*' --sort=-creatordate | Select-Object -First 6
$tags | ForEach-Object { $_ }

Notify "JP AUTO MERGE (DONE)" "Merged + synced master + smoke + tagged green." "Success"
