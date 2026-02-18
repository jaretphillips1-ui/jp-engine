Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Line([string]$s='') { Write-Host $s }

Line "=============================================================================="
Line "JP Housekeeping Reminder"
Line "=============================================================================="
Line

# Repo root check
if (-not (Test-Path -LiteralPath (Join-Path (Get-Location) '.git'))) {
  Line "Run from repo root. Current: $((Get-Location).Path)"
  exit 1
}

# Quick status
$branch = (git branch --show-current).Trim()
$porc   = git status --porcelain
$head   = (git log -1 --oneline --decorate)

Line ("Branch: " + $branch)
Line ("HEAD:   " + $head)
Line ("Dirty:  " + ($(if ($porc) { ($porc | Measure-Object).Count } else { 0 })) + " change(s)")
Line

Line "After merging a PR:"
Line " - git switch master"
Line " - git pull --ff-only"
Line " - git status --porcelain   (must be empty)"
Line " - ensure feature branch deleted (remote + local)"
Line

Line "CI sanity:"
Line " - confirm a green run on the merge commit"
Line " - if 'no required checks reported', treat as unknown (use status rollup)"
Line

Line "Security quick checks:"
Line " - .\scripts\jp-doctor.ps1"
Line

Line "Backup/restore points:"
Line " - keep a dated known-green restore point + moving latest-green marker"
Line
