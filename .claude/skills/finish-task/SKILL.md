---
name: finish-task
description: Close the loop on a ticket — collect evidence, run the adversarial reviewer, update progress, write the counted retro into lessons.md, and hand off to /pull-request. Use when the code is done and the gates are green.
disable-model-invocation: true
---

# Finish task

## 1. Evidence (paste real output later into the PR)
- `./scripts/check.sh` → keep the last 30 lines and the `RESULT` line.
- `./scripts/itest.sh :<module>` → same.
- `git -C <root> diff --stat origin/main...HEAD` → owned module only? size ≤400 lines? If not, stop and split.

## 2. Independent review
Run `/code-review`, then the `critic` subagent with: "Do not trust the implementer's claims. Verify by running. Attack: boundary values, null/empty, concurrency, ACL bypass, migration reversibility. Report gaps affecting correctness or requirements only." Fix blocking findings; list the rest with disposition.

## 3. Progress
Append to `.harness/state/progress.md` above `<!-- ARCHIVE -->`: `## [YYYY-MM-DD] #<n> <title> ✅` + commits + evidence lines.

## 4. Retro → counted lessons (self-improvement loop, spec §10.1)
Answer three questions in one line each and merge into `docs/llm-wiki/wiki/concepts/lessons.md`:
- What was slow? · What did the agent get wrong? · Which rule or check was missing?
If an equivalent lesson exists, increment its `count:` and add the ticket number; otherwise add a new entry with `count: 1`.
A lesson with `count: 3` is due for promotion (weekly routine opens the PR) — do not promote it yourself.

## 5. Decisions
Any decision made → ADR via /wiki-ingest (push gate checks). None → plan to use `Wiki-Skip: no decision` trailer.

## 6. Hand off
Run /pull-request.
