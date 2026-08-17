# Changelog

## 0.1.0

- Initial release of `bloom_i18n`.
- `BloomCatalog`: Single-locale message store with ICU MessageFormat-style argument interpolation, pluralization (`=0`, `=1`, `zero`, `one`, `two`, `few`, `many`, `other`, with `#` number replacement), and select/gender evaluation.
- `BloomLocales`: Multi-locale registry with fallback resolution (`requested locale` -> `language subtag` -> `defaultLocale` -> `default language subtag` -> `messageId`) and runtime message translation.
- `BloomLocaleMiddleware`: Bloom server middleware resolving `Accept-Language` HTTP headers with quality-value weighting, query overrides (`?locale=`), and attaching `ResolvedLocale` to `BloomRequest`.
- `localizedDate` and `localizedDateTime`: Locale-aware date and time formatting powered by `package:intl`.
