---
name: start-task
description: Load a GitHub issue into the session (body, acceptance criteria, owned module), refresh state, and produce a plan or decide to skip planning. Use right after /ticket, or when the owner names an existing issue to work on, before touching any file.
---

# Start task

1. `gh issue view <n> --json title,body,labels,milestone` — read Goal, Context, EARS criteria, Non-goals, Verify, Blocked-by.
   If **Blocked by** names an open issue → stop and report; the ready queue excludes it.
2. Confirm you are on `<type>/<n>-<slug>` and, when parallel, in your own worktree.
3. Re-read `.harness/state/goal.md`, `progress.md` (above the marker), and any ADR the ticket links.
4. Explore the owned module only: existing tests first, then code. Use a subagent for anything wider.
   Before creating files, Read the `.claude/rules/*.md` whose `paths` match them — rules load when a matching file is read, not when one is written.
5. Decide: one-sentence diff → implement directly. Otherwise write a numbered plan (files, tests per EARS line, order), show it, then proceed.
6. Write `.harness/state/goal.md` "Current ticket" block: number, EARS lines, verify commands.
