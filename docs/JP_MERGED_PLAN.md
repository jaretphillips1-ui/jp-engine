# JP Engine — Merged Plan (JP + FGS + EFSP)

## What’s true now (milestone reached)
**JP ONLINE PRIMARY BACKUP LIVE (GitHub Releases)**
- JP Save creates local artifacts (OneDrive save root)
- JP Save Publish creates a GitHub Release and uploads assets
- OneDrive is local snapshot + redundancy; GitHub Release is durable online primary

## Percent readiness (engineering estimate)
- JP Engine overall completeness: ~80%
- Safe readiness to build with JP workflow:
  - FGS: ~70%
  - EFSP: ~60%

## “Safe to resume production” definition
We resume real app work when:
1) Two consecutive PR cycles are green end-to-end INCLUDING publish-to-Release
2) One restore is proven (download Release asset, unpack, verify)
3) No manual hero steps required (one-button Shell blocks)

## Execution order (to get over the hump without creating a mess)

### 1) Keep JP Engine stable (done tonight)
- Online primary backup via GitHub Releases is working
- Local snapshot via OneDrive remains in place

### 2) Dry run before touching production apps
Milestone: **DRY RUN GREEN (FGS-style runner)**
- Prove JP workflow drops into target repo cleanly:
  gate -> branch -> PR -> CI -> merge -> overall-check/save -> publish release

### 3) FGS first (low-risk pilot)
Milestone: **FGS Pilot Change shipped via JP workflow**
- Small safe change (docs/minor UI/non-data impact)
- Run full JP loop to confirm friction is low

### 4) EFSP next (feature pilot)
Milestones:
- **DRY RUN GREEN (EFSP-style runner)**
- **EFSP Camera Module Pilot shipped via JP workflow**
- Then: leaderboard + points rules tied to camera/photo capture

## Milestones (in order)
1. DONE: JP ONLINE PRIMARY BACKUP LIVE (Release publishing works)
2. NEXT: DRY RUN GREEN (FGS-style runner)
3. NEXT: FGS Pilot Change shipped via JP workflow
4. NEXT: DRY RUN GREEN (EFSP-style runner)
5. NEXT: EFSP Camera Module Pilot shipped via JP workflow
6. NEXT: EFSP Leaderboard + Points rules integrated
