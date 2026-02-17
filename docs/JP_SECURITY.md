# JP Engine Security

This repo uses a small set of repeatable, local guardrails to prevent leaks and keep the workflow professional.
Everything here is designed to be fast, safe, deterministic, and runnable from PowerShell.

---

## Golden Rules

1. Never scan outside the repo root
   - Always run security tools from: `C:\Dev\JP_ENGINE\jp-engine`
   - Do not point scanners at broad folders like `C:\Users\lsphi\...` (you’ll hit permission noise, locked caches, and unrelated files).

2. Nothing secret-ish goes into git
   - No API keys, tokens, passwords, private certs, `.env` with real values, etc.
   - Use example templates (`.env.example`) and local-only overrides.

3. Guardrails must be in-repo
   - If ChatGPT memory gets messy or a session goes sideways, the repo itself must bring us back.

---

## Core guardrails (Practical)

- Keep scripts safe-by-default:
  - refuse placeholder writes
  - refuse wrong-directory operations (PWD gate)
  - prefer `-LiteralPath`
  - stop on error (`$ErrorActionPreference = 'Stop'`)
- Prefer small changes with a one-track CI loop:
  - run CI
  - inspect only the first failure
  - apply the smallest fix
  - commit/push
  - rerun

---

## Daily Safety Loop (local)

### Resume Gate (start of session)
- `.\scripts\jp-resume.ps1` (if present) should run verify + show status

### Verify (fast validation)
- `.\scripts\jp-verify.ps1` (if present)

This should confirm:
- repo root + branch
- toolchain presence (as defined in `docs/JP_TOOLCHAIN.md`)
- line-ending/attributes notes (if you enforce them)
- any local analyzers you’ve chosen to wire in later

### Pre-commit hooks (if used)
If this repo uses `pre-commit`:

Install (one time per clone):
- `pre-commit install`

Run manually:
- `pre-commit run --all-files`

---

## Secret Scanning

### 1) Pre-commit secrets checks
If configured, rely on pre-commit to catch obvious issues on commit.

### 2) Gitleaks (repo-only scope)

Install (Windows):
- `winget install -e --id Gitleaks.Gitleaks`

Run from repo root:
- `gitleaks detect --source . --no-git --redact`

Notes:
- `--source .` keeps scope inside repo root.
- `--no-git` scans the working tree only (fast). Use regular `gitleaks detect` to scan history too.
- `--redact` prevents printing full secret strings into the console/logs.

Optional: SARIF report output (recommended for a “pro” workflow)
- `gitleaks detect --source . --no-git --redact --report-format sarif --report-path .\_SECURITY\gitleaks.sarif`

If you do this, keep `_SECURITY/` ignored so reports don’t clutter commits.

---

## Repo hygiene controls

### .gitignore expectations (recommended)
Keep these out of git:
- `.env`
- `*.key`, `*.pfx`, `*.pem` (unless explicitly intended and public)
- build artifacts (`dist/`, `build/`, `.next/`, etc.)
- local scanner outputs (`_SECURITY/`)

### Line endings
We prefer stable line endings across machines. If you enforce this:
- use `.gitattributes`
- have `jp-verify.ps1` warn when something is off

(We saw a Git warning about LF → CRLF on `docs/JP_SECURITY.md`. That’s not an emergency; we’ll handle line-ending policy later when we expand CI surface.)

---

## Active Project (PowerShell)

- `Start-WorkJP` sets the active project and jumps to the JP repo.
- New PowerShell windows auto-start in the active repo.
- `Stop-Work` clears the active project (full shutdown).
- `Reload-Profile` re-imports your profile into the current session if commands are missing.

---

## If something feels off

If you suspect drift or a leak risk:

1. `Set-Location -LiteralPath C:\Dev\JP_ENGINE\jp-engine`
2. `git status`
3. `.\scripts\jp-verify.ps1` (if present)
4. `pre-commit run --all-files` (if configured)
5. `gitleaks detect --source . --no-git --redact`

If any step fails, stop and fix before continuing work.
