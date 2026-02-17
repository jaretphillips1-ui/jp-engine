# JP Engine Recovery System (Canonical)

JP Engine recovery is designed to survive:
- chat resets
- machine loss
- repo corruption
- accidental deletions
- dependency/toolchain drift

## Canonical roots

### Repo root (source of truth)
This git repo is the permanent truth for:
- docs (context, SOPs, blueprint)
- scripts (repeatable workflows)

### External artifact root (restore points, exports)
Default canonical artifact root (do not use Desktop / OneDrive roots):
- C:\Dev\_JP_ENGINE\RECOVERY\

(Enforced by scripts via guardrails.)

## Restore points

A restore point is a dated, self-contained snapshot that lets you get back to a known-good state.

### What a restore point contains
- repo.zip of the repo working tree (clean; excludes heavy/volatile folders like node_modules, .git, .next, etc.)
- manifest.json (timestamp, git commit, branch, machine, notes)
- LATEST_GREEN pointer folder containing the latest known-good restore point artifacts

### Restore point retention
- Keep dated restore points under:
  C:\Dev\_JP_ENGINE\RECOVERY\RESTORE_POINTS\
- Maintain a moving pointer:
  C:\Dev\_JP_ENGINE\RECOVERY\LATEST_GREEN\
- Never overwrite dated restore points

## Operational commands (proven)

### Dry run (no writes)
From repo root:
- .\scripts\jp-restore-point.ps1 -WhatIf -Note "dry run"

### Real restore point (writes to artifact root)
From repo root (requires clean working tree):
- .\scripts\jp-restore-point.ps1 -Note "reason/phase note"

### Rebuild-from-zero (guided bootstrap)
From repo root:
- .\scripts\jp-rebuild-from-zero.ps1

Optional: create restore point after verify (clean tree required):
- .\scripts\jp-rebuild-from-zero.ps1 -CreateRestorePoint -RestoreNote "initial restore point"

## Rebuild-from-zero (fresh machine)

Goal: a brand-new Windows machine can be productive quickly.

### Steps (high level)
1) Install toolchain (see JP_TOOLCHAIN.md)
2) Clone repo
3) Run scripts/jp-verify.ps1
4) Run scripts/jp-rebuild-from-zero.ps1 (guided bootstrap)
5) Create first restore point

## SOP alignment
- One-track CI loop: run -> fix first red step only -> commit -> rerun
- Script changes are full-file rewrites (paste discipline)
- Artifacts must never drift outside the canonical artifact root
