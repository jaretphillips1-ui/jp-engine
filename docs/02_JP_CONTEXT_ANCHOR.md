# JP Context Anchor (Read this first if Chat resets)

## What JP Engine is
JP Engine is a safety-first workflow + recovery platform that makes building apps fast and recoverable.

## Prime directives
- Big-picture-first: expand surface area before deep polish/hardening.
- Always maintain restore points (dated + “latest green baseline”).
- Smallest change loop: run CI, fix only first failing step, commit/push, rerun.
- Prefer one-button PowerShell flows; minimize typing.
- Paste discipline: never paste terminal prompts/transcripts. Paste only clean blocks.

## Canonical flows
- Start work: scripts\jp-start-work.ps1
- Publish/merge: scripts\jp-publish-work.ps1
- Verify: scripts\jp-verify.ps1
- Doctor: scripts\jp-doctor.ps1

## Where the truth lives
- docs/00_JP_INDEX.md (front door)
- docs/01_JP_BLUEPRINT.md
- docs/03_JP_RECOVERY_SYSTEM.md
- docs/04_JP_SOPS.md

## Current focus
Finish Layer 1 Recovery System (restore points + rebuild-from-zero) and make it the default muscle memory.
