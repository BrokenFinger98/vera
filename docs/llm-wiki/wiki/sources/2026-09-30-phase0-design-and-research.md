---
type: source
project: vera
tags: [phase-0, research, methodology]
created: 2026-09-30
updated: 2026-09-30
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

# Source: Phase 0 design and 2026-09 methodology research

Raw: the origin design chat (ServiceNow-style platform, four engines, ITAM first) and the 2026-09-30 research across Anthropic/OpenAI docs, Thoughtworks Radar Vol.34, GitHub workflow repos, and the owner's existing harness.

## Claims
1. All primary sources agree on one cycle: spec/plan separated from coding, small units, machine-verified completion, writer/reviewer separation, short instructions + skills + hooks.
2. Enforced TDD showed no quality gain for agents (Böckeler 2026-08); the research recommends scenarios + gates + mutation testing instead (a recommendation, not a measured effect).
3. "Graph engineering" is renamed workflow orchestration; explicit graph runtimes cost tokens without measured benefit for coding pipelines.
4. Stack baseline moved: Boot 4.1 / Java 25 / PG 18 / jOOQ 3.21 / Testcontainers 2 verified on Maven Central.
5. Self-improvement must be evidence-gated and human-merged (self-evaluation bias).

## Pages updated
[[decisions/2026-09-30-public-english-repository]] · [[decisions/2026-09-30-stack-baseline-sept-2026]] · [[decisions/2026-09-30-kotlin-2-3-until-toolchain-catches-up]] · [[decisions/2026-09-30-scenarios-and-gates-not-ritual-tdd]] · [[decisions/2026-09-30-orca-worktrees-for-parallel-work]] · [[decisions/2026-09-30-graaljs-on-stock-jdk-first]] · [[decisions/2026-09-30-stop-hook-gate-trial]] · [[decisions/2026-09-30-no-graph-runtime-for-pipeline]] · [[decisions/2026-09-30-human-approved-self-improvement-loop]]
