# Progress

Entries start with the date. Everything above the archive marker (the HTML comment on the last line) is injected into every session; move old entries below it.

## [2026-09-30] Phase 0-A — repository, toolchain, PoCs ✅
- Plan: `docs/superpowers/plans/2026-09-30-phase0-a-repo-and-build.md`
- Initial commit `295ffd1` (bootstrap pushed straight to main before the PR flow; never squashed, so the hash stays valid)
- Gradle 9.7.1 · Kotlin 2.3.21 · Boot 4.1.1 · Modulith 2.1.1 · PG 18 Testcontainers · detekt 2.0.0-alpha.6 / ktfmt / ArchUnit / Kover
- Evidence (CI run on main @ 3dd682d, check, itest, coverage and build all green: https://github.com/BrokenFinger98/vera/actions/runs/36801975950): `RESULT check exit=0 seconds=53` · `RESULT itest exit=0 seconds=71` · 37 unit, 5 archTest and 4 itest tests, 0 failed
- PoC 1 transactional DDL: pass (a rolled-back CREATE TABLE leaves no table, a committed one is visible)
- PoC 2 GraalJS sandbox: pass (js-isolate-community: 200; host access, IO, statement limit and wall clock enforced; no per-script heap cap on the stock JDK)
- PoC 3 detekt/ArchUnit on Kotlin 2.3: finding, resolved — detekt 1.23.8 (Kotlin 2.0.21 compiler) crashed on JDK 25 and could not read Kotlin 2.3 metadata, so PR #3 moved to 2.0.0-alpha.6 (same 12 findings on the smoke sample); Konsist 0.17.3 has the same compiler, so ArchUnit 1.5.1 is used
- PoC 4 kotlin-lsp: pass 2026-10-01 (first attempt blocked by outdated Command Line Tools; the plugin loads the server only at session start, so restart the session after installing it)
- PR #1 (merged 2026-09-30T14:12Z) `test: give size-handling sandbox tests a CI-safe time budget` — the bootstrap push had failed CI: two sandbox tests hit the 2 s wall clock on `ubuntu-latest`
- PR #2 (merged 2026-09-30T23:34Z) `docs: record PoC 4 (Kotlin LSP) as passing`
- PR #3 (merged 2026-10-01T01:37Z) `build: migrate to detekt 2.0.0-alpha.6 and run the Gradle daemon on JDK 25`

## [2026-10-02] Phase 0-B — harness, gates, wiki, self-improvement loop ✅ (closed 2026-10-06, #8)
- Plan: `docs/superpowers/plans/2026-09-30-phase0-b-harness.md`
- Closed: PR #4 squash-merged 2026-10-02T03:50Z · `CLAUDE_CODE_OAUTH_TOKEN` set 2026-10-02 · Task 13 protection on `main` (PRs only, no force pushes, six required checks: check, itest, coverage, build, label-required-when-tests-change, guards; squash only, merged branches deleted) · acceptance run #5 → PR #6 squash-merged 2026-10-06T00:18Z through the whole loop · non-probe events published to `.harness/events.jsonl`: stop-gate/check.sh-failed, pre-push-guard/assertion-decrease, wiki-gate/blocked-no-wiki-change, ci/label-required-when-tests-change (plus two critic events) · first scheduled harness-improve run 2026-10-05 succeeded and opened metrics PR #7 (merged 2026-10-06T00:36Z; it counted no non-probe events, so the first non-probe metrics line is due with the next weekly run)
- Status below is the 2026-10-02 snapshot, kept as written
- Exists: CLAUDE.md (102 lines) · 5 rules · 8 skills · 4 hooks + the `log-gate-event.sh` writer and `scripts/publish-events.sh` · pre-push guards (9 checks + wiki gate), hardened after the critic and final reviews · CI workflows: `ci.yml`, `test-guard.yml` (the `test-change` label job and the `guards` job, which runs the base commit's `guards.sh`), `claude-review.yml`, `harness-improve.yml` · 3 saved fan-out workflows · ADRs D1–D9 in `docs/llm-wiki/wiki/decisions/`
- Events: gate firings go to the shared untracked log in the git common dir and are published to `.harness/events.jsonl`; 4 probe lines (`"probe":true`: stop-gate 1, block-danger 1, pre-push-guard 2 from the negative probe) are published so far
- Pending: the owner installs the Claude GitHub App and sets `CLAUDE_CODE_OAUTH_TOKEN` (before the acceptance run and before the first scheduled `harness-improve` run, Mon 2026-10-05 06:00 KST) · squash-merge PR #4 · Task 13 branch protection · the acceptance run, which is the first deferred harness-hardening ticket through the whole loop (owned area `harness`)
- Deferred hardening tickets: test-weakening detection · harness-owned paths · migration rename/delete · danger-hook false negatives and positives · guard fixtures and `test-hooks.sh` in CI
- Next: Phase 0 ends when that first harness ticket completes the loop and stop-gate, pre-push-guard, wiki-gate and ci events have each been published; Phase 1 ticket 1 via /brainstorming → /ticket (see goal.md) follows

## [2026-10-02] #5 harness: detect test weakening per commit and per file ✅
- guards.sh checks 1–2 judge every commit and test source: fewer assertions or test cases, a new skip marker (any spelling, Kotlin aliases followed) or a deleted or moved-out test needs `Test-Change: <reason>` on that very commit; a merge is judged against the merge `git merge-tree` makes of its parents (ADR D10)
- Evidence: `RESULT check exit=0` · `RESULT itest exit=0` (Gradle up to date: no Kotlin input changed) · `scripts/test-hooks.sh` 125 PASS on macOS, 124 PASS on Ubuntu 26.04 with mawk and with gawk · 18 guards.sh mutants killed · pre-squash Phase 0-A history: one refusal in 58 commits, a true positive
- Review: /code-review (10 findings) and two critic rounds (1 blocking, 2 major, 4 minor; then 1 blocking, 1 major, 2 minor): annotation spellings, aliases and backtick names, conflicted and stacked merges, rename pairing, KDoc conflicts, string templates, CRLF markers and tab paths fixed; the rest are accepted costs in D10 or deferred below
- Acceptance run (plan Task 13 Step 3): stop-gate, pre-push-guard, wiki-gate and ci events forced on this ticket (each blocked, then fixed: a failing unit test at Stop, a commented-out `.check(` at push, a push before the ADR, a test-source change without the `test-change` label on PR #6) and published to `.harness/events.jsonl`; first lessons.md entries
- Found: `scripts/test-hooks.sh` fails one test on Linux (a >100 KB `jq --arg`; one argument is capped at 128 KiB), for the deferred "test-hooks.sh in CI" ticket
- Deferred to the Phase 0 close-out: spec §6 row 2 and `.github/PULL_REQUEST_TEMPLATE.md` still state the old rule; the CLAUDE.md sentence is fixed here (the owner approved the 11th file). Follow-up idea: compare executed and skipped tests from the JUnit XML reports of base and head in CI

## [2026-10-06] #8 docs: close Phase 0 and align spec §6 and the PR template with ADR D10 ✅
- Spec §6 row 2, §7 DoD item 4 and §13 and `.github/PULL_REQUEST_TEMPLATE.md` state the D10 rule: each commit and test source judged, the `Test-Change: <reason>` trailer on that very commit
- Old wording kept as historical records: the Phase 0-B plan, D10's Context and D4's Decision (refined by D10)
- Phase 0-B flipped to ✅; goal.md rewritten for Phase 1 (metadata engine)

<!-- ARCHIVE -->
