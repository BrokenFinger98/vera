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
