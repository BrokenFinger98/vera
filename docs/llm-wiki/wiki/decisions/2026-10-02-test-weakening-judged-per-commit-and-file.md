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
For a merge: (a) ours + theirs − base per file; (b) `git merge-file` per file, pairing renames ourselves; (c) the merge `git merge-tree` makes of the two parents, judged like a commit's parent.
## Decision
Option 3, merges by (c); a file merge-tree leaves conflicted counts as ours + theirs − base, each version rebuilt whole from the zdiff3 markers. A test source is a `.kt`/`.java` file under `src/{test,itest,archTest}/{kotlin,java}/`. A POSIX awk scanner blanks comments (nested in Kotlin), strings and raw strings (their Kotlin templates stay code), char literals and backtick names other than plain identifiers; reads annotations in any spelling (`@ X`, `@[X Y]`, `@field:X`, `@org.junit…X`, a backtick name, split over lines); and, reading the file twice, follows the Kotlin aliases it declares anywhere (aliasing a skip marker counts as one). It counts assertions (`assert…(`, `.check(`, `.verify(`), test cases (`@Test`, `@ParameterizedTest`, `@RepeatedTest`, `@TestFactory`, `@TestTemplate`, `@ArchTest`) and skip markers (`@Disabled…`, `@Enabled…`, `@Ignore`, `assume…(`). A commit that lowers a file's assertions or test cases, adds a skip marker (a new test included), deletes a test source or renames it out of the test sources is refused (`assertion-decrease`, `test-case-decrease`, `test-disabled`, `deleted-test-file`) unless its own message has a line `Test-Change: <reason>`. A merge may drop a test source only where one side deleted it (a modify/delete conflict). Octopus merges and paths holding a tab or newline exit 2. Refines guard 2 of [[decisions/2026-09-30-scenarios-and-gates-not-ritual-tdd]].
## Rationale
Per commit and per file ends offsetting and borrowed trailers; counting code only ends commenting-out. `/pull-request` updates branches with `git merge origin/main`, so merges are routine. (a) counts a change both parents carry (a stacked branch) twice; (b) mis-paired a rename on one side with a rewrite on the other, both ways; (c) reuses git's own merge, renames included, and the critic's stacked, rename and evil-merge cases pass or fail as they should. The scanner lives inside `guards.sh` because the CI `guards` job runs one copied file.
## Accepted costs
- Fail-closed false positives that need the trailer: splitting a test file, merging two assertions, a new test with a skip marker, a Java-to-Kotlin conversion or a rename too dissimilar for rename detection (read as a deletion), reverting a test added earlier in the branch, a rename/delete conflict resolved by deleting.
- A later commit does not cure an earlier one: reword or squash before pushing.
- Not seen: count-preserving weakening (new expected value, looser matcher, longer time budget, fewer `@ValueSource` values, a skip marker moved to a wider scope or given another condition) — REVIEW.md must-check 3; indirection across files (an `assume…` helper, a meta-annotation, a typealias declared elsewhere); a Kotlin typealias or `@[…]` split over lines (ktfmt joins them and spotlessCheck enforces ktfmt); a test moved to a directory Gradle does not build; a Java unicode escape that javac reads as `//`; build switches (`enabled = false`, test filters) — the harness-owned-paths ticket. Comparing executed and skipped tests from the JUnit XML reports of base and head in CI would close most of these.
- `git merge-tree` writes unreachable objects to the repository (gc prunes them); in-tree `.gitattributes` are ignored for that merge.
## Outcome
Measured 2026-10-02: `scripts/test-hooks.sh` 125 PASS on macOS (bash 3.2, BSD awk 20200816); on Ubuntu 26.04 (bash 5.3) 124 PASS with mawk and with gawk, the one failure being the existing >100 KB `jq --arg` test (Linux caps one argument at 128 KiB). Eighteen mutants of `guards.sh` each fail a fixture. Two critic rounds' reproductions (spelling, alias and backtick bypasses, conflicted stacked merges, KDoc conflicts, the rename evil merge, raw-string templates, CRLF markers, a tab in a path) now behave as stated. Over the 58 pre-squash Phase 0-A commits the check refuses one, `9f0640f`, which deleted an ArchUnit rule without a trailer.
