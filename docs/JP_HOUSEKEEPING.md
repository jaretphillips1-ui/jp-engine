# JP Engine — Housekeeping Reminder

Use this after merges and before shutdown.

## After merging a PR
- Confirm local master is synced:
  - `git switch master`
  - `git pull --ff-only`
- Confirm clean working tree:
  - `git status --porcelain` (must be empty)
- Confirm the PR head branch is deleted:
  - Remote: deleted by `gh pr merge --delete-branch`
  - Local: delete the feature branch if it still exists

## CI sanity
- For any new workflow/tooling:
  - Verify at least one full green CI run on the merge commit
  - If "no required checks reported", treat it as unknown (use status rollup)

## Security quick checks
- Run `scripts\jp-doctor.ps1` (repo-scoped scanners)
- If anything fails, fix the first failure only, smallest change, rerun

## Backup/restore points (lightweight)
- Prefer keeping at least one known-green reference (tag or note) for the last 24h baseline
- Avoid overwriting the “latest green” marker without a dated restore point

## Commands
- Show reminder (script): `pwsh -File .\scripts\jp-housekeeping.ps1`
