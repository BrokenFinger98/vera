---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, harness, orchestration]
created: 2026-09-30
updated: 2026-09-30
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

# D8 — No graph orchestration runtime for the development pipeline

## Context
"Graph engineering" became a buzzword in July 2026; its substance is workflow orchestration (Anthropic 2024-12 patterns, LangGraph). Thoughtworks Radar Vol.34 moved LangGraph from Adopt to Trial; Cognition (2026-04) reports arbitrary agent networks as "mostly a distraction"; multi-agent research systems cost ~15× tokens. No controlled benchmark shows graph-orchestrated coding pipelines beating a single agent with subagents.
## Options considered
LangGraph/Agent Framework pipeline · Gas Town-style agent hierarchy · single session + subagents + gates + worktrees, with graphs only where they pay.
## Decision
The harness-dev loop stays an implicit research → implement → verify → merge graph. Graphs are used in three places only: dependency-aware ticket scheduling (adopt), three saved fan-out Workflows for audits, release review and research (trial), a code knowledge graph when the codebase exceeds ~50k LOC or cross-module misses recur (assess).
## Rationale
Every 2026 primary source recommends the simplest composition that works; the owner's toolchain already provides worktrees and task dependencies.
## Accepted costs
Less spectacular parallelism; fan-out is limited to the three saved workflows.
## Outcome
`.claude/workflows/{audit-consistency,release-review,deep-research}.js`; ticket template carries Blocked-by/Blocks.
