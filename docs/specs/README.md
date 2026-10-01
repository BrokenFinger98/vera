# Living module specs (trial — drop after Phase 1 if unmaintained)

One file per module, `docs/specs/<module>.md`, updated in the same PR that changes behaviour.

```markdown
# <module> — living spec
## Purpose (one paragraph)
## Behaviours (EARS)
- WHEN <condition> THE SYSTEM SHALL <result>
## Invariants
- <statement that is always true; each has a test named after it>
## Public API (module root package)
- `Facade.method(args): Result` — one line each
## Open questions
```

Design specs (before building) live in `docs/superpowers/specs/`; plans in `docs/superpowers/plans/`.
