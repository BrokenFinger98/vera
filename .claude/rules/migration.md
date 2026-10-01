---
paths:
  - "**/db/migration/**"
---
# Flyway migrations

- File name `V<yyyyMMdd>_<hhmm>__<slug>.sql`; timestamp versions avoid worktree collisions.
- A merged migration is immutable. Fix forward with a new file (pre-push guard blocks edits to merged `V*.sql`).
- Every DDL change ships with its rollback note in the PR (a `drop`/`alter` statement or "plain revert").
- No data migrations in DDL files; data moves go through an `ApplicationRunner` documented in an ADR.
