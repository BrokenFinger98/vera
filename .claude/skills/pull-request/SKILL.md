---
name: pull-request
description: Push the branch, create the GitHub PR with the Evidence template filled from real command output, wait for checks, and squash-merge with branch deletion when green. Use when /finish-task has recorded evidence.
disable-model-invocation: true
---

# Pull request (GitHub, squash only)

## Pre-flight
1. On a work branch with commits ahead of `origin/main`.
2. `.harness/state/progress.md` updated in this branch — else stop and update.
3. `docs/llm-wiki/` changed in this branch, or a `Wiki-Skip: <reason>` trailer exists — else run /wiki-ingest first.
4. `git -C <root> push -u origin <branch>`. If the pre-push gate blocks, read its message: guards are fail-closed (fix the code), the wiki gate accepts the trailer.

## Body (from `.github/PULL_REQUEST_TEMPLATE.md`)
- What / Why from the issue.
- Evidence: paste **real** output — last 30 lines of `./scripts/check.sh` and `./scripts/itest.sh`, `git diff --stat origin/main...HEAD`, reviewer/critic findings with disposition.
- Rollback line. `Closes #<n>` (n from the branch name).
- Labels: `test-change` if any file under `src/test|itest|archTest` changed.

## Create and merge
1. `gh pr create --fill-first --body-file <tmp> [--label test-change]`
2. `gh pr checks --watch` until all required checks pass; if `claude-review` requests changes, address blocking items, push, re-watch.
3. Ask the owner for the design review (the five items on the PR template's "Owner design review" line). On approval: `gh pr merge --squash --delete-branch`.
4. `git -C <root> switch main && git -C <root> pull --ff-only`.
