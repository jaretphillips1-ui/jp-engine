# JP Engine Housekeeping Tracker

A lightweight checklist to keep momentum while ensuring we don’t forget small cleanup items.

## Daily start gate (every session)
- [ ] Open PowerShell in the JP repo root (must contain `.git` and `docs/00_JP_INDEX.md`)
- [ ] `git checkout master`
- [ ] `git pull --ff-only`
- [ ] `git status --porcelain` is empty (clean)

## Before pushing a PR
- [ ] Working tree clean (no accidental files)
- [ ] CI scope is single-track (only the intended change)
- [ ] Commit message is sane and specific
- [ ] If CI config changed: confirm it’s minimal and doesn’t touch unrelated jobs

## If CI goes red (strict rule)
- [ ] Look ONLY at the first failing check/step
- [ ] Apply the smallest possible fix
- [ ] Commit
- [ ] Re-run checks

## Merge + re-anchor (after PR is green)
- [ ] Squash merge (unless explicitly doing otherwise)
- [ ] Delete remote feature branch (if missed)
- [ ] Sync local master:
  - [ ] `git checkout master`
  - [ ] `git pull --ff-only`
  - [ ] `git fetch --prune`
- [ ] Confirm clean working tree again

## Local branch hygiene (weekly or after a burst)
- [ ] List local `ci/*` and `docs/*` branches
- [ ] Delete only branches that are fully merged into `master`
- [ ] If a branch is unmerged but not active: push it and “park” it intentionally

## Documentation touchpoints (only when relevant)
- [ ] If toolchain requirements change: update `docs/JP_TOOLCHAIN.md`
- [ ] If security/guardrails change: update `docs/JP_SECURITY.md`
- [ ] If recovery/restore process changes: update `docs/JP_RECOVERY.md`

## Notes
- Keep this doc short.
- The goal is: **clean baselines, minimal diffs, reliable rhythm**.
