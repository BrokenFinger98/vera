---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, harness, gates, testing]
created: 2026-10-02
updated: 2026-10-02
sources: []
---

# D10 — Test weakening is judged per commit and per test source

## Context
Guards checks 1–2 looked at deleted `.kt` test files and at the net assertion count of the whole push range, and took a `Test-Change:` trailer on any commit of the range. The PR #4 adversarial review (finding I1) verified the bypasses: `@Disabled` on a class, assertions commented out (comment lines counted), a test renamed to `*.kt.disabled` or moved to `src/test/resources/` (a rename is not a deletion), a deleted ArchUnit rule (`.check(` uncounted), losses in one file offset by trivial gains in another, and a trailer on an earlier, unrelated or merge commit excusing another commit. Criteria: issue #5.
## Options considered
1. Range totals with more patterns — offsetting and borrowed trailers remain.
2. Per file over the whole range — one trailer still excuses every commit.
3. Per commit and per test source, merges included.
For a merge: (a) ours + theirs − base per file, or (b) the file `git merge-file` makes of the parents' changes.
## Decision
Option 3, merges by (b), by (a) where merge-file reports a conflict. A test source is a `.kt`/`.java` file under `src/{test,itest,archTest}/{kotlin,java}/`. A POSIX awk scanner blanks comments (nested in Kotlin), strings, raw strings, char literals and backtick names, then counts assertions (`assert…(`, `.check(`, `.verify(`), test cases (`@Test`, `@ParameterizedTest`, `@RepeatedTest`, `@TestFactory`, `@TestTemplate`, `@ArchTest`) and skip markers (`@Disabled…`, `@Enabled…`, `@Ignore`, `assume…(`). A commit that lowers a file's assertions or test cases, adds a skip marker, deletes a test source or renames it out of the test sources is refused (`assertion-decrease`, `test-case-decrease`, `test-disabled`, `deleted-test-file`) unless its own message carries `Test-Change: <reason>`. A merge that drops a test source no parent deleted is the weakening commit. Refines guard 2 of [[decisions/2026-09-30-scenarios-and-gates-not-ritual-tdd]].
## Rationale
Per commit and per file ends offsetting and borrowed trailers; counting code only ends commenting-out. `/pull-request` updates branches with `git merge origin/main`, so merges are routine, and on a stacked branch both parents carry the same change: (a) counts it twice, merge-file once. The scanner lives inside `guards.sh` because the CI `guards` job runs one copied file.
## Accepted costs
- Fail-closed false positives that need the trailer: splitting a test file, merging two assertions, a Java-to-Kotlin conversion or a rename too dissimilar for git's rename detection (read as a deletion), reverting a test added earlier in the branch, a conflict resolved to one side where (a) applies.
- A later commit does not cure an earlier one: reword or squash before pushing.
- Count-preserving weakening (new expected value, looser matcher, longer time budget, fewer `@ValueSource` values) stays with the critic and claude-review (REVIEW.md must-check 3); build switches (`enabled = false`, test filters) wait for the harness-owned-paths ticket.
- Unusual literals (a string template holding quotes, a Java text block with `\"""`) may confuse the scanner.
## Outcome
Measured 2026-10-02: `scripts/test-hooks.sh` 95 PASS on macOS (bash 3.2, BSD awk 20200816); on Ubuntu 26.04 (bash 5.3) every guard fixture passes with mawk and with gawk (the one failure there is the existing >100 KB `jq --arg` test: Linux caps one argument at 128 KiB). Four mutants of `guards.sh` (no line-comment blanking, no deletion records, a trailer anywhere in the range, arithmetic-only merges) each fail a fixture. Over the 58 pre-squash Phase 0-A commits the check refuses one, `9f0640f`, which deleted an ArchUnit rule without a trailer (2.5 s for the range).
