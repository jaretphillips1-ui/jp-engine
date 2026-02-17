# JP Engine — Blueprint (Layer Model + Roadmap)

JP Engine is intentionally designed to serve four roles:
A) universal build system, B) disciplined workflow engine, C) public/open-source candidate, D) private developer OS.

We achieve “all four” by separating CORE from PERSONAL and keeping templates modular.

## Layer model

### Layer 1 — Foundation (Stability + Recovery)
Non-negotiable:
- deterministic repo gating
- CI green = safe to merge
- restore points (dated + latest green)
- rebuild-from-zero procedure
- documented recovery + SOP discipline

### Layer 2 — Build Acceleration
- scaffolds/templates
- standardized app bootstrap
- one-button flows
- feature module stubs (auth/payments/weather/etc.)

### Layer 3 — Product Expansion
- deploy targets
- paid features
- integrations
- UI screens & flows
- perf + UX iteration

### Layer 4 — Hardening & Sophistication
- drift detection / tamper detection
- event log heartbeat
- broader OS matrix
- release strategy + versioning

## Core rule
CORE never depends on PERSONAL.
PERSONAL may depend on CORE.

## Current posture
We prioritize Layer 1 completion before heavy Layer 2+ expansion.
