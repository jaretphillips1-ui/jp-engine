# JP Engine — Editing SOP (Shell-first, no guessing)

## Goals
- You do **zero** manual editing in Notepad/WordPad/VS Code for fix loops.
- Changes are **fast** and **safe**: no guessing, no drift, no accidental corruption.
- Every edit is reproducible and verified immediately.

## Non-negotiables
1) **Read before write**
   - Before any file write, capture the current text:
     - Whole file (preferred when small), OR
     - Anchored section around the intended change.
   - If we have not read the current text, we do not write.

2) **Patch-by-default**
   - Use Shell-only automation to apply the smallest safe change.
   - Patch must be anchored and deterministic.

3) **Exact-match guardrails**
   - A targeted patch must match **exactly once**:
     - 0 matches ⇒ wrong anchor / file drift ⇒ STOP and re-read or rewrite.
     - >1 matches ⇒ ambiguous ⇒ STOP and rewrite a larger block or whole file.

4) **Immediate verification**
   - After writing, run `git diff` immediately.
   - If diff is not exactly what we intended ⇒ STOP (no commit/push).

5) **Patch cap (anti-drift)**
   - Max **3 patches per file per session**.
   - After that, rewrite the function/block or the whole file to re-anchor.

## When to do a full rewrite immediately
- Merge conflicts / conflict markers
- Ambiguous patch targets (multiple matches)
- Large refactors, structural edits, or cascading changes
- The file has drifted and we can’t prove a single safe patch

## Output/flow conventions
- Provide “PASTE INTO POWERSHELL” blocks for all actions.
- Never require manual editor work.
- Use repo gates (`git rev-parse`, expected root, file existence checks).
- Prefer single-shot scriptblocks that STOP before writing if guards fail.

## Minimal workflow (every time)
1) Read file (or anchored section)
2) Apply patch (or rewrite)
3) `git diff`
4) Commit/push only after diff is correct
