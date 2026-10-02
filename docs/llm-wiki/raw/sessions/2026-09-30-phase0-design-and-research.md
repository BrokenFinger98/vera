# Phase 0 design and 2026-09 methodology research — English digest

> English digest of the owner's Korean research notes dated 2026-09-30 (not committed, per D1), written 2026-10-01.
> The notes start from the origin design chat (2026-09-30). `[repo: …]` marks a later repository measurement that differs.

## 1. Origin design chat — what it decided
- Insight: customers buy evidence that they control their IT, not software; that value holds only while data matches reality — data rot is the main enemy.
- Problem: customization pollutes the product core and turns it into one-off integration work; answer: confine it to an extension layer, fold recurring needs back into the core, reflect that in contracts.
- ServiceNow model: multi-instance SaaS whose customizations are metadata records, not code, so one platform binary serves every customer and upgrades ship twice a year.
- Scope, four engines: metadata (dynamic tables, fields, queries), rules (business rules, ACL, sandboxed scripts), layering and upgrade (standard vs customer changes, 3-way merge), instance provisioning.
- First app, ITAM: asset (finance, contract) split from CI (operations), lifecycle state machine, identification (serial → MAC → hostname), per-attribute source trust in reconciliation, per-source `last_seen` to find ghost assets.
- Shape: Spring Modulith modular monolith — `platform/{metadata,query,rule,layering}`, `apps/{itam,rack}`, `ingestion`, `control-plane`, `bootstrap`; dependencies point apps → platform only.
- Storage: fixed attributes as real columns, extension attributes as JSONB (generated columns only where an index needs one), dynamic DDL compared later; PostgreSQL chosen for transactional DDL.
- Ingestion: Kafka topic `ci.observations` keyed by the normalized identifier → idempotent reconciliation consumer → uncertain matches go to a needs-confirmation queue.
- Roadmap: 1 metadata engine + dynamic CRUD → 2 inheritance, references, cache → 3 rules, ACL, lifecycle → 3.5 ingestion + reconciliation → 4 layering and upgrade → 5 multi-instance.
- Constraints: public sources only — no proprietary code, designs or customer data; no ServiceNow trademarks, UI or copied code (generic conventions such as the `sys_`/`u_` table prefixes are fine).

## 2. Methodology consensus, 2026-09 (primary sources read on 2026-09-30)
- Anthropic: Claude Code best practices (explore → plan → implement → commit; gate strength prompt < `/goal` < Stop hook < verifier subagent; skip the plan for a one-sentence diff), Effective harnesses for long-running agents (2025-11-26: one feature per session, progress file, tests never edited), AI-native SDLC (2026-07-21: bugs fed back into CLAUDE.md).
- OpenAI: Codex best practices (Goal · Context · Constraints · Done when; lint rules belong in CI), Harness engineering (2026-02: ~1M LOC and 1,500 PRs with no hand-written code; AGENTS.md as a map; linter errors carry fix instructions; doc garbage-collection agents). AGENTS.md standard (Linux Foundation AAIF): the nearest file wins.
- Workflow repos — obra/superpowers, everything-claude-code, gstack, addyosmani/agent-skills, github/spec-kit, EveryInc/compound-engineering, claude-task-master, snarktank/ralph, snarktank/ai-dev-tasks: spec → plan → build → verify → review → ship, several closing with remember / compound / reflect.
- Roots: Harper Reed (2025-02) idea → plan → execute; Karpathy (2026-04-30) design detailed specs with the agent, keep human oversight; andrej-karpathy-skills: think first, simplicity, surgical changes, goal-driven execution.

Common ground across all of them:
1. Separate spec/plan from coding (interview, brainstorm, PRD, plan mode); skip it for small changes.
2. Cut work small and finish one unit at a time (one feature per session, 2–5 minute tasks, one approved subtask at a time).
3. A machine decides completion (tests, build, lint, screenshots); state "done when" up front.
4. Separate writer and reviewer (fresh-context subagent, second session, `/review`).
5. Durable guidance in short files (CLAUDE.md, AGENTS.md), repeated procedures in skills, enforcement in hooks and CI.
6. Keep memory outside the session in files (progress notes, PRDs, recorded solutions).
7. Autonomous loops only where tests define success, with iteration caps and an isolated branch.

## 3. Stack check (2026-09-30)
| Item | Origin chat | Latest | Recommended | Note |
|---|---|---|---|---|
| Java | 21 | 27 (non-LTS); LTS 25 | 25 LTS | Temurin 25 installed locally |
| Kotlin | 2.x | 2.4.20 | 2.3.21 (Boot BOM) | the table first said 2.4.20; stable ktlint/detekt parse only Kotlin 2.0 → D3 |
| Spring Boot / Modulith | 3.x / 1.x | 4.1.1 (4.2 GA due 2026-11) / 2.1.1 | 4.1.x / 2.1.x | Framework 7.0, Jackson 3, starter modules (Flyway needs its starter), `@MockBean` removed, JUnit 6 |
| Gradle | – | 9.8.0 | 9.7.x | the Kotlin Gradle plugin's supported ceiling |
| PostgreSQL | 16 | 18.6 | 18 | async I/O, `uuidv7()`, virtual generated columns; jOOQ OSS supports only the newest major |
| jOOQ | – | 3.21.9 | 3.21.x OSS | believed the Boot BOM held 3.20, so an override [repo: the Boot 4.1.1 BOM manages 3.21.7] |
| Flyway | – | 13.8.1 | BOM (12.4) | Boot 4 needs `spring-boot-starter-flyway` + `flyway-database-postgresql` |
| GraalJS | GraalJS | Polyglot 25.4 | `js-community` 25.x | 25.1+ on a stock JDK runs interpreter-only; isolate artifact checked by PoC 2 |
| Redis | Redis | Redis 8.8 (licences incl. AGPL) / Valkey 9.1 (BSD-3) | Valkey 9 | licence risk for a multi-instance product; compose needs a service-connection label |
| Kafka | – | 4.3.1 / Spring Kafka 4.1 | 4.3 (KRaft) | [repo: the Boot 4.1.1 BOM manages 4.2.1 and compose pins `apache/kafka:4.2.1`] |
| Testcontainers | – | 2.0.5 | 2.0.x | renamed artifacts and packages (`testcontainers-postgresql`, `org.testcontainers.postgresql`) |
| Keycloak / springdoc | – | 26.7.4 / 3.1.1 | 26.7.x / 3.1.x | Keycloak is not auto-detected by Boot's compose support; springdoc follows Boot majors |
| Lint / coverage | – | ktfmt (Spotless 8.10), detekt 2.0.0-alpha.6, Konsist 0.17.3, Kover 0.9.11, Pitest 1.30 | ktfmt + detekt, Kover thresholds, nightly Pitest on core modules | [repo: detekt 2.0 alpha adopted 2026-10-01; ArchUnit 1.5.1 replaced Konsist] |

## 4. Decisions D1–D9 (one ADR each in `wiki/decisions/`)
- D1 Public repository; every committed artifact in English; `README.ko.md` is the only Korean twin.
- D2 Stack: Java 25, Boot 4.1.1, Modulith 2.1.1, Gradle 9.7.1, PostgreSQL 18, jOOQ 3.21.7 and Flyway 12.4 via the BOM, Valkey 9, Kafka 4.2.1, Testcontainers 2.0.5; Keycloak 26.7 and springdoc 3.1 later.
- D3 Kotlin 2.3.21 as the Boot 4.1 BOM manages it; revisit 2.4 with Boot 4.2; detekt 2.0 alpha since 2026-10-01.
- D4 EARS scenarios plus gates (tests ship with code, no assertion loss, Modulith `verify()` + ArchUnit, Kover ≥ 80%, scoped Pitest) instead of enforced TDD.
- D5 Orca worktrees, at most three at once, one owned module per ticket; shared files change only in solo tickets.
- D6 GraalJS `js-community` 25.x on stock Temurin 25 (interpreter only); benchmark in Phase 3 before GraalVM CE.
- D7 Stop-hook `check.sh` gate as a one-month trial; kept only if it blocked a real mistake.
- D8 No graph orchestration runtime; graphs only for ticket dependencies, three saved fan-out workflows and, later, a code graph.
- D9 Gate events → counted lessons → weekly proposal PRs → monthly prune PRs; only the owner merges.
