# Changelog

## 0.1.0

- Initial release of `bloom_validate`.
- Declarative `BloomRequestSchema` base class mirroring the `BloomEnvironmentSchema` error-collection pattern for HTTP JSON request bodies and DTOs.
- `BloomValidationException` with `.toResponse()` helper generating structured HTTP 400 Bad Request responses (`{"error": "...", "errors": [...]}`).
- Field validation rules:
  - Primitive fields: `requireString`, `optionalString`, `requireInt`, `optionalInt`, `requireBool`, `optionalBool`, `requireDouble`, `optionalDouble`, `requireUri`, `optionalUri`.
  - HTTP & DTO rules: `requireEmail`, `optionalEmail`, `requireStringLength`, `optionalStringLength`, `requireIntRange`, `optionalIntRange`, `requireEnum`, `optionalEnum`, `requireNested`, `optionalNested`, `requireList`, `optionalList`, `requirePrimitiveList`, `optionalPrimitiveList`.
