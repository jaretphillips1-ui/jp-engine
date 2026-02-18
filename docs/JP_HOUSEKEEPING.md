# JP Engine — Housekeeping (Reminder + Tracker)

## Quick reminder (after merges + before shutdown)
- Sync default branch:
  - `git switch master`
  - `git pull --ff-only`
- Confirm clean tree:
  - `git status --porcelain` (must be empty)
- Confirm feature branch cleanup:
  - Remote: `gh pr merge --delete-branch` (preferred)
  - Local: delete the feature branch if it still exists
- CI sanity (if you changed workflows/tooling):
  - Confirm at least one full green CI run on the merge commit
  - If you ever see “no required checks reported”, treat that as unknown and use a rollup check

## Tracker (lightweight)
### Daily start gate (every session)
- [ ] Open PowerShell in JP repo root (must contain `.git`)
- [ ] `git switch master`
- [ ] `git pull --ff-only`
- [ ] `git status --porcelain` is empty

### Before pushing a PR
- [ ] Working tree clean (no accidental files)
- [ ] One-track CI loop (fix first failure only, smallest change)
- [ ] Commit message is specific + sane
- [ ] If CI config changed: confirm minimal diff + rerun CI

### Merge + re-anchor (after PR is green)
- [ ] Squash merge (unless explicitly doing otherwise)
- [ ] Delete remote feature branch (or confirm GitHub shows deleted)
- [ ] Sync local master:
  - [ ] `git switch master`
  - [ ] `git pull --ff-only`
  - [ ] `git fetch --prune`
- [ ] Confirm clean tree again

### Security quick checks (when relevant)
- [ ] `.\scripts\jp-doctor.ps1`
- [ ] If anything fails: fix first failure only, rerun

### Restore points (keep at least 24h of safety)
- [ ] Keep a dated known-green restore point (tag or note)
- [ ] Don’t overwrite “latest green” without a dated restore point

## Commands
- Show reminder (script): `pwsh -File .\scripts\jp-housekeeping.ps1`
- Merge helper (script): `pwsh -File .\scripts\jp-merge-pr.ps1 -PrNumber <n>`
