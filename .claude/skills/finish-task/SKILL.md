---
name: finish-task
description: Close the loop on a ticket once the code is done and check.sh and itest.sh are green — collect evidence, run the independent review, record progress and the counted retro, commit those records, then hand off to /pull-request. Not for work in progress.
---

# Finish task

`<root>` = `git rev-parse --show-toplevel` of this session (your worktree, not the main checkout).

## 1. Evidence (paste real output later into the PR)
- `./scripts/check.sh` → keep the last 30 lines and the `RESULT` line.
- `./scripts/itest.sh` → same.
- `git -C <root> diff --stat origin/main...HEAD` → owned module plus the always-allowed files only? size ≤400 lines? If not, stop and split.

## 2. Independent review
Run `/code-review` for a general pass, then the `critic` subagent: have it apply REVIEW.md's must-check list to `git -C <root> diff origin/main...HEAD`, then attack with: "Do not trust the implementer's claims. Verify by running. Attack: boundary values, null/empty, concurrency, ACL bypass, migration reversibility. Report gaps affecting correctness or requirements only." Fix blocking findings and log each one with `<root>/.claude/hooks/log-gate-event.sh critic <rule> <one line>`; list the rest with disposition.

## 3. Progress
Append to `.harness/state/progress.md` above `<!-- ARCHIVE -->`: `## [YYYY-MM-DD] #<n> <title> ✅` + commits + evidence lines.

## 4. Retro → counted lessons (self-improvement loop, spec §10.1)
Answer three questions in one line each and merge into `docs/llm-wiki/wiki/concepts/lessons.md`:
- What was slow? · What did the agent get wrong? · Which rule or check was missing?
If an equivalent lesson exists, increment its `count:` and add the ticket number; otherwise add a new entry with `count: 1`.
A lesson with `count: 3` is due for promotion (weekly routine opens the PR) — do not promote it yourself.

## 5. Decisions
Any decision made → ADR via /wiki-ingest (push gate checks). None → step 6 adds the `Wiki-Skip: no decision` trailer.

## 6. Commit the records
Stage `.harness/state/progress.md`, `docs/llm-wiki/wiki/concepts/lessons.md`, `.harness/events.jsonl` and any ADR, then run /gated-commit; with no decision, put `Wiki-Skip: no decision` in that commit's body.

## 7. Hand off
Run /pull-request.
