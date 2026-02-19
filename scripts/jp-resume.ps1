param(
  [Parameter(Mandatory=$false)]
  [switch]$RunDoctor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$m) { throw $m }

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if ([string]::IsNullOrWhiteSpace($repoRoot)) { Fail "Not inside a git repo." }
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current 2>$null)
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = 'DETACHED_HEAD' } else { $branch = $branch.Trim() }

$headShort = (git rev-parse --short HEAD).Trim()
$porc = @(git status --porcelain)

"=== JP: RESUME ==="
"Repo:   $repoRoot"
"Branch: $branch"
"HEAD:   $headShort"
"Dirty:  $($porc.Count) change(s)"
""
"=== JP: RECENT ==="
git log -3 --oneline --decorate
""

# Try to show PR (best-effort)
try {
  $repo = (git remote get-url origin 2>$null)
  if ($repo) {
    $pr = gh pr view --json number,url,state,headRefName --jq '"#\(.number) \(.state) \(.headRefName) \(.url)"' 2>$null
    if ($pr) {
      "=== JP: PR (current branch) ==="
      $pr
      ""
    }
  }
} catch { }

if ($RunDoctor) {
  "=== JP: RUN DOCTOR ==="
  pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'scripts\jp-doctor.ps1')
  if ($LASTEXITCODE -ne 0) { Fail "jp-doctor failed (exit $LASTEXITCODE)." }
  ""
}

"=== NEXT ==="
"- If starting new work: use scripts\jp-start-work-simple.ps1 (or your preferred starter)."
"- If continuing: check git diff + commit + push, then PR."
