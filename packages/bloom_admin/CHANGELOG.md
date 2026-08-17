# Changelog

## 0.1.0

- Initial release of `bloom_admin`: automatic, server-rendered HTML administration interface for Bloom applications.
- Mirroring `djangors-admin` architecture with `BloomAdminSite`, `BloomModelAdmin`, and `DefaultBloomModelAdmin`.
- Auto-generated changelist with pagination (`limit`/`offset`), multi-column ordering, search, and boolean filters.
- Auto-generated add/change forms with field-type mapping from `bloom_db` `FieldMeta`.
- Built-in CSRF token generation and server-side verification on all state-changing endpoints.
- Single and bulk object deletion with referential integrity protection awareness (`OnDelete.protect`).
- Safe-by-default server-side HTML rendering engine with strict auto-escaping.
