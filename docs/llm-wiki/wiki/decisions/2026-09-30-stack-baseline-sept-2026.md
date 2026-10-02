---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, stack, versions]
created: 2026-09-30
updated: 2026-09-30
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

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
