param(
  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [string]$Slug = 'work',

  [Parameter(Mandatory=$false)]
  [switch]$NoDoctor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$m){ throw $m }

$repoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $repoPath

if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) { Fail "Not a git repo: $repoPath" }

$cur = (git branch --show-current).Trim()

if (@(git status --porcelain).Count -ne 0) { Fail "Working tree not clean. Commit/stash first." }

git checkout master | Out-Null
git pull | Out-Null
if (@(git status --porcelain).Count -ne 0) { Fail "Master not clean after pull (unexpected)." }

$stamp  = (Get-Date).ToString('yyyyMMdd-HHmm')
$slugOk = ($Slug -replace '[^a-zA-Z0-9\-]+','-').Trim('-')
if ([string]::IsNullOrWhiteSpace($slugOk)) { $slugOk = 'work' }

$branch = "work/$stamp-$slugOk"
git checkout -b $branch | Out-Null

Write-Host "Branch created: $branch"

if (-not $NoDoctor) {
  Write-Host "Running: scripts\jp-doctor.ps1"
  pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath 'scripts\jp-doctor.ps1')
  if ($LASTEXITCODE -ne 0) { Fail "jp-doctor failed (exit $LASTEXITCODE)." }
}

Write-Host "OK"
