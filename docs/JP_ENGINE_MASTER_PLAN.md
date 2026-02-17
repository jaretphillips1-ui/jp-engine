# JP Engine Master Plan v1.0 (Merged + Reassessed)

## Phase A — Rails First (must be first)
Deliverables:
- Doctrine docs (done)
- Repo skeleton (done)
- JP Save / JP Verify / JP Break scripts (next)
Exit criteria:
- We can Save → Verify → Rollback Proof reliably.

## Phase B — Harvest the free pro-grade pieces
- Gitleaks CI
- PSScriptAnalyzer CI (optionally SARIF later)

## Phase C — Gate Core
- Green/Red pacing
- Expected output checks
- Window keep/close rules
- Transcript option

## Phase D — Doctor + Safe Auto-Repair v1
- jp-doctor (diagnose + propose)
- jp-fix (safe fixes only)
- 3 fails → read-pack trigger

## Phase E — Read-Pack Generator
- One-shot context bundles to eliminate guessing.

## Phase F — Drift + CI Lock + UI Parity Baseline
- script hash self-check
- core.autocrlf drift check
- heartbeat
- boring/stable CI
- UI parity baseline for FGS + EFSP

## Phase G — Scheduled Verify (report-first)
- scheduled checks
- auto-fix only for safe items
- never hides integrity failures
