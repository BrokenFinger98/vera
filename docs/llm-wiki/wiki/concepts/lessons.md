---
type: concept
project: vera
tags: [harness, self-improvement, lessons]
created: 2026-09-30
updated: 2026-10-02
sources: []
---

# Lessons (counted)

Format and promotion rule: see `docs/llm-wiki/CLAUDE.md` → "lessons.md format". Entries are added by `/finish-task`.
`count ≥ 3` → the weekly `harness-improve` routine opens a proposal (a PR, or an issue for `.claude/rules|hooks`) and marks the entry `proposed`. Promoted or dropped entries move below the line.

## Open

### vacuous-fixture-pass
count: 1 · tickets: #5 · first: 2026-10-02 · last: 2026-10-02 · status: open
what: guard fixtures passed without exercising their case (an unknown git flag; a same-second cherry-pick that recreated the original commit, so no merge happened); only mutants exposed them
fix: fixtures assert the history shape they rely on (e.g. HEAD has two parents), and a new guard ships with mutants that each must fail a fixture

### orca-branch-name
count: 1 · tickets: #5 · first: 2026-10-02 · last: 2026-10-02 · status: open
what: Orca named the worktree branch `BrokenFinger98/harness-5-…`; gate events read the ticket from `<type>/<n>-<slug>`, so they carried no ticket until the branch was renamed by hand
fix: /ticket step 5 renames the branch right after `orca worktree create`; log-gate-event.sh warns when the branch does not match `<type>/<n>-<slug>`

### ubuntu-awk-check-is-manual
count: 1 · tickets: #5 · first: 2026-10-02 · last: 2026-10-02 · status: open
what: proving guards.sh on Ubuntu (mawk, gawk) took a hand-built Docker run: apt failed on DNS until `--dns 1.1.1.1`, and installing gawk silently switched `awk` away from mawk
fix: run scripts/test-hooks.sh in CI on ubuntu-latest once with mawk and once with gawk (the deferred "test-hooks.sh in CI" ticket)

---

## Promoted / dropped
