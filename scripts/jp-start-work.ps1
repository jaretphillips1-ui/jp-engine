param(
  [Parameter(Mandatory=$false)]
  [string]$Slug = 'work',

  [Parameter(Mandatory=$false)]
  [switch]$RunSmoke,

  [Parameter(Mandatory=$false)]
  [switch]$AllowDirty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$m) { throw $m }

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if ([string]::IsNullOrWhiteSpace($repoRoot)) { Fail "Not inside a git repo." }
Set-Location -LiteralPath $repoRoot

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'scripts\jp-doctor.ps1'))) { Fail "Missing scripts/jp-doctor.ps1" }
if ($RunSmoke -and -not (Test-Path -LiteralPath (Join-Path $repoRoot 'scripts\jp-smoke.ps1'))) { Fail "Missing scripts/jp-smoke.ps1" }

git checkout master | Out-Null
git pull | Out-Null

$porc = @(git status --porcelain)
if (($porc.Count -ne 0) -and (-not $AllowDirty)) {
  Fail ("Working tree not clean. Re-run with -AllowDirty if intentional.`n" + ($porc -join "`n"))
}

$stamp  = (Get-Date).ToString('yyyyMMdd-HHmm')
$slug2  = ($Slug -replace '[^a-zA-Z0-9\-]+','-').Trim('-')
if ([string]::IsNullOrWhiteSpace($slug2)) { $slug2 = 'work' }
$branch = "work/$stamp-$slug2"

git checkout -b $branch | Out-Null

"=== JP: START WORK ==="
"Repo:   $repoRoot"
"Branch: $branch"
"Head:   " + (git rev-parse --short HEAD).Trim()
"Dirty:  " + (@(git status --porcelain).Count) + " change(s)"
""

"=== JP: RUN DOCTOR ==="
pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'scripts\jp-doctor.ps1')
if ($LASTEXITCODE -ne 0) { Fail "jp-doctor failed (exit $LASTEXITCODE)." }

if ($RunSmoke) {
  ""
  "=== JP: RUN SMOKE ==="
  pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'scripts\jp-smoke.ps1')
  if ($LASTEXITCODE -ne 0) { Fail "jp-smoke failed (exit $LASTEXITCODE)." }
}

""
"=== NEXT ==="
"Make changes, then:"
"  git status --porcelain"
"  git diff"
"  git add -A"
"  git commit -m `"<message>`""
"  git push -u origin $branch"
