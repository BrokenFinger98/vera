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
