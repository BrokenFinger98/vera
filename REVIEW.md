# Review contract for AI reviewers (`claude-review.yml` and the critic in /finish-task)

Report only findings that affect **correctness, the stated requirements, security, or an
immutable decision in `CLAUDE.md`**. Style is owned by ktfmt and detekt — never comment on it.

## Severity

- **blocking** — wrong behaviour, data loss, security hole, module-boundary violation, test weakened/deleted
  without a `Test-Change:` trailer and explanation on the commit that does it, migration edited, immutable decision contradicted,
  PR > 400 lines (`.harness/events.jsonl` excluded) without split rationale.
- **major** — requirement from the ticket's acceptance criteria not covered by a test; missing rollback note.
- **minor** — naming that contradicts `docs/domain/glossary.md`; missing ADR for an evident decision;
  domain identifier or name not wrapped in a `value class`; `if … else` where an early return works.
- Everything else: do not report.

## Must check on every PR

1. Every `WHEN … THE SYSTEM SHALL …` line in the linked issue has a test.
2. `git diff --stat` shows only the ticket's owned module plus the always-allowed files in CLAUDE.md; no unrelated files.
3. No test weakened in a way that keeps the counts: a new expected value, a looser matcher, a longer time budget, fewer
   `@ValueSource` values, a skip marker moved to a wider scope or given another condition, a test moved where Gradle
   does not build it. The push guard already refuses, per commit and per file, fewer assertions or test cases, a new
   skip marker and a deleted or moved-out test without that commit's `Test-Change:` trailer (`scripts/guards.sh`).
4. New tables/columns come with a new `V<timestamp>__*.sql`, never an edited one.
5. Logs and error messages contain no PII, secrets or customer identifiers.

## Skip

`docs/llm-wiki/raw/**`, `docs/superpowers/plans/**`, generated PlantUML — read them for context, do not report on them.

## Output

Group by severity, cite `path:line`, one sentence each, end with `verdict: approve | request-changes`.
