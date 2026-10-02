---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, harness, self-improvement]
created: 2026-09-30
updated: 2026-10-02
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

# D9 — Closed self-improvement loop with human-approved promotion

## Context
The cycle every 2026 source ends with — remember/compound/improve — was missing: lessons were recorded but nothing counted them or turned them into rules, and nothing removed rules that never fired. Autonomous self-improvement loops overstate their gains (arXiv 2607.25152: 56% of claimed improvements changed nothing).
## Options considered
Manual only · fully autonomous rule edits · machine-proposed, human-merged.
## Decision
Capture: hooks and guards append every gate firing, through `log-gate-event.sh`, to an untracked log shared by all worktrees (`<git common dir>/vera-events.jsonl`); `/finish-task` and `/pull-request` publish its new lines to `.harness/events.jsonl` with `scripts/publish-events.sh`, and the agent logs critic and ci events itself (CI does not parse its checks). Distill: `/finish-task` writes a counted retro to `lessons.md`. Promote: weekly `harness-improve` opens one proposal per lesson with count ≥ 3 or rule fired ≥ 3 times (unique events, probes excluded), proposing exactly one rule/hook/lint/test change: a PR, or one issue carrying the patch when the change touches `.claude/rules` or `.claude/hooks` (protected paths that CI cannot write, with no bypass). Prune: a monthly pass proposes deleting rules with zero firings in 30 days. Measure: the weekly metrics line, appended in promote mode. Only the owner merges.
## Rationale
Evidence-gated promotion mirrors Anthropic's "bugs → CLAUDE.md" loop and OpenAI's garbage-collection agents while keeping the owner as the judge of every rule change.
## Accepted costs
One weekly review of proposals; the committed events log only grows (nothing prunes it); events from a ticket's last push reach it with the next ticket, because they are published before the merge approval.
## Outcome
`.harness/events.jsonl`, `scripts/publish-events.sh`, `lessons.md`, `.github/workflows/harness-improve.yml`, `.harness/metrics.md`.
