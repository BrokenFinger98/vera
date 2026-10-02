---
name: ticket
description: Create a GitHub issue from the task template (EARS acceptance criteria, owned module, verify commands) once the owner approves the preview, then a branch <type>/<n>-<slug> from fresh main. Use when the owner asks for new work and no issue exists yet; the constitution forbids work without an issue. Not for an existing issue (use /start-task).
---

# Create issue and branch

Flow: /ticket → branch → /start-task → work → /gated-commit → /finish-task → /pull-request → squash merge.

`<root>` = `git rev-parse --show-toplevel` of this session (your worktree, not the main checkout).

## Process
1. Ask the type (one question): feat | fix | refactor | test | docs | chore | harness.
2. Draft the body from the task template below. Ask only for what you cannot infer; **Non-goals and Verify must not be empty**.
3. Show the preview; the owner approves it (Yes / Edit / Cancel). Create nothing before a Yes.
4. `gh issue create --title "<Type> title" --label task --label <type> --milestone phase-<n> --body-file <tmp>`
5. `git -C <root> fetch origin main && git -C <root> switch -c <type>/<n>-<slug> origin/main`
   With Orca instead: `orca worktree create --name <type>/<n>-<slug> --base-branch origin/main --issue <n> --agent claude --prompt "/start-task <n>"` (one ticket = one worktree).
   Check with `orca worktree show --worktree issue:<n>` that the branch is exactly `<type>/<n>-<slug>`; the new worktree's agent continues with /start-task and this session's part ends.

## Task template (issue body)
```
## Goal
<one sentence, behaviour change from the user's point of view>

## Context
- Spec: docs/superpowers/specs/<file>#<section> (or "none")
- ADR: <link or "may need one">
- Owned module: <Modulith module, e.g. metadata> (Gradle project `:platform:metadata`) — or `harness` for gate/hook/workflow work — plus the always-allowed files in CLAUDE.md
- Blocked by: #<n> (or "none")   Blocks: #<n> (or "none")

## Acceptance criteria (EARS)
- WHEN <condition> THE SYSTEM SHALL <result>
- WHEN <error condition> THE SYSTEM SHALL <error response / log>

## Non-goals
- <what this ticket deliberately does not do>

## Verify
- ./scripts/check.sh
- ./scripts/itest.sh

## Size guard
≤400 changed lines, ≤10 files. If exceeded: split into stacked PRs and link them here.

## Risks / Rollback
- <migration reversal or "plain revert">
```

## Labels
`task` always; type label; `harness` for gate/hook/workflow work; milestone `phase-<n>`.
