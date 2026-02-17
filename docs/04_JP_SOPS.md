# JP SOPs (Guardrails + Discipline)

## Golden rules
- Always gate to the correct repo root before any operation.
- When patching scripts: rewrite full file top-to-bottom; avoid partial edits.
- After writing files: run git diff immediately.
- One-track CI loop: fix only first failing step; smallest change possible.

## Paste discipline
- Provide blocks labeled “PASTE INTO POWERSHELL” only when safe.
- Do not paste YAML or other file formats into PowerShell.
- Avoid GitHub Actions expressions like ${{ }} inside PowerShell paste blocks unless treated as literal strings.

## Recovery discipline
- Maintain multiple restore points.
- Keep a “latest green baseline” that does not get overwritten by experiments.
