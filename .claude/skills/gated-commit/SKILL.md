---
name: gated-commit
description: Stage-aware Conventional Commit in English with no AI attribution. Runs the project gates (test pair, English-only, trailers) before the preview. Use for every commit in this repository.
disable-model-invocation: true
---

# Gated commit (project)

## Rules
- English only. Conventional Commits `<type>(<scope>): <subject>` — imperative, ≤50 chars, no period; body ≤72 cols says what and why.
- **No AI attribution** — no `Co-Authored-By`, no Claude/AI trailer of any kind.
- Preview first; commit only after "yes" (skip with `--quick`).

## Gates before the preview
1. `git diff --cached --name-only` empty → tell the user to stage, stop.
2. New production `.kt` without a test `.kt` in the same PR scope → warn loudly (push gate will enforce).
3. Test files changed with fewer assertions → require trailer `Test-Change: <reason>` in the body.
4. Files under `db/migration/` modified (not added) → refuse (immutable migrations).
5. Non-ASCII Hangul in staged files other than `README.ko.md` → refuse (English artifacts).
6. Run `./scripts/check.sh`; paste its `RESULT` line into the preview.

## Process
1. Analyse the staged diff, pick type/scope/subject.
2. Show: message, `RESULT` line, `git diff --cached --stat`.
3. On yes: `git -C <root> commit -F <tmpfile>`.
