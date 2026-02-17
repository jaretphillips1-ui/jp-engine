# JP Engine Toolchain (Canonical)

This file is the single source of truth for the JP Engine development toolchain and verification expectations.
Keep `jp-verify.ps1` aligned to this document.

## Required
- Git (available on PATH)
- PowerShell 7+ (pwsh)
- Node.js LTS (project-specific version policy; keep CI aligned)
- npm (ships with Node)

## Recommended
- 7-Zip (for archives if used by scripts)
- Docker (only if JP Engine uses containers)
- GitHub CLI (`gh`) (optional; only if workflows reference it)

## Verification checklist (human)
- From repo root: `git status` is clean when expected
- `git log -1 --oneline` matches current intent (baseline tag when applicable)
- Run the repo's verification entrypoint (examples):
  - `pwsh -File .\scripts\jp-verify.ps1` (if present)
  - `npm test` / `npm run test` (if defined)
- CI should be green on mainline (`master`/`main`) before tagging a new baseline

## Version policy
- Prefer pinning versions in CI where practical
- Keep minimum supported versions documented here as the project matures

## Notes
- If toolchain changes, update:
  1) this file
  2) verification script(s)
  3) CI workflow(s)
