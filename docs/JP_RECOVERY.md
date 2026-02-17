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
Default canonical artifact root (do not use Desktop):
- C:\Dev\_JP_ENGINE\RECOVERY\

(We enforce this in scripts via guardrails.)

## Restore points
A restore point is a dated, self-contained snapshot that lets you get back to a known-good state.

### What a restore point contains
- zip of repo working tree (clean, no node_modules, no artifacts)
- a manifest (timestamp, git commit, branch, machine, notes)
- optionally: toolchain snapshot output

### Restore point retention
- Keep dated restore points
- Maintain a moving pointer: LATEST_GREEN
- Never overwrite dated points

## Rebuild-from-zero (fresh machine)
Goal: a brand-new Windows machine can be productive quickly.

### Steps (high level)
1) Install toolchain (per JP_TOOLCHAIN.md)
2) Clone repo
3) Run scripts/jp-verify.ps1
4) Run scripts/jp-rebuild-from-zero.ps1 (guided bootstrap)
5) Create first restore point

## SOP alignment
- One-track CI loop: run -> fix first red step only -> commit -> rerun
- Script changes are full-file rewrites (paste discipline)
- Artifacts must never drift outside the canonical artifact root
