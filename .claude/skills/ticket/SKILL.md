---
name: ticket
description: Create a GitHub issue from the task template (EARS acceptance criteria, owned module, verify commands), then a branch <type>/<n>-<slug> from fresh main. Use when starting any work — the constitution forbids work without an issue.
disable-model-invocation: true
---

# Create issue and branch

Flow: /ticket → branch → /start-task → work → /gated-commit → /finish-task → /pull-request → squash merge.

## Process
1. Ask the type (one question): feat | fix | refactor | test | docs | chore | harness.
2. Draft the body from the task template below. Ask only for what you cannot infer; **Non-goals and Verify must not be empty**.
3. Preview, confirm (Yes / Edit / Cancel).
4. `gh issue create --title "<Type> title" --label task --label <type> --milestone <phase> --body-file <tmp>`
5. `git -C <root> fetch origin main && git -C <root> switch -c <type>/<n>-<slug> origin/main`
   (if the owner uses Orca, print the Orca task-create command instead: one ticket = one worktree.)

## Task template (issue body)
```
## Goal
<one sentence, behaviour change from the user's point of view>

## Context
- Spec: docs/superpowers/specs/<file>#<section> (or "none")
- ADR: <link or "may need one">
- Owned module: :platform:<name> | :apps:itam | :ingestion | :bootstrap  (no edits outside it)
- Blocked by: #<n> (or "none")   Blocks: #<n> (or "none")

## Acceptance criteria (EARS)
- WHEN <condition> THE SYSTEM SHALL <result>
- WHEN <error condition> THE SYSTEM SHALL <error response / log>

## Non-goals
- <what this ticket deliberately does not do>

## Verify
- ./scripts/check.sh
- ./scripts/itest.sh :<module>

## Size guard
≤400 changed lines, ≤10 files. If exceeded: split into stacked PRs and link them here.

## Risks / Rollback
- <migration reversal or "plain revert">
```

## Labels
`task` always; type label; `harness` for gate/hook work; milestone = phase.
