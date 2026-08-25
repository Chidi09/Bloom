# Changelog

## 0.2.1 - 2026-08-25

### Fixed
* Bumped `bloom_server` dependency constraint from `^0.1.0` to `^0.2.0` — the stale constraint was incompatible with any sibling package (`bloom_cache`, `bloom_admin`) requiring `bloom_server ^0.2.0`, breaking `pub get` in any app combining them.

## 0.2.0 - 2026-08-23

### Breaking
- Now depends on `bloom_server` instead of `bloom_framework`. Imports change from
  `package:bloom_framework/bloom_server.dart` to `package:bloom_server/bloom_server.dart`.
- **No longer requires Flutter.** The package now resolves against the Flutter-free
  `bloom_server` core, so it can be used from a plain `dart run`/`dart compile` backend.

## 0.1.0

- Initial release of `bloom_i18n`.
- `BloomCatalog`: Single-locale message store with ICU MessageFormat-style argument interpolation, pluralization (`=0`, `=1`, `zero`, `one`, `two`, `few`, `many`, `other`, with `#` number replacement), and select/gender evaluation.
- `BloomLocales`: Multi-locale registry with fallback resolution (`requested locale` -> `language subtag` -> `defaultLocale` -> `default language subtag` -> `messageId`) and runtime message translation.
- `BloomLocaleMiddleware`: Bloom server middleware resolving `Accept-Language` HTTP headers with quality-value weighting, query overrides (`?locale=`), and attaching `ResolvedLocale` to `BloomRequest`.
- `localizedDate` and `localizedDateTime`: Locale-aware date and time formatting powered by `package:intl`.
