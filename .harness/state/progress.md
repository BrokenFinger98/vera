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

## [2026-10-02] Phase 0-B — harness, gates, wiki, self-improvement loop 🚧
- Plan: `docs/superpowers/plans/2026-09-30-phase0-b-harness.md`
- Status: harness on PR #4 (this branch); the owner's GitHub App and secret, the merge, Task 13 protection and the acceptance run are pending
- Exists: CLAUDE.md (102 lines) · 5 rules · 8 skills · 4 hooks + the `log-gate-event.sh` writer and `scripts/publish-events.sh` · pre-push guards (9 checks + wiki gate), hardened after the critic and final reviews · CI workflows: `ci.yml`, `test-guard.yml` (the `test-change` label job and the `guards` job, which runs the base commit's `guards.sh`), `claude-review.yml`, `harness-improve.yml` · 3 saved fan-out workflows · ADRs D1–D9 in `docs/llm-wiki/wiki/decisions/`
- Events: gate firings go to the shared untracked log in the git common dir and are published to `.harness/events.jsonl`; 4 probe lines (`"probe":true`: stop-gate 1, block-danger 1, pre-push-guard 2 from the negative probe) are published so far
- Pending: the owner installs the Claude GitHub App and sets `CLAUDE_CODE_OAUTH_TOKEN` (before the acceptance run and before the first scheduled `harness-improve` run, Mon 2026-10-05 06:00 KST) · squash-merge PR #4 · Task 13 branch protection · the acceptance run, which is the first deferred harness-hardening ticket through the whole loop (owned area `harness`)
- Deferred hardening tickets: test-weakening detection · harness-owned paths · migration rename/delete · danger-hook false negatives and positives · guard fixtures and `test-hooks.sh` in CI
- Next: Phase 0 ends when that first harness ticket completes the loop and stop-gate, pre-push-guard, wiki-gate and ci events have each been published; Phase 1 ticket 1 via /brainstorming → /ticket (see goal.md) follows

<!-- ARCHIVE -->
