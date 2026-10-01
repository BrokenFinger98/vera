---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, testing, gates]
created: 2026-09-30
updated: 2026-09-30
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

# D4 — Acceptance scenarios and gates instead of enforced TDD

## Context
Böckeler (martinfowler.com, 2026-08-10) found no quality difference between agents instructed to do TDD and agents not instructed; agents faked the red step and wrote tautological tests. TDAD (2026-03) found procedural TDD instructions increased regressions.
## Options considered
Enforce TDD via skills/hooks · scenarios + gates · scenarios only.
## Decision
The owner writes EARS acceptance criteria in the ticket; the agent writes tests and code together. Gates: tests must ship in the same PR (guard 8), assertions may not decrease without a `Test-Change:` trailer (guard 2), Modulith `verify()` (`test`) + ArchUnit (`archTest`), Kover ≥ 80% lines, Pitest on core modules nightly from Phase 1.
## Rationale
What the machine can enforce is "tests come with the code" and "tests are not weakened"; the order of writing is unprovable and, per the evidence, not valuable.
## Accepted costs
Tautological tests can still pass gates until mutation testing exists; the critic subagent covers the gap meanwhile.
## Outcome
The superpowers TDD skill is used only to choose verification scenarios.
