# JP Recovery System (Plan)

Goal: You can lose Chat context, OneDrive state, or even the whole machine and still recover quickly.

## Restore points (two types)
1) LATEST_GREEN (moving baseline): last known merged green commit.
2) DATED snapshots: timestamped restore points retained for rollback.

## Rebuild-from-zero
A single script should:
- verify toolchain (install guidance if missing)
- clone/fetch repo
- validate environment
- run verify + doctor
- confirm CI parity

## Non-goals
- We do not polish UI or build product features until recovery is reliable.
