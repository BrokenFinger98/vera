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
- Status: harness on PR #4 (this branch); acceptance run (Plan B Task 13) pending
- CLAUDE.md (100 lines) · 5 rules · 8 skills · 4 hooks + the `log-gate-event.sh` writer · pre-push guards (9 checks + wiki gate; first firings logged: `.harness/events.jsonl` has 4 lines — stop-gate 1, block-danger 1, pre-push-guard 2 from the negative probe) · CI workflows: `ci.yml` only
- Pending: GitHub templates and the `test-guard`, `claude-review` and `harness-improve` workflows (Task 8) · 3 saved fan-out workflows (Task 9)
- ADRs D1–D9 in `docs/llm-wiki/wiki/decisions/`
- Next: Phase 1 ticket 1 via /brainstorming → /ticket (see goal.md), after the acceptance run

<!-- ARCHIVE -->
