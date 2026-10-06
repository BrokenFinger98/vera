# Index — Vera wiki catalogue

Read this first. Every page is registered here; entries start with a date so merges sort.

## Decisions
- 2026-09-30 [[decisions/2026-09-30-public-english-repository]] — D1: public GitHub repo, English committed artifacts, README.ko.md only Korean twin
- 2026-09-30 [[decisions/2026-09-30-stack-baseline-sept-2026]] — D2: Java 25, Boot 4.1, Modulith 2.1, PG 18, jOOQ 3.21, Valkey 9, Testcontainers 2
- 2026-09-30 [[decisions/2026-09-30-kotlin-2-3-until-toolchain-catches-up]] — D3: Kotlin 2.3.21 (Boot 4.1 BOM) until Boot 4.2; detekt 2.0 alpha since 2026-10-01
- 2026-09-30 [[decisions/2026-09-30-scenarios-and-gates-not-ritual-tdd]] — D4: EARS scenarios + gates + arch tests + scoped mutation instead of enforced TDD
- 2026-09-30 [[decisions/2026-09-30-orca-worktrees-for-parallel-work]] — D5: Orca, 2–3 worktrees, one owned module per ticket
- 2026-09-30 [[decisions/2026-09-30-graaljs-on-stock-jdk-first]] — D6: GraalJS js-community on stock JDK (interpreter), benchmark before GraalVM CE
- 2026-09-30 [[decisions/2026-09-30-stop-hook-gate-trial]] — D7: Stop-hook check.sh gate as a one-month trial with firing audit
- 2026-09-30 [[decisions/2026-09-30-no-graph-runtime-for-pipeline]] — D8: no graph orchestration runtime; dependency-aware tickets + three saved fan-out workflows
- 2026-09-30 [[decisions/2026-09-30-human-approved-self-improvement-loop]] — D9: events → counted lessons → weekly proposal PRs → monthly prune PRs, owner merges
- 2026-10-02 [[decisions/2026-10-02-test-weakening-judged-per-commit-and-file]] — D10: guards judge each commit and test source (assertions, test cases, skip markers, deletions; merges via git merge-file); the trailer sits on the weakening commit

## Concepts
- 2026-09-30 [[concepts/lessons]] — counted lessons feeding the self-improvement loop (open / proposed / promoted / dropped)

## Sources
- 2026-09-30 [[sources/2026-09-30-phase0-design-and-research]] — origin chat + 2026-09 methodology research → spec + D1–D9
