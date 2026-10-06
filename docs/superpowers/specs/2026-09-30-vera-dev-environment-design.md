# Vera — Development Environment & Methodology Design (Phase 0)

> Status: **Approved (2026-09-30).** D1–D7 confirmed in the decision interview; D8 (no graph runtime) and D9 (self-improvement loop) confirmed in follow-up review the same day. Next: implementation plan via writing-plans.
> Research and evidence: the Korean methodology research (moved to the owner's central wiki, raw/sessions, on
> 2026-10-02; this repository ships English artifacts only).
> Origin: the origin design chat (2026-09-30) that defined Vera.

## 1. Goal

Set up the repository, toolchain, and working process so that **Claude Code writes 100% of Vera's code** while the owner acts only as
product owner, architect, and reviewer. Phase 0 ends when the first harness ticket (a deferred hardening item, owned area `harness`)
completes the loop below and stop-gate, pre-push-guard, wiki-gate and ci events have each been published; Phase 1 ticket 1
(metadata engine: table/field definitions + DDL-transactional table creation) follows.

Vera itself: a metadata-driven enterprise platform engine (ServiceNow-style) — metadata engine, rule engine, layering/upgrade engine,
later multi-instance provisioning — with ITAM as the first domain app. The platform design (engines, storage strategy, roadmap phases 1–5)
comes from the origin chat and is **not** redesigned here; it is restated only where Phase 0 depends on it.

## 2. Decisions (confirmed 2026-09-30)

| # | Decision | Consequence |
|---|---|---|
| D1 | Public GitHub repository, **English committed artifacts** (code, commits, ADRs, CLAUDE.md, wiki). `README.ko.md` is the only Korean twin | Korean research notes live in the owner's central wiki, not in this repo |
| D2 | Stack raised to Sept-2026 baseline: **Java 25 LTS, Spring Boot 4.1.x, Spring Modulith 2.1.x, Gradle 9.7.x, PostgreSQL 18, jOOQ 3.21.7 (OSS, BOM), Flyway (BOM), Valkey 9, Kafka 4.2.1 (BOM, compose image), Testcontainers 2.0.x, Keycloak 26.7, springdoc 3.1, OTel starter** | The origin chat's Java 21 / Boot 3.x / PG 16 / Redis plan is superseded |
| D3 | **Kotlin 2.3.21**, because the Spring Boot 4.1 BOM manages it; revisit Kotlin 2.4 with Boot 4.2 (GA 2026-11). Revised 2026-10-01: the linter no longer holds Kotlin back | ktfmt via Spotless (version-agnostic) + **detekt 2.0.0-alpha.x**, adopted 2026-10-01: 1.23.x (unmaintained since 2025-02, Kotlin 2.0 compiler) cannot run on JDK 25. 2.0 is built on Kotlin 2.4, runs on the JDK 25 daemon and resolves types on every source set. The alpha is pinned exactly, never ships, and reverts in one PR |
| D4 | **Scenarios + gates, not ritual TDD.** EARS acceptance criteria are drafted by the agent in /ticket and approved by the owner; the agent writes tests and code; PRs must ship tests; architecture tests and scoped mutation testing watch quality | The superpowers TDD skill is used only to pick verification scenarios. "No `.kt` without a test in the same PR" is a push/CI gate, not an edit-time rule |
| D5 | Parallel work via **Orca**, 2–3 worktrees max, one owned module per ticket | Shared code (root build files, Flyway migrations, `common`) is changed only in a solo, preceding ticket |
| D6 | GraalJS `js-community` 25.x on the stock JDK (interpreter only) to start; benchmark before considering GraalVM CE as runtime | Rule-engine performance target is deferred to Phase 3 |
| D7 | Stop-hook quality gate runs as a **trial**; after one month audit whether it actually blocked a mistake, and keep or delete accordingly | Follows the owner's harness-debt-audit principle ("evidence of firing, or delete") |
| D8 | **No graph runtime for the pipeline.** "Graph engineering" (2026-07 buzzword) is workflow orchestration renamed; the harness-dev loop is already an implicit research → implement → verify → merge graph. Graphs are used only where they pay: dependency-aware ticket scheduling (adopt), three saved fan-out Workflows (trial), code knowledge graph later (assess) | No LangGraph / Agent Framework / custom orchestrator; no always-on ultracode |
| D9 | **Closed self-improvement loop, human-approved.** Gate firings are logged as events, lessons are counted, a weekly routine proposes rule/hook/lint changes as PRs (issues for `.claude/rules` or `.claude/hooks`), a monthly pass proposes deletions of rules that never fired. Only the owner merges those PRs | Mitigates the measured self-evaluation bias of autonomous loops (arXiv 2607.25152: 56% of "improvements" changed nothing) |

## 3. Operating model

```
Owner (PO · architect · reviewer)            Claude Code
────────────────────────────────────         ──────────────────────────────────────────────
idea, scope, non-functional needs        →   /brainstorming interview → design spec (docs/superpowers/specs)
approve spec                             →   /writing-plans → tasks → GitHub issues (EARS, owned module, verify commands)
approve & prioritise tickets             →   per ticket, in a worktree: Explore → Plan → Implement → Verify
                                             (architect designs · worker implements · tester produces evidence · critic attacks)
review PR for design only                ←   PR with Evidence (command output, `git diff --stat`, reviewer/critic findings)
approve merge                            →   squash merge (progress.md and the wiki were already updated in the branch)
```

- One session = one ticket. Large features: "interview me → SPEC.md → fresh session".
- If the diff can be described in one sentence, skip the plan.
- The human reviews five things only: module-boundary violations, domain-language drift, whether an ADR is needed,
  migration reversibility, PII in logs. Everything else must be caught by machines first.

## 4. Repository layout

```
vera/
├── CLAUDE.md                     # constitution, ≤120 lines: role · immutable decisions · forbidden · gates · flow · state ops
├── AGENTS.md -> CLAUDE.md        # tool-neutral symlink
├── REVIEW.md                     # AI reviewer contract: severities, must-check list, skip paths
├── README.md / README.ko.md
├── settings.gradle.kts · build.gradle.kts · gradle/libs.versions.toml · gradle.properties
├── platform/{metadata,query,rule,layering}/   # Spring Modulith modules (origin-chat structure)
├── apps/itam/  ingestion/  bootstrap/          # control-plane and apps/rack are later phases
├── compose.yml                   # human demo stack (PG 18, Valkey, Kafka, Keycloak). Tests never use it
├── scripts/{check,test,itest,build,guards,publish-events,test-hooks}.sh  # agent entry points; each prints a final status line and exits non-zero on failure
├── docs/
│   ├── superpowers/{specs,plans}/ # brainstorming / writing-plans outputs (existing convention)
│   ├── specs/<module>.md          # living spec per platform module: behaviour, invariants, API contract (spec-anchored; trial)
│   ├── domain/{glossary,context-map}.md
│   ├── development-rules.md       # coding conventions: package layout, value objects, error contract
│   └── llm-wiki/                  # repo-local LLM wiki: CLAUDE.md schema · index.md · log.md · wiki/{decisions,concepts,sources} · raw/ (raw/inbox gitignored)
│       └── wiki/concepts/lessons.md   # counted lessons feeding the self-improvement loop (§10.1)
├── .harness/
│   ├── state/{goal.md (gitignored, personal), progress.md (committed)}
│   ├── events.jsonl               # gate-firing log: published copy of the shared untracked log (append-only, committed, grows; never pruned)
│   └── metrics.md                 # weekly harness metrics (§10.1)
├── .claude/
│   ├── settings.json              # allow/deny/hooks ONLY — never defaultMode (ignored in project files, degrades session to manual)
│   ├── hooks/{inject-state,stop-gate,format,log-gate-event,block-project-danger}.sh
│   ├── rules/{domain,persistence,web,test,migration}.md   # path-scoped via `paths:` frontmatter
│   ├── skills/{ticket,gated-commit,pull-request,start-task,finish-task,wiki-ingest,wiki-query,wiki-lint}/
│   ├── agents/                    # empty: the seven global agents are reused; project-specific overrides only by same filename
│   └── workflows/{audit-consistency,release-review,deep-research}.js   # the only three saved fan-out Workflows (§9)
├── .githooks/pre-push             # guards.sh (fail-closed) + wiki gate (fail-open, `Wiki-Skip:` trailer); both log to the shared event log
├── .worktreeinclude               # .env.local, .harness/state/goal.md
└── .github/{CODEOWNERS, PULL_REQUEST_TEMPLATE.md, ISSUE_TEMPLATE/task.yml,
            workflows/{ci,test-guard,claude-review,harness-improve}.yml}   # harness-improve = weekly/monthly routine (§10.1)
```

Deliberately absent: a directory overview in CLAUDE.md (measured to hurt), `.claude/agents/` duplicates of global agents,
a `decisions.md` state file (ADRs in the wiki are the single authority, as in programmers-tracker), Kubernetes/kind (Phase 5).

## 5. Harness placement (global vs project)

| Layer | Global `~/.claude` (already exists, reused as is) | Project (this repo) |
|---|---|---|
| Skills | harness-dev / harness-review / harness-rca, superpowers plugin | `ticket`, `gated-commit`, `pull-request` (GitHub flow; **distinct names, because a personal skill outranks a same-name project skill** — enterprise > personal > project — so a project `issue` or `commit` would be shadowed by the global GitLab skills), `start-task`, `finish-task`, `wiki-*` (repo wiki target; a skill also outranks a same-name file in `~/.claude/commands/`) |
| Agents | architect, critic, tester, reviewer, evidence-reviewer, scout, worker | none initially |
| Hooks | `block-danger.sh` (dangerous commands + Evidence Gate), `post-edit-check.sh` (secrets), wiki archive hooks | `inject-state.sh` (SessionStart: goal + progress above marker + wiki index; idempotent `core.hooksPath`), `stop-gate.sh` (Stop: `scripts/check.sh` when `src/` is dirty), `format.sh` (PostToolUse Edit/Write on `.kt`: `spotlessApply` for the touched file), `block-project-danger.sh` (PreToolUse Bash: Vera-specific destructive commands and hook bypasses), `log-gate-event.sh` (the one writer of the shared gate-event log) |
| Rules | — | `.claude/rules/*.md` with `paths:` — enforceable summaries of ADRs (MUST / MUST NOT / verify command) |
| Settings | `defaultMode: bypassPermissions`, `model: fable` | allow list for `./gradlew`, `./scripts/*.sh`, read-only git; deny for `.env*` reads; hooks. Because a `Read()` deny rule makes `cd X && <relative read>` prompt even in bypass mode, CLAUDE.md forbids `cd` in Bash (absolute paths, `git -C`) |

Global fix required (owner's harness-debt principle): `harness-dev` skill refers to `.claude/state/`; the real convention is `.harness/state/`. Correct the skill.

Relation to the global company CLAUDE.md: Korean chat replies, English comments/commits, the five core principles and Effective Kotlin
auto-apply all still hold. Only the GitLab workflow (`/issue → /merge-request`) is superseded here, by project skills under distinct names (`/ticket → … → /gated-commit → … → /pull-request`), because a personal skill outranks a same-name project skill (see the Skills row above).

## 6. Gate stack (weakest → strongest)

| # | When | Mechanism | Blocks? | Status |
|---|---|---|---|---|
| 0a | on edit | global `post-edit-check.sh` (secrets) + project `format.sh` | secrets: yes (exit 2) | adopt |
| 0b | on Bash | global `block-danger.sh` + project patterns (`flywayClean`, `compose down -v`, `DROP SCHEMA`, `git checkout -- .`) | yes | adopt |
| 1 | on Stop | `stop-gate.sh` → `scripts/check.sh` = spotlessCheck + detekt + unit tests + archTest, target < 60 s. Guards against `stop_hook_active` loops. Skips (and logs it) while a Gradle build of the same checkout runs, a worker's for instance; the lead re-runs `check.sh` after the worker idles | yes | **trial (D7)** |
| 2 | on push | `.githooks/pre-push`: refuses pushes to `main`; then `guards.sh` fail-closed over what the branch adds since its merge-base with `main` — test weakening judged per commit and per test source (ADR D10; a merge against the merge `git merge-tree` makes of its parents): fewer assertions or test cases, a new skip marker, or a deleted or moved-out test, unless that very commit carries a `Test-Change: <reason>` trailer; new suppressions in any source set (`@Suppress`, `@file:Suppress`, `@SuppressWarnings`, `@[Suppress(...)]`), detekt baseline file, edited merged Flyway migration, newly added Hangul (added lines and commit messages, anywhere except `README.ko.md`), secrets, new production `.kt` without a test change, detekt configured outside the root `build.gradle.kts`; then the wiki gate, fail-open (a change under `docs/llm-wiki/wiki/` other than `concepts/lessons.md`, or a `Wiki-Skip: <reason>` trailer; enforced when the range touches code, harness, CI, `REVIEW.md`, detekt config or the root build); the global Evidence Gate is inert without `docs/evidence-gate.md` | yes | adopt |
| 3 | CI (PR) | `ci.yml`: build · unit · itest (Testcontainers PG 18 / Kafka / Valkey) · `verifyArch` (Modulith `verify()` + ArchUnit) · spotless/detekt · Kover thresholds per module · `test-guard.yml` (label `test-change` required when `src/test` changes, and the `guards` job, which runs the base commit's `scripts/guards.sh` over the PR range) · `claude-review.yml` (claude-code-action, once per PR open or ready-for-review, `REVIEW.md`; advisory, not a required check) | required checks | adopt |
| 4 | merge | branch protection on `main`: PR required but no GitHub approval count (agents open PRs from the owner's account, and GitHub never counts an author's approval; the owner's approval is the design review and the merge in the flow), the checks above required except the advisory `claude-review`, linear history, no force push, enforce for admins, conversation resolution, squash only, auto-delete branch | yes | adopt |
| 5 | human | five-item design review (§3) | yes | adopt |

Every guard's failure output states **what to change and how** — the message is an instruction to the agent, not just a verdict.

## 7. Tickets, specs, Definition of Done

- **Decomposition**: Phase (GitHub milestone) → Epic (label) → Task (one issue = one PR). Size guard: ≤ 400 changed lines, ≤ 10 files (`.harness/events.jsonl` excluded),
  one owned module, at most one new domain concept, half a day. Larger work becomes stacked PRs.
- **Ticket template** (`ISSUE_TEMPLATE/task.yml`): Goal (one sentence) · Context (spec link, ADR link, **owned module**) ·
  Acceptance Criteria in **EARS** (`WHEN <condition> THE SYSTEM SHALL <result>`, including error cases) · Non-goals · **Verify commands** ·
  Size guard · Risks / Rollback. A ticket with empty Non-goals or Verify is not started.
- **Specs**: design specs in `docs/superpowers/specs/` (brainstorming), plans in `docs/superpowers/plans/` (writing-plans),
  living module specs in `docs/specs/<module>.md` updated in the same PR that changes behaviour (trial; drop if unmaintained after Phase 1).
- **Decisions**: one ADR per decision in `docs/llm-wiki/wiki/decisions/<YYYY-MM-DD>-<slug>.md` — Context / Options / Decision / Rationale /
  **Accepted costs** / Outcome. Anything machine-enforceable is promoted to a `.claude/rules/` file or an ArchUnit/detekt rule.
- **Definition of Done** (PR template, Evidence section):
  1. every acceptance criterion has a corresponding test;
  2. last 30 lines and exit code of `scripts/check.sh` and `scripts/itest.sh`;
  3. `git diff --stat main...HEAD` pasted (git output, not memory);
  4. test changes explained; `Test-Change: <reason>` on each commit that deletes, disables or moves out a test or lowers a file's
     assertions or test cases;
  5. ≤ 400 lines (`.harness/events.jsonl` excluded) or split rationale;
  6. ADR / module spec updated, or "no decision made";
  7. `.harness/state/progress.md` updated in the branch;
  8. rollback note (migration reversal or "plain revert suffices");
  9. reviewer/critic findings listed with disposition.

## 8. Testing policy (D4)

- Three Gradle tasks per module: `test` (JVM-only, seconds), `itest` (`@Tag("it")`, Testcontainers), `archTest` (ArchUnit rules in `bootstrap`; Modulith `verify()` runs in `test`).
  `scripts/check.sh` runs the fast set; `scripts/itest.sh` the slow set; CI runs all.
- Real database only: no H2. Dynamic schema and transactional DDL are verified against PostgreSQL 18 in Testcontainers. No container reuse — a fresh PostgreSQL per test JVM (~1 s) keeps runs order-independent.
- The five core principles are **encoded in detekt** (`LongMethod allowedLines=10`, `ReturnCount`, `NestedBlockDepth`, `ForbiddenComment`),
  any finding fails the build (`failOnSeverity=Info`), no baseline file, `allWarningsAsErrors=true`.
- ArchUnit rules in `bootstrap/src/archTest` (initial set): domain packages import no Spring/jOOQ/Jakarta and domain exceptions extend
  `IllegalArgumentException`/`IllegalStateException` (`LayerRulesTest`); `*Repository` implementations live in an `internal` package and
  module markers in a direct sub-package of the root (`NamingRulesTest`); every module reaches the importer (`ImportScopeTest`). Value
  objects as `value class`/`data class` and no `else` outside `when` exhaustiveness stay review items, because bytecode cannot show them;
  merged Flyway files are guarded by `scripts/guards.sh`.
- Pitest (pitest-kotlin) nightly on `platform/rule`, ACL injection, 3-way merge, identification/reconciliation. Purpose: catch tautological tests. No score targets.
- Micrometer + OpenTelemetry starter from Phase 1; p99 of dynamic queries is a first-class metric.

## 9. Parallelism and autonomy (D5, D8)

- Orca: one ticket = one worktree = one terminal; 2–3 concurrent. Merge sequentially, running `check.sh` between merges.
- **Dependency-aware scheduling**: every ticket declares `blocks` / `blocked-by` (`Blocked by` / `Blocks` lines in the issue body, mirrored as Orca task dependencies).
  Dependencies only for real ordering; chains no deeper than 3–4; prefer parallel waves. The ready queue (open, unblocked, owned module free) is what feeds the worktrees.
  Metadata-engine work is naturally layered (schema → repository → service → API), so this is where the graph pays.
- **Exactly three saved Workflows** (`.claude/workflows/`), used only for fan-out that a single session cannot do well:
  `audit-consistency` (every endpoint checked for ACL injection and metadata consistency, then adversarially verified), `release-review` (per-file reviewers, findings ranked and merged before a release tag),
  `deep-research` (design-decision research). Never for day-to-day feature tickets; ultracode is never left on.
- `.worktreeinclude` carries `.env.local` and `.harness/state/goal.md`; `GRADLE_USER_HOME` shared across worktrees.
- Flyway migration versions are timestamps to avoid numbering collisions between worktrees.
- `/loop` and `/goal` only for tickets whose success is fully defined by tests (coverage top-ups, lint clean-ups, migrations), with
  iteration and cost caps and a dedicated branch. Workflows/ultracode only for research and multi-perspective review.
- Unattended runs only inside a container.

## 10. Knowledge (repo wiki + central wiki)

- Repo-local `docs/llm-wiki/` following the owner's schema; `raw/inbox/` gitignored so the global SessionEnd/PreCompact hooks archive there.
  `/wiki-ingest` runs in the ticket's branch, before the PR, whenever the ticket made a decision (`/finish-task` step 5); the pre-push wiki gate enforces it (escape: `Wiki-Skip: <reason>` trailer).
- Lessons that recur three times become a hook, test, or rule and are removed from prose.
- Cross-project knowledge (Boot 4 traps, GraalVM sandbox, permission modes) stays in the owner's central wiki; the repo links, never copies.

### 10.1 Self-improvement loop (D9)

The loop closes only if capture is automatic, promotion is proposed by a machine, and every rule change is merged by the owner.

| Stage | Mechanism | Automatic? |
|---|---|---|
| **Capture** | `log-gate-event.sh` appends one JSON line to the shared, untracked gate-event log in the git common dir (`<git common dir>/vera-events.jsonl`: one file for the main checkout and every worktree, so a firing never dirties a tree) whenever a gate fires: `block-danger` block, Stop-gate block or skip (with failing task), pre-push guard/wiki-gate block, critic `Blocking` finding and CI failure (both logged by the agent, in `/finish-task` and `/pull-request`; CI does not parse its own checks). `scripts/publish-events.sh`, run by `/finish-task` and `/pull-request`, copies new lines into the committed `.harness/events.jsonl`; events from a ticket's last push reach it with the next ticket. Fields: `ts, gate, rule, ticket, branch, detail` (`$HOME` appears as `<home>`, secret-like assignments are masked; deliberate gate tests carry `"probe": true`) | yes for hooks and git hooks; semi for critic and ci events (logged by the agent) |
| **Distill** | `finish-task` skill ends every PR with a three-question retro appended to `docs/llm-wiki/wiki/concepts/lessons.md`: what was slow, what the agent got wrong, which rule was missing. Each lesson carries a `count:` that increments when the same lesson recurs. `/wiki-ingest` (enforced by the push gate) turns decisions into ADRs | semi (skill-driven, runs in the PR session) |
| **Promote** | `harness-improve.yml` weekly: reads `events.jsonl` (unique lines only, `"probe": true` lines skipped) and `lessons.md`; for any lesson with `count ≥ 3` or any gate rule that fired ≥ 3 times for the same cause, opens **one proposal** proposing exactly one of: a CLAUDE.md line, a `.claude/rules/*.md` file, a detekt/ArchUnit rule, a `guards.sh` or `block-danger` pattern, a test. It is a PR, except that `.claude/rules` and `.claude/hooks` are protected paths (CI cannot write there, and nothing bypasses that), so such a proposal is one issue carrying the exact patch for a local ticket. The body cites the events. The lesson is marked `status: proposed` with the link, becomes `promoted` once merged and leaves prose | proposal yes, merge **owner only** |
| **Prune** | same routine, monthly (prune mode): rules/hooks/CLAUDE.md lines with zero firings in `events.jsonl` for 30 days, plus the `/wiki-lint` checks and a CLAUDE.md check for content derivable from code, become one deletion PR (one issue for items under `.claude/`) (D7 is the first instance) | proposal yes, merge **owner only** |
| **Measure** | weekly line in `.harness/metrics.md`, appended by the routine in promote mode (in its first promote PR, or in its own PR when nothing else is due): merged PRs, average changed lines per PR, gate firings by rule (probes excluded), critic Blocking per PR, CI failure rate, regressions (bugs on merged tickets), time-to-green | yes |

Rules of the loop: a lesson never becomes a rule without three occurrences or one incident; a rule never survives 30 days without a firing unless the owner marks it `keep:` with a reason; Claude Code auto memory is personal and does not count as a repo rule until promoted through this PR path.
The monthly prune pass runs the `/wiki-lint` checks and a CLAUDE.md derivability check inside the same routine.

## 11. Toolchain versions and Phase 0 proofs of concept

Versions: Java 25 (Temurin, already installed; set `JAVA_HOME`/toolchain to 25), Kotlin 2.3.21, Spring Boot 4.1.x, Spring Modulith 2.1.x,
Gradle 9.7.x, PostgreSQL 18, jOOQ 3.21.7 (BOM), Flyway (BOM) + `flyway-database-postgresql`, GraalJS `js-community` 25.x,
Caffeine 3.2.x, Valkey 9, Kafka 4.2.1 (BOM, compose image) + Spring Kafka 4.1 (BOM), Testcontainers 2.0.x, Keycloak 26.7.x, springdoc 3.1.x, `spring-boot-starter-opentelemetry`,
k6 2.x (upgrade local 0.56), Spotless + ktfmt, detekt 2.0.0-alpha.x (Gradle daemon on JDK 25), ArchUnit 1.5.x, Kover 0.9.x, Pitest 1.30 + pitest-kotlin.

Known Boot 4 traps to pre-empt (owner's wiki): Jackson 3 (`tools.jackson`), starter modularisation (Flyway silently not running without its starter),
`@MockBean` removed, JUnit 6, `commons-logging` exclude kills the app, `HttpHeaders` no longer a `Map`, jspecify nullability compile errors,
Gradle < 9 cannot parse the JDK 25 version string.

PoCs, each ≤ half a day, results recorded as ADRs:
1. jOOQ 3.21 + Boot 4.1 BOM + Testcontainers PG 18: create a table inside a transaction, roll back, assert it is gone.
2. GraalJS 25 on stock JDK 25: `HostAccess.NONE`, `IOAccess.NONE`, `statementLimit` all enforced; check whether `js-isolate-community` exists on Maven Central.
3. detekt 2.0.0-alpha.x runs against Kotlin 2.3 sources and ArchUnit 1.5.x against their classes in a Modulith multi-module build, and the five-principle detekt rules fire on a deliberately bad sample.
4. `kotlin-lsp` plugin resolves symbols across Gradle modules in Claude Code.

## 12. Phase 0 execution order (input to writing-plans)

1. `claude update`, `/doctor`; fix the global `harness-dev` state path.
2. `git init`; create the public GitHub repo; labels, milestones Phase 1–5; branch protection and required checks (checks are added as workflows land).
3. Gradle 9.7 wrapper, version catalog, Java 25 toolchain, Kotlin 2.3.21, Boot 4.1 BOM; empty Modulith modules + one `verify()` test; `scripts/*.sh`; `compose.yml`.
4. `CLAUDE.md`, `AGENTS.md` symlink, `REVIEW.md`, `docs/development-rules.md`, `docs/domain/*`, `.claude/{settings,hooks,rules,skills,workflows}`, `.githooks/pre-push`, `.github/*`, `docs/llm-wiki` schema, `.gitignore`, `.worktreeinclude`.
   Hooks include `log-gate-event.sh`; `finish-task` includes the retro; `harness-improve.yml` is created with the weekly/monthly schedule.
5. `.harness/state/goal.md` (Phase 1 goal), `progress.md` (Phase 0 record), empty `events.jsonl` and `metrics.md`, `lessons.md` with the schema header; move the Korean research doc to the central wiki; write ADRs for D1–D9.
6. Run the four PoCs; record outcomes as ADRs; adjust versions if a PoC fails.
7. First ticket through the full loop: the first deferred harness-hardening ticket (owned area `harness`; for example test-weakening detection, harness-owned paths,
   migration rename/delete, danger-hook false negatives and positives, guard fixtures and `test-hooks.sh` in CI). Its PR must publish stop-gate, pre-push-guard,
   wiki-gate and ci events, the first `lessons.md` retro and the first non-probe metrics line. Phase 1 ticket 1 follows: "metadata engine —
   `TableDefinition`/`FieldDefinition` system tables + create-table API with transactional DDL".

## 13. Acceptance criteria for Phase 0

- WHEN a Claude Code session opens in the repo THE SYSTEM SHALL inject goal, progress (above the archive marker) and the wiki index via `inject-state.sh`.
- WHEN an agent edits a `.kt` file THE SYSTEM SHALL reformat that file with ktfmt before the next tool call.
- WHEN an agent tries `git push --force`, `flywayClean`, `compose down -v` or `DROP SCHEMA` THE SYSTEM SHALL block the command with a corrective message.
- WHEN a session stops with uncommitted `src/` changes and `scripts/check.sh` fails THE SYSTEM SHALL refuse to stop and show the failing output.
- WHEN a pushed commit deletes, disables or moves out a test, or lowers a test source's assertions or test cases, without a `Test-Change: <reason>` trailer on that very commit THE SYSTEM SHALL reject the push (ADR D10).
- WHEN a PR is opened THE SYSTEM SHALL run build, unit, itest, verifyArch, lint, coverage, test-guard, guards and claude-review, and `main` SHALL refuse merge until every required check (all but the advisory claude-review) passes.
- WHEN the first harness ticket is executed THE SYSTEM SHALL produce a merged PR whose Evidence section satisfies all nine DoD items.
- WHEN any gate blocks an action THE SYSTEM SHALL append one line to the shared gate-event log naming the gate, the rule and the ticket.
- WHEN `/finish-task` or `/pull-request` runs THE SYSTEM SHALL copy the shared log's new lines into `.harness/events.jsonl`.
- WHEN a PR is finished with `finish-task` THE SYSTEM SHALL append a counted retro entry to `lessons.md`.
- WHEN the weekly routine runs and a lesson or gate rule has reached three occurrences THE SYSTEM SHALL open exactly one proposal (a PR, or an issue for `.claude/rules|hooks`) citing the events, and SHALL NOT merge it.
- WHEN a ticket is blocked by an open ticket THE SYSTEM SHALL keep it out of the ready queue until the blocker is closed.

## 14. Out of scope for Phase 0

Platform feature design (engines, storage strategy, ITAM domain model) beyond what the first ticket needs; Kubernetes/kind and the control plane;
a frontend; Beads or any external issue tracker (`Blocked by` / `Blocks` lines in the issue body plus Orca dependencies suffice); GraalVM CE as runtime; Claude Code cloud sessions;
any graph orchestration runtime (LangGraph, Agent Framework, custom) for the pipeline; code knowledge graph tools (graphify, CodeGraph) until the codebase or
cross-module misses justify a two-week pilot; harness evals (replaying canonical tickets) — revisit after Phase 1.

## 15. Risks and accepted costs

- **Stop-hook skips** while a Gradle build of the same checkout runs (a worker subagent's, say) — accepted; documented in CLAUDE.md, the lead re-runs `check.sh` after workers idle; other worktrees build into their own `build/`.
- **The committed event log only grows** — nothing prunes `.harness/events.jsonl`; accepted (one short JSON line per gate firing, and the routine reads only the last 30 days).
- **Boot 4.1 / Kotlin 2.3 / jOOQ 3.21 / Testcontainers 2 are all recent majors** — PoCs 1–4 exist to surface incompatibilities before Phase 1.
- **English-only artifacts cost the owner time** when reading — accepted for portfolio value; `README.ko.md` and the central Korean wiki compensate.
- **Gate count is high for a solo project** — each gate is tied to a documented failure mode from the 2026 evidence; the one-month audit (D7) removes gates that never fire.
