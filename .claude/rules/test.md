---
paths:
  - "**/src/test/**"
  - "**/src/itest/**"
  - "**/src/archTest/**"
---
# Tests

- One behaviour per test; the name states the behaviour in backticks.
- Acceptance criteria (`WHEN … THE SYSTEM SHALL …`) from the ticket map to tests 1:1 — name them alike.
- `itest`: `@SpringBootTest` + `@Import(TestcontainersConfiguration::class)`; Spring context tests live in `:bootstrap` for now. No H2, no mocks of the database.
- Never delete or weaken an assertion to go green. If a test is wrong, the commit that deletes it, moves it out of `src/{test,itest,archTest}/{kotlin,java}/`, disables it (`@Disabled…`, `@Enabled…`, `@Ignore`, `assume…(`) or lowers a file's assertion or test-case count carries the trailer `Test-Change: <reason>` with the reason in its body. The pre-push guard judges every commit and file on its own; a trailer on another commit does not count. Adding tests needs none.
- Fixtures MUST NOT contain real names, emails, serial numbers or the words `password=`/`token=` with literal values (secret hook false-positives).
