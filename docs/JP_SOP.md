# JP Engine SOP (Canonical)

## One True Paths
- Repo (canonical): $Repo = 'C:\Users\lsphi\OneDrive\AI_Workspace\JP_ENGINE\jp-engine'
- Save root (canonical): $SaveRoot = 'C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST'
- Desktop folder: **Always resolve via** [Environment]::GetFolderPath('Desktop') (never assume C:\Users\<name>\Desktop)

## Golden Rules
- Only run **clean "Shell" blocks** (start with & { and end with }).
- Never paste terminal prompts/transcripts into PowerShell.
- Read-first, then write. For file changes: prefer full-file rewrites via PowerShell Set-Content.
- One-track CI loop: if red, fix **only the first failure**, smallest change, commit/push, rerun.
- Saves must be deterministic: zips and notes go to the canonical SaveRoot; Desktop gets only the single mirror zip.

## Startup (Resume)
1. Set-Location to repo path (hard gate).
2. git status and git log -1 --oneline.
3. Run scripts\jp-verify.ps1 if present.

## Work
- Create branch when needed; keep working tree clean between logical steps.
- Avoid polishing into a corner: expand feature surface first, harden later.

## Save (Full Save + Retention)
- Run scripts\jp-save.ps1:
  - stage copy excluding .git,
ode_modules, build/cache dirs
  - zip **explicit item list** (no wildcard with -LiteralPath)
  - write checkpoint note
  - copy Desktop mirror to resolved Desktop folder
- Retention policy (recommended baseline):
  - Keep all timestamped zips from last **24 hours**
  - Keep newest **20** timestamped zips overall
  - Move older extras to an Archive folder (never delete)

## Shutdown (Handoff)
- Run scripts\jp-shutdown.ps1:
  - run audit
  - run save
  - write handoff report into SaveRoot
  - confirm repo clean + branch + head

## Desktop Cleanup (Safe)
- Never delete. Only quarantine moves.
- Use scripts\jp-clean-desktop.ps1 -WhatIf first.
- Always protect: JP_ENGINE_LATEST.zip, any JP folders/shortcuts, anything you rely on.
