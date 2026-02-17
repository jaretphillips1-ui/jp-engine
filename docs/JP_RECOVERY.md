# JP Engine Recovery (Restore Points + Handoff)

This document describes how we recover quickly and safely from mistakes, bad merges, or broken CI.

## Baselines
- When CI is green and local verify/doctor passes:
  - create a tag and push it (example: `baseline-ci-green-YYYY-MM-DD`)
- Keep at least one recent green baseline (24h+ retention) before risky expansions.

## Fast recovery moves
- If you need to return to a known-good baseline:
  1) `git fetch --tags`
  2) `git checkout <baseline-tag>`
  3) verify locally
  4) decide whether to branch or reset the mainline (policy depends on collaboration)

## Working directory safety
- Always confirm repo root before running scripts:
  - `Set-Location -LiteralPath C:\Dev\JP_ENGINE\jp-engine`
  - `git status`
- Avoid running scripts from the wrong directory.

## Profile/Work context (Active Project)
- `Start-WorkJP` sets the active project and jumps to the JP repo
- new PowerShell windows auto-start in the active repo
- `Stop-Work` clears the active project (full shutdown)

## If CI goes red
- Inspect only the first failing step.
- Apply the smallest possible change.
- Commit/push.
- Rerun.

## Handoff template
- Current branch + head commit
- Tag(s) and state (green/red)
- Working tree clean/dirty
- Next 1–3 tasks
- Any gotchas discovered during last run
