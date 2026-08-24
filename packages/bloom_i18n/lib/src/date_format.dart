// lib/src/date_format.dart
import 'package:intl/intl.dart';

/// Formats a [DateTime] date (year, month, day) according to locale conventions.
///
/// Uses `package:intl`'s [DateFormat.yMd] by default or a custom format [pattern]
/// when supplied. Normalizes locale identifiers (such as `'en-US'` to `'en_US'`)
/// to match `intl` canonical names. If [locale] is omitted, falls back to
/// [Intl.defaultLocale] or `'en-US'`.
///
/// Examples:
/// ```dart
/// localizedDate(DateTime(2026, 8, 17), 'en-US'); // "8/17/2026"
/// localizedDate(DateTime(2026, 8, 17), 'en-GB'); // "17/08/2026"
/// localizedDate(DateTime(2026, 8, 17), 'fr-FR'); // "17/08/2026"
/// localizedDate(DateTime(2026, 8, 17), 'en-US', 'yyyy-MM-dd'); // "2026-08-17"
/// ```
String localizedDate(
  DateTime date, [
  String? locale,
  String? pattern,
]) {
  final targetLocale = _normalizeLocale(locale ?? Intl.defaultLocale ?? 'en-US');
  final formatter = pattern != null
      ? DateFormat(pattern, targetLocale)
      : DateFormat.yMd(targetLocale);
  return formatter.format(date);
}

/// Formats a [DateTime] (date and time) according to locale conventions.
///
/// Uses `package:intl`'s [DateFormat.yMd().add_jms()] by default or a custom format [pattern]
/// when supplied. If [locale] is omitted, falls back to [Intl.defaultLocale] or `'en-US'`.
///
/// Examples:
/// ```dart
/// localizedDateTime(DateTime(2026, 8, 17, 14, 30, 0), 'en-US'); // "8/17/2026 2:30:00 PM"
/// localizedDateTime(DateTime(2026, 8, 17, 14, 30, 0), 'de-DE'); // "17.8.2026, 14:30:00"
/// localizedDateTime(DateTime(2026, 8, 17, 14, 30, 0), 'en-US', 'yyyy-MM-dd HH:mm'); // "2026-08-17 14:30"
/// ```
String localizedDateTime(
  DateTime dateTime, [
  String? locale,
  String? pattern,
]) {
  final targetLocale = _normalizeLocale(locale ?? Intl.defaultLocale ?? 'en-US');
  final formatter = pattern != null
      ? DateFormat(pattern, targetLocale)
      : DateFormat.yMd(targetLocale).add_jms();
  return formatter.format(dateTime);
}

/// Helper normalizing BCP-47 hyphenated tags to underscore-separated tags for `intl`.
String _normalizeLocale(String localeTag) {
  return localeTag.replaceAll('-', '_');
}

/// Convenience extension on [DateTime] providing locale-aware formatting methods.
///
/// ### Example
///
/// ```dart
/// final date = DateTime(2026, 8, 24, 15, 45);
/// print(date.toLocalizedDate('en-US')); // "8/24/2026"
/// print(date.toLocalizedDateTime('fr-FR')); // "24/08/2026 15:45:00"
/// ```
extension BloomDateTimeI18n on DateTime {
  /// Formats this date as a localized date string (year, month, day).
  ///
  /// Optionally accepts a BCP-47 [locale] and a custom `intl` [pattern].
  ///
  /// Example:
  /// ```dart
  /// final created = DateTime(2026, 8, 24);
  /// print(created.toLocalizedDate('en-US')); // "8/24/2026"
  /// print(created.toLocalizedDate('en-GB')); // "24/08/2026"
  /// ```
  String toLocalizedDate([String? locale, String? pattern]) =>
      localizedDate(this, locale, pattern);

  /// Formats this date as a localized date and time string.
  ///
  /// Optionally accepts a BCP-47 [locale] and a custom `intl` [pattern].
  ///
  /// Example:
  /// ```dart
  /// final published = DateTime(2026, 8, 24, 10, 0, 0);
  /// print(published.toLocalizedDateTime('en-US')); // "8/24/2026 10:00:00 AM"
  /// ```
  String toLocalizedDateTime([String? locale, String? pattern]) =>
      localizedDateTime(this, locale, pattern);
}
