---
paths:
  - "**/db/migration/**"
---
# Flyway migrations

- File name `V<yyyyMMdd>_<hhmm>__<slug>.sql`; timestamp versions avoid worktree collisions.
- A merged migration is immutable. Fix forward with a new file (pre-push guard blocks edits to merged `V*.sql`).
- Every DDL change ships with its rollback note in the PR (a `drop`/`alter` statement or "plain revert").
- No data migrations in DDL files. Data migrations need an ADR before the first one (mechanism undecided: a Flyway Java migration or an idempotent runner).
