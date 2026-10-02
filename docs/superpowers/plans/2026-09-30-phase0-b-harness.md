# Phase 0-B: Agent Harness, Gates, Knowledge and Self-Improvement Loop — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the repository built by Plan 0-A into an agent-first harness: a short constitution (`CLAUDE.md`), path-scoped rules, project skills for the GitHub flow, hooks and git gates that enforce the rules deterministically, CI checks and branch protection, the repo-local LLM wiki with the nine Phase 0 ADRs, session-state files, and the closed self-improvement loop (event log → counted lessons → weekly proposal PRs → monthly prune PRs).

**Architecture:** Instructions stay short and advisory (`CLAUDE.md` ≈ 100 lines, `.claude/rules/*.md` loaded by path); enforcement is deterministic and layered (PostToolUse format → PreToolUse deny → Stop gate → pre-push guards → CI → branch protection → human). Every gate firing is appended to `.harness/events.jsonl` by one script, `log-gate-event.sh`, which is the data source for the weekly `harness-improve` routine. Knowledge lives in `docs/llm-wiki/` (decisions, concepts, counted lessons); position lives in `.harness/state/`.

**Tech Stack:** Bash (hooks, gates), `jq`, `gh` CLI (authenticated as BrokenFinger98), Claude Code 2.1.x hooks/skills/rules/workflows, GitHub Actions with `anthropics/claude-code-action@v1`, Markdown.

**Spec:** `docs/superpowers/specs/2026-09-30-vera-dev-environment-design.md` §3, §5, §6, §7, §9, §10, §12 steps 1, 4, 5, 7, §13.

**Prerequisite:** Plan 0-A complete (`./scripts/check.sh` and `./scripts/itest.sh` green, `origin` pushed, CI workflow `ci.yml` green).

**Conventions:** English committed artifacts; Conventional Commits; no AI trailers; absolute paths in Bash, never `cd` in compound commands. Hooks are code: every hook gets a test in `scripts/test-hooks.sh` and is run once with real input before commit (owner's harness-debt-audit principle: a hook that never fired is a hook that may not work).

---

## File structure this plan creates

```
vera/
├── CLAUDE.md                          # constitution (≤120 lines)
├── AGENTS.md -> CLAUDE.md             # symlink
├── REVIEW.md                          # AI reviewer contract
├── docs/
│   ├── development-rules.md           # coding conventions (how to write the code)
│   ├── domain/{glossary.md,context-map.md}
│   ├── specs/README.md                # living-spec template (per module, trial)
│   └── llm-wiki/{CLAUDE.md,index.md,log.md,raw/sessions/.gitkeep,wiki/{decisions/*.md,concepts/lessons.md,sources/.gitkeep}}
├── .harness/{state/{goal.md.example,progress.md},events.jsonl,metrics.md}
├── .claude/
│   ├── settings.json
│   ├── hooks/{inject-state.sh,stop-gate.sh,format.sh,log-gate-event.sh,block-project-danger.sh}
│   ├── rules/{domain.md,persistence.md,web.md,test.md,migration.md}
│   ├── skills/{ticket,gated-commit,pull-request,start-task,finish-task,wiki-ingest,wiki-query,wiki-lint}/SKILL.md
│   └── workflows/{audit-consistency.js,release-review.js,deep-research.js}
├── .githooks/pre-push
├── scripts/{guards.sh,test-hooks.sh,publish-events.sh}
├── .worktreeinclude
└── .github/{CODEOWNERS,PULL_REQUEST_TEMPLATE.md,ISSUE_TEMPLATE/{task.yml,config.yml},workflows/{test-guard.yml,claude-review.yml,harness-improve.yml}}
```

---

### Task 1: Constitution — `CLAUDE.md`, `AGENTS.md`, `REVIEW.md`

**Files:**
- Create: `CLAUDE.md`, `AGENTS.md` (symlink), `REVIEW.md`

- [ ] **Step 1: Write `CLAUDE.md`**

```markdown
# Vera — Operating Contract

> The constitution. Loaded every session. Changes only via PR. ≤120 lines by design — if a rule
> keeps being ignored, this file is too long; move the rule to a hook, a test or `.claude/rules/`.

## Session start (the hook injects these; if missing, read them in this order)

1. `.harness/state/goal.md` — current goal. If it says "awaiting decision", present options first.
   It may be absent (fresh clone, CI); then proceed without it.
2. `.harness/state/progress.md` — position (above the `<!-- ARCHIVE -->` marker).
3. `docs/llm-wiki/index.md` — scan Decisions; if the request conflicts with an ADR, open it.

Do not process the request without this context. Design docs: `docs/superpowers/specs/`.
Coding conventions: `docs/development-rules.md`. Domain words: `docs/domain/glossary.md`.

## Role

You build Vera, a metadata-driven enterprise platform engine (ServiceNow-style) with an ITAM app
on top. The owner approves tickets and specs, reviews designs and approves merges; **you write all
code, tests and docs**, run the flow and prove completion with evidence (command output,
`git diff --stat`), never with assertions.

## Immutable decisions (change = PR + ADR in `docs/llm-wiki/wiki/decisions/`)

| Area | Decision |
|---|---|
| Stack | Kotlin 2.3 (BOM-managed) · Java 25 · Spring Boot 4.1 · Spring Modulith 2.1 · PostgreSQL 18 · jOOQ · Flyway |
| Shape | Modular monolith. Modules = direct sub-packages of `com.brokenfinger.vera`; platform never depends on apps or ingestion; allowed edges = each module's `allowedDependencies` |
| Storage | Fixed attributes as real columns, extension attributes as JSONB, transactional DDL for table creation |
| Persistence | jOOQ only — no JPA, no QueryDSL (tables exist at runtime, not compile time) |
| Scripts | GraalJS `js-community` sandbox: `HostAccess.NONE`, `IOAccess.NONE`, statement limit |
| Tests | Real PostgreSQL via Testcontainers; H2 is forbidden. Three suites: `test`, `itest`, `archTest` |
| Artifacts | English only (code, commits, issues, PRs, ADRs, wiki, this file). `README.ko.md` is the sole Korean twin |

## Forbidden — reject on sight, explain, then rediscuss

- Editing a merged Flyway migration (`V*.sql`). Add a new timestamped one.
- Weakening or deleting a test, or adding `@Suppress`, to get green. Fix the code.
- detekt baseline files, weakening detekt's `failOnSeverity = Info`, lowering Kover `minBound`.
- `cd` inside a Bash command (deny rules on `.env*` make it prompt; use absolute paths, `git -C`).
- Direct commits or pushes to `main`; PR > 400 changed lines without a split rationale.
- Work without an issue (exception: harness-improve proposal PRs on `harness/*` branches).
- `--no-verify`, `git commit -n`, changing or unsetting `core.hooksPath` (CI re-runs the guards).
- AI attribution in commits or PRs (`.claude/settings.json` turns Claude Code's off).
- Employer code, designs, customer data or names. Public sources only.
- Non-English text in committed files (except `README.ko.md`).
- Swallowing exceptions, `printStackTrace`, `TODO`/`FIXME` comments (track in issues).
- Speculative abstractions, configurability nobody asked for, "nice to haves" (YAGNI).

## Quality gate — all must exit 0 before you say "done"

```bash
./scripts/check.sh    # spotlessCheck + detekt + unit tests + archTest  (Stop hook runs this)
./scripts/itest.sh    # Testcontainers PostgreSQL 18
```

Spring context tests live in `:bootstrap` until Phase 1 decides a per-module test harness: run
`./scripts/itest.sh` for the whole repo (a module-scoped run that executes 0 tests proves nothing).

Also: every new production `.kt` ships with a test in the same PR; `progress.md` is updated in
the branch; decisions get an ADR (the push gate needs a change under `docs/llm-wiki/wiki/` other
than `concepts/lessons.md`, or a `Wiki-Skip: <reason>` trailer). `Test-Change: <reason>` is only for
deleting tests or reducing assertions, with the reason in the commit body; adding tests needs none.
The `test-change` PR label is separate: it marks any change under `src/test|itest|archTest`.

## Development flow (mandatory)

```
/ticket → <type>/<n>-<slug> branch (worktree) → /start-task → work → /gated-commit → /finish-task → /pull-request → squash merge
```

You run every step; the owner approves the ticket preview (/ticket), the design review and the merge (/pull-request).
Explore → Plan → Implement → Verify. Skip the plan only when the diff fits one sentence.
Large features: interview the owner, write the spec to `docs/superpowers/specs/`, execute in a fresh session.
Parallel work: one owned module per ticket plus the always-allowed files (`.harness/state/progress.md`,
`.harness/events.jsonl`, `docs/llm-wiki/**`, `docs/domain/glossary.md`, `docs/specs/<module>.md`);
root build files and migrations only in solo tickets.

## Evidence format for completion claims

1. Command run and its last line (`RESULT <name> exit=0 ...`).
2. `git diff --stat origin/main...HEAD`.
3. Reviewer/critic findings and what you did with each.

## State file operations

- Design decision → ADR file in `docs/llm-wiki/wiki/decisions/<date>-<slug>.md` (one per decision).
- Step done → `progress.md` entry (date, ✅, issue `#<n>`, evidence); never a commit hash (squash rewrites
  them). Use the PR number only when a change has no issue.
- New phase → rewrite `goal.md` completely; history lives in `progress.md`.
- Conflict → **code beats state files** (they may be stale).
- Something slowed you or a rule was missing → `/finish-task` records it in `docs/llm-wiki/wiki/concepts/lessons.md`.

## Bash habits that keep gates quiet

`<root>` = `git rev-parse --show-toplevel` of this session (your worktree, not the main checkout).
Absolute paths under `<root>`: `git -C <root> ...`, `<root>/scripts/*.sh`.
Scripts print `RESULT ... exit=N`; quote it. Commit messages and PR bodies go in files (`-F`,
`--body-file`) because the danger hook screens the whole command line.
Do not run Gradle while a worker subagent is running Gradle (shared `build/` → false failures).
```

- [ ] **Step 2: Create the `AGENTS.md` symlink and `REVIEW.md`**

```bash
ln -s CLAUDE.md /Users/yu-sun00/Desktop/vera/AGENTS.md
```

`REVIEW.md`:

```markdown
# Review contract for AI reviewers (`claude-review.yml` and the critic in /finish-task)

Report only findings that affect **correctness, the stated requirements, security, or an
immutable decision in `CLAUDE.md`**. Style is owned by ktfmt and detekt — never comment on it.

## Severity

- **blocking** — wrong behaviour, data loss, security hole, module-boundary violation, test weakened/deleted
  without a `Test-Change:` trailer and explanation, migration edited, immutable decision contradicted,
  PR > 400 lines without split rationale.
- **major** — requirement from the ticket's acceptance criteria not covered by a test; missing rollback note.
- **minor** — naming that contradicts `docs/domain/glossary.md`; missing ADR for an evident decision;
  domain identifier or name not wrapped in a `value class`; `if … else` where an early return works.
- Everything else: do not report.

## Must check on every PR

1. Every `WHEN … THE SYSTEM SHALL …` line in the linked issue has a test.
2. `git diff --stat` shows only the ticket's owned module plus the always-allowed files in CLAUDE.md; no unrelated files.
3. No assertion removed or weakened (compare `assertThat`/`assertThrows` counts).
4. New tables/columns come with a new `V<timestamp>__*.sql`, never an edited one.
5. Logs and error messages contain no PII, secrets or customer identifiers.

## Skip

`docs/llm-wiki/raw/**`, `docs/superpowers/plans/**`, generated PlantUML — read them for context, do not report on them.

## Output

Group by severity, cite `path:line`, one sentence each, end with `verdict: approve | request-changes`.
```

- [ ] **Step 3: Verify line count and commit**

Run: `wc -l /Users/yu-sun00/Desktop/vera/CLAUDE.md`
Expected: ≤ 120.

```bash
git add CLAUDE.md AGENTS.md REVIEW.md
git commit -m "docs: add constitution, AGENTS.md symlink and AI review contract"
```

---

### Task 2: Conventions and domain documents

**Files:**
- Create: `docs/development-rules.md`, `docs/domain/glossary.md`, `docs/domain/context-map.md`, `docs/specs/README.md`

- [ ] **Step 1: Write `docs/development-rules.md`**

```markdown
# Vera — Coding Conventions

Companion to `CLAUDE.md` (what is forbidden/decided). This is how to write the code. Machine-checked
where possible: detekt (`config/detekt/detekt.yml`), ArchUnit (`bootstrap/src/archTest`: `LayerRulesTest`, `NamingRulesTest`,
`ImportScopeTest`), Modulith `verify()`.

## Core principles (team standard, encoded in detekt)

1. One method = one job, ≤10 lines (`LongMethod allowedLines 10`).
2. No `if … else`; early return (`when` may use `else ->`; `NestedBlockDepth allowedDepth 2`, `ReturnCount` disabled on purpose).
3. Wrap primitives and collections in domain objects (`value class` with one property — review; no ArchUnit rule sees it).
4. Behaviour methods over getters (a domain object does things; it does not expose fields for others to decide).
5. Composition over inheritance (`AbstractClassCanBeConcreteClass`, `AbstractClassCanBeInterface`, `UnnecessaryInheritance`).

Effective Kotlin defaults: `val` over `var`, no `!!` in production code, `data class` for values,
`sealed interface` for closed hierarchies, scope functions only when they read better.

## Package layout inside a module (`com.brokenfinger.vera.<module>`)

```
<module>/               public API of the module: facade classes, events, value objects other modules may use
<module>/domain/        pure Kotlin: entities, value objects, domain services, exceptions. Imports nothing from Spring, jOOQ, Jakarta
<module>/application/   use cases, transactions (@Transactional lives here), ports (interfaces) the domain needs
<module>/internal/      adapters: jOOQ repositories, web controllers, Kafka consumers, caches. `internal` visibility
<module>/internal/web/  controllers and their request/response DTOs (Spring MVC)
```

Dependency direction: `internal → application → domain`. Other modules see only the module root package
and named interfaces (`@NamedInterface`; today `metadata.domain`).

## Naming

- Tables: `sys_*` for the platform catalog, `u_*` for customer-defined tables (`TableName.physicalName()`).
- Repositories: interface `XxxRepository` in `application/`, implementation `JooqXxxRepository` (internal).
- Use cases: verb phrases — `CreateTable`, `ReconcileObservation`. One public `fun handle(...)`/`operator fun invoke`.
- Exceptions: `<What>Exception` extending `IllegalArgumentException` (bad input) or `IllegalStateException` (bad state).
- Glossary words win: `docs/domain/glossary.md`.

## Persistence

- jOOQ `DSLContext` from Spring; never a second one. Dynamic tables use `DSL.table(DSL.name(...))` /
  `DSL.field(DSL.name(...), type)` with names validated by `TableName`/`FieldName` value objects first — never
  the `String` overloads (plain SQL, unquoted) and never raw user input in SQL.
- DDL and the metadata row change in **one** transaction (PoC 1 proves PostgreSQL rolls DDL back).
- Migrations: `bootstrap/src/main/resources/db/migration/V<yyyyMMdd>_<hhmm>__<slug>.sql`. Immutable once merged.

## Tests

- Unit (`src/test`): domain and application logic, no Spring context, AssertJ.
- Integration (`src/itest`): `@SpringBootTest` + `@Import(TestcontainersConfiguration::class)`; real PostgreSQL 18.
- Spring context tests (`@SpringBootTest`, `@WebMvcTest`) live in `:bootstrap` until Phase 1 decides a per-module harness.
- Architecture (`src/archTest`): ArchUnit rules in `bootstrap` — `LayerRulesTest`, `NamingRulesTest`, `ImportScopeTest`.
- Name tests as behaviour: `` `rejects names longer than 63 characters` ``. One behaviour per test.
- Acceptance criteria from the ticket (EARS) map 1:1 to test names.

## Errors and logs

Never swallow exceptions. Log at the boundary once, with structured key=value pairs, no PII, no secrets.

## Kotlin syntax and the linter

detekt 2.0.0-alpha.x (Kotlin 2.4.10 compiler) parses current Kotlin, so tooling restricts no construct. Known difference from 1.23: `LongMethod` counts only the function body, so KDoc above a function is free while KDoc inside a body adds +2 (+1 one-line); `LargeClass` counts member and class KDoc (+2 each); `//` and `/* */` never count; no option excludes KDoc. Current code impact: 0.
```

- [ ] **Step 2: Write the domain documents**

`docs/domain/glossary.md`:

```markdown
# Glossary

Words used in code, tickets and ADRs. If a word is missing, add it in the same PR that introduces it.

| Term | Meaning | Not to be confused with |
|---|---|---|
| **Platform** | The engines every app runs on: metadata, query, rule, layering, (later) provisioning | App |
| **App** | A domain package on the platform (ITAM first, rack later) that defines tables, rules and UI via metadata | Module |
| **Module** | A Spring Modulith module = a direct sub-package of `com.brokenfinger.vera` | Gradle project |
| **Table definition** | Metadata record describing a customer-visible table: name, label, parent, scope | Physical table (`u_*`) |
| **Field definition** | Metadata record describing a column: name, type, reference target, indexed, scope | Column |
| **Scope** | Who owns a metadata record: `BASE` (shipped by the platform) or `CUSTOMER` (created/modified by a customer) | Tenant |
| **Instance** | One customer's deployment: application + database (multi-instance, not multi-tenant) | Scope |
| **Layering** | Tracking whether a `BASE` record was modified by the customer, so upgrades can skip and report it | Versioning |
| **Rule** | Customer logic executed by the rule engine on events (before insert, after update…) in the sandbox | ACL |
| **ACL** | Row/field level access rule injected into every query by the query engine | Rule |
| **Asset** | ITAM: the financial/contractual view of a thing (cost, contract, owner, lifecycle) | CI |
| **CI (Configuration Item)** | ITAM: the operational/technical view (IP, OS, relationships). 1:1 with an Asset when in operation | Asset |
| **Observation** | One report about a CI from a source (discovery, monitoring, CSV, manual) at a time | CI |
| **Identification** | Matching an observation to an existing CI by ordered identifiers (serial → MAC → hostname+IP) | Reconciliation |
| **Reconciliation** | Choosing which source's value wins per attribute when observations disagree | Identification |
| **Ghost asset** | A CI no source has confirmed for longer than its threshold (`last_seen` per source) | Retired asset |
```

`docs/domain/context-map.md`:

```markdown
# Context map

```
                 ┌────────────────────────────┐
   observations  │        ingestion           │  reads: itam (Observation API)
  ──────────────▶│  discovery · monitoring ·  │
                 │  csv adapters → observations│
                 └─────────────┬──────────────┘
                               ▼
                 ┌────────────────────────────┐
                 │           itam             │  reads: metadata, query, rule
                 │ Asset ↔ CI · lifecycle ·   │
                 │ identification · reconcile │
                 └───────┬───────┬────────────┘
                         ▼       ▼
     ┌────────────┐  ┌────────┐  ┌──────────┐  ┌──────────────┐
     │  metadata  │◀─│ query  │◀─│   rule   │  │   layering   │─▶ metadata
     │ tables ·   │  │ jOOQ · │  │ scripts ·│  └──────────────┘
     │ fields ·   │  │ ACL    │  │ ACL defs │
     │ scope      │  └────────┘  └──────────┘
     └────────────┘
```

Arrows point from the module that depends to the module it depends on. `allowedDependencies` in each
`package-info.java` mirrors this map, and both change in the same PR. `ModularityTest` fails when code
crosses a boundary that `allowedDependencies` does not allow; it does not compare this document.
The control plane (instance provisioning) is a separate deployable and is out of scope until Phase 5.

`rule` also depends on `metadata` directly: `rule/package-info.java` allows `metadata` and `query`, and
the diagram draws only the hop through `query`.
```

`docs/specs/README.md`:

```markdown
# Living module specs (trial — drop after Phase 1 if unmaintained)

One file per module, `docs/specs/<module>.md`, updated in the same PR that changes behaviour.

```markdown
# <module> — living spec
## Purpose (one paragraph)
## Behaviours (EARS)
- WHEN <condition> THE SYSTEM SHALL <result>
## Invariants
- <statement that is always true; each has a test named after it>
## Public API (module root package)
- `Facade.method(args): Result` — one line each
## Open questions
```

Design specs (before building) live in `docs/superpowers/specs/`; plans in `docs/superpowers/plans/`.
```

- [ ] **Step 3: Commit**

```bash
git add docs/development-rules.md docs/domain docs/specs/README.md
git commit -m "docs: add coding conventions, glossary, context map and living-spec template"
```

---

### Task 3: Hooks and project settings

Five hooks. `log-gate-event.sh` is called by the other hooks, by `.githooks/pre-push` and by `guards.sh`; it is the single writer of the shared gate-event log `<git common dir>/vera-events.jsonl` (untracked, one file for the main checkout and every worktree, so a firing never leaves a tree dirty), and `scripts/publish-events.sh` copies new lines into the tracked `.harness/events.jsonl` when `/finish-task` commits the records. `block-project-danger.sh` extends the global `block-danger.sh` with Vera-specific destructive commands and git-hook bypasses (deterministic and logged; permission deny rules cannot express "anywhere in the command").

**Files:**
- Create: `.claude/hooks/log-gate-event.sh`, `scripts/publish-events.sh`, `.claude/hooks/inject-state.sh`, `.claude/hooks/stop-gate.sh`, `.claude/hooks/format.sh`, `.claude/hooks/block-project-danger.sh`, `.claude/settings.json`, `scripts/test-hooks.sh`, `.worktreeinclude`

- [ ] **Step 1: Write `log-gate-event.sh` and `scripts/publish-events.sh`**

```bash
#!/usr/bin/env bash
# log-gate-event.sh <gate> <rule> <detail...>
# Appends one JSON line to the shared gate-event log <git common dir>/vera-events.jsonl: untracked and one file for the
# main checkout and every worktree, so a firing never dirties a tree. $VERA_EVENTS_FILE overrides the path (tests).
# The only writer of that log (spec §10.1 Capture); scripts/publish-events.sh copies it into .harness/events.jsonl.
# gate  : block-danger | stop-gate | pre-push-guard | wiki-gate | critic | ci
# rule  : short machine name, e.g. "deleted-test-file", "check.sh-failed", "force-push"
# detail: free text; NAME=value assignments are masked as NAME=***, then cut to 300 bytes; jq -a escapes non-ASCII
set -uo pipefail
export LC_ALL=C   # bytes, not characters: invalid UTF-8 in a detail must not stop tr, sed or cut
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ $# -ge 2 ] || exit 0
gate="$1"; rule="$2"; shift 2
detail="$(printf '%s' "$*" | tr '\n' ' ' | sed -E 's/([A-Za-z_][A-Za-z0-9_]*)=[^[:space:]]+/\1=***/g' | cut -c1-300)"
branch="$(git -C "$ROOT" branch --show-current 2>/dev/null)"; [ -n "$branch" ] || branch=detached
ticket="$(printf '%s' "$branch" | sed -nE 's#^[a-z]+/([0-9]+)-.*#\1#p')"
EVENTS="${VERA_EVENTS_FILE:-$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/vera-events.jsonl}"
jq -acn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg gate "$gate" --arg rule "$rule" \
      --arg ticket "${ticket:-}" --arg branch "$branch" --arg detail "$detail" \
      '{ts:$ts, gate:$gate, rule:$rule, ticket:$ticket, branch:$branch, detail:$detail}' \
      >> "$EVENTS" 2>/dev/null || true
exit 0
```

`scripts/publish-events.sh`:

```bash
#!/usr/bin/env bash
# publish-events.sh — copies gate events from the shared, untracked log (<git common dir>/vera-events.jsonl, or
# $VERA_EVENTS_FILE) into the tracked .harness/events.jsonl that the weekly harness-improve routine reads.
# Appends the valid JSON lines the tracked file does not hold yet (exact match), in their original order, so a re-run
# adds nothing. /finish-task runs it before staging the state files. Exit codes: 0 ok · 2 environment (not a checkout).
set -uo pipefail
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)" || { echo "publish-events: not inside a git checkout" >&2; exit 2; }
SHARED="${VERA_EVENTS_FILE:-$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/vera-events.jsonl}"
TRACKED="$ROOT/.harness/events.jsonl"
added=0
if [ -s "$SHARED" ]; then
  mkdir -p "$ROOT/.harness" && touch "$TRACKED"
  # A truncated line stays out of the tracked file. FILENAME, not NR==FNR: with an empty tracked file NR==FNR would
  # also hold for the shared lines and skip them all.
  new="$(jq -rR 'select(try (fromjson | type == "object") catch false)' "$SHARED" \
    | awk -v tracked="$TRACKED" 'FILENAME == tracked {seen[$0]; next} !($0 in seen)' "$TRACKED" -)"
  if [ -n "$new" ]; then
    if [ -s "$TRACKED" ] && [ -n "$(tail -c1 "$TRACKED")" ]; then echo >> "$TRACKED"; fi   # never glue two events
    printf '%s\n' "$new" >> "$TRACKED"
    added="$(printf '%s\n' "$new" | wc -l | tr -d ' ')"
  fi
fi
echo "RESULT publish-events exit=0 added=$added"
```

- [ ] **Step 2: Write `inject-state.sh` (SessionStart)**

```bash
#!/usr/bin/env bash
# SessionStart hook — re-injects out-of-session memory (also after compaction) and installs the push gate.
# Fail-open: never block a session start.
cat >/dev/null 2>&1
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0

# 1. Idempotently point git at the versioned hooks
if [ -d "$ROOT/.githooks" ] && [ "$(git -C "$ROOT" config core.hooksPath 2>/dev/null)" != ".githooks" ]; then
  git -C "$ROOT" config core.hooksPath .githooks 2>/dev/null || true
fi

ctx=""
add() { ctx="${ctx}=== $1 ===
$2

"; }

# 2. goal (personal, may be absent on a fresh clone)
[ -f "$ROOT/.harness/state/goal.md" ] && add ".harness/state/goal.md" "$(cat "$ROOT/.harness/state/goal.md")"

# 3. progress — only the part above the archive marker (constant-cost injection, spec §10). The marker is a line of
#    its own, so prose that quotes it does not cut the injection short.
if [ -f "$ROOT/.harness/state/progress.md" ]; then
  add ".harness/state/progress.md (above <!-- ARCHIVE -->)" "$(awk '/^<!-- ARCHIVE -->[[:space:]]*$/{exit} {print}' "$ROOT/.harness/state/progress.md")"
fi

# 4. wiki index — Decisions section only
if [ -f "$ROOT/docs/llm-wiki/index.md" ]; then
  add "docs/llm-wiki/index.md (Decisions)" "$(awk '/^## Decisions/{f=1} /^## /&&!/^## Decisions/{f=0} f' "$ROOT/docs/llm-wiki/index.md")"
fi

# 5. gate events in the last 7 days — a nudge, not a report. The shared log (log-gate-event.sh) holds the firings of
#    every worktree; a fresh clone has only the tracked copy. fromjson? skips a truncated line instead of losing the rest.
events="${VERA_EVENTS_FILE:-$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/vera-events.jsonl}"
[ -s "$events" ] || events="$ROOT/.harness/events.jsonl"
if [ -f "$events" ]; then
  since="$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)"
  summary="$(jq -rR --arg since "$since" 'fromjson? | objects | select(.ts >= $since) | "\(.gate)/\(.rule)"' "$events" 2>/dev/null | sort | uniq -c | sort -rn | head -5)"
  [ -n "$summary" ] && add "gate events, last 7 days (count gate/rule)" "$summary"
fi

[ -z "$ctx" ] && exit 0
jq -n --arg c "[out-of-session memory — session start or compaction recovery. Check the request against the Decisions list; if it conflicts with an ADR, open that ADR before acting.]
$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}' 2>/dev/null
exit 0
```

- [ ] **Step 3: Write `stop-gate.sh` (Stop)**

```bash
#!/usr/bin/env bash
# Stop hook — refuse to end the turn while source changes fail the fast gate (spec §6 row 1, trial D7).
# exit 2 + stderr = Claude must keep working. Loop guard: stop_hook_active. Concurrency guard: a Gradle build of this checkout.
set -uo pipefail
INPUT="$(cat)"
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
LOG="$ROOT/.claude/hooks/log-gate-event.sh"

# Already blocked once this turn → let it stop (prevents infinite loops).
if printf '%s' "$INPUT" | jq -e '.stop_hook_active == true' >/dev/null 2>&1; then exit 0; fi

# Only care about source and build changes (tracked or untracked). -z names arrive unquoted, spaces included;
# --untracked-files=all lists the files of a new package directory instead of one 'dir/' entry.
changed="$(git -C "$ROOT" status --porcelain -z --untracked-files=all -- platform apps ingestion bootstrap \
  build.gradle.kts settings.gradle.kts gradle config gradle.properties 2>/dev/null \
  | tr '\0' '\n' | grep -E '\.(kt|kts|java|sql|yaml|yml|toml|properties)$' | head -50)"
[ -z "$changed" ] && exit 0

# A Gradle build of this checkout would share build/ and produce false failures (wiki 2026-09-09 lesson). Gradle 9's
# wrapper runs 'java ... -jar <root>/gradle/wrapper/gradle-wrapper.jar', so match that path: the bare word gradlew
# also matched Claude Code's own shell wrapper, and other worktrees build into their own build/.
if pgrep -f "$ROOT/gradle/wrapper/gradle-wrapper.jar" >/dev/null 2>&1; then
  "$LOG" stop-gate skipped-concurrent-gradle "a Gradle build of this checkout is running"
  echo "stop-gate: a Gradle build of this checkout is running; skipped. Re-run ./scripts/check.sh when it finishes." >&2
  exit 0
fi

out="$("$ROOT/scripts/check.sh" 2>&1)"
code=$?
if [ $code -eq 0 ]; then exit 0; fi

"$LOG" stop-gate check.sh-failed "$(printf '%s' "$out" | grep -E 'RESULT|tests,|FAILED|error:' | tail -5)"
{
  echo "🛑 stop-gate: ./scripts/check.sh failed (exit $code). Fix before stopping. Last 40 lines (Gradle boilerplate is ~12, so the failing test name survives):"
  printf '%s\n' "$out" | tail -40
  echo "Order: spotlessApply → <module>/build/reports/detekt/<source set>.md → test-results XML → archTest rule name. Never weaken a test or rule to pass."
} >&2
exit 2
```

- [ ] **Step 4: Write `format.sh` (PostToolUse Edit|Write)**

```bash
#!/usr/bin/env bash
# PostToolUse(Edit|Write) — format the touched Kotlin file with ktfmt via Spotless. Never blocks (check.sh verifies).
set -uo pipefail
INPUT="$(cat)"
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)"
case "$FILE" in *.kt|*.kts) ;; *) exit 0 ;; esac
[ -f "$FILE" ] || exit 0
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
case "$FILE" in "$ROOT"/*) ;; *) exit 0 ;; esac
if pgrep -f "$ROOT/gradle/wrapper/gradle-wrapper.jar" >/dev/null 2>&1; then exit 0; fi   # never fight a build of this checkout
"$ROOT/gradlew" -p "$ROOT" -q --console=plain spotlessApply -PspotlessIdeHook="$FILE" >/dev/null 2>&1 || true
exit 0
```

- [ ] **Step 5: Write `block-project-danger.sh` (PreToolUse Bash) and `.claude/settings.json`**

`.claude/hooks/block-project-danger.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse(Bash) — Vera-specific destructive commands and git-hook bypasses, on top of the global block-danger.sh. exit 2 = blocked.
set -uo pipefail
INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)"
[ -n "$CMD" ] || exit 0
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
LOG="$ROOT/.claude/hooks/log-gate-event.sh"

# The patterns below read NORM: the command with git's global options stripped ('git -C <path> push' → 'git push';
# CLAUDE.md mandates -C) and quotes dropped. One option per pass, those taking a value first, until none is left.
# hooks_path_values reads $CMD itself, because 'git -c core.hooksPath=...' is one of the stripped options.
GIT_OPT_ARG="(-[Cc]|--(git-dir|work-tree|namespace|config-env|attr-source))[[:space:]]+(\"[^\"]*\"|'[^']*'|[^[:space:];&|]+)"
NORM="$(printf '%s' "$CMD" | sed -E -e ':a' -e "s/(git)[[:space:]]+$GIT_OPT_ARG/\1/g" -e 'ta' \
  -e 's/(git)[[:space:]]+-[^[:space:];&|]*/\1/g' -e 'ta' -e "s/[\"']//g")"

block() {
  "$LOG" block-danger "$2" "$CMD"
  echo "🚫 blocked: $1" >&2
  echo "   command: $CMD" >&2
  echo "   $3" >&2
  exit 2
}
# grep reads all input (no -q): under pipefail an early exit kills printf with SIGPIPE on a long multi-line command,
# and the match would read as a miss (fail-open).
m() { printf '%s' "$NORM" | grep -iE "$1" >/dev/null; }
# Values the command gives core.hooksPath ('git config ... core.hooksPath V', 'git -c core.hooksPath=V'; the key may be quoted).
# A read gives none; the fd number of a redirect after a read ('core.hooksPath 2>/dev/null') is dropped.
hooks_path_values() {
  printf '%s' "$CMD" | grep -oiE "config([[:space:]]+[^[:space:];&|]+)*[[:space:]]+[\"']?core\.hookspath[\"']?[[:space:]]+[^[:space:];&|<>()]+|-c[[:space:]]+[\"']?core\.hookspath=[^[:space:];&|<>()]*" \
    | sed -E "s/.*[=[:space:]]//; s/[\"']//g" | grep -vxE '[0-9]+'
}

m 'flyway(Clean|Repair)|flyway[[:space:]]+(clean|repair)' && block "Flyway clean/repair" flyway-clean "Migrations are immutable; fix forward with a new V<timestamp>__*.sql."
m 'compose[[:space:]]+down.*(-v|--volumes)' && block "compose down with volumes" compose-down-volumes "Volumes hold the demo database; use 'docker compose down' without -v."
m 'drop[[:space:]]+schema' && block "DROP SCHEMA" drop-schema "Schema changes go through Flyway migrations reviewed in a PR."
m 'git[[:space:]]+(checkout|restore)([[:space:]]+[^[:space:];&|]+)*[[:space:]]+(\./?|:/)([[:space:];&|]|$)' && block "discarding all working-tree changes" git-discard-all "Discard single files by path, never the whole tree; to unstage everything, use 'git reset -q'."
# reset --hard and clean -f repeat global block-danger.sh rules, which need git next to the subcommand and so miss 'git -C <path>'.
m 'git[[:space:]]+reset([[:space:]]+[^[:space:];&|]+)*[[:space:]]+--hard([[:space:];&|]|$)' && block "git reset --hard" reset-hard "It drops uncommitted work; commit or stash it instead ('git reset -q' only unstages)."
m 'git[[:space:]]+clean([[:space:]]+[^[:space:];&|]+)*[[:space:]]+(-[[:alnum:]]*f[[:alnum:]]*|--force)([[:space:];&|]|$)' && block "git clean with --force" clean-force "It deletes untracked files for good; remove single paths instead, after a dry run with 'git clean -n'."
# Force push: --force* (incl. --force-with-lease), a short-flag cluster with f (-f, -fu, -uf) or a +<refspec>.
m 'git[[:space:]]+push([[:space:]]+[^[:space:];&|]+)*[[:space:]]+(--force[^[:space:];&|]*|-[[:alnum:]]*f[[:alnum:]]*|\+[^[:space:];&|]+)([[:space:];&|]|$)' && block "force push" force-push "History is linear and protected; open a new commit instead."
m 'git[[:space:]].*--no-verify([^-[:alnum:]]|$)' && block "skipping git hooks with --no-verify" no-verify "The guards are fail-closed; fix the code instead of skipping them."
m 'unset[^;&|]*core\.hookspath' && block "unsetting core.hooksPath" hooks-path "core.hooksPath installs the push gate; it stays .githooks."
hooks_path_values | grep -vx '\.githooks' >/dev/null && block "core.hooksPath other than .githooks" hooks-path "core.hooksPath installs the push gate; only 'git config core.hooksPath .githooks' is allowed."
exit 0
```

`.claude/settings.json`:

```json
{
  "$comment": "Project-shared settings: allow/deny, attribution and hooks only. Never set defaultMode here — project files cannot grant bypass and doing so degrades the session to manual (owner wiki, 2026-09-21). Empty attribution: commits and PRs carry no AI trailer or link (owner rule). Destructive-command and hook-bypass blocks live in hooks/block-project-danger.sh so they match anywhere in a command and are logged.",
  "permissions": {
    "allow": [
      "Bash(./gradlew *)",
      "Bash(./scripts/check.sh*)",
      "Bash(./scripts/test.sh*)",
      "Bash(./scripts/itest.sh*)",
      "Bash(./scripts/build.sh*)",
      "Bash(./scripts/guards.sh*)",
      "Bash(git status*)",
      "Bash(git diff*)",
      "Bash(git log*)",
      "Bash(git show*)",
      "Bash(git branch*)",
      "Bash(gh issue view*)",
      "Bash(gh pr view*)",
      "Bash(gh pr checks*)",
      "Bash(docker compose ps*)"
    ],
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)"
    ]
  },
  "attribution": { "commit": "", "pr": "", "sessionUrl": false },
  "hooks": {
    "SessionStart": [
      { "matcher": "", "hooks": [ { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/inject-state.sh" } ] }
    ],
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-project-danger.sh" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/format.sh", "timeout": 60 } ] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [ { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/stop-gate.sh", "timeout": 180 } ] }
    ]
  }
}
```

- [ ] **Step 6: Write `.worktreeinclude`**

```text
.env.local
.harness/state/goal.md
```

- [ ] **Step 7: Write `scripts/test-hooks.sh` — hooks are code**

```bash
#!/usr/bin/env bash
# Exercises every project hook and gate script with real input. Run after any hook change. Exit 0 = all pass.
# Probes log to a temporary VERA_EVENTS_FILE and fixtures are throwaway repositories under one temp directory, so
# neither the real gate-event logs nor this working tree are touched.
set -uo pipefail
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
H="$ROOT/.claude/hooks"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export VERA_EVENTS_FILE="$T/events.jsonl"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
fail=0
ok()   { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }
last() { tail -1 "$VERA_EVENTS_FILE"; }
# fixture <dir>: a throwaway repository holding this checkout's hooks and scripts in one commit on main = origin/main.
fixture() {
  git init -q -b main "$1" && mkdir -p "$1/.claude" && cp -R "$H" "$1/.claude/" && cp -R "$ROOT/scripts" "$ROOT/.githooks" "$1/" \
    && git -C "$1" add -A && git -C "$1" commit -qm "base" && git -C "$1" update-ref refs/remotes/origin/main HEAD
}
# simulate <arg>: a 30 s background process whose command line holds <arg>; its pid lands in $sim.
simulate() { perl -e 'sleep 30' "$1" & sim=$!; for _ in $(seq 50); do pgrep -f "$1" >/dev/null && return; sleep 0.1; done; }

# log-gate-event writes one valid JSON line, masks NAME=value assignments, and keeps the line ASCII (jq -a) even
# for a detail with invalid UTF-8 (the lone byte \xff becomes U+FFFD)
"$H/log-gate-event.sh" test-gate unit-test "hello world"
last | jq -e '.gate=="test-gate" and .rule=="unit-test" and (.ts|length)==20' >/dev/null && ok "log-gate-event json" || bad "log-gate-event json"
"$H/log-gate-event.sh" test-gate mask "export API_KEY=abc123 then PASSWORD=x y"
[ "$(last | jq -r .detail)" = "export API_KEY=*** then PASSWORD=*** y" ] && ok "log-gate-event masks NAME=value" || bad "log-gate-event masks NAME=value"
"$H/log-gate-event.sh" test-gate non-ascii "$(printf 'caf\xc3\xa9 \xff')"
last | jq -e '.detail == "café �"' >/dev/null && ! last | LC_ALL=C grep '[^ -~]' >/dev/null \
  && ok "log-gate-event escapes non-ASCII and invalid UTF-8" || bad "log-gate-event escapes non-ASCII and invalid UTF-8"

# Without VERA_EVENTS_FILE every worktree logs to one untracked file in the git common dir; detached HEAD logs 'detached'
F="$T/repo"; fixture "$F"
git -C "$F" checkout -q --detach && git -C "$F" worktree add -q -b wt "$T/wt"
env -u VERA_EVENTS_FILE "$F/.claude/hooks/log-gate-event.sh" test-gate shared "from the main checkout"
env -u VERA_EVENTS_FILE "$T/wt/.claude/hooks/log-gate-event.sh" test-gate shared "from a worktree"
jq -s -e 'map(.branch) == ["detached","wt"]' "$(git -C "$F" rev-parse --path-format=absolute --git-common-dir)/vera-events.jsonl" >/dev/null \
  && [ -z "$(git -C "$F" status --porcelain)$(git -C "$T/wt" status --porcelain)" ] \
  && ok "log-gate-event: one untracked log for every worktree" || bad "log-gate-event: one untracked log for every worktree"

# publish-events appends the valid lines the tracked file lacks, in order; a re-run adds nothing
printf '%s\n' '{"rule":"a"}' '{"rule":"b"}' '{"rule":"trunc' '{"rule":"c"}' > "$T/shared.jsonl"
mkdir -p "$F/.harness" && printf '%s' '{"rule":"a"}' > "$F/.harness/events.jsonl"   # no final newline
r1="$(VERA_EVENTS_FILE="$T/shared.jsonl" "$F/scripts/publish-events.sh")"; r2="$(VERA_EVENTS_FILE="$T/shared.jsonl" "$F/scripts/publish-events.sh")"
[ "$r1 | $r2" = "RESULT publish-events exit=0 added=2 | RESULT publish-events exit=0 added=0" ] \
  && [ "$(jq -r .rule "$F/.harness/events.jsonl" | tr '\n' ' ')" = "a b c " ] \
  && ok "publish-events: new valid lines in order, idempotent" || bad "publish-events: new valid lines in order, idempotent"

# inject-state emits hookSpecificOutput JSON with the Decisions of this checkout's wiki index
out="$(echo '{}' | "$H/inject-state.sh")"
printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName=="SessionStart"' >/dev/null && ok "inject-state json" || bad "inject-state json"
printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep 'Decisions' >/dev/null && ok "inject-state includes decisions" || bad "inject-state includes decisions"
# ... stops at the marker line, not at prose quoting the marker, and counts events around a truncated line
mkdir -p "$F/.harness/state"
printf '%s\n' '# Progress' 'Move old entries below the <!-- ARCHIVE --> line.' '## current entry' '<!-- ARCHIVE -->' '## archived entry' > "$F/.harness/state/progress.md"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s\n' "{\"ts\":\"$now\",\"gate\":\"g\",\"rule\":\"r\"}" '{"ts":"trunc' "{\"ts\":\"$now\",\"gate\":\"g\",\"rule\":\"r\"}" > "$T/inject.jsonl"
ctx="$(echo '{}' | VERA_EVENTS_FILE="$T/inject.jsonl" "$F/.claude/hooks/inject-state.sh" | jq -r .hookSpecificOutput.additionalContext)"
printf '%s\n' "$ctx" | grep -x '## current entry' >/dev/null && ! printf '%s\n' "$ctx" | grep -x '## archived entry' >/dev/null \
  && ok "inject-state: a quoted marker does not cut progress short" || bad "inject-state: a quoted marker does not cut progress short"
printf '%s\n' "$ctx" | grep -E '^ +2 g/r$' >/dev/null && ok "inject-state: a truncated event line hides nothing" || bad "inject-state: a truncated event line hides nothing"
# ... and reads the tracked copy when the shared log does not exist yet (fresh clone)
F2="$T/fresh"; fixture "$F2"; mkdir -p "$F2/.harness" && printf '%s\n' "{\"ts\":\"$now\",\"gate\":\"g\",\"rule\":\"tracked\"}" > "$F2/.harness/events.jsonl"
echo '{}' | env -u VERA_EVENTS_FILE "$F2/.claude/hooks/inject-state.sh" | jq -r .hookSpecificOutput.additionalContext | grep -E '^ +1 g/tracked$' >/dev/null \
  && ok "inject-state: fresh clone falls back to the tracked log" || bad "inject-state: fresh clone falls back to the tracked log"

# stop-gate: loop guard exits 0 immediately
echo '{"stop_hook_active": true}' | "$H/stop-gate.sh" >/dev/null 2>&1 && ok "stop-gate loop guard" || bad "stop-gate loop guard"
# stop-gate: clean tree exits 0 (skipped when this checkout has source changes: the gate would run the real check.sh)
if [ -z "$(git -C "$ROOT" status --porcelain --untracked-files=all -- platform apps ingestion bootstrap build.gradle.kts settings.gradle.kts gradle config gradle.properties)" ]; then
  echo '{"stop_hook_active": false}' | "$H/stop-gate.sh" >/dev/null 2>&1 && ok "stop-gate clean tree" || bad "stop-gate clean tree"
else
  echo "SKIP stop-gate clean tree (working tree dirty)"
fi
# stop-gate in a fixture whose check.sh always fails: it sees a .kt file in a new package directory and a name with a
# space, and skips only while this checkout's wrapper jar runs, not for a process that merely names gradlew
G="$T/gate"; fixture "$G"; printf '#!/usr/bin/env bash\necho "RESULT format exit=1 seconds=0"\nexit 1\n' > "$G/scripts/check.sh"
gate() { echo '{"stop_hook_active": false}' | "$G/.claude/hooks/stop-gate.sh" >/dev/null 2>&1; echo $?; }
mkdir -p "$G/platform/m/src/main/kotlin/new/pkg" && : > "$G/platform/m/src/main/kotlin/new/pkg/New.kt"
[ "$(gate)" = 2 ] && ok "stop-gate sees a .kt file in a new package directory" || bad "stop-gate sees a .kt file in a new package directory"
rm -rf "$G/platform" && mkdir -p "$G/platform/a b" && : > "$G/platform/a b/C.kt"
[ "$(gate)" = 2 ] && ok "stop-gate sees a file name with a space" || bad "stop-gate sees a file name with a space"
simulate "$(git -C "$G" rev-parse --show-toplevel)/gradle/wrapper/gradle-wrapper.jar"   # physical path, as gradlew's pwd -P
[ "$(gate)" = 0 ] && last | jq -e '.rule=="skipped-concurrent-gradle"' >/dev/null \
  && ok "stop-gate skips while this checkout's wrapper jar runs" || bad "stop-gate skips while this checkout's wrapper jar runs"
kill "$sim"; wait "$sim" 2>/dev/null
simulate "gradlew GradleWrapperMain"
[ "$(gate)" = 2 ] && ok "stop-gate ignores a process that only names gradlew" || bad "stop-gate ignores a process that only names gradlew"
kill "$sim"; wait "$sim" 2>/dev/null

# format: ignores non-Kotlin files and exits 0
echo '{"tool_input":{"file_path":"'"$ROOT"'/README.md"}}' | "$H/format.sh" && ok "format ignores md" || bad "format ignores md"

# block-project-danger: blocks the destructive and hook-bypass patterns (exit 2), passes normal commands (exit 0),
# also behind git's global options ('git -C <path> ...', the form CLAUDE.md mandates).
for c in "./gradlew flywayClean" "docker compose down -v" "psql -c 'drop schema vera cascade'" "git checkout -- ." "git push --force origin main" \
         "git push --no-verify origin main" "git config core.hooksPath /dev/null" "git config --unset core.hooksPath" "git -c core.hooksPath=/dev/null push origin main" \
         "git -C $ROOT checkout -- ." "git -C $ROOT restore ." "git -C $ROOT push --force origin x" "git -C $ROOT push -f origin x" \
         "git checkout HEAD -- ." "git -C $ROOT restore --source=HEAD ." "git -C $ROOT push --no-verify origin x" "git -C $ROOT restore --staged ." \
         "git -C $ROOT reset --hard" "git -C $ROOT clean -fd" "git -C $ROOT clean --force" "git -C $ROOT push origin +x" \
         "git -C $ROOT push -fu origin x" "git -C $ROOT push -uf origin x" "git config 'core.hooksPath' /dev/null" "git -c 'core.hooksPath=/dev/null' push origin x"; do
  echo "{\"tool_input\":{\"command\":\"$c\"}}" | "$H/block-project-danger.sh" >/dev/null 2>&1
  [ $? -eq 2 ] && ok "block-project-danger blocks: $c" || bad "block-project-danger blocks: $c"
done
for c in "./scripts/check.sh" "git config core.hooksPath .githooks" "git config --get core.hooksPath" \
         "git -C $ROOT checkout -- docs/x.md" "git -C $ROOT checkout -- ./docs/x.md" "git -C $ROOT checkout -- .gitattributes" \
         "git -C $ROOT push origin x" "git -C $ROOT status" "git -C $ROOT config core.hooksPath .githooks" \
         "git -C $ROOT reset -q" "git -C $ROOT reset --soft HEAD~1" "git clean -n" "git push origin main"; do
  echo "{\"tool_input\":{\"command\":\"$c\"}}" | "$H/block-project-danger.sh" >/dev/null 2>&1 && ok "block-project-danger passes: $c" || bad "block-project-danger passes: $c"
done
# A pattern on the first line of a long multi-line command is still blocked: under pipefail, a reader that exits early
# (grep -q) would kill the writer with SIGPIPE once the input outgrows the pipe buffer, and the match would read as a miss.
long="git push --force origin x"$'\n'"$(seq -f 'echo padding line %g' 1 8000)"
jq -cn --arg c "$long" '{tool_input:{command:$c}}' | "$H/block-project-danger.sh" >/dev/null 2>&1
[ $? -eq 2 ] && ok "block-project-danger blocks: force push on line 1 of a >100 KB command" || bad "block-project-danger blocks: force push on line 1 of a >100 KB command"

# guards: current HEAD against itself must pass
"$ROOT/scripts/guards.sh" HEAD HEAD >/dev/null 2>&1 && ok "guards no-op range" || bad "guards no-op range"

# guards and pre-push in a fixture, offline: origin/main is a local ref and the remote a bare repository under $T.
# Secrets and Korean text are built from escapes at run time, so this file holds neither.
P="$T/guards"; fixture "$P"; git init -q --bare "$T/remote.git"; git -C "$P" config core.hooksPath .githooks
commit_in() { git -C "$1" add -A && git -C "$1" commit -qm "$2"; }
guards_last() { "$P/scripts/guards.sh" HEAD~1 HEAD 2>&1 || true; }   # output only: under pipefail a violation's exit 1 would fail the grep
out="$("$P/scripts/guards.sh" no-such-ref HEAD 2>&1)"
[ $? -eq 2 ] && printf '%s' "$out" | grep 'git fetch origin main' >/dev/null && ok "guards: a ref that does not resolve is exit 2" || bad "guards: a ref that does not resolve is exit 2"
mkdir -p "$T/nogit" && cp "$P/scripts/guards.sh" "$T/nogit/" && out="$(cd "$T/nogit" && ./guards.sh 2>&1)"
[ $? -eq 2 ] && printf '%s' "$out" | grep 'not inside a git checkout' >/dev/null && ok "guards: outside a checkout is exit 2" || bad "guards: outside a checkout is exit 2"
mkdir -p "$P/m/src/main/kotlin" && printf '*.kt -diff\n' > "$P/.gitattributes" && printf '@Suppress("X")\nclass A\n' > "$P/m/src/main/kotlin/A.kt"
commit_in "$P" "feat: a suppression behind -diff"
guards_last | grep 'new suppression' >/dev/null && ok "guards: '*.kt -diff' hides no added line" || bad "guards: '*.kt -diff' hides no added line"
mkdir -p "$P/m/src/test/kotlin" && printf 'class T { fun t() = assertThat(1) }\n' > "$P/m/src/test/kotlin/T.kt" && commit_in "$P" "test: add T"
git -C "$P" rm -q m/src/test/kotlin/T.kt && commit_in "$P" $'test: drop T\n\nTest-Change:'
guards_last | grep 'test files deleted' >/dev/null && ok "guards: 'Test-Change:' without a reason excuses nothing" || bad "guards: 'Test-Change:' without a reason excuses nothing"
git -C "$P" commit -q --amend -m $'test: drop T\n\nTest-Change: obsolete probe'
"$P/scripts/guards.sh" HEAD~1 HEAD >/dev/null 2>&1 && ok "guards: 'Test-Change: <reason>' accepts the deletion" || bad "guards: 'Test-Change: <reason>' accepts the deletion"
printf 'k = "%s"\n' "sk-ant-$(printf 'x%.0s' $(seq 24))" > "$P/k1.txt" && commit_in "$P" "chore: k1"
guards_last | grep 'secret-like literal' >/dev/null && ok "guards: an sk-ant- key is a secret" || bad "guards: an sk-ant- key is a secret"
printf 'k = "%s"\n' "github_pat_$(printf 'y%.0s' $(seq 24))" > "$P/k2.txt" && commit_in "$P" "chore: k2"
guards_last | grep 'secret-like literal' >/dev/null && ok "guards: a github_pat_ token is a secret" || bad "guards: a github_pat_ token is a secret"
printf 'jamo %s\n' "$(printf '\xe3\x84\xb1')" > "$P/j1.md" && commit_in "$P" "docs: j1"
guards_last | grep 'Korean text added' >/dev/null && ok "guards: compatibility jamo are Korean" || bad "guards: compatibility jamo are Korean"
printf 'jamo %s\n' "$(printf '\xe1\x84\x80')" > "$P/j2.md" && commit_in "$P" "docs: j2"
guards_last | grep 'Korean text added' >/dev/null && ok "guards: Hangul Jamo are Korean" || bad "guards: Hangul Jamo are Korean"
printf 'ok\n' > "$P/j3.md" && commit_in "$P" "docs: $(printf '\xed\x95\x9c')"
guards_last | grep 'Korean text in a commit message' >/dev/null && ok "guards: Korean in a commit message" || bad "guards: Korean in a commit message"
git -C "$P" push -q "$T/remote.git" HEAD:refs/heads/main >/dev/null 2>&1
[ $? -ne 0 ] && last | jq -e '.rule=="push-to-main"' >/dev/null && ok "pre-push refuses a push to main" || bad "pre-push refuses a push to main"
git -C "$P" update-ref refs/remotes/origin/main HEAD
printf 'x\n' > "$P/scripts/x.txt" && commit_in "$P" $'chore: touch scripts\n\nWiki-Skip:'
git -C "$P" push -q "$T/remote.git" HEAD:refs/heads/feature >/dev/null 2>&1
[ $? -ne 0 ] && last | jq -e '.rule=="blocked-no-wiki-change"' >/dev/null && ok "pre-push: 'Wiki-Skip:' without a reason does not pass" || bad "pre-push: 'Wiki-Skip:' without a reason does not pass"
git -C "$P" commit -q --amend -m $'chore: touch scripts\n\nWiki-Skip: probe, nothing decided'
git -C "$P" push -q "$T/remote.git" HEAD:refs/heads/feature >/dev/null 2>&1 && ok "pre-push: 'Wiki-Skip: <reason>' passes" || bad "pre-push: 'Wiki-Skip: <reason>' passes"
git -C "$P" worktree add -q "$T/pwt" -b wt-guards && printf '@Suppress("Y")\nclass B\n' > "$T/pwt/m/src/main/kotlin/B.kt" && commit_in "$T/pwt" "feat: B"
git -C "$T/pwt" push -q "$T/remote.git" HEAD:refs/heads/wt-guards >/dev/null 2>&1
[ $? -ne 0 ] && jq -s -e 'map(select(.branch=="wt-guards" and .rule=="new-suppress")) | length == 1' "$VERA_EVENTS_FILE" >/dev/null \
  && ok "guards log from a worktree (git exports GIT_DIR to hooks there)" || bad "guards log from a worktree (git exports GIT_DIR to hooks there)"

exit $fail
```

- [ ] **Step 8: Make executable and run the hook tests (guards.sh comes in Task 7; run again then)**

```bash
chmod +x /Users/yu-sun00/Desktop/vera/.claude/hooks/*.sh /Users/yu-sun00/Desktop/vera/scripts/test-hooks.sh /Users/yu-sun00/Desktop/vera/scripts/publish-events.sh
mkdir -p /Users/yu-sun00/Desktop/vera/.harness && : > /Users/yu-sun00/Desktop/vera/.harness/events.jsonl
/Users/yu-sun00/Desktop/vera/scripts/test-hooks.sh; echo exit=$?
```

Expected: `PASS` for every line except `guards no-op range` (FAIL until Task 7) and `exit=1` for now. After Task 7 rerun and expect `exit=0`.

- [ ] **Step 9: Commit**

```bash
git add .claude/settings.json .claude/hooks scripts/test-hooks.sh scripts/publish-events.sh .worktreeinclude .harness/events.jsonl
git commit -m "chore: add project hooks (state injection, stop gate, formatter, gate-event log) and settings"
```

---

### Task 4: Path-scoped rules (`.claude/rules/`)

Each file is an enforceable summary; the machine check that backs it is named so the rule can be deleted when the check exists.

**Files:**
- Create: `.claude/rules/domain.md`, `.claude/rules/persistence.md`, `.claude/rules/web.md`, `.claude/rules/test.md`, `.claude/rules/migration.md`

- [ ] **Step 1: Write the five rule files**

`.claude/rules/domain.md`:

```markdown
---
paths:
  - "**/src/main/kotlin/com/brokenfinger/vera/*/domain/**"
---
# Domain packages

- MUST NOT import `org.springframework.*`, `org.jooq.*`, `jakarta.*` (ArchUnit `LayerRulesTest`).
- MUST wrap identifiers and names in `value class` types with one property (review; no ArchUnit rule sees it).
- Exceptions MUST extend `IllegalArgumentException` (bad input) or `IllegalStateException` (bad state) — ArchUnit `LayerRulesTest`.
- Behaviour lives on the object (`asset.retire(at)`), not in a service that reads its fields.
- Verify: `./scripts/check.sh` (archTest).
```

`.claude/rules/persistence.md`:

```markdown
---
paths:
  - "**/internal/**/*Repository*.kt"
  - "**/internal/**/*Jooq*.kt"
  - "**/platform/query/src/main/**"
---
# jOOQ adapters

- Repository implementations MUST be `internal` and named `Jooq<Aggregate>Repository`.
- Dynamic identifiers MUST come from `TableName`/`FieldName` value objects and be rendered with `DSL.table(DSL.name(...))` / `DSL.field(DSL.name(...), type)`; never the `String` overloads (plain SQL, unquoted), never SQL built from raw strings.
- Use the Spring-provided `DSLContext`; never construct a second one (breaks transactional DDL — PoC 1).
- Return domain types, not jOOQ `Record`s, from the repository boundary.
- Verify: `./scripts/itest.sh` (no module argument; the Spring context tests live in `:bootstrap` for now).
```

`.claude/rules/web.md`:

```markdown
---
paths:
  - "**/internal/web/**"
---
# Web adapters (Spring MVC)

- Controllers only translate HTTP ↔ use case; no business logic, no repository access.
- Request/response DTOs are `data class`es in the same package; never expose domain objects directly.
- Validation with Jakarta annotations on DTOs; domain value objects validate again on construction.
- Error responses follow RFC 9457 problem details (`ProblemDetail`), never stack traces.
- Verify: a `@WebMvcTest` (starter `spring-boot-starter-webmvc-test`) per controller, in `:bootstrap` for now.
```

`.claude/rules/test.md`:

```markdown
---
paths:
  - "**/src/test/**"
  - "**/src/itest/**"
  - "**/src/archTest/**"
---
# Tests

- One behaviour per test; the name states the behaviour in backticks.
- Acceptance criteria (`WHEN … THE SYSTEM SHALL …`) from the ticket map to tests 1:1 — name them alike.
- `itest`: `@SpringBootTest` + `@Import(TestcontainersConfiguration::class)`; Spring context tests live in `:bootstrap` for now. No H2, no mocks of the database.
- Never delete or weaken an assertion to go green. If a test is wrong, deleting it or reducing assertions needs the reason in the commit body and the trailer `Test-Change: <reason>` (pre-push guard); adding tests needs none.
- Fixtures MUST NOT contain real names, emails, serial numbers or the words `password=`/`token=` with literal values (secret hook false-positives).
```

`.claude/rules/migration.md`:

```markdown
---
paths:
  - "**/db/migration/**"
---
# Flyway migrations

- File name `V<yyyyMMdd>_<hhmm>__<slug>.sql`; timestamp versions avoid worktree collisions.
- A merged migration is immutable. Fix forward with a new file (pre-push guard blocks edits to merged `V*.sql`).
- Every DDL change ships with its rollback note in the PR (a `drop`/`alter` statement or "plain revert").
- No data migrations in DDL files. Data migrations need an ADR before the first one (mechanism undecided: a Flyway Java migration or an idempotent runner).
```

- [ ] **Step 2: Commit**

```bash
git add .claude/rules
git commit -m "docs: add path-scoped agent rules for domain, persistence, web, tests and migrations"
```

---

### Task 5: Project skills — the GitHub flow and task lifecycle

A personal skill outranks a same-name project skill (Claude Code docs, "Resolve skills that share a name": enterprise over personal over project), so the GitHub flow uses the distinct names `ticket` and `gated-commit` instead of the global GitLab `issue` and `commit`; `pull-request`, `start-task`, `finish-task` and `wiki-*` do not collide, and a skill also wins over a same-name file in `~/.claude/commands/`.

**Files:**
- Create: `.claude/skills/ticket/SKILL.md`, `.claude/skills/gated-commit/SKILL.md`, `.claude/skills/pull-request/SKILL.md`, `.claude/skills/start-task/SKILL.md`, `.claude/skills/finish-task/SKILL.md`

- [ ] **Step 1: Write `ticket/SKILL.md`**

```markdown
---
name: ticket
description: Create a GitHub issue from the task template (EARS acceptance criteria, owned module, verify commands) once the owner approves the preview, then a branch <type>/<n>-<slug> from fresh main. Use when the owner asks for new work and no issue exists yet; the constitution forbids work without an issue. Not for an existing issue (use /start-task).
---

# Create issue and branch

Flow: /ticket → branch → /start-task → work → /gated-commit → /finish-task → /pull-request → squash merge.

`<root>` = `git rev-parse --show-toplevel` of this session (your worktree, not the main checkout).

## Process
1. Ask the type (one question): feat | fix | refactor | test | docs | chore | harness.
2. Draft the body from the task template below. Ask only for what you cannot infer; **Non-goals and Verify must not be empty**.
3. Show the preview; the owner approves it (Yes / Edit / Cancel). Create nothing before a Yes.
4. `gh issue create --title "<Type> title" --label task --label <type> --milestone phase-<n> --body-file <tmp>`
5. `git -C <root> fetch origin main && git -C <root> switch -c <type>/<n>-<slug> origin/main`
   (with Orca, run `orca worktree create --name <type>/<n>-<slug> --base-branch origin/main --issue <n>` instead: one ticket = one worktree.)

## Task template (issue body)
```
## Goal
<one sentence, behaviour change from the user's point of view>

## Context
- Spec: docs/superpowers/specs/<file>#<section> (or "none")
- ADR: <link or "may need one">
- Owned module: <Modulith module, e.g. metadata> (Gradle project `:platform:metadata`) — plus the always-allowed files in CLAUDE.md
- Blocked by: #<n> (or "none")   Blocks: #<n> (or "none")

## Acceptance criteria (EARS)
- WHEN <condition> THE SYSTEM SHALL <result>
- WHEN <error condition> THE SYSTEM SHALL <error response / log>

## Non-goals
- <what this ticket deliberately does not do>

## Verify
- ./scripts/check.sh
- ./scripts/itest.sh

## Size guard
≤400 changed lines, ≤10 files. If exceeded: split into stacked PRs and link them here.

## Risks / Rollback
- <migration reversal or "plain revert">
```

## Labels
`task` always; type label; `harness` for gate/hook work; milestone `phase-<n>`.
```

- [ ] **Step 2: Write `gated-commit/SKILL.md`**

```markdown
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
5. Hangul in staged files other than `README.ko.md` → refuse (English artifacts). Scan them with `LC_ALL=C command grep -l -E $'[\xEA-\xED][\x80-\xBF][\x80-\xBF]'`; plain `grep` may be ugrep in the agent shell and miss byte patterns.
6. Run `./scripts/check.sh`; paste its `RESULT` line into the preview.

## Process
1. Analyse the staged diff, pick type/scope/subject.
2. Show: message, `RESULT` line, `git diff --cached --stat`.
3. Commit: `git -C <root> commit -F <tmpfile>`.
```

- [ ] **Step 3: Write `pull-request/SKILL.md`**

```markdown
---
name: pull-request
description: Push the branch, open the GitHub PR with real evidence, drive the required checks green, and squash-merge only after the owner approves the design review and the merge. Use after /finish-task has committed its records.
---

# Pull request (GitHub, squash only)

`<root>` = `git rev-parse --show-toplevel` of this session (your worktree, not the main checkout).

## Pre-flight
1. On a work branch with commits ahead of `origin/main`.
2. `.harness/state/progress.md` updated in this branch — else stop and update.
3. The branch changes a file under `docs/llm-wiki/wiki/` other than `concepts/lessons.md` (an ADR via /wiki-ingest), or carries a `Wiki-Skip: <reason>` trailer — used only when no decision was made.
4. `git -C <root> push -u origin <branch>`. If the pre-push gate blocks, read its message: guards are fail-closed (fix the code), the wiki gate accepts the trailer.

## Body (from `.github/PULL_REQUEST_TEMPLATE.md`)
- What / Why from the issue.
- Evidence: paste **real** output — last 30 lines of `./scripts/check.sh` and `./scripts/itest.sh`, `git diff --stat origin/main...HEAD`, reviewer/critic findings with disposition.
- Rollback line. `Closes #<n>` (n from the branch name).
- Labels: `test-change` if any file under `src/test|itest|archTest` changed.

## Create and merge
1. `gh pr create --fill-first --body-file <tmp> [--label test-change]`
2. `gh pr checks --watch` until all required checks pass. Log each failing required check with `<root>/.claude/hooks/log-gate-event.sh ci <check> <run url>`, fix, push.
   `claude-review` runs on opened/ready_for_review only: after pushing a fix, re-trigger it with `gh pr ready --undo && gh pr ready`. Fix its blocking items and resolve each review thread you addressed (`gh api graphql`, mutation `resolveReviewThread`; conversation resolution is required).
3. Behind or conflicting with `origin/main`: `git -C <root> merge origin/main` — never rebase and force push (blocked) — keep both sides' entries in state files, re-run `./scripts/check.sh`, push.
4. Ask the owner for the design review (the five items on the PR template's "Owner design review" line) and for explicit merge approval. Merge only after both.
5. Merge. In a worktree: `gh pr merge --squash` (the repo deletes merged branches), then from the main checkout (`<main>` = the first path of `git worktree list`) run `git -C <main> pull --ff-only` and remove the worktree with `orca worktree rm --worktree branch:<branch>` or `git -C <main> worktree remove <path>`.
   Without a worktree: `gh pr merge --squash --delete-branch`, then `git -C <root> switch main && git -C <root> pull --ff-only`.
```

- [ ] **Step 4: Write `start-task/SKILL.md`**

```markdown
---
name: start-task
description: Load a GitHub issue into the session (body, acceptance criteria, owned module), refresh state, and produce a plan or decide to skip planning. Use right after /ticket, or when the owner names an existing issue to work on, before touching any file.
---

# Start task

1. `gh issue view <n> --json title,body,labels,milestone` — read Goal, Context, EARS criteria, Non-goals, Verify, Blocked-by.
   If **Blocked by** names an open issue → stop and report; the ready queue excludes it.
2. Confirm you are on `<type>/<n>-<slug>` and, when parallel, in your own worktree.
3. Re-read `.harness/state/goal.md`, `progress.md` (above the marker), and any ADR the ticket links.
4. Explore the owned module only: existing tests first, then code. Use a subagent for anything wider.
   Before creating files, Read the `.claude/rules/*.md` whose `paths` match them — rules load when a matching file is read, not when one is written.
5. Decide: one-sentence diff → implement directly. Otherwise write a numbered plan (files, tests per EARS line, order), show it, then proceed.
6. Write `.harness/state/goal.md` "Current ticket" block: number, EARS lines, verify commands.
```

- [ ] **Step 5: Write `finish-task/SKILL.md`**

```markdown
---
name: finish-task
description: Close the loop on a ticket once the code is done and check.sh and itest.sh are green — collect evidence, run the independent review, record progress and the counted retro, commit those records, then hand off to /pull-request. Not for work in progress.
---

# Finish task

`<root>` = `git rev-parse --show-toplevel` of this session (your worktree, not the main checkout).

## 1. Evidence (paste real output later into the PR)
- `./scripts/check.sh` → keep the last 30 lines and the `RESULT` line.
- `./scripts/itest.sh` → same.
- `git -C <root> diff --stat origin/main...HEAD` → owned module plus the always-allowed files only? size ≤400 lines? If not, stop and split.

## 2. Independent review
Run `/code-review` for a general pass, then the `critic` subagent: have it apply REVIEW.md's must-check list to `git -C <root> diff origin/main...HEAD`, then attack with: "Do not trust the implementer's claims. Verify by running. Attack: boundary values, null/empty, concurrency, ACL bypass, migration reversibility. Report gaps affecting correctness or requirements only." Fix blocking findings and log each one with `<root>/.claude/hooks/log-gate-event.sh critic <rule> <one line>`; list the rest with disposition.

## 3. Progress
Append to `.harness/state/progress.md` above `<!-- ARCHIVE -->`: `## [YYYY-MM-DD] #<n> <title> ✅` + evidence lines. `#<n>` is the issue number — the PR's `Closes #<n>` links the two; no commit hashes (the squash merge rewrites them).

## 4. Retro → counted lessons (self-improvement loop, spec §10.1)
Answer three questions in one line each and merge into `docs/llm-wiki/wiki/concepts/lessons.md`:
- What was slow? · What did the agent get wrong? · Which rule or check was missing?
If an equivalent lesson exists, increment its `count:` and add the ticket number; otherwise add a new entry with `count: 1`.
A lesson with `count: 3` is due for promotion (weekly routine opens the PR) — do not promote it yourself.

## 5. Decisions
Any decision made → ADR via /wiki-ingest (push gate checks). None → step 6 adds the `Wiki-Skip: no decision` trailer.

## 6. Commit the records
Run `<root>/scripts/publish-events.sh` (copies new gate events from the shared, untracked log into `.harness/events.jsonl`; keep its `RESULT` line), then stage `.harness/state/progress.md`, `docs/llm-wiki/wiki/concepts/lessons.md`, `.harness/events.jsonl` and any ADR, then run /gated-commit; with no decision, put `Wiki-Skip: no decision` in that commit's body.

## 7. Hand off
Run /pull-request.
```

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/ticket .claude/skills/gated-commit .claude/skills/pull-request .claude/skills/start-task .claude/skills/finish-task
git commit -m "feat: add project skills for ticket, gated-commit and the task lifecycle"
```

---

### Task 6: Repo-local LLM wiki and its skills

**Files:**
- Create: `docs/llm-wiki/CLAUDE.md`, `docs/llm-wiki/index.md`, `docs/llm-wiki/log.md`, `docs/llm-wiki/raw/sessions/.gitkeep`, `docs/llm-wiki/wiki/sources/.gitkeep`, `docs/llm-wiki/wiki/concepts/lessons.md`
- Create: `.claude/skills/wiki-ingest/SKILL.md`, `.claude/skills/wiki-query/SKILL.md`, `.claude/skills/wiki-lint/SKILL.md`

- [ ] **Step 1: Write the wiki schema `docs/llm-wiki/CLAUDE.md`**

```markdown
# Vera LLM Wiki — Schema

Karpathy-style LLM wiki, repo-local. `raw/` is immutable source (session excerpts, decisions as recorded);
`wiki/` is owned by the agent and rewritten as knowledge integrates; this file is the schema.
The owner's cross-project wiki (`~/Desktop/llm-wiki`) is a different wiki — never ingest there from here.

```
docs/llm-wiki/
├── CLAUDE.md            this schema
├── index.md             catalogue; read first; every page registered here (no orphans)
├── log.md               append-only: ingest/query/lint history
├── raw/sessions/        YYYY-MM-DD-<slug>.md — immutable
├── raw/inbox/           transcript snapshots from the global hooks (gitignored, consumed by /wiki-ingest)
└── wiki/
    ├── decisions/       ADRs: YYYY-MM-DD-<slug>.md, one decision per file
    ├── concepts/        patterns, traps, lessons.md (counted)
    └── sources/         one stub per raw file: 3–5 claims + pages updated
```

## Page rules
- kebab-case file names, English, frontmatter:
  `type: decision|concept|source` · `project: vera` · `tags: [...]` · `created` · `updated` · `sources: [raw/sessions/...]`
- ADR sections: **Context / Options considered / Decision / Rationale / Accepted costs / Outcome**. Add `author:`.
- Cite evidence: `(raw/sessions/2026-09-30-foo.md)`. Distinguish measured from believed.
- Link pages with `[[decisions/...]]`; new pages get an index line **starting with the date** and ≥1 inbound link.
- Contradictions: mark the old statement `⚠️ (superseded)` and keep it; newest is canonical.

## lessons.md format (feeds the self-improvement loop)
```
### <lesson slug>
count: <n> · tickets: #12, #15 · first: 2026-10-02 · last: 2026-10-09 · status: open|promoted|dropped
what: <one line: what was slow / wrong / missing>
fix: <what a rule, hook, test or lint would look like>
```
`count` ≥ 3 → the weekly routine proposes a promotion PR; on merge the entry becomes `status: promoted` and moves to the bottom.

## Workflows
- **ingest** — `/wiki-ingest`: read index → save raw → source stub → integrate into pages (merge, never overwrite) → index + links → log line.
- **query** — `/wiki-query <question>`: index → pages → answer with citations; new findings are ingested.
- **lint** — `/wiki-lint`: contradictions, stale `updated:`, orphans, index mismatches, lessons past due.
```

- [ ] **Step 2: Write `index.md`, `log.md`, `lessons.md`, keep files**

`docs/llm-wiki/index.md`:

```markdown
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

## Concepts
- 2026-09-30 [[concepts/lessons]] — counted lessons feeding the self-improvement loop (open / promoted / dropped)

## Sources
- 2026-09-30 [[sources/2026-09-30-phase0-design-and-research]] — origin chat + 2026-09 methodology research → spec + D1–D9
```

`docs/llm-wiki/log.md`:

```markdown
# Log (append-only)

## [2026-09-30] bootstrap | wiki created with schema, index, lessons.md, 9 ADRs (D1–D9), 1 source stub
```

`docs/llm-wiki/wiki/concepts/lessons.md`:

```markdown
---
type: concept
project: vera
tags: [harness, self-improvement, lessons]
created: 2026-09-30
updated: 2026-09-30
sources: []
---

# Lessons (counted)

Format and promotion rule: see `docs/llm-wiki/CLAUDE.md` → "lessons.md format". Entries are added by `/finish-task`.
`count ≥ 3` → the weekly `harness-improve` routine opens a proposal PR. Promoted or dropped entries move below the line.

## Open

_(none yet — the first ticket writes the first entry)_

---

## Promoted / dropped
```

```bash
mkdir -p /Users/yu-sun00/Desktop/vera/docs/llm-wiki/raw/sessions /Users/yu-sun00/Desktop/vera/docs/llm-wiki/wiki/sources /Users/yu-sun00/Desktop/vera/docs/llm-wiki/wiki/decisions
touch /Users/yu-sun00/Desktop/vera/docs/llm-wiki/raw/sessions/.gitkeep /Users/yu-sun00/Desktop/vera/docs/llm-wiki/wiki/sources/.gitkeep
```

- [ ] **Step 3: Write the three wiki skills**

`.claude/skills/wiki-ingest/SKILL.md`:

```markdown
---
name: wiki-ingest
description: Ingest decisions, deliverables and reusable know-how from the current work into THIS repo's wiki (docs/llm-wiki). Use when work wraps up, when an ADR is needed, or when the push gate asks for wiki changes. Not for chit-chat.
---

# wiki-ingest (repo wiki: docs/llm-wiki — never the owner's central wiki)

1. Read `docs/llm-wiki/CLAUDE.md` and `docs/llm-wiki/index.md`.
2. Sources: arguments first; otherwise pick from this conversation what is worth revisiting (decisions, measured results, traps, wrong hypotheses).
   Check `docs/llm-wiki/raw/inbox/*.jsonl` (hook snapshots); slice by the owner's local time zone (KST). Delete only the snapshots you consumed.
3. Save raw: `docs/llm-wiki/raw/sessions/YYYY-MM-DD-<slug>.md` (immutable; `-2` suffix if it exists).
4. Source stub: `docs/llm-wiki/wiki/sources/<same-slug>.md` — 3–5 claims + links to pages updated.
5. Integrate: **one decision = one ADR file** `wiki/decisions/YYYY-MM-DD-<slug>.md` (Context / Options / Decision / Rationale / Accepted costs / Outcome, `author:`).
   Concepts merge into existing pages (update `updated:` and `sources:`); contradictions get `⚠️ (superseded)`.
6. Index + links: register new pages (date first), ensure ≥1 inbound link.
7. Log: `## [YYYY-MM-DD] ingest | <title> → N updated, M created` in `docs/llm-wiki/log.md`.
8. Stage `docs/llm-wiki` so the push gate sees it; the caller commits with /gated-commit.
English only. Cite measured evidence; record failed attempts too.
```

`.claude/skills/wiki-query/SKILL.md`:

```markdown
---
name: wiki-query
description: Answer a question from THIS repo's wiki (docs/llm-wiki) with citations — past decisions, traps, lessons. Use before re-deciding anything or when a request may conflict with an ADR.
---

# wiki-query

1. Read `docs/llm-wiki/index.md`; pick candidate pages by title/description (no embeddings).
2. Read only those pages. Answer with `[[page]]` citations and the ADR status (active / superseded).
3. If the answer required knowledge not in the wiki and it is durable, propose `/wiki-ingest`.
4. Append `## [YYYY-MM-DD] query | <question> → <pages>` to `docs/llm-wiki/log.md` only when the answer changed a decision.
```

`.claude/skills/wiki-lint/SKILL.md`:

```markdown
---
name: wiki-lint
description: Health-check THIS repo's wiki (docs/llm-wiki) — contradictions, stale pages, orphans, index mismatches, lessons past their promotion threshold. Use monthly (harness-improve routine) or when the index feels wrong.
---

# wiki-lint

Report, then fix what is mechanical:
1. Index ↔ files: every `wiki/**/*.md` registered? every index line has a file?
2. Orphans: pages with no inbound `[[link]]`.
3. Contradictions: same topic, different claims → newest canonical, old marked `⚠️ (superseded)`.
4. Stale: `updated:` older than 90 days on a page whose subject changed in git since.
5. Lessons: entries with `count ≥ 3` and `status: open` → list them as "due for promotion".
6. Raw inbox: snapshots older than 14 days → list for deletion.
Write `## [YYYY-MM-DD] lint | <n> issues, <m> fixed` to `docs/llm-wiki/log.md`.
```

- [ ] **Step 4: Commit**

```bash
git add docs/llm-wiki .claude/skills/wiki-ingest .claude/skills/wiki-query .claude/skills/wiki-lint
git commit -m "docs: add repo-local LLM wiki schema, index, counted lessons and wiki skills"
```

---

### Task 7: Push gate — `.githooks/pre-push` and `scripts/guards.sh`

**Files:**
- Create: `scripts/guards.sh`, `.githooks/pre-push`
- Modify: `.gitattributes` (union merge for the two append-only shared files)

- [ ] **Step 1: Write `scripts/guards.sh` (fail-closed constitution guards)**

```bash
#!/usr/bin/env bash
# guards.sh [<base> <head>] — constitution guards over a commit range (default origin/main..HEAD). Fail-closed.
# Exit 0 = pass, 1 = violation, 2 = cannot judge (not a checkout, a ref that does not resolve, a failing git command).
# Each failure prints WHAT is wrong and HOW to fix it (the message is an instruction to the agent).
set -uo pipefail
# Check pipelines end in a reader that consumes all input (grep ... >/dev/null, never grep -q): under pipefail an early
# exit kills the writer with SIGPIPE on a large diff or log, and a match would read as a miss.
# ROOT: the script's own checkout, else the working directory (CI runs the base commit's copy from outside the
# checkout). GIT_DIR is dropped for that lookup only: git exports it to hooks in a worktree, and with it set
# 'git -C <dir> rev-parse --show-toplevel' answers <dir> itself, so the event log path would point nowhere.
ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "guards: not inside a git checkout" >&2; exit 2; }
LOG="$ROOT/.claude/hooks/log-gate-event.sh"
die() { echo "guards: $1" >&2; exit 2; }
BASE="${1:-refs/remotes/origin/main}"; HEAD_="${2:-HEAD}"
# No fallback base: the root commit made the range all of history and blamed files nobody touched.
for ref in "$BASE" "$HEAD_"; do
  git -C "$ROOT" rev-parse --verify -q "$ref^{commit}" >/dev/null || die "cannot resolve '$ref' — run: git fetch origin main"
done
RANGE="$BASE..$HEAD_"
fail=0
violation() { echo "✖ $1"; echo "  → $2"; "$LOG" pre-push-guard "$3" "$1"; fail=1; }
# Content diffs are raw text whatever the repository says: a PR's '.gitattributes' with '*.kt -diff' (or a textconv,
# an external diff or color.diff=always) would otherwise hide added lines from checks 3, 6, 7 and 9.
DIFF=(--text --no-color --no-ext-diff --no-textconv)
# A trailer counts only with a reason after the colon ('Test-Change:' alone excuses nothing).
trailer() { printf '%s\n' "$messages" | grep -E "^$1:[[:space:]]*[^[:space:]]" >/dev/null; }

changed="$(git -C "$ROOT" diff --name-only "$BASE" "$HEAD_")" || die "git diff $RANGE failed"
[ -z "$changed" ] && { echo "guards: empty range, pass"; exit 0; }
messages="$(git -C "$ROOT" log --format=%B "$RANGE")" || die "git log $RANGE failed"

# 1. Deleted test files without a Test-Change trailer (with the trailer the deletion is accepted and nothing is logged)
deleted="$(git -C "$ROOT" diff --diff-filter=D --name-only "$BASE" "$HEAD_")" || die "git diff $RANGE failed"
deleted_tests="$(echo "$deleted" | grep -E 'src/(test|itest|archTest)/.*\.kt$' || true)"
if [ -n "$deleted_tests" ] && ! trailer Test-Change; then
  violation "test files deleted: $(echo "$deleted_tests" | tr '\n' ' ')" \
    "Restore them. If a test is genuinely obsolete, explain in the commit body and add the trailer 'Test-Change: <reason>'." deleted-test-file
elif [ -n "$deleted_tests" ]; then
  echo "  (Test-Change trailer present — deletion accepted)"
fi

# 2. Net assertion decrease without Test-Change trailer (git grep exits 1 when nothing matches; 2 or more is a failure)
count_asserts() {
  local out
  out="$(git -C "$ROOT" grep --text -c -E 'assertThat\(|assertThrows|assertThatThrownBy|assertTrue\(|assertFalse\(|assertEquals\(' "$1" -- '*/src/test/*' '*/src/itest/*' '*/src/archTest/*')"
  [ $? -le 1 ] || die "git grep $1 failed"
  printf '%s\n' "$out" | awk -F: '{s+=$NF} END {print s+0}'
}
before="$(count_asserts "$BASE")" || exit 2; after="$(count_asserts "$HEAD_")" || exit 2
if [ "$after" -lt "$before" ] && ! trailer Test-Change; then
  violation "assertions decreased $before → $after" "Restore the assertions, or justify with a 'Test-Change: <reason>' trailer." assertion-decrease
fi

# 3. New suppression in any Kotlin or Java source, tests included: @Suppress, @file:Suppress, @SuppressWarnings, @[Suppress(...)]
src_diff="$(git -C "$ROOT" diff "${DIFF[@]}" "$BASE" "$HEAD_" -- '*/src/*.kt' '*/src/*.java')" || die "git diff $RANGE failed"
if printf '%s\n' "$src_diff" | grep -E '^\+.*Suppress(Warnings)?\(' >/dev/null; then
  violation "new suppression under src/ (@Suppress, @file:Suppress, @SuppressWarnings or @[Suppress(...)])" "Fix the reported issue instead of suppressing it: a suppression hides findings in tests as much as in production code. The array form @[Suppress(...)] counts too: detekt honours it and ktfmt keeps it. If the rule is wrong, change config/detekt/detekt.yml in a harness ticket." new-suppress
fi

# 4. detekt baseline files (detekt 2.x names them per source set, e.g. detekt-baseline-main.xml)
if echo "$changed" | grep -E 'detekt-baseline[^/]*\.xml$' >/dev/null; then
  violation "detekt baseline file added" "Delete it. Baselines hide debt from the gates (CLAUDE.md Forbidden)." detekt-baseline
fi

# 5. Merged migrations edited (modified, not added)
modified="$(git -C "$ROOT" diff --diff-filter=M --name-only "$BASE" "$HEAD_")" || die "git diff $RANGE failed"
edited_mig="$(echo "$modified" | grep -E 'db/migration/V.*\.sql$' || true)"
[ -n "$edited_mig" ] && violation "merged migration edited: $(echo "$edited_mig" | tr '\n' ' ')" \
  "Revert the edit and add a new V<yyyyMMdd>_<hhmm>__<slug>.sql that fixes forward." migration-edited

# 6. Hangul added to committed artifacts or written in the range's commit messages (English-only, D1) — README.ko.md
#    is the sole exception. Only lines the range adds count: a file that already holds Korean (Plan A embeds
#    README.ko.md) stays editable. awk tags each added line with its file ('+++ <path>' header; -M keeps a pure rename
#    free of added lines), grep matches. Portable byte-range match (macOS grep has no -P): UTF-8 lead bytes EA–ED cover
#    U+A000–U+D7FF incl. Hangul syllables; E3 84–86 the compatibility jamo; E1 84–87 the Hangul Jamo block.
HANGUL=$'([\xEA-\xED][\x80-\xBF][\x80-\xBF]|\xE3[\x84-\x86][\x80-\xBF]|\xE1[\x84-\x87][\x80-\xBF])'
added="$(git -C "$ROOT" diff "${DIFF[@]}" -M --no-prefix "$BASE" "$HEAD_" -- . ':(exclude)README.ko.md' ':(exclude)docs/research/')" \
  || die "git diff $RANGE failed"
hangul="$(printf '%s\n' "$added" \
  | LC_ALL=C awk '/^diff --git /{h=1} h && /^\+\+\+ /{f=substr($0, 5)} /^@@/{h=0} !h && /^\+/{print f "\t" $0}' \
  | LC_ALL=C grep -E $'\t\\+.*'"$HANGUL" | cut -f1 | sort -u || true)"
[ -n "$hangul" ] && violation "Korean text added in: $(echo "$hangul" | tr '\n' ' ')" \
  "Committed artifacts are English (ADR D1). Translate, or move the text to the owner's central wiki." non-english
if printf '%s\n' "$messages" | LC_ALL=C grep -E "$HANGUL" >/dev/null; then
  violation "Korean text in a commit message of $RANGE" \
    "Commit messages are English (ADR D1). Reword the commit (git commit --amend -F <file> for the last one)." non-english
fi

# 7. Secrets
all_diff="$(git -C "$ROOT" diff "${DIFF[@]}" "$BASE" "$HEAD_")" || die "git diff $RANGE failed"
if printf '%s\n' "$all_diff" | grep -E '^\+' | grep -E 'AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[0-9A-Za-z]{36,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[0-9A-Za-z-]{10,}|sk-ant-[A-Za-z0-9_-]{20,}' >/dev/null; then
  violation "secret-like literal added" "Remove it, rotate the credential, load it from the environment." secret-literal
fi

# 8. New production .kt without any test change in the range (test pair)
added_files="$(git -C "$ROOT" diff --diff-filter=A --name-only "$BASE" "$HEAD_")" || die "git diff $RANGE failed"
new_prod="$(echo "$added_files" | grep -E 'src/main/kotlin/.*\.kt$' | grep -v -E 'Module\.kt$|package-info' || true)"
tests_touched="$(echo "$changed" | grep -E 'src/(test|itest|archTest)/' || true)"
if [ -n "$new_prod" ] && [ -z "$tests_touched" ]; then
  violation "new production Kotlin without tests: $(echo "$new_prod" | tr '\n' ' ')" \
    "Add the tests in this PR (DoD item 1). Every acceptance criterion maps to a test." missing-test-pair
fi

# 9. detekt touched outside the root build script: one module line (actions.clear(), which also drops
#    DetektGateGuard, enabled = false, setSource(files())) would switch the gate off and still exit 0.
gradle_diff="$(git -C "$ROOT" diff "${DIFF[@]}" "$BASE" "$HEAD_" -- '*.gradle.kts' ':(exclude)build.gradle.kts')" || die "git diff $RANGE failed"
detekt_lines="$(printf '%s\n' "$gradle_diff" | grep -E '^\+[^+]' | grep -E '[Dd]etekt' || true)"
[ -n "$detekt_lines" ] && violation "detekt configured outside the root build.gradle.kts: $(echo "$detekt_lines" | head -3 | tr '\n' ' ')" \
  "detekt is configured only in the root build.gradle.kts (Plan A Task 3); move the change there in a harness ticket." detekt-outside-root

if [ $fail -eq 0 ]; then echo "guards: pass ($RANGE)"; fi
exit $fail
```

- [ ] **Step 2: Write `.githooks/pre-push`**

```bash
#!/usr/bin/env bash
# pre-push — constitution guards (fail-closed) then the wiki gate (fail-open with 'Wiki-Skip: <reason>' trailer).
# Installed by .claude/hooks/inject-state.sh via core.hooksPath. Both halves log through .claude/hooks/log-gate-event.sh.
set -u
ROOT="$(git rev-parse --show-toplevel)"
LOG="$ROOT/.claude/hooks/log-gate-event.sh"
Z40="0000000000000000000000000000000000000000"

while read -r local_ref local_sha remote_ref remote_sha; do
  [ -z "${local_ref:-}" ] && continue
  case "$remote_ref" in refs/heads/*) ;; *) continue ;; esac          # tags/notes pass
  if [ "$remote_ref" = refs/heads/main ]; then                          # main changes only through a reviewed PR
    "$LOG" pre-push-guard push-to-main "$local_ref -> $remote_ref"
    echo "✖ pushes to main are refused — push your branch and open a PR (/pull-request)." >&2
    exit 1
  fi
  [ "$local_sha" = "$Z40" ] && continue                                 # deletions pass
  # Base = where the branch leaves main, on every push (never $remote_sha): after 'git merge origin/main'
  # the old remote tip would pull other PRs' commits, trailers and deletions into the range. No merge-base →
  # empty base → guards.sh falls back to origin/main and, if that does not resolve either, asks for a fetch.
  base="$(git merge-base refs/remotes/origin/main "$local_sha" 2>/dev/null)"

  # --- guards: fail-closed ---
  if [ -x "$ROOT/scripts/guards.sh" ]; then
    if ! "$ROOT/scripts/guards.sh" "$base" "$local_sha" >&2; then
      echo "" >&2; echo "✖ constitution guards failed — nothing was pushed." >&2
      exit 1
    fi
  else
    echo "pre-push: scripts/guards.sh missing or not executable — refusing to push without guards" >&2
    exit 1
  fi

  # --- wiki gate: fail-open ---
  # concepts/lessons.md does not count: /finish-task edits it on every branch, so it would pass every range.
  if ! git diff --quiet "$base" "$local_sha" -- docs/llm-wiki/wiki/ ':(exclude)docs/llm-wiki/wiki/concepts/lessons.md' 2>/dev/null; then
    continue                                                            # wiki page or ADR changed → fine
  fi
  if git log --format=%B "$base..$local_sha" 2>/dev/null | grep -q '^Wiki-Skip:[[:space:]]*[^[:space:]]'; then   # needs a reason
    "$LOG" wiki-gate skipped-with-trailer "$(git log --format=%B "$base..$local_sha" | grep -m1 '^Wiki-Skip:[[:space:]]*[^[:space:]]')"
    continue
  fi
  # code-only ranges without decisions are common; block only when the range touched source or harness
  if git diff --name-only "$base" "$local_sha" | grep -qE '^(platform|apps|ingestion|bootstrap|\.claude|\.githooks|scripts|CLAUDE\.md)'; then
    "$LOG" wiki-gate blocked-no-wiki-change "$remote_ref"
    echo "🛑 wiki gate: this range changes code or harness but no file under docs/llm-wiki/wiki/ (concepts/lessons.md alone does not count)." >&2
    echo "   Run /wiki-ingest (each decision → an ADR in docs/llm-wiki/wiki/decisions/), or add a commit trailer 'Wiki-Skip: <reason>' if truly nothing was decided." >&2
    exit 1
  fi
done
exit 0
```

- [ ] **Step 3: Union-merge the append-only shared files**

Parallel PRs each append to `.harness/events.jsonl` and `.harness/state/progress.md`; git's built-in `union` merge driver keeps the lines of both sides instead of raising a conflict. Append to `.gitattributes` (from Plan A):

```text
.harness/events.jsonl merge=union
.harness/state/progress.md merge=union
```

- [ ] **Step 4: Install, test the gates with real input, commit**

```bash
chmod +x /Users/yu-sun00/Desktop/vera/scripts/guards.sh /Users/yu-sun00/Desktop/vera/.githooks/pre-push
git -C /Users/yu-sun00/Desktop/vera config core.hooksPath .githooks
/Users/yu-sun00/Desktop/vera/scripts/guards.sh origin/main HEAD; echo exit=$?
/Users/yu-sun00/Desktop/vera/scripts/test-hooks.sh; echo exit=$?
```

Expected: `guards: pass (...)`, `exit=0`; test-hooks all `PASS`, `exit=0`.

Negative test (must fail, then undo). It runs on the work branch with the new files still unstaged, so the probe commit holds only the deletion:

```bash
git -C /Users/yu-sun00/Desktop/vera switch -c tmp/guard-negative
git -C /Users/yu-sun00/Desktop/vera rm -q platform/metadata/src/test/kotlin/com/brokenfinger/vera/metadata/domain/TableNameTest.kt
printf 'test: negative guard probe\n' | git -C /Users/yu-sun00/Desktop/vera commit -q -F -
/Users/yu-sun00/Desktop/vera/scripts/guards.sh chore/phase-0-b-harness HEAD; echo exit=$?
git -C /Users/yu-sun00/Desktop/vera switch -q chore/phase-0-b-harness && git -C /Users/yu-sun00/Desktop/vera branch -qD tmp/guard-negative
tail -2 /Users/yu-sun00/Desktop/vera/.harness/events.jsonl
```

Expected: two `✖` lines (`test files deleted`, `assertions decreased`), `exit=1`, and two `pre-push-guard` events in the log. Keep those two events: they are the first real evidence of a gate firing.

The same deletion with a `Test-Change:` trailer is accepted and logs nothing:

```bash
git -C /Users/yu-sun00/Desktop/vera switch -c tmp/guard-trailer
git -C /Users/yu-sun00/Desktop/vera rm -q platform/metadata/src/test/kotlin/com/brokenfinger/vera/metadata/domain/TableNameTest.kt
printf 'test: trailer guard probe\n\nTest-Change: probe\n' | git -C /Users/yu-sun00/Desktop/vera commit -q -F -
wc -l < /Users/yu-sun00/Desktop/vera/.harness/events.jsonl
/Users/yu-sun00/Desktop/vera/scripts/guards.sh chore/phase-0-b-harness HEAD; echo exit=$?
wc -l < /Users/yu-sun00/Desktop/vera/.harness/events.jsonl
git -C /Users/yu-sun00/Desktop/vera switch -q chore/phase-0-b-harness && git -C /Users/yu-sun00/Desktop/vera branch -qD tmp/guard-trailer
```

Expected: `(Test-Change trailer present — deletion accepted)`, `guards: pass (...)`, `exit=0`, the same line count twice.

The push gate itself, run from the repository root with the stdin line git sends for the first push of this branch:

```bash
printf '%s %s %s %s\n' refs/heads/chore/phase-0-b-harness "$(git -C /Users/yu-sun00/Desktop/vera rev-parse HEAD)" refs/heads/chore/phase-0-b-harness 0000000000000000000000000000000000000000 | /Users/yu-sun00/Desktop/vera/.githooks/pre-push origin https://github.com/BrokenFinger98/vera.git; echo exit=$?
```

Expected: `guards: pass (...)`, `exit=0` (the branch adds ADRs under `docs/llm-wiki/wiki/decisions/`).

```bash
git add scripts/guards.sh .githooks/pre-push .gitattributes .harness/events.jsonl
git commit -m "chore: add fail-closed constitution guards and pre-push wiki gate"
```

---

### Task 8: GitHub templates and workflows (test guard, Claude review, harness routine)

**Files:**
- Create: `.github/CODEOWNERS`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/task.yml`, `.github/ISSUE_TEMPLATE/config.yml`, `.github/workflows/test-guard.yml`, `.github/workflows/claude-review.yml`, `.github/workflows/harness-improve.yml`

- [ ] **Step 1: Write `CODEOWNERS`, PR template, issue template**

`.github/CODEOWNERS`:

```text
# Harness and decisions need the owner's eyes even when an agent opens the PR.
/CLAUDE.md                 @BrokenFinger98
/REVIEW.md                 @BrokenFinger98
/.claude/                  @BrokenFinger98
/.githooks/                @BrokenFinger98
/.github/                  @BrokenFinger98
/scripts/                  @BrokenFinger98
/docs/llm-wiki/wiki/decisions/  @BrokenFinger98
/config/detekt/            @BrokenFinger98
# Attributes decide how diffs and merges treat files (guards.sh diffs with --text; merge drivers still apply).
/.gitattributes            @BrokenFinger98
# Build scripts can switch a gate off in one line (guards.sh check 9 is the machine half).
/build.gradle.kts          @BrokenFinger98
*.gradle.kts               @BrokenFinger98
/gradle/                   @BrokenFinger98
```

`.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## What

## Why
Closes #

## Evidence (real output — not intentions)
<details><summary>./scripts/check.sh (last 30 lines)</summary>

```
```
</details>
<details><summary>./scripts/itest.sh (last 30 lines)</summary>

```
```
</details>

```
git diff --stat origin/main...HEAD
```

Reviewer / critic findings and disposition:
-

## Definition of Done
- [ ] Every acceptance criterion in the issue has a test
- [ ] `check.sh` and `itest.sh` output above, exit 0
- [ ] Only the owned module changed, plus the always-allowed files in CLAUDE.md (or split rationale below)
- [ ] ≤ 400 changed lines, one behaviour change
- [ ] `Test-Change:` trailer if tests were deleted or assertions reduced; label `test-change` if `src/test|itest|archTest` touched
- [ ] ADR / module spec updated, or "no decision made"
- [ ] `.harness/state/progress.md` updated in this branch (issue `#<n>`)
- [ ] Rollback: <migration reversal or "plain revert suffices">
- [ ] Owner design review: module boundaries · domain language · ADR needed? · migration reversible · no PII in logs
```

`.github/ISSUE_TEMPLATE/task.yml`:

```yaml
name: Task
description: One behaviour change, one PR, ≤400 lines. Filled by /ticket.
labels: ["task"]
body:
  - type: input
    id: goal
    attributes:
      label: Goal
      description: One sentence, behaviour change from the user's point of view
    validations:
      required: true
  - type: textarea
    id: context
    attributes:
      label: Context
      value: |
        - Spec:
        - ADR:
        - Owned module (Modulith module + Gradle project):
        - Blocked by:   Blocks:
    validations:
      required: true
  - type: textarea
    id: acceptance
    attributes:
      label: Acceptance criteria (EARS)
      value: |
        - WHEN <condition> THE SYSTEM SHALL <result>
        - WHEN <error condition> THE SYSTEM SHALL <error response / log>
    validations:
      required: true
  - type: textarea
    id: nongoals
    attributes:
      label: Non-goals
    validations:
      required: true
  - type: textarea
    id: verify
    attributes:
      label: Verify (commands the agent must run)
      value: |
        - ./scripts/check.sh
        - ./scripts/itest.sh
    validations:
      required: true
  - type: textarea
    id: risks
    attributes:
      label: Risks / Rollback
```

`.github/ISSUE_TEMPLATE/config.yml`:

```yaml
blank_issues_enabled: false
```

- [ ] **Step 2: Write `test-guard.yml` (test-change label, constitution guards as a required check)**

```yaml
name: test-guard

on:
  pull_request:
    types: [opened, synchronize, reopened, labeled, unlabeled]

permissions:
  contents: read
  pull-requests: read

# base.sha is the base branch tip, not where the PR left it: both jobs diff from the merge-base,
# so commits merged into main after the PR branched never count as changes of this PR.
jobs:
  label-required-when-tests-change:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - name: Require label test-change when test sources change
        env:
          GH_TOKEN: ${{ github.token }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
        run: |
          BASE="$(git merge-base "$BASE_SHA" "$HEAD_SHA")"
          changed="$(git diff --name-only "$BASE" "$HEAD_SHA" | grep -E 'src/(test|itest|archTest)/' || true)"
          if [ -z "$changed" ]; then echo "no test sources changed"; exit 0; fi
          labels="$(gh pr view "$PR_NUMBER" --json labels --jq '.labels[].name')"
          if echo "$labels" | grep -qx 'test-change'; then echo "label present"; exit 0; fi
          echo "::error::Test sources changed but label 'test-change' is missing. Explain the test change in the PR and add the label."
          echo "$changed"
          exit 1

  guards:
    name: guards (constitution, fail-closed)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0    # full history: a shallow clone has no merge-base, and guards.sh reads an empty range as a pass
      # The pre-push hook runs the same script; this required check also covers pushes that skipped the hook.
      # It runs the base commit's copy, so a PR that weakens scripts/guards.sh cannot pass its own check.
      - name: Run the base commit's scripts/guards.sh over the PR range
        env:
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
        run: |
          BASE="$(git merge-base "$BASE_SHA" "$HEAD_SHA")"
          guards="$RUNNER_TEMP/guards.sh"
          if ! git show "$BASE:scripts/guards.sh" > "$guards" 2>/dev/null; then
            echo "::notice::The base commit has no scripts/guards.sh; running the PR's own copy."
            guards=scripts/guards.sh
          fi
          bash "$guards" "$BASE" "$HEAD_SHA"
```

The guards job runs the merge-base's copy of `scripts/guards.sh` from `$RUNNER_TEMP`, so a PR that weakens the script cannot pass its own required check; only the PR that introduces the script, whose base has none, runs its own copy.

- [ ] **Step 3: Write `claude-review.yml`**

```yaml
name: claude-review

on:
  pull_request:
    types: [opened, ready_for_review]

permissions:
  contents: read
  pull-requests: write
  issues: read
  id-token: write

jobs:
  review:
    if: github.event.pull_request.draft == false
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          # harness-improve opens its PRs as claude[bot]; the action fails runs started by bots it does not list.
          allowed_bots: claude
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}

            Review this pull request under the contract in REVIEW.md. Read CLAUDE.md for the immutable
            decisions and the forbidden list, and the linked issue for the acceptance criteria
            ("Closes #<n>" in the PR body; read it with gh issue view <n>). Read the change with gh pr view
            and gh pr diff. The action restores CLAUDE.md and .claude/ from the base branch before you start;
            the PR's own versions are in the diff and under .claude-pr/.
            Report only correctness, requirement, security and boundary findings.
            Post each finding as an inline comment on its line with mcp__github_inline_comment__create_inline_comment:
            the severity, then one sentence.
            Then post ONE summary comment with gh pr comment: the findings grouped by severity, with path:line,
            one sentence each, ending with the line "verdict: approve" or "verdict: request-changes".
          claude_args: |
            --max-turns 20
            --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*),Bash(gh issue view:*)"
```

`allowed_bots: claude` lets the review run on the routine's PRs: harness-improve opens them as `claude[bot]`, and the action fails any run started by a bot it does not list (it compares names without the `[bot]` suffix).

- [ ] **Step 4: Write `harness-improve.yml` (weekly promote, monthly prune — proposal PRs and issues only)**

```yaml
name: harness-improve

on:
  schedule:
    - cron: '0 21 * * 0'    # Monday 06:00 KST — weekly promotion pass
    - cron: '0 22 1 * *'    # 1st of month 07:00 KST — monthly prune pass
  workflow_dispatch:
    inputs:
      mode:
        description: promote | prune
        default: promote

permissions:
  contents: write
  pull-requests: write
  issues: read
  actions: read
  id-token: write

jobs:
  improve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      # The repo's .claude/settings.json hooks run inside the action: the Stop gate runs check.sh on source changes.
      - uses: actions/setup-java@v6
        with:
          distribution: temurin
          java-version: '25'
      - uses: gradle/actions/setup-gradle@v6
      - name: Decide mode
        id: mode
        env:
          INPUT_MODE: ${{ github.event.inputs.mode }}
          SCHEDULE: ${{ github.event.schedule }}
        run: |
          mode="promote"
          [ "$SCHEDULE" = "0 22 1 * *" ] && mode="prune"
          [ -n "$INPUT_MODE" ] && mode="$INPUT_MODE"
          echo "mode=$mode" >> "$GITHUB_OUTPUT"
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          # gh runs on the action's GitHub App token; gh run list (CI failures) needs actions: read on it.
          additional_permissions: |
            actions: read
          claude_args: |
            --max-turns 40
            --allowedTools "Read,Glob,Grep,Edit,Write,Bash(./scripts/check.sh),Bash(jq:*)"
            --allowedTools "Bash(git switch:*),Bash(git add:*),Bash(git commit:*),Bash(git push:*)"
            --allowedTools "Bash(git status:*),Bash(git diff:*),Bash(git log:*),Bash(git show:*)"
            --allowedTools "Bash(gh pr create:*),Bash(gh pr list:*),Bash(gh issue create:*),Bash(gh issue list:*),Bash(gh run list:*)"
          prompt: |
            You run the Vera self-improvement loop (docs/superpowers/specs/2026-09-30-vera-dev-environment-design.md §10.1).
            Mode: ${{ steps.mode.outputs.mode }}. You may open pull requests and issues; you MUST NOT merge anything.

            Read .harness/events.jsonl, docs/llm-wiki/wiki/concepts/lessons.md, CLAUDE.md, .claude/rules/*.md,
            config/detekt/detekt.yml, scripts/guards.sh, .claude/hooks/*.sh.

            Proposal rules:
              - Skip an item that already has an open PR or issue (gh pr list, gh issue list).
              - Claude Code denies your writes under .claude/ in this run, so a proposal that touches .claude/rules/ or
                .claude/hooks/ is ONE issue: label harness, title "harness: promote <slug>" (prune: "harness: prune <yyyymmdd>"),
                body = the evidence and the exact patch as a fenced diff, applied later in a local ticket session.
                Every other proposal is a pull request.
              - A pull request gets its own branch from origin/main, named harness/promote-<slug> or harness/prune-<yyyymmdd>
                (CLAUDE.md exempts these branches from the issue rule), label harness, plus test-change when it touches
                src/test, src/itest or src/archTest.
              - Every commit either changes a page under docs/llm-wiki/wiki/ other than concepts/lessons.md or carries the
                trailer "Wiki-Skip: harness-improve proposal" (the pre-push gate checks this).
              - Before committing a change to Kotlin, Gradle or detekt files, run ./scripts/check.sh and put its RESULT lines
                in the PR body (the Stop gate does not cover committed changes).
              - Write commit messages and PR and issue bodies to files under build/harness-improve/ (git ignores build/) and
                pass them with git commit -F and --body-file. No AI attribution in commits, PRs or issues.

            If mode is promote:
              - Find lessons with count >= 3 and status open, and gate rules that fired >= 3 times for the same cause in the last 30 days.
              - For EACH such item open exactly ONE proposal for exactly one of: a CLAUDE.md line, a .claude/rules/<file>.md entry,
                a detekt or ArchUnit rule, a guards.sh/hook pattern, or a test. Cite the event lines and lesson entry, and mark
                the lesson status: promoted (pending) in the same pull request or in the issue's patch.
              - If nothing qualifies, do nothing and print "promote: nothing due".
            If mode is prune:
              - List every rule, hook pattern and CLAUDE.md line that has zero related events in .harness/events.jsonl for the last 30 days
                and is not marked "keep:" with a reason. Run the checks in .claude/skills/wiki-lint/SKILL.md and check CLAUDE.md
                for content derivable from code.
              - Propose the deletions in ONE pull request on branch harness/prune-<yyyymmdd> (those under .claude/ in ONE issue),
                one bullet per item with the evidence (no firing in 30 days). Never delete block-danger patterns for destructive commands.
              - Append a weekly metrics line to .harness/metrics.md (merged PRs, gate firings by rule, critic blocking count, CI failures)
                computed from git log, events.jsonl, gh pr list --state merged and gh run list.
            Write in English. Keep each PR under 100 changed lines.
```

Proposals that touch `.claude/rules/` or `.claude/hooks/` are issues because Claude Code never auto-approves writes under `.claude/` in the action's headless default mode: allow rules and `acceptEdits` leave them denied, only `bypassPermissions` would pass them, and the owner keeps that mode out of CI.

Before committing, check the inputs both Claude workflows use against the action's current `action.yml`, then parse every template and workflow:

Run: `curl -sL https://raw.githubusercontent.com/anthropics/claude-code-action/main/action.yml | grep -E '^  (prompt|claude_code_oauth_token|claude_args|additional_permissions|allowed_bots):'`
Expected: five lines. If one is missing, adapt the `with:` blocks to the current input names and note it in progress.md.

Run: `python3 -c 'import sys, yaml; [yaml.safe_load(open(f)) for f in sys.argv[1:]]; print("yaml ok")' .github/ISSUE_TEMPLATE/*.yml .github/workflows/*.yml`
Expected: `yaml ok`.

- [ ] **Step 5: Owner — install the Claude GitHub App and set the OAuth token secret; commit**

The owner runs the setup and the agent never handles the token value. Install https://github.com/apps/claude on `BrokenFinger98/vera` (the action trades the job's OIDC token for the App's installation token), then run `claude setup-token` locally and `gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo BrokenFinger98/vera`, pasting the token at the prompt.
Expected: `gh secret list --repo BrokenFinger98/vera` lists `CLAUDE_CODE_OAUTH_TOKEN`. Neither Claude workflow runs on the PR that adds it: the action skips a workflow that is not on the default branch yet.

```bash
git add .github
git commit -m "ci: add PR guards, Claude PR review and the harness-improve routine; PR and issue templates"
```

---

### Task 9: The three saved fan-out workflows (D8)

Workflow scripts use the Dynamic Workflows API (`meta`, `agent()`, `parallel()`, `pipeline()`). Load the `workflow-authoring` skill before executing this task and adjust only API details if the reference differs; the shape below is the contract.
Runtime behaviour verified 2026-10-02: `agent()` returns null when its agent dies or is skipped, `parallel()` resolves a failed thunk to null and a `pipeline()` stage that throws drops its item to null, so every result is null-guarded before it is dereferenced. `meta` must be a pure literal, and scripts are plain JavaScript without `Date.now()`, `Math.random()` or an argless `new Date()`.

**Files:**
- Create: `.claude/workflows/audit-consistency.js`, `.claude/workflows/release-review.js`, `.claude/workflows/deep-research.js`

- [ ] **Step 1: Write `audit-consistency.js`**

```javascript
export const meta = {
  name: 'audit-consistency',
  description: 'Fan out over every web endpoint: verify ACL injection and metadata consistency, then adversarially verify each finding',
  phases: [{ title: 'Inventory' }, { title: 'Audit' }, { title: 'Verify' }],
}

const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' }, file: { type: 'string' }, line: { type: 'number' },
          kind: { type: 'string', enum: ['acl-bypass', 'metadata-inconsistency', 'unvalidated-identifier', 'other'] },
          evidence: { type: 'string' },
        },
        required: ['title', 'file', 'kind', 'evidence'],
      },
    },
  },
  required: ['findings'],
}
const VERDICT = {
  type: 'object',
  properties: { isReal: { type: 'boolean' }, reproduction: { type: 'string' }, severity: { type: 'string', enum: ['blocking', 'major', 'minor'] } },
  required: ['isReal', 'reproduction', 'severity'],
}

const inventory = await agent(
  'List every HTTP endpoint (controller class, method, path) under **/internal/web/** in this repository. Return JSON {"endpoints":[{"file":"","method":"","path":""}]}.',
  { label: 'inventory', phase: 'Inventory', schema: { type: 'object', properties: { endpoints: { type: 'array', items: { type: 'object', properties: { file: { type: 'string' }, method: { type: 'string' }, path: { type: 'string' } }, required: ['file', 'method', 'path'] } } }, required: ['endpoints'] } },
)
if (!inventory) {
  return { error: 'The inventory agent returned nothing, so no endpoint was audited. Run the workflow again.' }
}

const results = await pipeline(
  inventory.endpoints,
  (e) => agent(
    `Audit endpoint ${e.method} ${e.path} in ${e.file}. Check: (1) every query it triggers goes through the query module so ACL conditions are injected; (2) table/field names come from TableName/FieldName value objects; (3) metadata reads and writes happen in one transaction. Report findings with file:line and evidence. No style comments.`,
    { label: `audit:${e.path}`, phase: 'Audit', schema: FINDINGS },
  ),
  (audit) => parallel(((audit && audit.findings) || []).map((f) => () =>
    agent(
      `Adversarially verify this finding by reading the code and, if possible, writing a throwaway test: ${JSON.stringify(f)}. Do not trust the auditor. Return isReal, a reproduction, and severity.`,
      { label: `verify:${f.title}`, phase: 'Verify', schema: VERDICT },
    ).then((v) => ({ ...f, verdict: v })),
  )),
)

const confirmed = results.flat().filter(Boolean).filter((f) => f.verdict?.isReal)
return { endpoints: inventory.endpoints.length, confirmed }
```

- [ ] **Step 2: Write `release-review.js`**

```javascript
export const meta = {
  name: 'release-review',
  description: 'Before a release tag: one reviewer per changed file since the last tag, findings ranked and merged',
  phases: [{ title: 'Review' }, { title: 'Rank' }],
}

const FILE_FINDINGS = {
  type: 'object',
  properties: { findings: { type: 'array', items: { type: 'object', properties: { file: { type: 'string' }, line: { type: 'number' }, severity: { type: 'string', enum: ['blocking', 'major', 'minor'] }, summary: { type: 'string' } }, required: ['file', 'severity', 'summary'] } } },
  required: ['findings'],
}

const files = (args && args.files) || []
if (files.length === 0) {
  return { error: 'Pass args.files: output of `git diff --name-only $(git describe --tags --abbrev=0)..HEAD -- "*.kt" "*.sql"`' }
}

const perFile = await parallel(files.map((file) => () =>
  agent(
    `Review ${file} against REVIEW.md and CLAUDE.md. Only correctness, requirement, security, boundary and migration findings. Cite line numbers.`,
    { label: `review:${file}`, phase: 'Review', schema: FILE_FINDINGS },
  ),
))
const findings = perFile.filter(Boolean).flatMap((r) => r.findings)

const ranked = await agent(
  `Merge and rank these findings; drop duplicates; keep blocking first. Findings: ${JSON.stringify(findings)}. Return the same schema.`,
  { label: 'rank', phase: 'Rank', schema: FILE_FINDINGS },
)
if (!ranked) {
  return { files: files.length, error: 'The rank agent returned nothing; the findings below are unranked.', findings }
}
return { files: files.length, findings: ranked.findings }
```

- [ ] **Step 3: Write `deep-research.js`**

```javascript
export const meta = {
  name: 'deep-research',
  description: 'Design-decision research: three independent researchers, one synthesiser, evidence with dates and URLs',
  phases: [{ title: 'Research' }, { title: 'Synthesise' }],
}

const question = (args && args.question) || null
if (!question) return { error: 'Pass args.question' }

const REPORT = { type: 'object', properties: { summary: { type: 'string' }, sources: { type: 'array', items: { type: 'string' } } }, required: ['summary', 'sources'] }

const angles = ['official documentation and vendor release notes', 'independent benchmarks, papers and post-mortems', 'production experience reports and known traps']
const reports = await parallel(angles.map((angle) => () =>
  agent(`Research: "${question}". Angle: ${angle}. Today is the current date; prefer sources from the last 12 months and date every claim. Return a summary and source URLs.`,
    { label: `research:${angle}`, phase: 'Research', schema: REPORT }),
))
const delivered = reports.filter(Boolean)
if (delivered.length === 0) return { error: 'All three researchers returned nothing, so there is nothing to synthesise. Run the workflow again.' }

const synthesis = await agent(
  `Synthesise these reports into a decision memo with Options / Evidence / Recommendation / Accepted costs, in English, suitable as an ADR draft: ${JSON.stringify(delivered)}`,
  { label: 'synthesise', phase: 'Synthesise', schema: REPORT },
)
return synthesis || { error: 'The synthesiser returned nothing; the research reports follow.', reports: delivered }
```

- [ ] **Step 4: Validate against the reference and commit**

Load the `workflow-authoring` skill and compare: `meta` literal, `agent(prompt, {label, phase, schema})`, `parallel(fns)`, `pipeline(items, stage1, stage2)`, `args`. Fix only naming differences.

Syntax-check each file: copy it to a scratch file with `export ` removed from the `meta` line and the body wrapped in `(async () => { ... })()`, then run `node --check <copy>`.
Expected: exit 0 for all three, and every `phase:` string in a file names one of its `meta.phases` titles.

```bash
git add .claude/workflows
git commit -m "feat: add the three saved fan-out workflows (audit, release review, deep research)"
```

---

### Task 10: Session state, metrics, and the Phase 0 progress record

**Files:**
- Create: `.harness/state/goal.md.example`, `.harness/state/goal.md` (gitignored), `.harness/state/progress.md`, `.harness/metrics.md`

- [ ] **Step 1: Write `goal.md.example` and the owner's `goal.md`**

`.harness/state/goal.md.example`:

```markdown
# Goal (personal — copy to goal.md; goal.md is gitignored)

## Where we are
<one paragraph: the current phase and what "done" means for it>

## Current ticket
- #<n> <title>
- EARS:
  - WHEN … THE SYSTEM SHALL …
- Verify: ./scripts/check.sh · ./scripts/itest.sh

## Owner's standing instructions
- <things the agent must never re-ask>
```

`.harness/state/goal.md`:

```markdown
# Goal (personal — gitignored)

## Where we are
Phase 0 (environment and harness) is complete when the first metadata-engine ticket goes through the whole loop
(issue → worktree → implement → gates → PR → review → squash) and every gate has fired at least once
(`.harness/events.jsonl` has entries for stop-gate, pre-push-guard, wiki-gate, ci).

## Current ticket
- Phase 1, ticket 1 (to be created with /ticket): metadata engine — `sys_table` / `sys_field` system tables (Flyway),
  `TableDefinition` / `FieldDefinition` domain, and a create-table use case that inserts the definitions and runs
  `CREATE TABLE u_<name>` in one transaction.
- EARS (draft, refine in /brainstorming):
  - WHEN a valid TableName and at least one FieldDefinition are submitted THE SYSTEM SHALL create the physical table and the catalog rows atomically
  - WHEN the physical DDL fails THE SYSTEM SHALL leave no catalog row behind
  - WHEN a TableName already exists THE SYSTEM SHALL reject with a conflict error and change nothing
- Verify: ./scripts/check.sh · ./scripts/itest.sh (the Phase 1 design interview decides where module-level Spring tests live)

## Owner's standing instructions
- The owner does not write code. Ask for decisions, not for implementations.
- The owner approves three things: the ticket preview, the design review and the merge.
- Never use employer code, designs, customer data or names.
- English artifacts; Korean only in chat and README.ko.md.
```

`goal.md` is written but never committed: `git -C /Users/yu-sun00/Desktop/vera check-ignore .harness/state/goal.md` prints the path and exits 0. The Verify lines name no module because Spring context tests live in `:bootstrap` until Phase 1 decides a per-module test harness (CLAUDE.md, Quality gate).

- [ ] **Step 2: Write `progress.md` with the Phase 0 record (evidence from Plan 0-A, `gh` and the job logs of the green CI run on main; the 0-B entry stays 🚧 until the Task 13 acceptance run)**

```markdown
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
```

Evidence sources (2026-10-02): `RESULT` lines and test counts from `gh run view 36801975950 --repo BrokenFinger98/vera --log` (jobs `check` and `itest`); PR titles and merge times from `gh pr view <n> --repo BrokenFinger98/vera --json title,mergedAt,url`; the PoC 2 status from `curl -s -o /dev/null -w '%{http_code}\n' https://repo1.maven.org/maven2/org/graalvm/polyglot/js-isolate-community/25.4.4.1.1/`; PoC 1 from the two `TransactionalDdlPocTest` cases in the `:bootstrap:itest` XML report after a forced re-run (`4 tests, 0 failed, 0 skipped`); PoC 3 and 4 from Plan 0-A Tasks 3 and 11. The 0-B counts come from `wc -l CLAUDE.md`, `ls .claude/rules .claude/skills .claude/hooks`, `jq '[.hooks[][] | .hooks[]] | length' .claude/settings.json`, the numbered checks in `scripts/guards.sh` and `jq -r .gate .harness/events.jsonl | sort | uniq -c`. `#4` is the next free number (`gh pr list --state all` ends at `#3` and `gh issue list --state all` is empty); confirm it when the PR is opened.

The intro line does not spell the marker out: `inject-state.sh` stops at the first line that contains the marker string, so a literal mention above the real marker drops every entry from the injection (the earlier wording injected only the `# Progress` title). Keep it that way in every entry.

- [ ] **Step 3: Write `.harness/metrics.md`**

```markdown
# Harness metrics (weekly line appended by the harness-improve routine)

| week | merged PRs | avg changed lines/PR | gate firings (rule:count) | critic blocking/PR | CI failure rate | regressions | time-to-green (median) |
|---|---|---|---|---|---|---|---|
| 2026-W40 (to 2026-10-02) | 3 | 558 | stop-gate/check.sh-failed:1, block-danger/git-discard-all:1, pre-push-guard/deleted-test-file:1, pre-push-guard/assertion-decrease:1 (the pre-push-guard pair is the negative probe) | – | 11% (1 of 9 completed runs; 1 cancelled run not counted) | 0 | – |
```

Computed 2026-10-02 for ISO week 2026-W40 (Mon 2026-09-28 to Sun 2026-10-04), so far:
- Merged PRs and changed lines: `gh pr list --repo BrokenFinger98/vera --state merged --search "merged:>=2026-09-28" --json number,additions,deletions` gives #1 (54 changed lines), #2 (3) and #3 (1618); 3 PRs, (54 + 3 + 1618) / 3 = 558.
- Gate firings: `jq -r '"\(.gate)/\(.rule)"' .harness/events.jsonl | sort | uniq -c`, all four events fall in the week. The two `pre-push-guard` events come from the Task 7 negative probe (branch `tmp/guard-negative`).
- CI failure rate: `gh run list --repo BrokenFinger98/vera --created ">=2026-09-28" --limit 200 --json conclusion,event,headBranch` gives 10 runs: 8 success, 1 failure (the bootstrap push, fixed by PR #1), 1 cancelled. The rate is failures over completed runs, 1 / (8 + 1).
- Regressions: `gh issue list --repo BrokenFinger98/vera --state all` is empty, so no bug is filed against a merged ticket.
- Critic blocking and time-to-green stay `–`: no critic event exists yet, and neither the spec nor the harness-improve prompt defines a time-to-green formula.

- [ ] **Step 4: Commit**

```bash
git add .harness/state/goal.md.example .harness/state/progress.md .harness/metrics.md
git commit -m "docs: add session state files, progress record and harness metrics table"
```

`git status --porcelain` is empty afterwards: `goal.md` is ignored and was never staged.

---

### Task 11: The nine ADRs and the source stub

**Files:**
- Create: `docs/llm-wiki/wiki/decisions/2026-09-30-*.md` (9 files), `docs/llm-wiki/wiki/sources/2026-09-30-phase0-design-and-research.md`

- [ ] **Step 1: Write the ADRs (same frontmatter pattern; bodies below)**

Frontmatter for every file (adjust `tags`; D3, rewritten on 2026-10-01, also sets `updated: 2026-10-01`):

```yaml
---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, harness]
created: 2026-09-30
updated: 2026-09-30
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---
```

`2026-09-30-public-english-repository.md`:

```markdown
# D1 — Public repository, English committed artifacts

## Context
Vera is a learning and portfolio project. Portfolio value depends on readers outside Korea; the owner reads Korean faster.
## Options considered
Public + English · public + Korean allowed · private + Korean.
## Decision
Public GitHub repository. All committed artifacts (code, commits, ADRs, wiki, CLAUDE.md) are English. `README.ko.md` is the only Korean twin.
## Rationale
Same rule as the owner's programmers-tracker repo; consistent with the "docs are for agents" guidance (Karpathy 2026-04) where English is the models' strongest language.
## Accepted costs
Reading friction for the owner; Korean research notes live in the owner's central wiki instead of this repo. Guard: `scripts/guards.sh` check 6.
## Outcome
`.gitignore` excludes `docs/research/`; pre-push guard rejects Hangul outside `README.ko.md`.
```

`2026-09-30-stack-baseline-sept-2026.md`:

```markdown
# D2 — Stack baseline as of September 2026

## Context
The origin design chat proposed Java 21, Spring Boot 3.x, PostgreSQL 16, Redis. Verified on 2026-09-30: Boot 3.5 reached OSS EOL 2026-06; jOOQ OSS supports only the newest PostgreSQL major; Redis 8 carries an AGPL option.
## Options considered
Keep the chat's plan · raise to current LTS/GA line.
## Decision
Java 25 LTS, Spring Boot 4.1.1 (Framework 7.0.9), Spring Modulith 2.1.1, Gradle 9.7.1, PostgreSQL 18, jOOQ 3.21.7 (BOM), Flyway 12.4 (BOM) + `flyway-database-postgresql`, Valkey 9, Kafka 4.2.1 (BOM, matching the compose image; Phase 3.5), Testcontainers 2.0.5, Keycloak 26.7 (Phase 3), springdoc 3.1 (Phase 1).
## Rationale
Maven Central metadata checked for every pinned artifact; the owner's own upgrade notes from 2026-09-28 cover the same Boot 4/JDK 25 upgrade, so the traps are documented.
## Accepted costs
Boot 4 starter modularisation fails silently when a starter is missing; Testcontainers 2 renamed artifacts and packages; Valkey needs a service-connection label in compose.
## Outcome
`gradle/libs.versions.toml`; PoC 1 passed on PG 18 with jOOQ 3.21.
```

`2026-09-30-kotlin-2-3-until-toolchain-catches-up.md`:

```markdown
# D3 — Kotlin 2.3.21 while the Spring Boot BOM manages it

## Context
Kotlin 2.4.20 is current; Spring Boot 4.1.1's BOM manages Kotlin 2.3.21. On 2026-09-30 the linter was a second reason to stay: detekt's stable line (1.23.8, no release since 2025-02) embeds a Kotlin 2.0.21 compiler that cannot run on JDK 25 or read Kotlin 2.3 stdlib metadata. On 2026-10-01 detekt 2.0.0-alpha.x replaced it: built on Kotlin 2.4, tested against JDK 25, type resolution on every source set (Plan A, Task 3 decision).
## Options considered
Kotlin 2.4.20 over the BOM · Kotlin 2.3.21 as the BOM manages it.
## Decision
Kotlin 2.3.21 (BOM-managed). The reason is the Boot BOM, no longer the linter: detekt 2.0.0-alpha.x, adopted on 2026-10-01 for JDK 25 support and full type resolution, parses Kotlin 2.4.
## Rationale
The BOM's Kotlin is the version Boot 4.1 is built and tested with; overriding it buys no feature the project needs yet.
## Accepted costs
No Kotlin 2.4 features yet. The linter is an alpha: pinned exactly, a development tool that never ships, reverted in one PR if it misbehaves. Its one measured boundary difference is KDoc: `LongMethod` counts KDoc inside a function body (+2, +1 one-line) but not above it, `LargeClass` counts member and class KDoc (+2 each), comments never count, and no option excludes KDoc; current code impact: 0. `scripts/detekt-calibrate.sh` re-measures every boundary on each bump.
## Outcome
Revisit Kotlin 2.4 with Spring Boot 4.2 (GA 2026-11).
```

`2026-09-30-scenarios-and-gates-not-ritual-tdd.md`:

```markdown
# D4 — Acceptance scenarios and gates instead of enforced TDD

## Context
Böckeler (martinfowler.com, 2026-08-10) found no quality difference between agents instructed to do TDD and agents not instructed; agents faked the red step and wrote tautological tests. TDAD (2026-03) found procedural TDD instructions increased regressions.
## Options considered
Enforce TDD via skills/hooks · scenarios + gates · scenarios only.
## Decision
EARS acceptance criteria are drafted by the agent in /ticket and approved by the owner; the agent writes tests and code together. Gates: tests must ship in the same PR (guard 8), assertions may not decrease without a `Test-Change:` trailer (guard 2), Modulith `verify()` (`test`) + ArchUnit (`archTest`), Kover ≥ 80% lines, Pitest on core modules nightly from Phase 1.
## Rationale
What the machine can enforce is "tests come with the code" and "tests are not weakened"; the order of writing is unprovable and, per the evidence, not valuable.
## Accepted costs
Tautological tests can still pass gates until mutation testing exists; the critic subagent covers the gap meanwhile.
## Outcome
The superpowers TDD skill is used only to choose verification scenarios.
```

`2026-09-30-orca-worktrees-for-parallel-work.md`:

```markdown
# D5 — Orca worktrees, two to three in parallel, one owned module per ticket

## Context
Parallel agents collide on shared files; 2026 practice caps at 4–8 worktrees per developer before review becomes the bottleneck. The owner already uses Orca (used on two earlier projects).
## Options considered
Orca · Claude Code `--worktree`/`/batch` only · sequential only.
## Decision
Orca: one ticket = one worktree = one terminal, at most three concurrent. Tickets declare an owned module; shared files (root build, migrations, common) change only in solo tickets. Merge sequentially with `check.sh` between merges. Flyway versions are timestamps.
## Rationale
Reuses installed tooling and experience; module ownership is the single-writer principle that prevents merge hell.
## Accepted costs
Orca is a third-party app that the skills drive through its CLI (`orca worktree create/rm`); worktrees share the Gradle daemon and can produce false Stop-gate failures (hook skips when another build runs).
## Outcome
`.worktreeinclude`; `start-task` checks for blockers before work begins.
```

`2026-09-30-graaljs-on-stock-jdk-first.md`:

```markdown
# D6 — GraalJS js-community on the stock JDK first

## Context
GraalVM Polyglot 25.1+ on a non-GraalVM JDK runs the fallback (interpreter) runtime. The rule engine has no performance target yet.
## Options considered
GraalVM CE 25 as runtime from day one · stock Temurin 25 with interpreter · another scripting engine.
## Decision
`org.graalvm.polyglot:js-community` 25.x on Temurin 25. Sandbox: `HostAccess.NONE`, `IOAccess.NONE`, no threads/processes/native, statement limit. Benchmark in Phase 3; switch the runtime to GraalVM CE only if measured latency demands it.
## Rationale
One JDK for build, test and run keeps the toolchain simple; the sandbox contract (JSON in, JSON out) is independent of the runtime.
## Accepted costs
Interpreter-only execution; `js-isolate-community` availability recorded by PoC 2. No per-script heap cap on the stock JDK (PoC 2 measured `sandbox.MaxHeapMemory` as unsupported); Phase 3 decides between process isolation and the isolate build.
## Outcome
`platform/rule` `ScriptSandbox` with 17 passing tests (14 methods, the contract test parameterised four times).
```

`2026-09-30-stop-hook-gate-trial.md`:

```markdown
# D7 — Stop-hook quality gate as a one-month trial

## Context
The owner deleted a global stop-verify hook in 2026-07 after it never fired; an earlier project's stop gate produced false failures during concurrent Gradle runs. Anthropic's best practices name the Stop hook as the deterministic completion gate.
## Options considered
No Stop gate · Stop gate always · trial with audit.
## Decision
`stop-gate.sh` runs `scripts/check.sh` when source files changed, skips when another Gradle client is running, and logs every block. After 30 days: keep if it blocked a real mistake at least once, otherwise delete.
## Rationale
Harness-debt-audit principle: a mechanism earns its place with evidence of firing.
## Accepted costs
Up to ~60 s per session end when sources changed; occasional skipped runs.
## Outcome
Audit due 2026-10-30; evidence in `.harness/events.jsonl` (`gate: stop-gate`).
```

`2026-09-30-no-graph-runtime-for-pipeline.md`:

```markdown
# D8 — No graph orchestration runtime for the development pipeline

## Context
"Graph engineering" became a buzzword in July 2026; its substance is workflow orchestration (Anthropic 2024-12 patterns, LangGraph). Thoughtworks Radar Vol.34 moved LangGraph from Adopt to Trial; Cognition (2026-04) reports arbitrary agent networks as "mostly a distraction"; multi-agent research systems cost ~15× tokens. No controlled benchmark shows graph-orchestrated coding pipelines beating a single agent with subagents.
## Options considered
LangGraph/Agent Framework pipeline · Gas Town-style agent hierarchy · single session + subagents + gates + worktrees, with graphs only where they pay.
## Decision
The harness-dev loop stays an implicit research → implement → verify → merge graph. Graphs are used in three places only: dependency-aware ticket scheduling (adopt), three saved fan-out Workflows for audits, release review and research (trial), a code knowledge graph when the codebase exceeds ~50k LOC or cross-module misses recur (assess).
## Rationale
Every 2026 primary source recommends the simplest composition that works; the owner's toolchain already provides worktrees and task dependencies.
## Accepted costs
Less spectacular parallelism; fan-out is limited to the three saved workflows.
## Outcome
`.claude/workflows/{audit-consistency,release-review,deep-research}.js`; ticket template carries Blocked-by/Blocks.
```

`2026-09-30-human-approved-self-improvement-loop.md`:

```markdown
# D9 — Closed self-improvement loop with human-approved promotion

## Context
The cycle every 2026 source ends with — remember/compound/improve — was missing: lessons were recorded but nothing counted them or turned them into rules, and nothing removed rules that never fired. Autonomous self-improvement loops overstate their gains (arXiv 2607.25152: 56% of claimed improvements changed nothing).
## Options considered
Manual only · fully autonomous rule edits · machine-proposed, human-merged.
## Decision
Capture: `log-gate-event.sh` appends every gate firing to `.harness/events.jsonl`. Distill: `/finish-task` writes a counted retro to `lessons.md`. Promote: weekly `harness-improve` opens one PR per lesson with count ≥ 3 or rule fired ≥ 3 times, proposing exactly one rule/hook/lint/test change. Prune: monthly PR deleting rules with zero firings in 30 days. Measure: weekly metrics line. Only the owner merges.
## Rationale
Evidence-gated promotion mirrors Anthropic's "bugs → CLAUDE.md" loop and OpenAI's garbage-collection agents while keeping the owner as the judge of every rule change.
## Accepted costs
One weekly review of proposal PRs; events log grows (pruned monthly).
## Outcome
`.harness/events.jsonl`, `lessons.md`, `.github/workflows/harness-improve.yml`, `.harness/metrics.md`.
```

- [ ] **Step 2: Write the source stub**

`docs/llm-wiki/wiki/sources/2026-09-30-phase0-design-and-research.md`:

```markdown
---
type: source
project: vera
tags: [phase-0, research, methodology]
created: 2026-09-30
updated: 2026-09-30
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

# Source: Phase 0 design and 2026-09 methodology research

Raw: the origin design chat (ServiceNow-style platform, four engines, ITAM first) and the 2026-09-30 research across Anthropic/OpenAI docs, Thoughtworks Radar Vol.34, GitHub workflow repos, and the owner's existing harness.

## Claims
1. All primary sources agree on one cycle: spec/plan separated from coding, small units, machine-verified completion, writer/reviewer separation, short instructions + skills + hooks.
2. Enforced TDD showed no quality gain for agents (Böckeler 2026-08); the research recommends scenarios + gates + mutation testing instead (a recommendation, not a measured effect).
3. "Graph engineering" is renamed workflow orchestration; explicit graph runtimes cost tokens without measured benefit for coding pipelines.
4. Stack baseline moved: Boot 4.1 / Java 25 / PG 18 / jOOQ 3.21 / Testcontainers 2 verified on Maven Central.
5. Self-improvement must be evidence-gated and human-merged (self-evaluation bias).

## Pages updated
[[decisions/2026-09-30-public-english-repository]] · [[decisions/2026-09-30-stack-baseline-sept-2026]] · [[decisions/2026-09-30-kotlin-2-3-until-toolchain-catches-up]] · [[decisions/2026-09-30-scenarios-and-gates-not-ritual-tdd]] · [[decisions/2026-09-30-orca-worktrees-for-parallel-work]] · [[decisions/2026-09-30-graaljs-on-stock-jdk-first]] · [[decisions/2026-09-30-stop-hook-gate-trial]] · [[decisions/2026-09-30-no-graph-runtime-for-pipeline]] · [[decisions/2026-09-30-human-approved-self-improvement-loop]]
```

Also create the raw file the stub points at, `docs/llm-wiki/raw/sessions/2026-09-30-phase0-design-and-research.md`, containing an English summary (≤60 lines) of: the origin chat's decisions (§1 of the research doc), the 2026-09 methodology consensus (§2.6 table), the stack table (§5.1), and D1–D9. Do not copy the Korean text.

- [ ] **Step 3: Commit**

```bash
git add docs/llm-wiki
git commit -m "docs: add ADRs D1-D9 and the Phase 0 source stub to the repo wiki"
```

---

### Task 12: Global fixes and research hand-over (outside the repo)

- [ ] **Step 1: Fix the global `harness-dev` skill state path**

Run: `grep -n '\.claude/state' /Users/yu-sun00/.claude/skills/harness-dev/SKILL.md`
Expected: two lines (`goal.md`, `progress.md`). Replace `.claude/state/` with `.harness/state/` in both (use `sed -i '' 's#\.claude/state/#.harness/state/#g' /Users/yu-sun00/.claude/skills/harness-dev/SKILL.md`), then re-run the grep and expect no output.

- [ ] **Step 2: Move the Korean research document to the owner's central wiki raw layer**

```bash
mv /Users/yu-sun00/Desktop/vera/docs/research/2026-09-30-ai-driven-development-methodology.md /Users/yu-sun00/Desktop/llm-wiki/raw/sessions/2026-09-30-vera-ai-driven-development-methodology-research.md
rmdir /Users/yu-sun00/Desktop/vera/docs/research
```

Then, in a session opened in `/Users/yu-sun00/Desktop/llm-wiki`, run `/wiki-ingest` so the central wiki gets the decisions and the methodology findings (that wiki's skills, not this repo's).

- [ ] **Step 3: Update Claude Code and audit the constitution**

Run: `claude update` then, in a new session in the repo, `/doctor`.
Expected: version ≥ 2.1.277 (rules directory and AGENTS.md support per docs); `/doctor` proposes no cuts to `CLAUDE.md` that remove a rule backed by a gate — accept cuts only for content derivable from code.

---

### Task 13: Branch protection and Phase 0 acceptance run

- [ ] **Step 1: Push and let CI register all checks**

```bash
git -C /Users/yu-sun00/Desktop/vera push origin main
gh run list --repo BrokenFinger98/vera --limit 3
```

Expected: the `CI` run is green; `test-guard` and `claude-review` appear only on PRs (they are registered as checks after the first PR — see Step 3).

- [ ] **Step 2: Branch protection on `main`**

```bash
gh api -X PUT repos/BrokenFinger98/vera/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  --input - <<'JSON'
{
  "required_status_checks": { "strict": true, "contexts": ["check (format, detekt, unit, arch)", "itest (Testcontainers PostgreSQL 18)", "coverage (Kover ≥ 80% lines)", "build (bootJar)", "label-required-when-tests-change"] },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 1, "require_code_owner_reviews": true },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
gh api -X PATCH repos/BrokenFinger98/vera -f allow_squash_merge=true -f allow_merge_commit=false -f allow_rebase_merge=false -f delete_branch_on_merge=true >/dev/null && echo "merge settings ok"
```

Expected: JSON response with `required_status_checks` echoing the five contexts; `merge settings ok`. A solo owner approving their own PR: GitHub does not count self-approval, so set `required_approving_review_count` to `0` if merges block — record that in progress.md (the design review still happens; it is documented in the PR checklist).

- [ ] **Step 3: Acceptance run (spec §13) — a harness ticket through the whole loop**

Use the flow itself to prove itself: `/ticket` → "harness: verify Phase 0 gates fire" (owned module `:bootstrap`, EARS = the §13 lines) → in the worktree make a trivial test-covered change (add `TableName.equals` behaviour test or similar) → let the Stop hook run → `/gated-commit` → push (guards + wiki gate) → `/finish-task` (retro → first `lessons.md` entry) → `/pull-request` → CI + claude-review → owner approves → squash merge.

Expected evidence, pasted into `progress.md`:
- `.harness/events.jsonl` contains at least one `stop-gate` or `pre-push-guard` or `wiki-gate` event from this ticket (force one: push once without wiki changes and without the trailer, observe the block, then add the trailer).
- `lessons.md` has its first entry with `count: 1`.
- PR shows `claude-review` verdict and all required checks green; merged with squash; branch deleted.
- `gh workflow run harness-improve.yml -f mode=promote` completes with "promote: nothing due" in the log.

- [ ] **Step 4: Close Phase 0**

Update `.harness/state/progress.md` Phase 0-B entry with the evidence, rewrite `goal.md` "Where we are" to "Phase 1 — metadata engine", commit via `/gated-commit` on a `docs/` branch, PR, merge.

---

## Self-review against the spec

- §3 operating model → CLAUDE.md flow + skills (`ticket`, `start-task`, `finish-task`, `pull-request`) ✓
- §4 layout → every harness path created (Tasks 1–11) ✓; `docs/specs/<module>.md` template only (modules get specs with their first ticket) ✓
- §5 harness placement → global reused, GitHub-flow skills under distinct names (a personal skill outranks a same-name project skill), rules path-scoped, settings without `defaultMode`, `cd` rule ✓; global `harness-dev` path fix (Task 12) ✓
- §6 gate stack → 0a format.sh + global secrets ✓ · 0b deny list + global block-danger ✓ · 1 stop-gate.sh ✓ · 2 guards.sh + wiki gate ✓ · 3 ci.yml (Plan A) + test-guard + claude-review ✓ · 4 branch protection ✓ · 5 PR checklist ✓; every failure message says what to change ✓
- §7 tickets/DoD → issue template, PR template, size guard, ADR rule ✓
- §9 D5/D8 → worktree include, blocked-by in template and `start-task`, three workflows ✓
- §10 knowledge + §10.1 loop → wiki schema/skills, lessons.md format, events log, weekly/monthly routine, metrics ✓
- §12 steps 1, 4, 5, 7 ✓ (step 7 is the acceptance run, Task 13)
- §13 acceptance criteria → each mapped: inject-state (Task 3), format (Task 3), deny/block (Task 3 settings + global hook), stop-gate (Task 3), guards on push (Task 7), CI + protection (Plan A Task 12 + Task 13), events log (Task 3), retro (Task 5), routine PR (Task 8, dry run in Task 13), ready queue (Task 5 `start-task` blocker check) ✓
- Placeholder scan: the only `<...>` tokens are inside templates meant to be filled per ticket, and `<200|404>`-style evidence slots filled by the run itself. No TODO/TBD.
- Consistency: script names (`log-gate-event.sh`, `guards.sh`, `check.sh`), trailers (`Test-Change:`, `Wiki-Skip:`), labels (`test-change`, `task`, `harness`), event gate names (`stop-gate`, `pre-push-guard`, `wiki-gate`, `critic`, `ci`) match across hooks, skills, workflows and ADRs.
