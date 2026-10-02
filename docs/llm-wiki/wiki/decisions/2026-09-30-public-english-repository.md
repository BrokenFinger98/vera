---
type: decision
project: vera
author: BrokenFinger98
tags: [phase-0, repository, language]
created: 2026-09-30
updated: 2026-09-30
sources: [raw/sessions/2026-09-30-phase0-design-and-research.md]
---

# D1 — Public repository, English committed artifacts

## Context
Vera is a learning and portfolio project. Portfolio value depends on readers outside Korea; the owner reads Korean faster.
## Options considered
Public + English · public + Korean allowed · private + Korean.
## Decision
Public GitHub repository. All committed artifacts (code, commits, ADRs, wiki, CLAUDE.md) are English. `README.ko.md` is the only Korean twin.
## Rationale
Same rule as the owner's programmers-tracker repo; consistent with the "docs are for agents" guidance (Karpathy 2026-04) where English is the models' strongest language.
## Accepted costs
Reading friction for the owner; Korean research notes live in the owner's central wiki instead of this repo. Guard: `scripts/guards.sh` check 6.
## Outcome
`.gitignore` excludes `docs/research/`; the pre-push guard rejects newly added Hangul (added lines and commit messages) outside `README.ko.md`; the CI `guards` job runs the same script.
