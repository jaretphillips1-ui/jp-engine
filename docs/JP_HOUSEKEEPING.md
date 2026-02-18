# JP Housekeeping (Lightweight)

After merging:
- [ ] On default branch (master/main)
- [ ] git pull --ff-only
- [ ] Local feature branch deleted
- [ ] Remote feature branch deleted (or GitHub shows deleted)
- [ ] Working tree clean
- [ ] If behavior changed: update docs/JP_TOOLCHAIN.md (and/or SECURITY/RECOVERY)

## Lessons Learned

- Never `-match` on string arrays (join first, or loop deterministically).
- Always rewrite workflow from HEAD when structural YAML fixes are needed.
- actions/checkout owns its with: block; do not attach checkout with: options to unrelated steps.
