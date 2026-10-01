---
paths:
  - "**/src/main/kotlin/com/brokenfinger/vera/*/domain/**"
---
# Domain packages

- MUST NOT import `org.springframework.*`, `org.jooq.*`, `jakarta.*` (ArchUnit `LayerRulesTest`).
- MUST wrap identifiers and names in `value class` types with one property (review; no ArchUnit rule sees it).
- Exceptions MUST extend `IllegalArgumentException` (bad input) or `IllegalStateException` (bad state) — ArchUnit `LayerRulesTest`.
- Behaviour lives on the object (`asset.retire(at)`), not in a service that reads its fields.
- Verify: `./scripts/check.sh` (archTest).
