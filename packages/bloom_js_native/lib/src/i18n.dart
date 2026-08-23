// lib/src/i18n.dart
//
// Pure-Dart Internationalization (i18n) module for Bloom JS Native.
// Safe for both SSR (VM) and browser DOM mounting. Zero DOM or browser imports.

import 'dart:async';
import 'dart:convert';
import 'package:signals/signals.dart';

// ─── ICU Message Formatter & Catalog ────────────────────────────────────────

/// A message catalog storing translated templates for a single locale.
///
/// Stores translation message strings indexed by message ID and evaluates them
/// using ICU MessageFormat-style patterns (interpolated arguments, plurals with `#`
/// substitution, select/gender cases, and nested sub-patterns).
///
/// Fully source- and format-compatible with `packages/bloom_i18n` on the server.
///
/// ```dart
/// final catalog = BloomCatalog('en-US', {
///   'greeting': 'Hello, {name}!',
///   'cart_items': '{count, plural, =0 {Cart is empty} =1 {1 item} other {# items}}',
/// });
///
/// final text = catalog.get('cart_items', args: {'count': 3}); // "3 items"
/// ```
class BloomCatalog {
  /// The BCP-47 locale tag identifier for this catalog (e.g. `'en-US'`, `'fr-FR'`, `'de'`).
  final String locale;

  /// Internal message key-value store.
  final Map<String, String> _messages;

  /// Creates a [BloomCatalog] from a map of message IDs to ICU-formatted message templates.
  BloomCatalog(this.locale, Map<String, String> messages)
      : _messages = Map<String, String>.from(messages);

  /// Creates a [BloomCatalog] from a dynamic map (e.g. decoded JSON).
  factory BloomCatalog.fromJson(String locale, Map<String, dynamic> json) {
    final messages = <String, String>{};
    json.forEach((key, value) {
      if (value != null) {
        messages[key] = value.toString();
      }
    });
    return BloomCatalog(locale, messages);
  }

  /// Creates a [BloomCatalog] by decoding a JSON string.
  factory BloomCatalog.fromJsonString(String locale, String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is Map<String, dynamic>) {
      return BloomCatalog.fromJson(locale, decoded);
    } else if (decoded is Map) {
      return BloomCatalog.fromJson(
        locale,
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    throw FormatException(
        'Invalid JSON for BloomCatalog: expected a JSON object.');
  }

  /// Returns a read-only view of the registered message templates.
  Map<String, String> get messages => Map.unmodifiable(_messages);

  /// Checks if a message ID is defined in this catalog.
  bool has(String messageId) => _messages.containsKey(messageId);

  /// Looks up and formats a translated message by ID, substituting arguments
  /// and evaluating ICU MessageFormat plural/select patterns.
  ///
  /// Returns `null` if the message ID is not found in this catalog.
  String? get(String messageId, {Map<String, Object>? args}) {
    final template = _messages[messageId];
    if (template == null) return null;
    return formatMessage(template, args: args, locale: locale);
  }

  /// Evaluates an ICU MessageFormat [template] string with [args] for the specified [locale].
  ///
  /// Supports variable interpolation `{name}`, plurals `{count, plural, ...}` with `#` replacement,
  /// select `{gender, select, ...}`, number formatting `{amount, number, currency}`, and date
  /// formatting `{date, date, short}` in pure Dart without `package:intl`.
  ///
  /// ```dart
  /// final result = BloomCatalog.formatMessage(
  ///   'You have {count, plural, =0 {no messages} =1 {one message} other {# messages}}',
  ///   args: {'count': 5},
  ///   locale: 'en-US',
  /// );
  /// // result: "You have 5 messages"
  /// ```
  static String formatMessage(
    String template, {
    Map<String, Object>? args,
    String? locale,
  }) {
    if (args == null || args.isEmpty) {
      if (!template.contains('{')) {
        return template;
      }
    }
    return _IcuMessageFormatter(locale: locale).format(template, args ?? const {});
  }
}

/// Evaluates ICU MessageFormat templates supporting argument interpolation,
/// plurals, select/gender cases, and recursive sub-patterns in pure Dart.
class _IcuMessageFormatter {
  final String? locale;

  _IcuMessageFormatter({this.locale});

  String format(String pattern, Map<String, Object> args) {
    final buffer = StringBuffer();
    int i = 0;
    final length = pattern.length;

    while (i < length) {
      final char = pattern[i];

      // Handle quoted literal sequences: '' -> ' or '{escaped}' -> {escaped}
      if (char == "'") {
        if (i + 1 < length && pattern[i + 1] == "'") {
          buffer.write("'");
          i += 2;
          continue;
        }
        final nextQuote = pattern.indexOf("'", i + 1);
        if (nextQuote != -1) {
          buffer.write(pattern.substring(i + 1, nextQuote));
          i = nextQuote + 1;
          continue;
        }
      }

      if (char == '{') {
        int depth = 1;
        int j = i + 1;
        while (j < length && depth > 0) {
          if (pattern[j] == "'") {
            final innerQuote = pattern.indexOf("'", j + 1);
            if (innerQuote != -1) {
              j = innerQuote + 1;
              continue;
            }
          }
          if (pattern[j] == '{') {
            depth++;
          } else if (pattern[j] == '}') {
            depth--;
          }
          j++;
        }

        if (depth == 0) {
          final inside = pattern.substring(i + 1, j - 1);
          buffer.write(_evaluateExpression(inside, args));
          i = j;
          continue;
        }
      }

      buffer.write(char);
      i++;
    }

    return buffer.toString();
  }

  String _evaluateExpression(String expr, Map<String, Object> args) {
    final firstComma = _findTopLevelComma(expr);
    if (firstComma == -1) {
      // Simple variable interpolation: {name}
      final varName = expr.trim();
      final value = args[varName];
      return value != null ? value.toString() : '{$varName}';
    }

    final varName = expr.substring(0, firstComma).trim();
    final rest = expr.substring(firstComma + 1).trim();

    final secondComma = _findTopLevelComma(rest);
    if (secondComma == -1) {
      // Missing pattern type details, fallback to variable value
      final value = args[varName];
      return value != null ? value.toString() : '{$varName}';
    }

    final type = rest.substring(0, secondComma).trim().toLowerCase();
    final branchesContent = rest.substring(secondComma + 1).trim();
    final branches = _parseBranches(branchesContent);

    if (type == 'plural') {
      return _evaluatePlural(varName, branches, args);
    } else if (type == 'select' || type == 'gender') {
      return _evaluateSelect(varName, branches, args);
    } else if (type == 'number') {
      return _evaluateNumber(varName, branchesContent, args);
    } else if (type == 'date' || type == 'time') {
      return _evaluateDate(varName, branchesContent, args);
    }

    // Unrecognized format type fallback
    final value = args[varName];
    return value != null ? value.toString() : '{$varName}';
  }

  String _evaluatePlural(
    String varName,
    Map<String, String> branches,
    Map<String, Object> args,
  ) {
    final rawVal = args[varName];
    final num count = rawVal is num
        ? rawVal
        : (num.tryParse(rawVal?.toString() ?? '') ?? 0);

    final exactKey = count is int || count == count.toInt()
        ? '=${count.toInt()}'
        : '=$count';

    String? selectedTemplate;

    // 1. Exact match (=0, =1, =2, etc.)
    if (branches.containsKey(exactKey)) {
      selectedTemplate = branches[exactKey];
    } else {
      // 2. Standard CLDR plural keyword matching
      if (count == 0 && branches.containsKey('zero')) {
        selectedTemplate = branches['zero'];
      } else if (count == 1 && branches.containsKey('one')) {
        selectedTemplate = branches['one'];
      } else if (count == 2 && branches.containsKey('two')) {
        selectedTemplate = branches['two'];
      } else if (branches.containsKey(count.toString())) {
        selectedTemplate = branches[count.toString()];
      } else if (branches.containsKey('other')) {
        selectedTemplate = branches['other'];
      } else if (branches.isNotEmpty) {
        selectedTemplate = branches.values.first;
      }
    }

    selectedTemplate ??= '';

    // Replace '#' with formatted number
    final formattedCount = formatNumber(count, locale: locale);
    final withHashSubstituted =
        _replaceHashSymbol(selectedTemplate, formattedCount);

    // Recursively evaluate any nested interpolations or select blocks
    return format(withHashSubstituted, args);
  }

  String _evaluateSelect(
    String varName,
    Map<String, String> branches,
    Map<String, Object> args,
  ) {
    final rawVal = args[varName];
    final key = rawVal?.toString().trim() ?? '';

    final selectedTemplate = branches[key] ??
        branches[key.toLowerCase()] ??
        branches['other'] ??
        (branches.isNotEmpty ? branches.values.first : '');

    return format(selectedTemplate, args);
  }

  String _evaluateNumber(
    String varName,
    String formatStyle,
    Map<String, Object> args,
  ) {
    final rawVal = args[varName];
    final num count = rawVal is num
        ? rawVal
        : (num.tryParse(rawVal?.toString() ?? '') ?? 0);

    final style = formatStyle.trim().toLowerCase();
    if (style == 'currency') {
      return formatCurrency(count, locale: locale);
    } else if (style == 'percent') {
      return formatPercent(count, locale: locale);
    } else {
      return formatNumber(count, locale: locale);
    }
  }

  String _evaluateDate(
    String varName,
    String formatStyle,
    Map<String, Object> args,
  ) {
    final rawVal = args[varName];
    DateTime? date;
    if (rawVal is DateTime) {
      date = rawVal;
    } else if (rawVal is String) {
      date = DateTime.tryParse(rawVal);
    }
    if (date == null) return rawVal?.toString() ?? '';

    final style = formatStyle.trim().toLowerCase();
    if (style == 'short') {
      return formatDate(date, locale: locale, style: DateFormatStyle.short);
    } else if (style == 'medium') {
      return formatDate(date, locale: locale, style: DateFormatStyle.medium);
    } else if (style == 'long') {
      return formatDate(date, locale: locale, style: DateFormatStyle.long);
    } else if (style == 'full') {
      return formatDate(date, locale: locale, style: DateFormatStyle.full);
    }
    return formatDate(date, locale: locale, pattern: formatStyle.trim());
  }

  int _findTopLevelComma(String str) {
    int depth = 0;
    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
      } else if (char == ',' && depth == 0) {
        return i;
      }
    }
    return -1;
  }

  Map<String, String> _parseBranches(String str) {
    final branches = <String, String>{};
    int i = 0;
    final length = str.length;

    while (i < length) {
      while (i < length &&
          (str[i] == ' ' ||
              str[i] == '\t' ||
              str[i] == '\n' ||
              str[i] == '\r')) {
        i++;
      }
      if (i >= length) break;

      final openBrace = str.indexOf('{', i);
      if (openBrace == -1) break;

      final branchKey = str.substring(i, openBrace).trim();

      int depth = 1;
      int j = openBrace + 1;
      while (j < length && depth > 0) {
        if (str[j] == '{') {
          depth++;
        } else if (str[j] == '}') {
          depth--;
        }
        j++;
      }

      if (depth == 0) {
        final branchBody = str.substring(openBrace + 1, j - 1);
        branches[branchKey] = branchBody;
        i = j;
      } else {
        break;
      }
    }

    return branches;
  }

  String _replaceHashSymbol(String template, String replacement) {
    final buffer = StringBuffer();
    for (int i = 0; i < template.length; i++) {
      final char = template[i];
      if (char == '#') {
        buffer.write(replacement);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}

// ─── Pure Dart Number, Currency, Date & Relative Time Formatting ───────────

/// Formatting styles for localized dates.
enum DateFormatStyle {
  /// Short compact date (e.g. "8/23/2026", "23/08/2026", "23.08.2026").
  short,

  /// Medium abbreviated date (e.g. "Aug 23, 2026", "23 août 2026").
  medium,

  /// Long full month date (e.g. "August 23, 2026", "23 August 2026").
  long,

  /// Complete date with weekday (e.g. "Sunday, August 23, 2026").
  full,
}

/// Formats a [num] value with locale-aware grouping and decimal separators in pure Dart.
///
/// ### Limitations vs Full CLDR
/// This is a lightweight, pure-Dart implementation covering major language families
/// (English, French, German, Spanish, Portuguese, Italian, Russian, Japanese, Chinese,
/// Arabic, etc.). For comprehensive CLDR locale data with numbering systems, use
/// server-side `package:bloom_i18n` with `package:intl`.
///
/// ```dart
/// formatNumber(1234567.89, locale: 'en-US'); // "1,234,567.89"
/// formatNumber(1234567.89, locale: 'de-DE'); // "1.234.567,89"
/// formatNumber(1234567.89, locale: 'fr-FR'); // "1 234 567,89"
/// ```
String formatNumber(
  num value, {
  String? locale,
  int? decimalDigits,
  bool useGrouping = true,
  String style = 'decimal',
}) {
  final loc = (locale ?? BloomI18n.instance.locale.value).replaceAll('_', '-').toLowerCase();
  final lang = loc.split('-').first;

  // Determine separators
  String decimalSep = '.';
  String groupSep = ',';

  if (['de', 'it', 'es', 'pt', 'nl', 'tr', 'id'].contains(lang)) {
    decimalSep = ',';
    groupSep = '.';
  } else if (['fr', 'ru', 'sv', 'pl', 'cs', 'fi', 'no', 'uk', 'bg'].contains(lang)) {
    decimalSep = ',';
    groupSep = ' ';
  } else if (['ar'].contains(lang)) {
    decimalSep = '٫';
    groupSep = '٬';
  }

  // Handle decimals
  final isInt = value is int || value == value.roundToDouble();
  String formatted;

  if (decimalDigits != null) {
    formatted = value.toStringAsFixed(decimalDigits);
  } else if (isInt) {
    formatted = value.toInt().toString();
  } else {
    formatted = value.toString();
  }

  final parts = formatted.split('.');
  String integerPart = parts[0];
  final isNegative = integerPart.startsWith('-');
  if (isNegative) integerPart = integerPart.substring(1);

  if (useGrouping && integerPart.length > 3) {
    final buf = StringBuffer();
    final len = integerPart.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buf.write(groupSep);
      }
      buf.write(integerPart[i]);
    }
    integerPart = buf.toString();
  }

  if (isNegative) integerPart = '-$integerPart';

  if (parts.length > 1 && parts[1].isNotEmpty) {
    return '$integerPart$decimalSep${parts[1]}';
  }
  return integerPart;
}

/// Formats a percentage value (e.g. `0.25` or `25`) for [locale] in pure Dart.
///
/// ```dart
/// formatPercent(0.42, locale: 'en-US'); // "42%"
/// formatPercent(0.42, locale: 'fr-FR'); // "42 %"
/// ```
String formatPercent(
  num value, {
  String? locale,
  int? decimalDigits = 0,
}) {
  final loc = (locale ?? BloomI18n.instance.locale.value).replaceAll('_', '-').toLowerCase();
  final lang = loc.split('-').first;
  final percentValue = value <= 1.0 && value >= -1.0 ? value * 100 : value;
  final numStr = formatNumber(percentValue, locale: locale, decimalDigits: decimalDigits);

  if (['fr', 'de', 'ru', 'sv', 'pl', 'fi', 'no', 'cs'].contains(lang)) {
    return '$numStr %';
  }
  return '$numStr%';
}

/// Formats a currency amount with currency code/symbol and locale positioning in pure Dart.
///
/// ```dart
/// formatCurrency(49.99, currency: 'USD', locale: 'en-US'); // "$49.99"
/// formatCurrency(49.99, currency: 'EUR', locale: 'fr-FR'); // "49,99 €"
/// formatCurrency(1500, currency: 'JPY', locale: 'ja-JP');   // "¥1,500"
/// ```
String formatCurrency(
  num value, {
  String currency = 'USD',
  String? locale,
  int? decimalDigits,
}) {
  final loc = (locale ?? BloomI18n.instance.locale.value).replaceAll('_', '-').toLowerCase();
  final lang = loc.split('-').first;

  final symbols = <String, String>{
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CAD': r'CA$',
    'AUD': r'A$',
    'CHF': 'CHF',
    'CNY': '¥',
    'INR': '₹',
    'BRL': r'R$',
    'KRW': '₩',
    'RUB': '₽',
  };

  final symbol = symbols[currency.toUpperCase()] ?? currency;
  final decimals = decimalDigits ?? (['JPY', 'KRW'].contains(currency.toUpperCase()) ? 0 : 2);
  final numStr = formatNumber(value, locale: locale, decimalDigits: decimals);

  // Position symbol
  if (['fr', 'de', 'ru', 'es', 'pt', 'it', 'sv', 'pl', 'nl', 'fi', 'no'].contains(lang)) {
    return '$numStr $symbol';
  } else if (['ar'].contains(lang)) {
    return '$symbol $numStr';
  }
  return '$symbol$numStr';
}

const _monthNamesEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
const _monthNamesEnShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _dayNamesEn = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
// Note: no DateFormatStyle currently renders an abbreviated weekday, so the
// short day-name tables are deliberately absent. Add them alongside a style
// that uses them rather than leaving them unreferenced.

const _monthNamesFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];
const _monthNamesFrShort = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
];
const _dayNamesFr = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
];

const _monthNamesDe = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
];
const _monthNamesDeShort = [
  'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni',
  'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.'
];
const _dayNamesDe = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'
];

const _monthNamesEs = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
];
const _monthNamesEsShort = [
  'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
  'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
];
const _dayNamesEs = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
];

/// Formats a [DateTime] date according to locale conventions in pure Dart.
///
/// Supports named [style] presets ([DateFormatStyle.short], [DateFormatStyle.medium],
/// [DateFormatStyle.long], [DateFormatStyle.full]) or custom [pattern] tokens (`yyyy`, `MM`, `dd`, etc.).
///
/// ```dart
/// final date = DateTime(2026, 8, 23);
/// formatDate(date, locale: 'en-US'); // "8/23/2026"
/// formatDate(date, locale: 'en-GB'); // "23/08/2026"
/// formatDate(date, locale: 'de-DE'); // "23.08.2026"
/// formatDate(date, style: DateFormatStyle.long, locale: 'en-US'); // "August 23, 2026"
/// ```
String formatDate(
  DateTime date, {
  String? locale,
  String? pattern,
  DateFormatStyle? style,
}) {
  final loc = (locale ?? BloomI18n.instance.locale.value).replaceAll('_', '-');
  final lang = loc.split('-').first.toLowerCase();

  if (pattern != null) {
    return _formatDateWithPattern(date, pattern, lang);
  }

  final effectiveStyle = style ?? DateFormatStyle.short;
  return _formatDateWithStyle(date, effectiveStyle, loc, lang);
}

String _formatDateWithStyle(
    DateTime date, DateFormatStyle style, String loc, String lang) {
  final y = date.year.toString();
  final m = date.month.toString();
  final mm = date.month.toString().padLeft(2, '0');
  final d = date.day.toString();
  final dd = date.day.toString().padLeft(2, '0');

  List<String> monthNames = _monthNamesEn;
  List<String> monthNamesShort = _monthNamesEnShort;
  List<String> dayNames = _dayNamesEn;

  if (lang == 'fr') {
    monthNames = _monthNamesFr;
    monthNamesShort = _monthNamesFrShort;
    dayNames = _dayNamesFr;
  } else if (lang == 'de') {
    monthNames = _monthNamesDe;
    monthNamesShort = _monthNamesDeShort;
    dayNames = _dayNamesDe;
  } else if (lang == 'es') {
    monthNames = _monthNamesEs;
    monthNamesShort = _monthNamesEsShort;
    dayNames = _dayNamesEs;
  }

  final monthName = monthNames[date.month - 1];
  final monthNameShort = monthNamesShort[date.month - 1];
  final weekdayName = dayNames[date.weekday - 1];

  switch (style) {
    case DateFormatStyle.short:
      if (loc.toLowerCase() == 'en-us') {
        return '$m/$d/$y';
      } else if (['de', 'ru', 'pl', 'cz'].contains(lang)) {
        return '$dd.$mm.$y';
      } else if (['ja', 'zh', 'ko', 'hu'].contains(lang)) {
        return '$y/$mm/$dd';
      }
      return '$dd/$mm/$y';

    case DateFormatStyle.medium:
      if (loc.toLowerCase() == 'en-us') {
        return '$monthNameShort $d, $y';
      } else if (['de'].contains(lang)) {
        return '$d. $monthNameShort $y';
      } else if (['ja', 'zh', 'ko'].contains(lang)) {
        return '$y年$m月$d日';
      }
      return '$d $monthNameShort $y';

    case DateFormatStyle.long:
      if (loc.toLowerCase() == 'en-us') {
        return '$monthName $d, $y';
      } else if (['de'].contains(lang)) {
        return '$d. $monthName $y';
      } else if (['ja', 'zh', 'ko'].contains(lang)) {
        return '$y年$m月$d日';
      }
      return '$d $monthName $y';

    case DateFormatStyle.full:
      if (loc.toLowerCase() == 'en-us') {
        return '$weekdayName, $monthName $d, $y';
      } else if (['de'].contains(lang)) {
        return '$weekdayName, $d. $monthName $y';
      } else if (['ja', 'zh', 'ko'].contains(lang)) {
        return '$y年$m月$d日 $weekdayName';
      }
      return '$weekdayName $d $monthName $y';
  }
}

String _formatDateWithPattern(DateTime date, String pattern, String lang) {
  var result = pattern;

  final yyyy = date.year.toString();
  final yy = date.year.toString().substring(2);
  final mm = date.month.toString().padLeft(2, '0');
  final m = date.month.toString();
  final dd = date.day.toString().padLeft(2, '0');
  final d = date.day.toString();
  final hh24 = date.hour.toString().padLeft(2, '0');
  final h24 = date.hour.toString();
  final hour12 = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
  final hh12 = hour12.toString().padLeft(2, '0');
  final h12 = hour12.toString();
  final min = date.minute.toString().padLeft(2, '0');
  final sec = date.second.toString().padLeft(2, '0');
  final ampm = date.hour < 12 ? 'AM' : 'PM';

  final monthNames = lang == 'fr'
      ? _monthNamesFr
      : (lang == 'de'
          ? _monthNamesDe
          : (lang == 'es' ? _monthNamesEs : _monthNamesEn));
  final monthNamesShort = lang == 'fr'
      ? _monthNamesFrShort
      : (lang == 'de'
          ? _monthNamesDe
          : (lang == 'es' ? _monthNamesEs : _monthNamesEnShort));

  result = result.replaceAll('yyyy', yyyy);
  result = result.replaceAll('yy', yy);
  result = result.replaceAll('MMMM', monthNames[date.month - 1]);
  result = result.replaceAll('MMM', monthNamesShort[date.month - 1]);
  result = result.replaceAll('MM', mm);
  result = result.replaceAll('M', m);
  result = result.replaceAll('dd', dd);
  result = result.replaceAll('d', d);
  result = result.replaceAll('HH', hh24);
  result = result.replaceAll('H', h24);
  result = result.replaceAll('hh', hh12);
  result = result.replaceAll('h', h12);
  result = result.replaceAll('mm', min);
  result = result.replaceAll('ss', sec);
  result = result.replaceAll('a', ampm);

  return result;
}

/// Formats a [DateTime] date and time according to locale conventions in pure Dart.
///
/// ```dart
/// final dt = DateTime(2026, 8, 23, 14, 30);
/// formatDateTime(dt, locale: 'en-US'); // "8/23/2026, 2:30 PM"
/// formatDateTime(dt, locale: 'fr-FR'); // "23/08/2026 14:30"
/// ```
String formatDateTime(
  DateTime dateTime, {
  String? locale,
  String? pattern,
  DateFormatStyle? style,
}) {
  if (pattern != null) {
    final loc = (locale ?? BloomI18n.instance.locale.value).replaceAll('_', '-');
    final lang = loc.split('-').first.toLowerCase();
    return _formatDateWithPattern(dateTime, pattern, lang);
  }

  final datePart = formatDate(dateTime, locale: locale, style: style);
  final loc = (locale ?? BloomI18n.instance.locale.value).replaceAll('_', '-');
  final lang = loc.split('-').first.toLowerCase();

  final h24 = dateTime.hour.toString().padLeft(2, '0');
  final min = dateTime.minute.toString().padLeft(2, '0');
  final h12 = (dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour)).toString();
  final ampm = dateTime.hour < 12 ? 'AM' : 'PM';

  if (['en-us', 'en-ca'].contains(loc.toLowerCase())) {
    return '$datePart, $h12:$min $ampm';
  } else if (['fr', 'de', 'es', 'it', 'ru'].contains(lang)) {
    return '$datePart $h24:$min';
  }
  return '$datePart $h24:$min';
}

/// Formats relative time (e.g. "just now", "5 minutes ago", "in 2 hours", "yesterday") in pure Dart.
///
/// Evaluates [date] relative to [relativeTo] (defaults to `DateTime.now()`).
///
/// ```dart
/// final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5));
/// formatRelativeTime(fiveMinAgo, locale: 'en-US'); // "5 minutes ago"
/// formatRelativeTime(fiveMinAgo, locale: 'fr-FR'); // "il y a 5 minutes"
/// ```
String formatRelativeTime(
  DateTime date, {
  DateTime? relativeTo,
  String? locale,
  bool numeric = false,
}) {
  final now = relativeTo ?? DateTime.now();
  final diff = now.difference(date);
  final isPast = !diff.isNegative;
  final absSeconds = diff.inSeconds.abs();
  final loc = (locale ?? BloomI18n.instance.locale.value).replaceAll('_', '-').toLowerCase();
  final lang = loc.split('-').first;

  if (absSeconds < 45) {
    if (lang == 'fr') return 'à l\'instant';
    if (lang == 'de') return 'gerade eben';
    if (lang == 'es') return 'hace un momento';
    if (lang == 'ja') return 'たった今';
    if (lang == 'zh') return '刚刚';
    return 'just now';
  }

  final minutes = (absSeconds / 60).round();
  if (minutes < 45) {
    return _formatRelativeUnit(minutes, 'minute', isPast, lang);
  }

  final hours = (absSeconds / 3600).round();
  if (hours < 22) {
    return _formatRelativeUnit(hours, 'hour', isPast, lang);
  }

  final days = (absSeconds / 86400).round();
  if (days == 1 && !numeric) {
    if (isPast) {
      if (lang == 'fr') return 'hier';
      if (lang == 'de') return 'gestern';
      if (lang == 'es') return 'ayer';
      if (lang == 'ja') return '昨日';
      if (lang == 'zh') return '昨天';
      return 'yesterday';
    } else {
      if (lang == 'fr') return 'demain';
      if (lang == 'de') return 'morgen';
      if (lang == 'es') return 'mañana';
      if (lang == 'ja') return '明日';
      if (lang == 'zh') return '明天';
      return 'tomorrow';
    }
  }

  if (days < 26) {
    return _formatRelativeUnit(days, 'day', isPast, lang);
  }

  final months = (days / 30).round();
  if (months < 11) {
    return _formatRelativeUnit(months, 'month', isPast, lang);
  }

  final years = (days / 365).round();
  return _formatRelativeUnit(years, 'year', isPast, lang);
}

String _formatRelativeUnit(int count, String unit, bool isPast, String lang) {
  if (lang == 'fr') {
    final unitFr = switch (unit) {
      'minute' => count > 1 ? 'minutes' : 'minute',
      'hour' => count > 1 ? 'heures' : 'heure',
      'day' => count > 1 ? 'jours' : 'jour',
      'month' => 'mois',
      'year' => count > 1 ? 'ans' : 'an',
      _ => unit,
    };
    return isPast ? 'il y a $count $unitFr' : 'dans $count $unitFr';
  } else if (lang == 'de') {
    final unitDe = switch (unit) {
      'minute' => count > 1 ? 'Minuten' : 'Minute',
      'hour' => count > 1 ? 'Stunden' : 'Stunde',
      'day' => count > 1 ? 'Tagen' : 'Tag',
      'month' => count > 1 ? 'Monaten' : 'Monat',
      'year' => count > 1 ? 'Jahren' : 'Jahr',
      _ => unit,
    };
    return isPast ? 'vor $count $unitDe' : 'in $count $unitDe';
  } else if (lang == 'es') {
    final unitEs = switch (unit) {
      'minute' => count > 1 ? 'minutos' : 'minuto',
      'hour' => count > 1 ? 'horas' : 'hora',
      'day' => count > 1 ? 'días' : 'día',
      'month' => count > 1 ? 'meses' : 'mes',
      'year' => count > 1 ? 'años' : 'año',
      _ => unit,
    };
    return isPast ? 'hace $count $unitEs' : 'en $count $unitEs';
  } else if (lang == 'ja') {
    final unitJa = switch (unit) {
      'minute' => '分',
      'hour' => '時間',
      'day' => '日',
      'month' => 'ヶ月',
      'year' => '年',
      _ => unit,
    };
    return isPast ? '$count$unitJa前' : '$count$unitJa後';
  } else if (lang == 'zh') {
    final unitZh = switch (unit) {
      'minute' => '分钟',
      'hour' => '小时',
      'day' => '天',
      'month' => '个月',
      'year' => '年',
      _ => unit,
    };
    return isPast ? '$count$unitZh前' : '$count$unitZh后';
  }

  // English fallback
  final unitEn = count == 1 ? unit : '${unit}s';
  return isPast ? '$count $unitEn ago' : 'in $count $unitEn';
}

/// Convenience extension on [DateTime] for localized formatting.
extension BloomDateTimeClientI18n on DateTime {
  /// Formats this date as a localized date string.
  String toLocalizedDate({String? locale, String? pattern, DateFormatStyle? style}) =>
      formatDate(this, locale: locale, pattern: pattern, style: style);

  /// Formats this date as a localized date and time string.
  String toLocalizedDateTime({String? locale, String? pattern, DateFormatStyle? style}) =>
      formatDateTime(this, locale: locale, pattern: pattern, style: style);

  /// Formats this date as a relative time string (e.g. "5 minutes ago").
  String toLocalizedRelativeTime({DateTime? relativeTo, String? locale}) =>
      formatRelativeTime(this, relativeTo: relativeTo, locale: locale);
}

// ─── Text Direction & RTL Support ──────────────────────────────────────────

/// Text direction representation.
enum BloomTextDirection {
  /// Left-to-right (default for Latin, Cyrillic, Han, etc.).
  ltr('ltr'),

  /// Right-to-left (Arabic, Hebrew, Persian, Urdu, etc.).
  rtl('rtl');

  /// The HTML `dir` attribute value (`"ltr"` or `"rtl"`).
  final String value;

  const BloomTextDirection(this.value);

  @override
  String toString() => value;
}

const _rtlLanguages = {
  'ar', // Arabic
  'he', // Hebrew
  'iw', // Hebrew (legacy)
  'fa', // Persian (Farsi)
  'ur', // Urdu
  'ps', // Pashto
  'sd', // Sindhi
  'ug', // Uyghur
  'yi', // Yiddish
  'syr', // Syriac
  'arc', // Aramaic
  'ckb', // Central Kurdish (Sorani)
  'ku', // Kurdish
  'dv', // Divehi
};

/// Returns `true` if [locale] represents a right-to-left (RTL) script.
///
/// Defaults to testing the active [BloomI18n.instance.locale] signal when [locale] is omitted.
///
/// ```dart
/// isRtl('ar-EG'); // true
/// isRtl('en-US'); // false
/// ```
bool isRtl([String? locale]) {
  final loc = (locale ?? BloomI18n.instance.locale.value).replaceAll('_', '-').toLowerCase();
  final lang = loc.split('-').first;
  return _rtlLanguages.contains(lang);
}

/// Returns the [BloomTextDirection] ([BloomTextDirection.rtl] or [BloomTextDirection.ltr]) for [locale].
///
/// ```dart
/// getTextDirection('ar-SA'); // BloomTextDirection.rtl
/// getTextDirection('en-US'); // BloomTextDirection.ltr
/// ```
BloomTextDirection getTextDirection([String? locale]) {
  return isRtl(locale) ? BloomTextDirection.rtl : BloomTextDirection.ltr;
}

/// Helper returning a `{ 'dir': 'rtl' }` or `{ 'dir': 'ltr' }` attribute map.
///
/// Useful for spreading directly into element attributes:
///
/// ```dart
/// Div(
///   attrs: {
///     ...dirAttribute(),
///     'id': 'main-content',
///   },
///   children: [...],
/// )
/// ```
Map<String, String> dirAttribute([String? locale]) {
  return {'dir': getTextDirection(locale).value};
}

// ─── Locale Resolution & Accept-Language ────────────────────────────────────

/// Request wrapper carrying the resolved BCP-47 locale string.
class ResolvedLocale {
  /// The resolved BCP-47 language tag (e.g. `'en-US'`, `'fr-FR'`, `'de'`).
  final String languageTag;

  const ResolvedLocale(this.languageTag);

  @override
  String toString() => languageTag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedLocale &&
          runtimeType == other.runtimeType &&
          languageTag.toLowerCase() == other.languageTag.toLowerCase();

  @override
  int get hashCode => languageTag.toLowerCase().hashCode;
}

/// A parsed entry from language preferences or `Accept-Language` headers with quality weighting.
class AcceptLanguageEntry implements Comparable<AcceptLanguageEntry> {
  /// The BCP-47 language tag or subtag (e.g. `'fr'`, `'en-US'`).
  final String tag;

  /// Quality value weight (`q=`) ranging between `0.0` and `1.0`.
  final double quality;

  /// Creates an [AcceptLanguageEntry] with [tag] and optional [quality] weighting.
  const AcceptLanguageEntry(this.tag, [this.quality = 1.0]);

  @override
  int compareTo(AcceptLanguageEntry other) {
    final diff = other.quality.compareTo(quality);
    if (diff != 0) return diff;
    return 0;
  }

  @override
  String toString() => '$tag;q=$quality';
}

/// Parses the first valid BCP-47 language tag from an `Accept-Language` header string.
String? firstLocaleTag(String? header) {
  if (header == null) return null;
  final firstPart = header.split(',').firstOrNull;
  if (firstPart == null) return null;

  final tag = firstPart.trim().split(';').firstOrNull?.trim();
  if (tag == null || tag.isEmpty || tag == '*') {
    return null;
  }

  return _isValidLanguageTag(tag) ? tag : null;
}

/// Parses an entire `Accept-Language` header string, sorting entries by quality weight (`q=`).
List<AcceptLanguageEntry> parseAcceptLanguage(String? header) {
  if (header == null || header.trim().isEmpty) return const [];

  final entries = <AcceptLanguageEntry>[];
  final items = header.split(',');

  for (final item in items) {
    final trimmed = item.trim();
    if (trimmed.isEmpty) continue;

    final parts = trimmed.split(';');
    final tag = parts[0].trim();
    if (tag.isEmpty || tag == '*' || !_isValidLanguageTag(tag)) continue;

    double quality = 1.0;
    if (parts.length > 1) {
      for (int i = 1; i < parts.length; i++) {
        final param = parts[i].trim();
        if (param.startsWith('q=') || param.startsWith('Q=')) {
          final parsedQ = double.tryParse(param.substring(2).trim());
          if (parsedQ != null) {
            quality = parsedQ.clamp(0.0, 1.0);
          }
        }
      }
    }

    if (quality > 0.0) {
      entries.add(AcceptLanguageEntry(tag, quality));
    }
  }

  entries.sort();
  return entries;
}

bool _isValidLanguageTag(String tag) {
  final regex = RegExp(r'^[a-zA-Z]{1,8}(-[a-zA-Z0-9]{1,8})*$');
  return regex.hasMatch(tag);
}

/// Resolves an active locale from an ordered list of preferences (e.g. `navigator.languages`).
///
/// Matches against [supported] locale tags using exact matching first, then base language subtags,
/// falling back to [fallback] if no candidate matches.
///
/// ```dart
/// final chosen = resolveLocale(
///   ['fr-CA', 'fr-FR', 'en'],
///   supported: ['en-US', 'fr-FR'],
///   fallback: 'en-US',
/// );
/// // chosen: "fr-FR"
/// ```
String resolveLocale(
  List<String> preferences, {
  List<String>? supported,
  String fallback = 'en-US',
}) {
  if (supported == null || supported.isEmpty) {
    return preferences.isNotEmpty ? preferences.first : fallback;
  }

  final normalizedSupported = supported.map((s) => s.replaceAll('_', '-').toLowerCase()).toList();

  // 1. Exact match
  for (final pref in preferences) {
    final normPref = pref.replaceAll('_', '-').toLowerCase();
    final idx = normalizedSupported.indexOf(normPref);
    if (idx != -1) return supported[idx];
  }

  // 2. Base language match (e.g. 'fr' for 'fr-CA')
  for (final pref in preferences) {
    final basePref = pref.replaceAll('_', '-').split('-').first.toLowerCase();
    for (int i = 0; i < normalizedSupported.length; i++) {
      final baseSupported = normalizedSupported[i].split('-').first;
      if (baseSupported == basePref) {
        return supported[i];
      }
    }
  }

  return fallback;
}

/// Contract for persisting user locale selection across sessions.
///
/// Pure-Dart interface. In browser environments, adapters can implement this using
/// `window.localStorage` without introducing browser dependencies into core logic.
abstract class LocaleStorage {
  /// Loads the persisted locale identifier, or `null` if none saved.
  Future<String?> load();

  /// Persists [locale].
  Future<void> save(String locale);
}

/// In-memory implementation of [LocaleStorage] suitable for testing and SSR.
class InMemoryLocaleStorage implements LocaleStorage {
  String? _saved;

  /// Creates an in-memory storage optionally initialized with [initial].
  InMemoryLocaleStorage([this._saved]);

  @override
  Future<String?> load() async => _saved;

  @override
  Future<void> save(String locale) async {
    _saved = locale;
  }
}

// ─── Reactive i18n Store ───────────────────────────────────────────────────

/// Reactive internationalization controller and catalog store for Bloom applications.
///
/// Manages registered message catalogs, dynamic catalog loading, fallback resolution,
/// and provides reactive signal state ([locale], [isLoading]) that triggers fine-grained
/// UI re-renders inside [Live] blocks when the locale updates.
///
/// ```dart
/// // Setup catalogs
/// BloomI18n.instance.addCatalog(BloomCatalog('en-US', {
///   'welcome': 'Welcome to Bloom!',
/// }));
/// BloomI18n.instance.addCatalog(BloomCatalog('fr-FR', {
///   'welcome': 'Bienvenue sur Bloom !',
/// }));
///
/// // In a reactive component:
/// BloomNode greeting() => Live(() => Div(
///   text: t('welcome'),
/// ));
///
/// // Change locale seamlessly:
/// BloomI18n.instance.setLocale('fr-FR'); // Re-renders greeting() automatically
/// ```
class BloomI18n {
  /// Reactive signal containing the current active locale tag (e.g. `'en-US'`).
  final Signal<String> locale;

  /// Fallback locale used when a message is missing in the active locale.
  final Signal<String> defaultLocale;

  /// Reactive signal indicating whether an asynchronous catalog is currently loading.
  final Signal<bool> isLoading = signal(false);

  final Map<String, BloomCatalog> _catalogs = {};
  final Map<String, Future<BloomCatalog> Function()> _loaders = {};

  /// Optional handler called whenever a requested translation key is missing.
  void Function(String key, String locale)? onMissingKey;

  /// Optional storage adapter for persisting locale choices.
  final LocaleStorage? storage;

  /// Global singleton instance of [BloomI18n].
  static final BloomI18n instance = BloomI18n();

  /// Creates a new [BloomI18n] store instance.
  BloomI18n({
    String initialLocale = 'en-US',
    String defaultLocale = 'en-US',
    Map<String, BloomCatalog>? catalogs,
    this.onMissingKey,
    this.storage,
  })  : locale = signal(initialLocale),
        defaultLocale = signal(defaultLocale) {
    if (catalogs != null) {
      _catalogs.addAll(catalogs);
    }
  }

  /// The active locale string value.
  String get currentLocale => locale.value;

  /// Sets the active locale string value.
  set currentLocale(String val) => setLocale(val);

  /// Whether the currently active locale uses a right-to-left (RTL) script.
  bool get isCurrentRtl => isRtl(locale.value);

  /// The text direction of the currently active locale.
  BloomTextDirection get currentDirection => getTextDirection(locale.value);

  /// Changes the active locale to [newLocale] and persists it if [storage] is configured.
  void setLocale(String newLocale) {
    locale.value = newLocale;
    storage?.save(newLocale);
  }

  /// Adds an already-constructed [BloomCatalog] to the store.
  void addCatalog(BloomCatalog catalog) {
    _catalogs[catalog.locale] = catalog;
  }

  /// Adds a map of ICU message templates for [locale].
  void addMessages(String locale, Map<String, String> messages) {
    _catalogs[locale] = BloomCatalog(locale, messages);
  }

  /// Adds messages from a dynamic/JSON map for [locale].
  void addJson(String locale, Map<String, dynamic> json) {
    _catalogs[locale] = BloomCatalog.fromJson(locale, json);
  }

  /// Registers an asynchronous catalog loader function for [locale].
  ///
  /// Enables code-splitting and on-demand loading of translation bundles.
  void registerLoader(
    String locale,
    Future<BloomCatalog> Function() loader,
  ) {
    _loaders[locale] = loader;
  }

  /// Asynchronously loads the catalog for [targetLocale] if a loader is registered.
  ///
  /// Returns `true` if a catalog is loaded or already present.
  Future<bool> loadLocale(String targetLocale) async {
    if (_catalogs.containsKey(targetLocale)) return true;

    final loader = _loaders[targetLocale] ?? _findLoaderNormalized(targetLocale);
    if (loader == null) return false;

    isLoading.value = true;
    try {
      final catalog = await loader();
      addCatalog(catalog);
      return true;
    } finally {
      isLoading.value = false;
    }
  }

  /// Returns the registered [BloomCatalog] for [targetLocale], or `null` if not loaded.
  BloomCatalog? getCatalog(String targetLocale) =>
      _catalogs[targetLocale] ?? _findCatalogNormalized(targetLocale);

  /// Checks if a catalog is registered or currently loaded for [targetLocale].
  bool hasLocale(String targetLocale) => getCatalog(targetLocale) != null;

  /// Returns a list of all registered/loaded locale tags.
  List<String> get supportedLocales => List.unmodifiable(_catalogs.keys);

  /// Translates [messageId] for [targetLocale] (or active [locale] if null), substituting [args].
  ///
  /// Fallback resolution order:
  /// 1. Exact requested locale catalog (e.g. `'en-US'`)
  /// 2. Language-only subtag of requested locale (e.g. `'en'`)
  /// 3. Configured [defaultLocale] catalog (e.g. `'en-US'`)
  /// 4. Language-only subtag of [defaultLocale] (e.g. `'en'`)
  /// 5. The raw [messageId] itself (and calls [onMissingKey] if configured).
  String translate(
    String messageId, {
    Map<String, Object>? args,
    String? locale,
  }) {
    // Read reactive signal if no explicit locale was passed so Live subtrees track updates
    final active = locale ?? this.locale.value;

    // 1. Try requested locale
    if (active.trim().isNotEmpty) {
      final targetCat = _findCatalogNormalized(active);
      if (targetCat != null) {
        final message = targetCat.get(messageId, args: args);
        if (message != null) return message;
      }

      // 2. Try language subtag of requested locale (e.g. 'en' for 'en-US')
      final langSubtag = _extractLanguageSubtag(active);
      if (langSubtag != null && langSubtag != active) {
        final langCat = _findCatalogNormalized(langSubtag);
        if (langCat != null) {
          final message = langCat.get(messageId, args: args);
          if (message != null) return message;
        }
      }
    }

    // 3. Try default locale
    final def = defaultLocale.value;
    final defaultCat = _findCatalogNormalized(def);
    if (defaultCat != null) {
      final message = defaultCat.get(messageId, args: args);
      if (message != null) return message;
    }

    // 4. Try language subtag of default locale
    final defaultLangSubtag = _extractLanguageSubtag(def);
    if (defaultLangSubtag != null && defaultLangSubtag != def) {
      final langCat = _findCatalogNormalized(defaultLangSubtag);
      if (langCat != null) {
        final message = langCat.get(messageId, args: args);
        if (message != null) return message;
      }
    }

    // 5. Missing key handler notification & raw key fallback
    onMissingKey?.call(messageId, active);
    return messageId;
  }

  /// Shorthand alias for [translate].
  String t(
    String messageId, {
    Map<String, Object>? args,
    String? locale,
  }) =>
      translate(messageId, args: args, locale: locale);

  BloomCatalog? _findCatalogNormalized(String localeTag) {
    if (_catalogs.containsKey(localeTag)) {
      return _catalogs[localeTag];
    }
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    for (final entry in _catalogs.entries) {
      if (entry.key.replaceAll('_', '-').toLowerCase() == normalized) {
        return entry.value;
      }
    }
    return null;
  }

  Future<BloomCatalog> Function()? _findLoaderNormalized(String localeTag) {
    if (_loaders.containsKey(localeTag)) {
      return _loaders[localeTag];
    }
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    for (final entry in _loaders.entries) {
      if (entry.key.replaceAll('_', '-').toLowerCase() == normalized) {
        return entry.value;
      }
    }
    return null;
  }

  String? _extractLanguageSubtag(String localeTag) {
    final delimiter =
        localeTag.contains('-') ? '-' : (localeTag.contains('_') ? '_' : null);
    if (delimiter != null) {
      final subtag = localeTag.split(delimiter).first.trim();
      if (subtag.isNotEmpty) return subtag;
    }
    return null;
  }
}

// ─── Global Shorthand Functions ─────────────────────────────────────────────

/// Translates [messageId] for the current active locale, automatically tracking reactivity.
///
/// When called inside a [Live] builder without an explicit [locale], reads
/// [BloomI18n.instance.locale] so that updates to the current locale trigger a re-render.
///
/// ```dart
/// BloomNode greeting() => Live(() => Div(
///   text: t('greeting', args: {'name': 'Alice'}),
/// ));
/// ```
String t(
  String messageId, {
  Map<String, Object>? args,
  String? locale,
}) =>
    BloomI18n.instance.t(messageId, args: args, locale: locale);

/// Shorthand alias for [t].
String tr(
  String messageId, [
  Map<String, Object>? args,
]) =>
    BloomI18n.instance.t(messageId, args: args);

/// Returns the global reactive locale signal.
Signal<String> get currentLocaleSignal => BloomI18n.instance.locale;

/// Changes the active locale globally on [BloomI18n.instance].
void setLocale(String locale) => BloomI18n.instance.setLocale(locale);

/// Asynchronously loads a catalog bundle for [locale] via [BloomI18n.instance].
Future<bool> loadLocale(String locale) =>
    BloomI18n.instance.loadLocale(locale);

/// Formats a localized date for the active locale.
String localizedDate(DateTime date, [String? locale, String? pattern]) =>
    formatDate(date, locale: locale, pattern: pattern);

/// Formats a localized date and time for the active locale.
String localizedDateTime(DateTime dateTime, [String? locale, String? pattern]) =>
    formatDateTime(dateTime, locale: locale, pattern: pattern);

/// Formats a localized relative time string for the active locale.
String localizedRelativeTime(DateTime date, [DateTime? relativeTo, String? locale]) =>
    formatRelativeTime(date, relativeTo: relativeTo, locale: locale);

/// Formats a localized number for the active locale.
String localizedNumber(num value, [String? locale, int? decimalDigits]) =>
    formatNumber(value, locale: locale, decimalDigits: decimalDigits);

/// Formats a localized currency string for the active locale.
String localizedCurrency(num value, [String currency = 'USD', String? locale]) =>
    formatCurrency(value, currency: currency, locale: locale);
