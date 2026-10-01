---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, harness, self-improvement]
created: 2026-09-30
updated: 2026-09-30
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

# D9 — Closed self-improvement loop with human-approved promotion

## Context
The cycle every 2026 source ends with — remember/compound/improve — was missing: lessons were recorded but nothing counted them or turned them into rules, and nothing removed rules that never fired. Autonomous self-improvement loops overstate their gains (arXiv 2607.25152: 56% of claimed improvements changed nothing).
## Options considered
Manual only · fully autonomous rule edits · machine-proposed, human-merged.
## Decision
Capture: `log-gate-event.sh` appends every gate firing to `.harness/events.jsonl`. Distill: `/finish-task` writes a counted retro to `lessons.md`. Promote: weekly `harness-improve` opens one PR per lesson with count ≥ 3 or rule fired ≥ 3 times, proposing exactly one rule/hook/lint/test change. Prune: monthly PR deleting rules with zero firings in 30 days. Measure: weekly metrics line. Only the owner merges.
## Rationale
Evidence-gated promotion mirrors Anthropic's "bugs → CLAUDE.md" loop and OpenAI's garbage-collection agents while keeping the owner as the judge of every rule change.
## Accepted costs
One weekly review of proposal PRs; events log grows (pruned monthly).
## Outcome
`.harness/events.jsonl`, `lessons.md`, `.github/workflows/harness-improve.yml`, `.harness/metrics.md`.
