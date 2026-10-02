# Vera

> *vera* — Latin, "true". A metadata-driven enterprise platform engine, built to understand how
> systems of record like ServiceNow keep one platform binary while every customer customises.

Vera is a learning and portfolio project. It implements the platform layer first — a metadata
engine (tables and fields defined at runtime), a rule engine with sandboxed scripts, a
layering/upgrade engine that keeps customer changes apart from the standard, and later
multi-instance provisioning — and puts an IT Asset Management (ITAM) application on top of it.

**Every line of code in this repository is written by AI coding agents.** The owner approves
specs and tickets, reviews designs and approves merges; agents write all code, tests and docs.
How that works is documented in `CLAUDE.md` and `docs/superpowers/specs/`.

## Status

Phase 0 — repository, toolchain and harness. See `.harness/state/progress.md`.

## Build

Requires JDK 25 and Docker (integration tests).

```bash
./scripts/check.sh   # format check, detekt, unit tests, architecture tests
./scripts/itest.sh   # integration tests (Testcontainers PostgreSQL 18)
./scripts/build.sh   # assemble
```

Run the demo stack: `docker compose up -d` then `SPRING_PROFILES_ACTIVE=dev ./gradlew :bootstrap:bootRun`.
Run from the repository root; IDE run configurations must use the root as working directory so `compose.yml` is found.

## Stack

Kotlin 2.3 · Java 25 · Spring Boot 4.1 · Spring Modulith 2.1 · PostgreSQL 18 · jOOQ 3.21 ·
Flyway · GraalJS (rule sandbox) · Testcontainers 2 · Gradle 9.7.

## License

MIT. Korean readers: see `README.ko.md`.
