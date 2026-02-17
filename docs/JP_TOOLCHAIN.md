# JP Engine Toolchain (Canonical)

This document is the single source of truth for the JP Engine toolchain:
- what tools are required
- what versions are recommended
- how to install them
- how to verify they are working

## Principles
- Prefer stable, pinned versions where possible.
- Prefer scripted verification over “it worked once”.
- Keep this aligned with scripts/jp-verify.ps1 (and CI).

## Required on Windows (baseline)
- PowerShell 7.x
- Git
- Node.js (LTS recommended)
- npm (bundled with Node)
- Python 3.x (optional unless a feature requires it)
- 7-Zip (optional but useful)

## Required on CI / cross-platform (baseline)
- Git
- Node.js + npm
- gitleaks (pinned version; do NOT rely on "latest" URLs)

## Verification commands (examples)
(Keep these high-signal and simple; scripts should automate them.)
- git --version
- node --version
- npm --version
- gitleaks version

## Install notes
Fill in install steps per OS as we formalize the rebuild-from-zero path.

### Windows (suggested)
- Use winget/choco where appropriate (prefer reproducible).
- If CI pins a tool version, match that here.

### Ubuntu (CI)
- Use apt for OS deps
- Pin 3rd-party tools (like gitleaks) to specific versions.
