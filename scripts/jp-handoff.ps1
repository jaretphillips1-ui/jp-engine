param(
  [Parameter(Mandatory=$false)]
  [string]$Next = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$m) { throw $m }

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if ([string]::IsNullOrWhiteSpace($repoRoot)) { Fail "Not inside a git repo." }
Set-Location -LiteralPath $repoRoot

function Get-BranchLabel {
  $b = (git branch --show-current 2>$null)
  if ([string]::IsNullOrWhiteSpace($b)) {
    $b = (git symbolic-ref --short -q HEAD 2>$null)
  }
  if ([string]::IsNullOrWhiteSpace($b)) { return 'DETACHED_HEAD' }
  return $b.Trim()
}

$when    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ssK')
$branch  = Get-BranchLabel
$head    = (git rev-parse HEAD).Trim()
$headS   = (git rev-parse --short HEAD).Trim()
$porc    = @(git status --porcelain)

$prUrl = $null
try { $prUrl = gh pr view --json url --jq .url 2>$null } catch { }

"=== JP: HANDOFF (paste into new chat) ==="
""
"JP ENGINE — HANDOVER"
"- When:   $when"
"- Repo:   $repoRoot"
"- Branch: $branch"
"- HEAD:   $headS ($head)"
"- Dirty:  $($porc.Count) change(s)"
if ($prUrl) { "- PR:     $prUrl" }

if ($porc.Count -gt 0) {
  ""
  "Working tree (porcelain):"
  $porc
}

""
"Recent commits:"
git log -5 --oneline --decorate

if ($Next) {
  ""
  "Next:"
  $Next
}
