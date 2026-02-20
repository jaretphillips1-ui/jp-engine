# AI Reminders — JP Engine

This file is the “always reread” guardrails checklist for JP Engine work sessions.
It is meant to be printed at start/resume so the assistant and user stay aligned.

## Non-negotiables (Shell safety)

- Paste ONLY clean Shell blocks (start with `& {` and end with `}`).
- Never paste transcripts into PowerShell (`PS C:\...>`, `>>`, diffs, warnings, tool output).
- Use one-track loop: change → git diff → stage → commit → push → rerun verify.
- Prefer exact-match guarded patches; if drift/ambiguity/conflict → rewrite whole file/section.
- “2–3 strikes rule”: if we hit the same class of problem repeatedly, stop patching and step back:
  reread guidebook/SOP section, then rewrite cleanly.

## Known friction points (auto-handled)

- `core.safecrlf` may block staging → temporary `core.safecrlf warn` staging fallback.
- pre-commit may modify files (EOF newline) → re-stage and retry commit (two-pass).
- Avoid newline “glue” bugs (`}Require-Cmd`, `Out-Null$branch`) by:
  - keeping clear line boundaries
  - avoiding `-NoNewline` for text files unless explicitly needed
  - using single-quoted here-strings `@' '@` when content includes `$` tokens.

## Blueprint priorities (weekend rails)

1) Lock green baseline and repeatable commit flow (jp-commit helper).
2) Add tripwires to prevent known regressions.
3) Travel Mode readiness (MacBook/iPad/iPhone) before vacation (~4 days).
4) Housekeeping/cleanup as a dedicated block (don’t mix with active patching).
5) Feature building after workflow is calm (“green by default”).

## Canonical paths (this machine)

- Repo: `C:\Users\lsphi\OneDrive\AI_Workspace\JP_ENGINE\jp-engine`
- SaveRoot: `C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST`
- Desktop: resolve via `[Environment]::GetFolderPath('Desktop')`
