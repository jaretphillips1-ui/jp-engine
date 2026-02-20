# JP Engine SOP: Publish, Green Check, Full Save, Handoff

Last updated: 2026-02-20 07:57:49

## Goals
- Prevent accidental publishing from `master`
- Prevent “no commits between …” PR loops
- Ensure CI is truly green before we declare a checkpoint
- Produce a verified, hash-checked save artifact for handoff/restore

## Core rules
1. **LIVE publish must refuse on `master`.**
   - `scripts/jp-publish-work.ps1 -Live` should only run from `work/*`.
2. **DRYRUN is allowed on `master`** for preview, but must not mutate.
3. **No-commit PR loop is forbidden.**
   - Refuse PR create when ahead vs base is 0 (guards in publish workflow).
4. **Use gh CLI only** (no manual browser typing for PR title/body).

## Green confirmation (CI)
When you need a “real checkpoint”:
- Confirm CI is green for the current `HEAD` SHA on `master` (don’t assume).
- Note: `gh run list --json` fields are limited; use `url` / `databaseId` / `headSha` etc.
- If runs are still in progress, wait or re-check; do not tag/save as “green” early.

## Full save (canonical)
Preferred:
- Run `scripts/jp-save.ps1`
  - It should run verify, then produce:
    - `..._SAVES\JP_ENGINE\LATEST\JP_ENGINE_LATEST.zip`
    - timestamped zip
    - checkpoint txt
    - SHA256 txt

Integrity:
- Verify the SHA256 file matches the zip(s).
- Our SHA file format is **two-line per entry**:
  - zip path line
  - SHA256 line on the next non-empty line

## Pre-commit / line endings gotchas

### Encoding / quote safety (PowerShell doc writes)
- Prefer ASCII punctuation when writing docs from PowerShell:
  - Use " instead of smart quotes
  - Use ' instead of curly apostrophes
  - Use ... instead of Unicode ellipsis
- Use SINGLE-QUOTED here-strings (@' ... '@) and insert variables via -f formatting.
- Avoid pasted Unicode punctuation to prevent mojibake artifacts (example: mojibake like "ΓÇ£").
- If pre-commit modifies files (e.g., end-of-file-fixer), re-stage and commit again.
- If Git warns about CRLF/LF:
  - It's a warning; only change settings if Git blocks staging/commit.
  - If blocked by safecrlf: temporarily set `git config --local core.safecrlf warn`, stage, then restore.

## Handoff checklist
- Repo clean: `git status --porcelain` empty
- CI green confirmed for `HEAD` SHA
- `scripts/jp-save.ps1` completed successfully
- Save artifacts exist in `..._SAVES\JP_ENGINE\LATEST` (latest + timestamped + checkpoint + sha256)
