# JP Engine Notes

This file captures operational lessons learned and “why” decisions, so CI/dev behavior is explainable later.

## CI detached HEAD (smoke)

- **When:** 2026-02-18 21:30:22-04:00
- **Baseline:** CI detached HEAD (smoke) — merged in 0f3c6d5ac6f01896741130443975a548b11f5952

**What happened**
- GitHub Actions can run the repo in **detached HEAD** for certain contexts.
- git branch --show-current may return empty/null in CI.
- Smoke summary code must **not** call .Trim() on a null branch string.

**Fix pattern**
Prefer, in order:
1) git branch --show-current
2) git symbolic-ref --short -q HEAD
3) fallback label: DETACHED_HEAD

**Gotcha**
- pre-commit nd-of-file-fixer may modify files during git commit, causing the first commit attempt to fail.
  - Solution: stage again and retry the commit.
