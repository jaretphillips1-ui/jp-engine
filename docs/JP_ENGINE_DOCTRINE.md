# JP Engine Doctrine (Hard Rules)

## 1) No Band-Aids Doctrine
If a problem is structural and a clean rewrite is the right move, we **rewrite it cleanly** (with the full file in view).
Patches are allowed only when they are small, surgical, low-risk, and clearly bounded (not masking a broken design).

## 2) Save → Verify → Rollback Proof (Mandatory)
No meaningful change is complete until we can:
- restore the last known good state quickly, and
- prove the current state via verification checks.

Integrity failures are never papered over. We diagnose root cause and fix it correctly.

## 3) Three-Strike Rule (Stop Thrash)
After **3 failed patch attempts**:
1) Stop editing.
2) Run Read-Pack.
3) Decide once: rewrite / rollback / redesign.

## 4) Trigger Phrases (Behavior Contract)
When the user says **"Reset JP Engine"** or **"Handoff JP Engine"**, the assistant must:
- freeze work
- run standardized Save + Verify + Rollback Proof
- produce a paste-ready context pack in the same disciplined format

## 5) One Task at a Time
No side quests. New ideas go into a Parking Lot until the current task is saved + verified.