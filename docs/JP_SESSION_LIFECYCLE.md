# JP Engine Session Lifecycle (v1)

## Startup (Resume)
Run:
- `pwsh -File scripts\jp-resume.ps1`
- or `pwsh -File scripts\jp-resume.ps1 -RunDoctor`

This prints:
- repo + branch (DETACHED_HEAD safe)
- HEAD short hash
- dirty count
- recent commits
- PR link (best-effort)

## Start Work (Create a work branch)
Run:
- `pwsh -File scripts\jp-start-work.ps1 -Slug "<topic>"`
- add `-RunSmoke` if you want a smoke pass up front
- add `-AllowDirty` only if intentional

## Work
- Make changes
- `git status --porcelain`
- `git diff`
- `git add -A`
- `git commit -m "<message>"`
- `git push -u origin <branch>`

## Publish (PR + checks + merge + cleanup)
Run:
- `pwsh -File scripts\jp-publish-work.ps1 -Title "<title>" -Body "<body>"`
- omit `-Title/-Body` to default to last commit subject + a template body
- add `-SkipChecks` only if you are intentionally skipping watch mode

This:
- creates or finds the PR
- sets title/body via gh (no browser typing)
- watches checks (unless skipped)
- squash-merges and deletes the remote branch
- syncs local master and deletes the local work branch

## Shutdown (Handoff)
Run:
- `pwsh -File scripts\jp-shutdown.ps1 -Next "…"`
- add `-AllowDirty` only if intentional

This prints a paste-ready handover block for a new chat.
