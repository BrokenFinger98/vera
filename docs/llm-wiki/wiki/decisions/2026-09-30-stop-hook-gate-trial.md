---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, harness, gates, trial]
created: 2026-09-30
updated: 2026-09-30
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

# D7 — Stop-hook quality gate as a one-month trial

## Context
The owner deleted a global stop-verify hook in 2026-07 after it never fired; an earlier project's stop gate produced false failures during concurrent Gradle runs. Anthropic's best practices name the Stop hook as the deterministic completion gate.
## Options considered
No Stop gate · Stop gate always · trial with audit.
## Decision
`stop-gate.sh` runs `scripts/check.sh` when source or build files changed, skips only while a Gradle build of the same checkout runs (other worktrees build into their own `build/`), and logs every block and skip. After 30 days: keep if it blocked a real mistake at least once, otherwise delete.
## Rationale
Harness-debt-audit principle: a mechanism earns its place with evidence of firing.
## Accepted costs
Up to ~60 s per session end when sources changed; occasional skipped runs.
## Outcome
Audit due 2026-10-30; evidence in `.harness/events.jsonl` (`gate: stop-gate`).
