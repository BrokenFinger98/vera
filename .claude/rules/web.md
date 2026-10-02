---
paths:
  - "**/internal/web/**"
---
# Web adapters (Spring MVC)

- Controllers only translate HTTP ↔ use case; no business logic, no repository access.
- Request/response DTOs are `data class`es in the same package; never expose domain objects directly.
- Validation with Jakarta annotations on DTOs; domain value objects validate again on construction.
- Error responses follow RFC 9457 problem details (`ProblemDetail`), never stack traces.
- Verify: a `@WebMvcTest` (starter `spring-boot-starter-webmvc-test`) per controller, in `:bootstrap` for now.
