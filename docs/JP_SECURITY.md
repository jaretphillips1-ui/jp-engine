# JP Engine Security

This repo uses a small set of **repeatable, local guardrails** to prevent leaks and keep the workflow professional.
Everything here is designed to be **fast, safe, deterministic**, and runnable from PowerShell.

---

## Golden Rules

1. **Never scan outside the repo root**
   - Always run security tools from: `C:\Dev\JP_ENGINE\jp-engine`
   - Do **not** point scanners at `C:\Users\lsphi\...` or other broad folders (you will hit GPU cache locks, permission noise, and unrelated files).

2. **Nothing “secret-ish” goes into git**
   - No API keys, tokens, passwords, private certs, `.env` with real values, etc.
   - Use example templates (`.env.example`) and local-only overrides.

3. **Guardrails must be in-repo**
   - If ChatGPT memory gets messy or a session goes sideways, the repo itself must bring us back to full tilt.

---

## Daily Safety Loop (local)

### Resume Gate (start of session)

Run:

- `.\scripts\jp-resume.ps1` (this should run verify + show status)

### Verify (fast validation)

Run:

- `.\scripts\jp-verify.ps1`

This confirms:
- repo root + branch
- toolchain present (git/gh/openssl/node/npm/vercel/netlify/pipx/pre-commit)
- line-ending guardrails
- PSScriptAnalyzer (if installed)

### Pre-commit hooks

We use `pre-commit` locally.

Install (one time per clone):

- `pre-commit install`

Run manually:

- `pre-commit run --all-files`

---

## Secret Scanning

### 1) pre-commit “Detect hardcoded secrets”
This is already in our pre-commit config and should run on commits.

### 2) Gitleaks (repo-only scope)

Install:

- `winget install -e --id Gitleaks.Gitleaks`

Run from repo root:

- `gitleaks detect --source . --no-git --redact`

Notes:
- `--source .` keeps scope inside repo root.
- `--no-git` scans the working tree only (fast).
  Use regular `gitleaks detect` if you want to scan git history too.
- `--redact` prevents printing full secret strings into the console/logs.

Optional: report output (recommended for “pro” workflow)

- `gitleaks detect --source . --no-git --redact --report-format sarif --report-path .\_SECURITY\gitleaks.sarif`

(If you use this, keep `_SECURITY/` in `.gitignore` so reports don’t clutter commits.)

---

## Repo Hygiene Controls

### .gitignore expectations (recommended)
Keep these out of git:
- `.env`
- `*.key`, `*.pfx`, `*.pem` (unless explicitly intended and public)
- build artifacts (`dist/`, `build/`, `.next/`, etc.)
- local scanner outputs (`_SECURITY/`)

### Line endings
We use `.gitattributes` to keep line endings stable across machines.
`jp-verify.ps1` prints current settings and warns when something is off.

---

## “JP Doctor” concept (future)

Goal: one command that runs a safe “health + security” bundle, repo-only:

- runs `.\scripts\jp-verify.ps1`
- runs `pre-commit run --all-files`
- runs `gitleaks detect` (repo-only)
- prints a clean summary + exit code

This is intentionally:
- fast
- deterministic
- no scanning outside repo root
- no noisy false positives

---

## If Something Feels Off

If you suspect the system state is drifting:

1. `Set-Location "C:\Dev\JP_ENGINE\jp-engine"`
2. `git status`
3. `.\scripts\jp-verify.ps1`
4. `pre-commit run --all-files`
5. `gitleaks detect --source . --no-git --redact`

If any step fails, stop and fix **before** continuing work.
