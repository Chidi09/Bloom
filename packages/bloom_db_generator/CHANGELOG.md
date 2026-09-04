# Changelog

## 0.1.2 - 2026-09-04

### Changed
* **Loud `fromRow` null handling (#15)**: generated `fromRow` for a non-nullable field now throws a `StateError` on a null value instead of silently substituting `0` / `''` / epoch, so wrong data surfaces instead of being masked.
* **Uninferrable field kinds error instead of defaulting to text (#15)**: a Dart type with no standard `FieldKind` mapping (e.g. `List<String>`, enums, `Uint8List`) now throws an `UnsupportedError` asking for an explicit `@Field(kind: ...)` rather than silently emitting `FieldKind.text`.

### Fixed
* **Preserve `@BloomField` schema metadata (#11)**: generated `FieldMeta` now carries `maxLength` and `defaultVal`, allowing migration DDL to emit the requested `VARCHAR(n)` and `DEFAULT` definitions instead of silently falling back.

## 0.1.1 - 2026-08-31

* Preserve explicit `@BloomField` false values and custom field metadata.

## 0.1.0

Initial release.

- `@BloomModel`-driven `build_runner` builder generating `ModelMeta`, `fieldValues()`, and
  row-mapping boilerplate for `bloom_db` models.
