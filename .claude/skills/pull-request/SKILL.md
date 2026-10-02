---
name: pull-request
description: Push the branch, open the GitHub PR with real evidence, drive the required checks green, and squash-merge only after the owner approves the design review and the merge. Use after /finish-task has committed its records.
---

# Pull request (GitHub, squash only)

`<root>` = `git rev-parse --show-toplevel` of this session (your worktree, not the main checkout).

## Pre-flight
1. On a work branch with commits ahead of `origin/main`.
2. `.harness/state/progress.md` updated in this branch — else stop and update.
3. The branch changes a file under `docs/llm-wiki/wiki/` other than `concepts/lessons.md` (an ADR via /wiki-ingest), or carries a `Wiki-Skip: <reason>` trailer — used only when no decision was made.
4. `git -C <root> push -u origin <branch>`. If the pre-push gate blocks, read its message: guards are fail-closed (fix the code), the wiki gate accepts the trailer.

## Body (from `.github/PULL_REQUEST_TEMPLATE.md`)
- What / Why from the issue.
- Evidence: paste **real** output — last 30 lines of `./scripts/check.sh` and `./scripts/itest.sh`, `git diff --stat origin/main...HEAD`, reviewer/critic findings with disposition.
- Rollback line. `Closes #<n>` (n from the branch name).
- Labels: `test-change` if any file under `src/test|itest|archTest` changed.

## Create and merge
1. `gh pr create --fill-first --body-file <tmp> [--label test-change]`
2. `gh pr checks --watch` until all required checks pass. Log each failing required check with `<root>/.claude/hooks/log-gate-event.sh ci <check> <run url>`, fix, push.
   `claude-review` runs on opened/ready_for_review only: after pushing a fix, re-trigger it with `gh pr ready --undo && gh pr ready`. Fix its blocking items and resolve each review thread you addressed (`gh api graphql`, mutation `resolveReviewThread`; conversation resolution is required).
3. Behind or conflicting with `origin/main`: `git -C <root> merge origin/main` — never rebase and force push (blocked) — keep both sides' entries in state files, re-run `./scripts/check.sh`, push.
4. Ask the owner for the design review (the five items on the PR template's "Owner design review" line) and for explicit merge approval. Merge only after both.
5. Merge. In a worktree: `gh pr merge --squash` (the repo deletes merged branches), then from the main checkout (`<main>` = the first path of `git worktree list`) run `git -C <main> pull --ff-only` and remove the worktree with `orca worktree rm --worktree branch:<branch>` or `git -C <main> worktree remove <path>`.
   Without a worktree: `gh pr merge --squash --delete-branch`, then `git -C <root> switch main && git -C <root> pull --ff-only`.
