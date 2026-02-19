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

## Work
- Make changes
- `git status --porcelain`
- `git diff`
- `git add -A`
- `git commit -m "<message>"`
- `git push -u origin <branch>`
- `gh pr create ...` (or your helper)

## Shutdown (Handoff)
Run:
- `pwsh -File scripts\jp-shutdown.ps1 -Next "…" `
- add `-AllowDirty` only if intentional

This prints a paste-ready handover block for a new chat.
