# JP Engine Guidebook

This is the single “ops manual” for JP Engine. If anything feels unclear or repetitive, update this file first.

## Table of Contents

1. Start Gate (opening a safe session)
2. Verify (read-only health check)
3. Save (proof run outputs + desktop mirror)
4. Shutdown / Handoff
5. Recovery Playbook (common failures + fixes)
6. Rules of Engagement (SOP essentials)
7. Script Map (what lives where)

---

## 1) Start Gate (opening a safe session)

**Canonical repo (this machine):**
- `C:\Users\lsphi\OneDrive\AI_Workspace\JP_ENGINE\jp-engine`

**Canonical SaveRoot:**
- `C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST`

**Desktop (must be resolved, OneDrive redirected):**
- Always resolve via: `[Environment]::GetFolderPath('Desktop')`

**Start steps (minimum):**
- `Set-Location` to the canonical repo root
- `git status`
- `git log -1 --oneline`

---

## 2) Verify (read-only)

Run:
- `scripts\jp-verify.ps1`

Verify is **read-only** and must:
- show repo path + branch
- validate key tools (git/gh/node/npm/etc.)
- run PSScriptAnalyzer
- exit PASS/FAIL clearly

**OneDrive rule:**
- No warning when running in the canonical repo.
- Warn only if you are in a *non-canonical* OneDrive path.

---

## 3) Save (proof run outputs + desktop mirror)

A proof run save produces:
- `JP_ENGINE_LATEST.zip`
- timestamped zip (e.g., `JP_ENGINE_YYYYMMDD_HHMMSS.zip`)
- `JP_ENGINE_LATEST_CHECKPOINT.txt`
- handoff report `JP_HANDOFF_*.txt`
- audit report `JP_AUDIT_PROOF_*.txt`
- desktop mirror: `Desktop\JP_ENGINE_LATEST.zip`

SaveRoot target:
- `C:\Users\lsphi\OneDrive\AI_Workspace\_SAVES\JP_ENGINE\LATEST`

---

## 4) Shutdown / Handoff

At shutdown, ensure:
- `scripts\jp-verify.ps1` is green
- repo is clean (`git status --porcelain` empty)
- save artifacts written to SaveRoot + desktop mirror updated
- write a brief handoff note (what changed + next step)

---

## 5) Recovery Playbook (common failures + fixes)

### A) safecrlf blocks staging (CRLF would be replaced by LF)

Symptom:
- `fatal: CRLF would be replaced by LF in <file>`

Fix (temporary local-only):
- `git config --local core.safecrlf warn`
- `git add ...`
- restore original `core.safecrlf` value afterwards

### B) pre-commit auto-stash output

Pre-commit may stash/restore. Do not assume a commit happened.
Always confirm with:
- `git status --porcelain`
- `git log -1 --oneline`

### C) “No commits between …” on PR create

Hard stop:
- branch has no diffs vs base
- verify with `git log base..branch` and `git diff base..branch`

### D) Never paste transcripts into PowerShell

Do not paste:
- `PS C:\...>`
- `>>`
- tool output / diffs / warnings

Only paste clean Shell blocks that start with `& {` and end with `}`.

---

## 6) Rules of Engagement (SOP essentials)

- One-track loop: change → diff → commit → push → rerun verify.
- Prefer exact-match guarded patches; if drift/conflict, rewrite whole file.
- After edits: always `git diff`, then stage/commit.
- Never assume Desktop path; always resolve it.
- Keep a “latest green” restore point and at least one dated restore.

---

## 7) Script Map

- `scripts\jp-validate.ps1` — environment + repo validation gate (must PASS).
- `scripts\jp-verify.ps1` — read-only health check (must PASS).
- Save scripts — produce LATEST + timestamp + checkpoint + reports + desktop mirror.
