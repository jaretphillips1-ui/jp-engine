param(
  [Parameter(Mandatory=$false)]
  [switch]$AllowDirty,

  [Parameter(Mandatory=$false)]
  [string]$Next = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$m) { throw $m }

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if ([string]::IsNullOrWhiteSpace($repoRoot)) { Fail "Not inside a git repo." }
Set-Location -LiteralPath $repoRoot

$porc = @(git status --porcelain)
if (($porc.Count -ne 0) -and (-not $AllowDirty)) {
  Fail ("Refusing shutdown: working tree not clean. Re-run with -AllowDirty if intentional.`n" + ($porc -join "`n"))
}

"=== JP: SHUTDOWN ==="
"Repo:  $repoRoot"
"Dirty: $($porc.Count) change(s)"
""

# Print a handoff block every time (this is the point of shutdown)
pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'scripts\jp-handoff.ps1') -Next $Next
""
"Shutdown complete (handoff printed above)."
