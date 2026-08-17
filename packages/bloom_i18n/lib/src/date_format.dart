// lib/src/date_format.dart
import 'package:intl/intl.dart';

/// Formats a [DateTime] date (year, month, day) according to locale conventions.
///
/// Uses `package:intl`'s [DateFormat.yMd] by default or a custom format [pattern]
/// when supplied. Normalizes locale identifiers (such as `'en-US'` to `'en_US'`)
/// to match `intl` canonical names.
///
/// Examples:
/// ```dart
/// localizedDate(DateTime(2026, 8, 17), 'en-US'); // "8/17/2026"
/// localizedDate(DateTime(2026, 8, 17), 'en-GB'); // "17/08/2026"
/// localizedDate(DateTime(2026, 8, 17), 'fr-FR'); // "17/08/2026"
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
/// when supplied.
///
/// Examples:
/// ```dart
/// localizedDateTime(DateTime(2026, 8, 17, 14, 30, 0), 'en-US');
/// localizedDateTime(DateTime(2026, 8, 17, 14, 30, 0), 'de-DE');
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

/// Convenience extension on [DateTime] for locale formatting.
extension BloomDateTimeI18n on DateTime {
  /// Formats this date as a localized date string.
  String toLocalizedDate([String? locale, String? pattern]) =>
      localizedDate(this, locale, pattern);

  /// Formats this date as a localized date and time string.
  String toLocalizedDateTime([String? locale, String? pattern]) =>
      localizedDateTime(this, locale, pattern);
}
