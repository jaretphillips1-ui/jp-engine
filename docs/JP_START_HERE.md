# JP Engine — Start Here

This repo is intentionally **Shell-first** and **guardrail-heavy**.

If you're resuming work (or starting a new PR), do these in order:

## 1) Always confirm you're in the right repo
Repo root should be:
- `C:\dev\JP_ENGINE\jp-engine`

Quick sanity:
- `git status -sb`
- `git log -1 --oneline --decorate`

## 2) Run Doctor / Verify (baseline safety)
Primary commands:
- `pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\jp-doctor.ps1`
- `pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\jp-verify.ps1`

Expected:
- verify PASS
- repo clean
- scanners OK (repo-scoped)

## 3) Work model (SOP)
### Big-picture-first
- Expand platform/feature surface before deep hardening.
- Keep guardrails, but avoid heavyweight automation that can “false succeed.”

### Shell-only
- Prefer one-shot PowerShell scriptblocks.
- Avoid manual editor work.
- When writing files: full-file rewrite with guards + `git diff` immediately.

### Hard-stop rules
- If a PR tool says “No commits between …” → STOP.
  - Run: `git log master..HEAD` and `git diff master..HEAD`
  - Fix the branch before proceeding.

## 4) Green baseline tags (restore points)
After merges and a clean smoke:
- `pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\jp-tag-green.ps1 -RunSmoke`

Baseline tags look like:
- `baseline/green-YYYYMMDD-HHMM`

List recent:
- `git tag --list "baseline/green-*" --sort=-creatordate | Select-Object -First 10`

## 5) Handoff template
Use:
- `docs/JP_HANDOFF_TEMPLATE.md`

Keep the handoff factual:
- branch, PR link, what changed, what’s next.
