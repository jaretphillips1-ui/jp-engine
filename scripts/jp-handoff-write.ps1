[CmdletBinding()]
param(
  [string]$HandoffPath = "docs/JP_ENGINE_HANDOFF.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path ".git")) { throw "Not in repo root." }

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
$commit = (git rev-parse --short HEAD).Trim()
$msg    = (git log -1 --pretty=%s).Trim()
$stamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# NOTE: Release/asset discovery via gh --json is Phase 2 (no guessing here yet)
$body = @"
# JP Engine Handoff

Generated: $stamp

## Repo State
- Branch: $branch
- Commit: $commit
- Message: $msg

## Release / Backups
- (Phase 2) Populate from GitHub Release via gh --json
- (Phase 2) Populate local artifacts + SHA summary

## Work Context
- What I was doing:
- What’s next:
- Housekeeping:
"@

$body | Set-Content -LiteralPath $HandoffPath -Encoding utf8
Write-Host ("Handoff written -> {0}" -f $HandoffPath) -ForegroundColor Green
