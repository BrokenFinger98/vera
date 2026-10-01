---
paths:
  - "**/src/test/**"
  - "**/src/itest/**"
  - "**/src/archTest/**"
---
# Tests

- One behaviour per test; the name states the behaviour in backticks.
- Acceptance criteria (`WHEN … THE SYSTEM SHALL …`) from the ticket map to tests 1:1 — name them alike.
- `itest`: `@SpringBootTest` + `@Import(TestcontainersConfiguration::class)`. No H2, no mocks of the database.
- Never delete or weaken an assertion to go green. If a test is wrong, say so in the commit body and add the trailer `Test-Change: <reason>` (pre-push guard).
- Fixtures MUST NOT contain real names, emails, serial numbers or the words `password=`/`token=` with literal values (secret hook false-positives).
