---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, stack, kotlin, detekt]
created: 2026-09-30
updated: 2026-10-01
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

# D3 — Kotlin 2.3.21 while the Spring Boot BOM manages it

## Context
Kotlin 2.4.20 is current; Spring Boot 4.1.1's BOM manages Kotlin 2.3.21. On 2026-09-30 the linter was a second reason to stay: detekt's stable line (1.23.8, no release since 2025-02) embeds a Kotlin 2.0.21 compiler that cannot run on JDK 25 or read Kotlin 2.3 stdlib metadata. On 2026-10-01 detekt 2.0.0-alpha.x replaced it: built on Kotlin 2.4, tested against JDK 25, type resolution on every source set (Plan A, Task 3 decision).
## Options considered
Kotlin 2.4.20 over the BOM · Kotlin 2.3.21 as the BOM manages it.
## Decision
Kotlin 2.3.21 (BOM-managed). The reason is the Boot BOM, no longer the linter: detekt 2.0.0-alpha.x, adopted on 2026-10-01 for JDK 25 support and full type resolution, parses Kotlin 2.4.
## Rationale
The BOM's Kotlin is the version Boot 4.1 is built and tested with; overriding it buys no feature the project needs yet.
## Accepted costs
No Kotlin 2.4 features yet. The linter is an alpha: pinned exactly, a development tool that never ships, reverted in one PR if it misbehaves. Its one measured boundary difference is KDoc: `LongMethod` counts KDoc inside a function body (+2, +1 one-line) but not above it, `LargeClass` counts member and class KDoc (+2 each), comments never count, and no option excludes KDoc; current code impact: 0. `scripts/detekt-calibrate.sh` re-measures every boundary on each bump.
## Outcome
Revisit Kotlin 2.4 with Spring Boot 4.2 (GA 2026-11).
