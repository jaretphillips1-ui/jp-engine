# JP Engine Workflows Contract

This document defines the “one-button” workflow contracts for JP Engine automation.

**Principles**
- Big-picture-first (avoid polishing into a corner)
- One-button workflows wherever possible
- Full-script rewrites (no partial patches)
- Guardrails before writes
- CI must stay green
- Always gate to repo root
- Keep `master` clean
- PR-only merges
- Post-merge cleanup automated

---

## Housekeeping Reminder (lightweight)

Use this as a quick “did we do the cleanup?” checklist.

- Post-merge cleanup ran (local + remote)
- Remote feature branch deleted (GitHub)
- Local feature branch deleted (optional)
- `master` synced and clean (`git status` empty)
- CI green after merge
- Any “quick fix” notes captured (why + what + where)

---

## Start-JPWork (Start Workflow) — Contract

### Intent
Start a safe feature branch session with a single command, leaving the repo in a ready-to-work state.

### Inputs
- `-BranchName <string>` (optional)
- `-Stash` (optional; if provided, stashes local changes including untracked)
- `-SkipVerify` (optional)
- `-SkipDoctor` (optional)

### Preconditions (Guardrails)
- Must run inside JP Engine repo (detect `.git` + `docs/00_JP_INDEX.md`)
- Must be able to run `git`
- If working tree dirty and `-Stash` not provided → fail with a clear message

### Actions (High-Level)
1. Gate to repo root
2. Ensure clean tree (or stash if `-Stash`)
3. Ensure on `master`
4. Fetch/prune + pull fast-forward only
5. Ensure clean tree again (or stash if `-Stash`)
6. Determine branch name:
   - If `-BranchName` provided: use it
   - Else: default `feat/YYYYMMDD_HHMMSS`
7. Fail if branch exists locally or on origin
8. Create/switch to the new branch
9. Run `scripts/jp-verify.ps1` (unless skipped and if present)
10. Run `scripts/jp-doctor.ps1` (unless skipped and if present)
11. Print READY summary

### Outputs (Guarantees)
- You end on a new feature branch
- Repo is clean after start (unless your verify/doctor creates artifacts, which it should not)
- Verify/doctor ran (unless skipped/missing)
- Failure leaves repo in a safe state (no partial writes; no half-created branch if preventable)

### Failure Modes
- Dirty tree without `-Stash` → fail
- `master` not fast-forwardable → fail (user must resolve)
- Branch name collision → fail (user picks another)
- Verify/doctor fail → fail with exit code non-zero

---

## Publish-JPWork (Publish Workflow) — Contract (Design Only)

### Intent
Publish a feature branch safely:
- create PR
- wait for CI
- squash-merge via PR
- delete remote branch
- optional local cleanup
- sync `master`
- run post-merge cleanup

### Inputs (Proposed)
- `-Title <string>` (optional; PR title)
- `-Body <string>` (optional; PR body)
- `-Draft` (optional)
- `-SkipVerify` (optional)
- `-SkipDoctor` (optional)
- `-SkipWaitChecks` (optional; advanced / last resort)
- `-NoDeleteRemoteBranch` (optional; advanced / last resort)
- `-NoDeleteLocalBranch` (optional)
- `-NoCleanup` (optional; skips jp-post-merge-cleanup)

### Preconditions (Guardrails)
- Must run inside JP Engine repo
- Must be on a **feature branch**, not `master`
- Working tree must be clean (or fail)
- `origin` remote must exist
- `gh` CLI must be available and authenticated
- CI must be green before merge (unless `-SkipWaitChecks`)

### Actions (High-Level)
1. Gate to repo root
2. Assert:
   - current branch != `master`
   - clean working tree
3. (Optional) run verify/doctor before publish (recommended)
4. Push feature branch to origin (set upstream if needed)
5. Create PR (gh):
   - base: `master`
   - head: current branch
   - draft if requested
6. Wait for checks (gh / GitHub API) until green
7. Squash-merge PR (gh) with delete-branch enabled (default)
8. Sync local:
   - checkout `master`
   - fetch/prune
   - pull `--ff-only`
9. Run `scripts/jp-post-merge-cleanup.ps1` (unless `-NoCleanup`)
10. Optionally delete local feature branch
11. Print a clear success summary:
   - PR link
   - merge commit sha (if available)
   - cleanup status

### Outputs (Guarantees)
- If success:
  - PR merged into `master` via squash
  - remote feature branch deleted (default)
  - local `master` synced and clean
  - post-merge cleanup applied (default)
- If failure:
  - no merge occurs unless checks passed and merge step executed
  - clear “next action” guidance printed

### Failure Modes + Recovery
- Checks fail → stop; user fixes branch and re-run Publish-JPWork
- Merge conflict → stop; user resolves via PR update (no direct master pushes)
- `gh` auth missing → stop; user logs in
- Network issues mid-run → safe to re-run (idempotent steps where possible)

---

## Notes on Idempotency

Workflows should be safe to re-run:
- If PR already exists, reuse it (or print link and continue to checks/merge)
- If branch already pushed, don’t treat as error
- If master already synced, no-op

---

## “Next Command” Convention

Every script should end with:
- a short READY / STOP block
- the exact next command(s) to run
- no terminal prompts or transcript text
