# Review contract for AI reviewers (Claude Code `/code-review`, `claude-review.yml`)

Report only findings that affect **correctness, the stated requirements, security, or an
immutable decision in `CLAUDE.md`**. Style is owned by ktfmt and detekt — never comment on it.

## Severity

- **blocking** — wrong behaviour, data loss, security hole, module-boundary violation, test weakened/deleted,
  migration edited, immutable decision contradicted, PR > 400 lines without split rationale.
- **major** — requirement from the ticket's acceptance criteria not covered by a test; missing rollback note.
- **minor** — naming that contradicts `docs/domain/glossary.md`; missing ADR for an evident decision.
- Everything else: do not report.

## Must check on every PR

1. Every `WHEN … THE SYSTEM SHALL …` line in the linked issue has a test.
2. `git diff --stat` matches the ticket's owned module; no unrelated files.
3. No assertion removed or weakened (compare `assertThat`/`assertThrows` counts).
4. New tables/columns come with a new `V<timestamp>__*.sql`, never an edited one.
5. Logs and error messages contain no PII, secrets or customer identifiers.

## Skip

`docs/llm-wiki/raw/**`, `*.md` outside `docs/superpowers/specs/`, generated PlantUML.

## Output

Group by severity, cite `path:line`, one sentence each, end with `verdict: approve | request-changes`.
