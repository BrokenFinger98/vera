---
name: gated-commit
description: Commit staged changes as an English Conventional Commit with no AI attribution, after the project gates pass (test pair, trailers, immutable migrations, English-only). Use for every commit in this repository; do not run git commit directly.
---

# Gated commit (project)

`<root>` = `git rev-parse --show-toplevel` of this session (your worktree, not the main checkout).

## Rules
- English only. Conventional Commits `<type>(<scope>): <subject>` — imperative, ≤50 chars, no period; body ≤72 cols says what and why.
- **No AI attribution** — no `Co-Authored-By`, no Claude/AI trailer of any kind.
- Show the preview, then commit — no owner confirmation; the gates below replace it.

## Gates before the preview
1. `git diff --cached --name-only` empty → stage the files this commit is about (by path), or stop if there is nothing to commit.
2. New production `.kt` without a test `.kt` in the same PR scope → warn loudly (push gate will enforce).
3. Test files deleted or with fewer assertions → require trailer `Test-Change: <reason>` with the reason in the body; adding tests needs none.
4. Files under `db/migration/` that exist on `origin/main` and are modified → refuse (immutable migrations); a migration added in this branch may still change.
5. Hangul in an added staged line outside `README.ko.md` → refuse (English artifacts). The scan matches guards.sh check 6 (same bytes, jamo included; only added lines, so English edits to a file that already holds Korean pass): `git -C <root> diff --cached --text -U0 -- . ':(exclude)README.ko.md' ':(exclude)docs/research/' | LC_ALL=C command grep -E $'^\\+.*([\xEA-\xED][\x80-\xBF][\x80-\xBF]|\xE3[\x84-\x86][\x80-\xBF]|\xE1[\x84-\x87][\x80-\xBF])'` — any output refuses. Plain `grep` may be ugrep in the agent shell and miss byte patterns.
6. Run `./scripts/check.sh`; paste its `RESULT` line into the preview.

## Process
1. Analyse the staged diff, pick type/scope/subject.
2. Show: message, `RESULT` line, `git diff --cached --stat`.
3. Commit: `git -C <root> commit -F <tmpfile>`.
