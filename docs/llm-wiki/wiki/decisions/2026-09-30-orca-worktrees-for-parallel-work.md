---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, parallelism, worktrees]
created: 2026-09-30
updated: 2026-09-30
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

# D5 — Orca worktrees, two to three in parallel, one owned module per ticket

## Context
Parallel agents collide on shared files; 2026 practice caps at 4–8 worktrees per developer before review becomes the bottleneck. The owner already uses Orca (used on two earlier projects).
## Options considered
Orca · Claude Code `--worktree`/`/batch` only · sequential only.
## Decision
Orca: one ticket = one worktree = one terminal, at most three concurrent. Tickets declare an owned module; shared files (root build, migrations, common) change only in solo tickets. Merge sequentially with `check.sh` between merges. Flyway versions are timestamps.
## Rationale
Reuses installed tooling and experience; module ownership is the single-writer principle that prevents merge hell.
## Accepted costs
Orca is UI-configured only; worktrees share the Gradle daemon and can produce false Stop-gate failures (hook skips when another build runs).
## Outcome
`.worktreeinclude`; `start-task` checks for blockers before work begins.
