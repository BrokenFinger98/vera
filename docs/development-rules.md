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
