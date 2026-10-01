---
paths:
  - "**/internal/**/*Repository*.kt"
  - "**/internal/**/*Jooq*.kt"
---
# jOOQ adapters

- Repository implementations MUST be `internal` and named `Jooq<Aggregate>Repository`.
- Dynamic identifiers MUST come from `TableName`/`FieldName` value objects; never build SQL from raw strings.
- Use the Spring-provided `DSLContext`; never construct a second one (breaks transactional DDL — PoC 1).
- Return domain types, not jOOQ `Record`s, from the repository boundary.
- Verify: `./scripts/itest.sh :<module>`.
