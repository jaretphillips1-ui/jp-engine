# JP Engine — Travel Mode Readiness

Goal: be able to open a fresh session on another machine (MacBook / iPad via remote/terminal) and reliably reach:
**Tripwire → Validate → Verify → (optional SaveProof)** with minimal friction.

This doc is intentionally practical and short.

---

## 1) Minimum “it works anywhere” workflow

From repo root:

- Start/resume: `scripts/jp-start.ps1`
- Health check (safe during active work): `scripts/jp-health.ps1`
- Proof save (requires clean): `scripts/jp-health.ps1 -SaveProof -Note "travel proof save"`
- Full shutdown: `scripts/jp-shutdown.ps1`

If any of the above fails, do **not** patch randomly. Follow:
- `docs/JP_GUIDEBOOK.md` → Recovery Playbook
- rerun verify after the smallest change

---

## 2) New machine bootstrap checklist

### A) Get the repo
- Clone the repo (or pull latest) onto the machine.
- Confirm you are in the correct folder (repo root) before running scripts.

### B) Install/verify core tools
The verify script expects these to exist (or it will clearly fail):

- PowerShell (pwsh)
- git
- gh (GitHub CLI)
- node + npm
- openssl
- pre-commit
- pipx (for pre-commit install path scenarios)
- optionally: vercel + netlify CLI (if used in this project)

Run `scripts/jp-verify.ps1` and let it tell you what’s missing.

### C) GitHub authentication (gh)
- `gh auth status`
- If not authenticated: `gh auth login`
- Ensure the repo remote uses the expected GitHub account.

### D) Pre-commit hooks
If pre-commit hooks aren’t installed yet:
- `pre-commit install`

Then run:
- `scripts/jp-verify.ps1`

---

## 3) iPad/iPhone access strategy (choose one)

Option 1 — Remote into the Windows dev box (fastest)
- Use your preferred remote desktop method.
- Run the standard scripts locally on the dev box.

Option 2 — Run directly on MacBook
- Install tools (brew, etc.)
- Clone repo
- Run `scripts/jp-verify.ps1` and follow failures.

Option 3 — “Read-only” from iPad
- Use remote shell or remote desktop.
- Run `scripts/jp-health.ps1` to confirm status.
- Avoid editing/committing from iPad unless the workflow is proven safe.

---

## 4) Definition of “Travel Ready”

You are Travel Ready when, on the target setup, you can run:

1) `scripts/jp-health.ps1` → PASS
2) clean-tree proof: `scripts/jp-health.ps1 -SaveProof -Note "travel ready proof"` → PASS and save artifacts created

---
