---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, rule-engine, graaljs, sandbox]
created: 2026-09-30
updated: 2026-09-30
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

# D6 — GraalJS js-community on the stock JDK first

## Context
GraalVM Polyglot 25.1+ on a non-GraalVM JDK runs the fallback (interpreter) runtime. The rule engine has no performance target yet.
## Options considered
GraalVM CE 25 as runtime from day one · stock Temurin 25 with interpreter · another scripting engine.
## Decision
`org.graalvm.polyglot:js-community` 25.x on Temurin 25. Sandbox: `HostAccess.NONE`, `IOAccess.NONE`, no threads/processes/native, statement limit. Benchmark in Phase 3; switch the runtime to GraalVM CE only if measured latency demands it.
## Rationale
One JDK for build, test and run keeps the toolchain simple; the sandbox contract (JSON in, JSON out) is independent of the runtime.
## Accepted costs
Interpreter-only execution; `js-isolate-community` availability recorded by PoC 2. No per-script heap cap on the stock JDK (PoC 2 measured `sandbox.MaxHeapMemory` as unsupported); Phase 3 decides between process isolation and the isolate build.
## Outcome
`platform/rule` `ScriptSandbox` with 17 passing tests (14 methods, the contract test parameterised four times).
