// lib/src/i18n.dart
//
// Pure-Dart Internationalization (i18n) module for Bloom JS Native.
// Safe for both SSR (VM) and browser DOM mounting. Zero DOM or browser imports.

import 'dart:async';
import 'dart:convert';
import 'package:signals_core/signals_core.dart';

// ─── ICU Message Formatter & Catalog ────────────────────────────────────────

/// A localized message catalog storing translated templates for a single BCP-47 locale.
///
/// Stores translation message templates indexed by message ID and evaluates them
/// using ICU MessageFormat syntax in pure Dart. Supports variable interpolation,
/// pluralization with `#` count replacement, select/gender branching, nested sub-patterns,
/// number formatting, and date formatting.
///
/// Fully source- and syntax-compatible with server-side `packages/bloom_i18n`.
///
/// ### Supported ICU MessageFormat Syntax
/// - **Variable Interpolation**: `{name}` substitutes `args['name']`.
/// - **Escaped Characters**: Two consecutive single quotes `''` emit a single quote `'`.
///   Quoted brace blocks such as `'{escaped}'` prevent interpolation and emit `{escaped}`.
/// - **Plurals**: `{count, plural, =0 {No items} =1 {One item} other {# items}}`.
///   Exact numeric matches (`=0`, `=1`, `=2`, etc.) take precedence over keyword
///   branches (`zero`, `one`, `two`, `other`). The `#` character within a plural branch
///   is automatically replaced by the localized number representation via [formatNumber].
/// - **Select & Gender**: `{gender, select, female {She liked} male {He liked} other {They liked}}`.
/// - **Number Formatting**: `{amount, number, currency}` or `{rate, number, percent}`.
/// - **Date Formatting**: `{date, date, short}`, `{date, date, medium}`, `{date, date, long}`,
///   `{date, date, full}`, or custom token patterns like `{date, date, yyyy-MM-dd}`.
///
/// ```dart
/// final catalog = BloomCatalog('en-US', {
///   'greeting': 'Hello, {name}!',
///   'cart_items': '{count, plural, =0 {Cart is empty} =1 {1 item} other {# items}}',
/// });
///
/// final text = catalog.get('cart_items', args: {'count': 3}); // "3 items"
/// ```
///
/// See also:
/// - [BloomI18n], the reactive multi-catalog translation store.
/// - [formatNumber], [formatCurrency], and [formatDate] for standalone formatting.
class BloomCatalog {
  /// The BCP-47 language tag identifying the locale of this catalog (e.g. `'en-US'`, `'fr-FR'`, `'de'`).
  final String locale;

  /// Internal message key-value store.
  final Map<String, String> _messages;

  /// Creates a [BloomCatalog] from a map of message IDs to ICU-formatted message templates.
  ///
  /// ```dart
  /// final catalog = BloomCatalog('en-US', {
  ///   'welcome': 'Welcome, {user}!',
  ///   'status': 'Status: {status, select, active {Online} other {Offline}}',
  /// });
  /// ```
  BloomCatalog(this.locale, Map<String, String> messages)
      : _messages = Map<String, String>.from(messages);

  /// Creates a [BloomCatalog] from a dynamic map, converting values to strings.
  ///
  /// Useful when parsing translation bundles loaded from JSON assets or network endpoints.
  ///
  /// ```dart
  /// final rawJson = {'home.title': 'Dashboard', 'home.unread': '{count, plural, =0 {None} other {# unread}}'};
  /// final catalog = BloomCatalog.fromJson('en-US', rawJson);
  /// ```
  factory BloomCatalog.fromJson(String locale, Map<String, dynamic> json) {
    final messages = <String, String>{};
    json.forEach((key, value) {
      if (value != null) {
        messages[key] = value.toString();
      }
    });
    return BloomCatalog(locale, messages);
  }

  /// Creates a [BloomCatalog] by decoding a JSON-encoded string.
  ///
  /// Throws a [FormatException] if [jsonString] does not decode to a valid JSON object map.
  ///
  /// ```dart
  /// const json = '{"welcome": "Hello!", "notifications": "{count} new"}';
  /// final catalog = BloomCatalog.fromJsonString('en-US', json);
  /// ```
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

  /// Returns an unmodifiable view of all registered message template strings.
  Map<String, String> get messages => Map.unmodifiable(_messages);

  /// Returns `true` if this catalog contains a template defined for [messageId].
  ///
  /// ```dart
  /// if (catalog.has('auth.login')) {
  ///   print('Login key is available.');
  /// }
  /// ```
  bool has(String messageId) => _messages.containsKey(messageId);

  /// Looks up and evaluates an ICU MessageFormat template by [messageId].
  ///
  /// Substitutes [args] into the message pattern according to ICU rules (plurals,
  /// select, numbers, dates). Returns `null` if [messageId] is not found in this catalog.
  ///
  /// ```dart
  /// final msg = catalog.get('unread_messages', args: {'count': 4});
  /// ```
  ///
  /// See also:
  /// - [BloomI18n.translate], which evaluates catalogs with fallback chains.
  /// - [formatMessage], the underlying static message evaluation method.
  String? get(String messageId, {Map<String, Object>? args}) {
    final template = _messages[messageId];
    if (template == null) return null;
    return formatMessage(template, args: args, locale: locale);
  }

  /// Evaluates an ICU MessageFormat [template] string with [args] for the specified [locale].
  ///
  /// Supports argument interpolation `{name}`, plurals `{count, plural, ...}` with `#` replacement,
  /// select `{gender, select, ...}`, number formatting `{amount, number, currency}`, and date
  /// formatting `{date, date, short}` in pure Dart without dependencies on `package:intl`.
  ///
  /// ```dart
  /// final result = BloomCatalog.formatMessage(
  ///   'You have {count, plural, =0 {no messages} =1 {one message} other {# messages}}',
  ///   args: {'count': 5},
  ///   locale: 'en-US',
  /// );
  /// // result: "You have 5 messages"
  /// ```
  ///
  /// See also:
  /// - [get], which looks up a template by key before formatting.
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

/// Formatting styles for localized date presentations.
///
/// Used with [formatDate] and [BloomDateTimeClientI18n.toLocalizedDate] to select
/// standard formatting presets.
///
/// ```dart
/// final date = DateTime(2026, 8, 23);
/// formatDate(date, style: DateFormatStyle.medium, locale: 'en-US'); // "Aug 23, 2026"
/// ```
///
/// See also:
/// - [formatDate], which formats dates according to these styles.
/// - [formatDateTime], which combines date styles with localized time strings.
enum DateFormatStyle {
  /// Short compact date representation (e.g. `"8/23/2026"`, `"23/08/2026"`, `"23.08.2026"`).
  short,

  /// Medium abbreviated date representation (e.g. `"Aug 23, 2026"`, `"23 août 2026"`, `"23. Aug. 2026"`).
  medium,

  /// Long full-month date representation (e.g. `"August 23, 2026"`, `"23 août 2026"`, `"23. August 2026"`).
  long,

  /// Complete full date including weekday name (e.g. `"Sunday, August 23, 2026"`).
  full,
}

/// Formats a [num] value with locale-aware grouping and decimal separators in pure Dart.
///
/// Formats integers and floating point numbers according to language conventions,
/// using appropriate thousand separators (`","`, `"."`, `" "`, or `"٬"`) and decimal
/// points (`"."`, `","`, or `"٫"`). When [locale] is omitted, uses the active
/// [BloomI18n.instance.locale] signal value.
///
/// ### Limitations vs Full CLDR
/// This is a lightweight, pure-Dart implementation covering major language families
/// (English, French, German, Spanish, Portuguese, Italian, Russian, Japanese, Chinese,
/// Arabic, etc.). It does not include full Unicode CLDR tables or localized numbering
/// systems (e.g. eastern Arabic-Indic numerals).
///
/// ```dart
/// formatNumber(1234567.89, locale: 'en-US'); // "1,234,567.89"
/// formatNumber(1234567.89, locale: 'de-DE'); // "1.234.567,89"
/// formatNumber(1234567.89, locale: 'fr-FR'); // "1 234 567,89"
/// ```
///
/// See also:
/// - [formatPercent], for formatting percentage values.
/// - [formatCurrency], for currency formatting.
/// - [localizedNumber], convenience top-level shorthand.
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

/// Formats a percentage value for [locale] in pure Dart.
///
/// Accepts ratio fractions between `-1.0` and `1.0` (e.g. `0.42` becomes `42%`) as well
/// as whole percentage numbers (e.g. `42` becomes `42%`). Includes appropriate locale spacing
/// before the `%` symbol for languages such as French, German, Russian, and Swedish.
///
/// When [locale] is omitted, defaults to the active [BloomI18n.instance.locale] value.
///
/// ```dart
/// formatPercent(0.42, locale: 'en-US'); // "42%"
/// formatPercent(0.42, locale: 'fr-FR'); // "42 %"
/// ```
///
/// See also:
/// - [formatNumber], the underlying number formatter.
/// - [formatCurrency], for currency formatting.
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

/// Formats a currency amount with currency code or symbol and locale positioning in pure Dart.
///
/// Maps common ISO 4217 currency codes (`USD`, `EUR`, `GBP`, `JPY`, `CAD`, `AUD`, `CHF`, `CNY`,
/// `INR`, `BRL`, `KRW`, `RUB`) to symbols, applies zero decimal places for zero-fraction currencies
/// (`JPY`, `KRW`), and places symbols before or after the number according to locale conventions.
///
/// When [locale] is omitted, defaults to the active [BloomI18n.instance.locale] value.
///
/// ```dart
/// formatCurrency(49.99, currency: 'USD', locale: 'en-US'); // "$49.99"
/// formatCurrency(49.99, currency: 'EUR', locale: 'fr-FR'); // "49,99 €"
/// formatCurrency(1500, currency: 'JPY', locale: 'ja-JP');   // "¥1,500"
/// ```
///
/// See also:
/// - [formatNumber], the underlying number formatting helper.
/// - [localizedCurrency], top-level convenience shorthand.
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
/// [DateFormatStyle.long], [DateFormatStyle.full]) or custom [pattern] tokens (`yyyy`, `yy`,
/// `MMMM`, `MMM`, `MM`, `M`, `dd`, `d`, `HH`, `H`, `hh`, `h`, `mm`, `ss`, `a`).
///
/// ### Limitations vs Full CLDR
/// Includes hand-rolled month and day translations for English, French, German, and Spanish.
/// For unsupported languages, month and weekday names fallback to English.
///
/// ```dart
/// final date = DateTime(2026, 8, 23);
/// formatDate(date, locale: 'en-US'); // "8/23/2026"
/// formatDate(date, locale: 'en-GB'); // "23/08/2026"
/// formatDate(date, locale: 'de-DE'); // "23.08.2026"
/// formatDate(date, style: DateFormatStyle.long, locale: 'en-US'); // "August 23, 2026"
/// ```
///
/// See also:
/// - [formatDateTime], for formatting combined dates and timestamps.
/// - [formatRelativeTime], for relative time expressions ("5 minutes ago").
/// - [DateFormatStyle], the style enumeration.
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
/// Combines localized date formatting with appropriate 12-hour (AM/PM) or 24-hour time
/// formatting based on locale rules.
///
/// When [locale] is omitted, defaults to the active [BloomI18n.instance.locale] value.
///
/// ```dart
/// final dt = DateTime(2026, 8, 23, 14, 30);
/// formatDateTime(dt, locale: 'en-US'); // "8/23/2026, 2:30 PM"
/// formatDateTime(dt, locale: 'fr-FR'); // "23/08/2026 14:30"
/// ```
///
/// See also:
/// - [formatDate], for date-only formatting.
/// - [formatRelativeTime], for relative time formatting ("5 minutes ago").
/// - [localizedDateTime], top-level convenience shorthand.
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

/// Formats relative time intervals (e.g. "just now", "5 minutes ago", "in 2 hours", "yesterday") in pure Dart.
///
/// Evaluates [date] relative to [relativeTo] (which defaults to `DateTime.now()`).
/// If [numeric] is `true`, produces numeric representations like `"1 day ago"` instead of `"yesterday"`.
///
/// Supports translations for English, French, German, Spanish, Japanese, and Chinese, falling back to English.
///
/// ```dart
/// final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5));
/// formatRelativeTime(fiveMinAgo, locale: 'en-US'); // "5 minutes ago"
/// formatRelativeTime(fiveMinAgo, locale: 'fr-FR'); // "il y a 5 minutes"
/// ```
///
/// See also:
/// - [BloomDateTimeClientI18n.toLocalizedRelativeTime], extension method on [DateTime].
/// - [localizedRelativeTime], top-level convenience shorthand.
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

/// Convenience internationalization extension on [DateTime] for localized formatting.
extension BloomDateTimeClientI18n on DateTime {
  /// Formats this date as a localized date string.
  ///
  /// ```dart
  /// final formatted = DateTime(2026, 8, 23).toLocalizedDate(locale: 'en-US'); // "8/23/2026"
  /// ```
  String toLocalizedDate({String? locale, String? pattern, DateFormatStyle? style}) =>
      formatDate(this, locale: locale, pattern: pattern, style: style);

  /// Formats this date as a localized date and time string.
  ///
  /// ```dart
  /// final formatted = DateTime.now().toLocalizedDateTime(locale: 'fr-FR');
  /// ```
  String toLocalizedDateTime({String? locale, String? pattern, DateFormatStyle? style}) =>
      formatDateTime(this, locale: locale, pattern: pattern, style: style);

  /// Formats this date as a relative time string (e.g. "5 minutes ago").
  ///
  /// ```dart
  /// final rel = DateTime.now().subtract(const Duration(minutes: 10)).toLocalizedRelativeTime();
  /// ```
  String toLocalizedRelativeTime({DateTime? relativeTo, String? locale}) =>
      formatRelativeTime(this, relativeTo: relativeTo, locale: locale);
}

// ─── Text Direction & RTL Support ──────────────────────────────────────────

/// Text direction representation for bidirectional script layout.
///
/// Encapsulates left-to-right ([BloomTextDirection.ltr]) and right-to-left
/// ([BloomTextDirection.rtl]) scripts and their corresponding HTML `dir` attribute values.
///
/// See also:
/// - [isRtl], tests whether a locale uses RTL script.
/// - [getTextDirection], resolves text direction for a locale.
/// - [dirAttribute], helper generating a `{ 'dir': '...' }` attribute map.
enum BloomTextDirection {
  /// Left-to-right text layout direction (used by Latin, Cyrillic, Greek, Han, etc.).
  ltr('ltr'),

  /// Right-to-left text layout direction (used by Arabic, Hebrew, Persian, Urdu, etc.).
  rtl('rtl');

  /// The raw HTML `dir` attribute string value (`"ltr"` or `"rtl"`).
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
/// Tests language subtags against known RTL scripts (Arabic, Hebrew, Persian, Urdu, etc.).
/// When [locale] is omitted, defaults to testing the active [BloomI18n.instance.locale] signal.
///
/// ```dart
/// isRtl('ar-EG'); // true
/// isRtl('en-US'); // false
/// ```
///
/// See also:
/// - [getTextDirection], which returns a [BloomTextDirection] enum.
/// - [dirAttribute], which produces an attribute map for element descriptors.
bool isRtl([String? locale]) {
  final loc = (locale ?? BloomI18n.instance.locale.value).replaceAll('_', '-').toLowerCase();
  final lang = loc.split('-').first;
  return _rtlLanguages.contains(lang);
}

/// Resolves the [BloomTextDirection] for the specified [locale].
///
/// Returns [BloomTextDirection.rtl] for right-to-left language tags and [BloomTextDirection.ltr]
/// for all others. Defaults to evaluating the active [BloomI18n.instance.locale] signal when omitted.
///
/// ```dart
/// getTextDirection('ar-SA'); // BloomTextDirection.rtl
/// getTextDirection('en-US'); // BloomTextDirection.ltr
/// ```
///
/// See also:
/// - [isRtl], returning a boolean check.
/// - [dirAttribute], returning an attribute map.
BloomTextDirection getTextDirection([String? locale]) {
  return isRtl(locale) ? BloomTextDirection.rtl : BloomTextDirection.ltr;
}

/// Generates a `{ 'dir': 'rtl' }` or `{ 'dir': 'ltr' }` attribute map for [locale].
///
/// Convenient for spreading directly into element attributes:
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
///
/// See also:
/// - [getTextDirection], resolving the [BloomTextDirection] enum.
/// - [isRtl], checking if a locale is right-to-left.
Map<String, String> dirAttribute([String? locale]) {
  return {'dir': getTextDirection(locale).value};
}

// ─── Locale Resolution & Accept-Language ────────────────────────────────────

/// Immutable wrapper carrying a resolved BCP-47 language tag.
///
/// Used in request pipelines and client routers to represent normalized locale identifiers
/// (e.g. `'en-US'`, `'fr-FR'`, `'de'`).
///
/// ```dart
/// const resolved = ResolvedLocale('en-US');
/// print(resolved.languageTag); // "en-US"
/// ```
///
/// See also:
/// - [resolveLocale], which resolves preferences against supported tags.
/// - [parseAcceptLanguage], which parses HTTP headers into weighted entries.
class ResolvedLocale {
  /// The resolved BCP-47 language tag (e.g. `'en-US'`, `'fr-FR'`, `'de'`).
  final String languageTag;

  /// Creates a [ResolvedLocale] containing [languageTag].
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

/// A parsed entry from an HTTP `Accept-Language` header or browser preferences with quality weighting.
///
/// Implements [Comparable] to sort entries in descending order of quality weight ([quality]),
/// from highest preference (`q=1.0`) to lowest.
///
/// ```dart
/// const entry = AcceptLanguageEntry('fr-FR', 0.9);
/// print(entry.tag); // "fr-FR"
/// print(entry.quality); // 0.9
/// ```
///
/// See also:
/// - [parseAcceptLanguage], which parses an entire header string into sorted entries.
/// - [firstLocaleTag], extracting only the top priority tag.
class AcceptLanguageEntry implements Comparable<AcceptLanguageEntry> {
  /// The BCP-47 language tag or subtag (e.g. `'fr'`, `'en-US'`).
  final String tag;

  /// Quality value weight (`q=`) ranging between `0.0` and `1.0`.
  final double quality;

  /// Creates an [AcceptLanguageEntry] with [tag] and optional [quality] weighting (defaults to `1.0`).
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
///
/// Extracts the leading entry from [header], ignoring wildcard tokens (`"*"`) and
/// discarding quality weighting parameters (`";q=..."`). Returns `null` if [header] is
/// empty or contains no valid language tag.
///
/// ```dart
/// final tag = firstLocaleTag('fr-CH, fr;q=0.9, en;q=0.8');
/// // tag: "fr-CH"
/// ```
///
/// See also:
/// - [parseAcceptLanguage], for parsing and sorting all entries in a header.
/// - [resolveLocale], for matching candidate tags against supported catalogs.
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

/// Parses an entire `Accept-Language` header string into a list of entries sorted by quality.
///
/// Splits comma-separated language tags, extracts explicit `q=` quality parameters
/// (clamping values between `0.0` and `1.0`, defaulting to `1.0`), filters out invalid
/// tokens and wildcards, and sorts results in descending preference order.
///
/// ```dart
/// final entries = parseAcceptLanguage('en-US,en;q=0.8,fr;q=0.9');
/// // entries: [en-US;q=1.0, fr;q=0.9, en;q=0.8]
/// ```
///
/// See also:
/// - [firstLocaleTag], for extracting only the first valid tag.
/// - [resolveLocale], for matching preference lists against supported locales.
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
/// Matches candidate tags in [preferences] against [supported] locale tags using:
/// 1. **Exact match**: Case-insensitive and hyphen/underscore normalized (e.g. `'en-us'` matches `'en-US'`).
/// 2. **Base language prefix match**: Evaluates the primary language subtag (e.g. `'fr-CA'` matches `'fr-FR'`
///    if only `'fr-FR'` is supported).
/// 3. **Fallback**: If no match is found, returns [fallback] (defaults to `'en-US'`).
///
/// ```dart
/// final chosen = resolveLocale(
///   ['fr-CA', 'fr-FR', 'en'],
///   supported: ['en-US', 'fr-FR'],
///   fallback: 'en-US',
/// );
/// // chosen: "fr-FR"
/// ```
///
/// See also:
/// - [BloomI18n], which uses locale tags for translation routing.
/// - [parseAcceptLanguage], for extracting preference lists from HTTP headers.
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

/// Contract for persisting user locale selection across browser sessions.
///
/// Pure-Dart interface. In browser environments, adapters can implement this using
/// `window.localStorage` without introducing browser dependencies into core logic.
/// In SSR or test environments, [InMemoryLocaleStorage] provides an in-memory fallback.
///
/// See also:
/// - [InMemoryLocaleStorage], the default memory-based adapter.
/// - [BloomI18n], which delegates locale persistence to [LocaleStorage].
abstract class LocaleStorage {
  /// Loads the persisted locale identifier, or `null` if none saved.
  Future<String?> load();

  /// Persists [locale] for future application sessions.
  Future<void> save(String locale);
}

/// In-memory implementation of [LocaleStorage] suitable for testing and SSR.
///
/// Stores the active locale in an in-memory string field without accessing browser storage APIs.
///
/// ```dart
/// final storage = InMemoryLocaleStorage('en-US');
/// final i18n = BloomI18n(storage: storage);
/// ```
///
/// See also:
/// - [LocaleStorage], the abstract persistence contract.
class InMemoryLocaleStorage implements LocaleStorage {
  String? _saved;

  /// Creates an in-memory storage optionally initialized with [initial].
  InMemoryLocaleStorage([this._saved]);

  /// Loads the stored locale string.
  @override
  Future<String?> load() async => _saved;

  /// Saves [locale] to memory.
  @override
  Future<void> save(String locale) async {
    _saved = locale;
  }
}

// ─── Reactive i18n Store ───────────────────────────────────────────────────

/// Reactive internationalization controller and multi-catalog store for Bloom applications.
///
/// Manages registered message catalogs, dynamic on-demand catalog loading, fallback resolution,
/// and provides reactive signal state ([locale], [isLoading]) that triggers fine-grained
/// UI re-renders inside [Live] blocks when the active locale updates.
///
/// ### Reactivity Model
/// Calling [translate] or [t] without an explicit `locale` argument reads the reactive signal
/// [BloomI18n.locale]. When evaluated inside a [Live] component, signals automatically record
/// a dependency on the active locale. When [setLocale] is called, only components observing
/// the locale update in-place without reloading the page or re-mounting unaffected DOM branches.
///
/// ### Singleton vs Standalone Instances
/// [BloomI18n.instance] is the global ambient singleton used by top-level convenience functions
/// ([t], [setLocale], [loadLocale]). You can also instantiate standalone `BloomI18n(...)` instances
/// for isolated sub-applications, headless server rendering, or unit tests.
///
/// ### Fallback Resolution Chain
/// When a translation key is looked up via [translate], [BloomI18n] resolves templates through:
/// 1. Exact requested locale catalog (e.g. `'fr-CA'`)
/// 2. Base language subtag of requested locale (e.g. `'fr'`)
/// 3. Configured [defaultLocale] catalog (e.g. `'en-US'`)
/// 4. Base language subtag of [defaultLocale] (e.g. `'en'`)
/// 5. The raw [messageId] itself as fallback, triggering the [onMissingKey] callback if configured.
///
/// ### Lazy Catalog Loading
/// Translation catalogs can be split and loaded on demand using [registerLoader] and [loadLocale].
/// While a catalog is loading over the network, [isLoading] is set to `true`, allowing UI components
/// to render loading indicators or skeletons.
///
/// ```dart
/// // Register catalogs
/// BloomI18n.instance.addCatalog(BloomCatalog('en-US', {
///   'welcome': 'Welcome to Bloom, {name}!',
/// }));
/// BloomI18n.instance.addCatalog(BloomCatalog('fr-FR', {
///   'welcome': 'Bienvenue sur Bloom, {name} !',
/// }));
///
/// // Use in a reactive UI component:
/// BloomNode greeting() => Live(() => Div(
///   text: t('welcome', args: {'name': 'Alice'}),
/// ));
///
/// // Update locale dynamically:
/// BloomI18n.instance.setLocale('fr-FR'); // Re-renders greeting() automatically
/// ```
///
/// See also:
/// - [BloomCatalog], storing ICU message templates for a single locale.
/// - [t], global shorthand for reactive translations.
/// - [setLocale], global shorthand for updating the active locale.
class BloomI18n {
  /// Reactive signal containing the current active locale tag (e.g. `'en-US'`).
  ///
  /// Reading `.value` inside a [Live] builder registers an automatic reactive dependency.
  final Signal<String> locale;

  /// Fallback locale signal used when a message template is missing in the active locale catalog.
  final Signal<String> defaultLocale;

  /// Reactive signal indicating whether an asynchronous catalog is currently loading via [loadLocale].
  final Signal<bool> isLoading = signal(false);

  final Map<String, BloomCatalog> _catalogs = {};
  final Map<String, Future<BloomCatalog> Function()> _loaders = {};

  /// Optional callback invoked whenever a translation key is missing across all fallback catalogs.
  void Function(String key, String locale)? onMissingKey;

  /// Optional storage adapter for persisting user locale choices across sessions.
  final LocaleStorage? storage;

  /// Global singleton instance of [BloomI18n].
  static final BloomI18n instance = BloomI18n();

  /// Creates a new [BloomI18n] store instance.
  ///
  /// Initializes [locale] to [initialLocale] and [defaultLocale] to [defaultLocale].
  /// Optionally pre-populates the store with [catalogs] and configures [storage].
  ///
  /// ```dart
  /// final i18n = BloomI18n(
  ///   initialLocale: 'en-US',
  ///   defaultLocale: 'en-US',
  ///   catalogs: {
  ///     'en-US': BloomCatalog('en-US', {'app.title': 'My App'}),
  ///   },
  /// );
  /// ```
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

  /// Sets the active locale string value, updating the reactive [locale] signal and persisting to [storage].
  set currentLocale(String val) => setLocale(val);

  /// Whether the currently active locale uses a right-to-left (RTL) script.
  bool get isCurrentRtl => isRtl(locale.value);

  /// The text direction of the currently active locale ([BloomTextDirection.rtl] or [BloomTextDirection.ltr]).
  BloomTextDirection get currentDirection => getTextDirection(locale.value);

  /// Changes the active locale to [newLocale], updates the reactive [locale] signal, and persists to [storage].
  ///
  /// ```dart
  /// BloomI18n.instance.setLocale('es-ES');
  /// ```
  void setLocale(String newLocale) {
    locale.value = newLocale;
    storage?.save(newLocale);
  }

  /// Registers a pre-constructed [BloomCatalog] in this store.
  ///
  /// ```dart
  /// i18n.addCatalog(BloomCatalog('de-DE', {'hello': 'Hallo!'}));
  /// ```
  void addCatalog(BloomCatalog catalog) {
    _catalogs[catalog.locale] = catalog;
  }

  /// Adds a map of ICU message templates for [locale].
  ///
  /// ```dart
  /// i18n.addMessages('fr-FR', {'login': 'Connexion', 'logout': 'Déconnexion'});
  /// ```
  void addMessages(String locale, Map<String, String> messages) {
    _catalogs[locale] = BloomCatalog(locale, messages);
  }

  /// Adds message templates from a dynamic JSON-compatible map for [locale].
  ///
  /// ```dart
  /// i18n.addJson('en-US', {'items_count': '{count, plural, =0 {None} other {# items}}'});
  /// ```
  void addJson(String locale, Map<String, dynamic> json) {
    _catalogs[locale] = BloomCatalog.fromJson(locale, json);
  }

  /// Registers an asynchronous catalog loader function for [locale].
  ///
  /// Enables code splitting and on-demand downloading of translation bundles.
  ///
  /// ```dart
  /// i18n.registerLoader('ja-JP', () async {
  ///   final jsonStr = await httpGet('/i18n/ja-JP.json');
  ///   return BloomCatalog.fromJsonString('ja-JP', jsonStr);
  /// });
  /// ```
  void registerLoader(
    String locale,
    Future<BloomCatalog> Function() loader,
  ) {
    _loaders[locale] = loader;
  }

  /// Asynchronously loads the catalog for [targetLocale] using a registered loader.
  ///
  /// Sets [isLoading] to `true` while the loader future is resolving.
  /// Returns `true` if a catalog was loaded successfully or was already present.
  ///
  /// ```dart
  /// final success = await BloomI18n.instance.loadLocale('ja-JP');
  /// if (success) {
  ///   BloomI18n.instance.setLocale('ja-JP');
  /// }
  /// ```
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
  ///
  /// Performs case-insensitive and hyphen/underscore normalized matching.
  BloomCatalog? getCatalog(String targetLocale) =>
      _catalogs[targetLocale] ?? _findCatalogNormalized(targetLocale);

  /// Returns `true` if a catalog is registered or currently loaded for [targetLocale].
  bool hasLocale(String targetLocale) => getCatalog(targetLocale) != null;

  /// Returns an unmodifiable list of all currently loaded locale tags.
  List<String> get supportedLocales => List.unmodifiable(_catalogs.keys);

  /// Translates [messageId] for [targetLocale] (or active [locale] if omitted), substituting [args].
  ///
  /// When [locale] is omitted, reads the reactive [this.locale] signal so that enclosing
  /// [Live] components automatically re-render when the active locale changes.
  ///
  /// Follows the 5-step fallback chain:
  /// 1. Exact requested locale catalog (e.g. `'fr-CA'`)
  /// 2. Base language subtag of requested locale (e.g. `'fr'`)
  /// 3. Configured [defaultLocale] catalog (e.g. `'en-US'`)
  /// 4. Base language subtag of [defaultLocale] (e.g. `'en'`)
  /// 5. Raw [messageId] string (and calls [onMissingKey] callback if configured).
  ///
  /// ```dart
  /// final text = i18n.translate('cart.total', args: {'count': 3});
  /// ```
  ///
  /// See also:
  /// - [t], shorthand alias.
  /// - [BloomCatalog.get], single catalog evaluation.
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
  ///
  /// ```dart
  /// final title = i18n.t('nav.home');
  /// ```
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
/// [BloomI18n.instance.locale] so that updates to the current locale trigger a fine-grained
/// re-render of the component.
///
/// ```dart
/// BloomNode greeting() => Live(() => Div(
///   text: t('greeting', args: {'name': 'Alice'}),
/// ));
/// ```
///
/// See also:
/// - [BloomI18n.translate], the full translation method on the store instance.
/// - [tr], shorthand with positional arguments.
/// - [setLocale], changes the active locale globally.
String t(
  String messageId, {
  Map<String, Object>? args,
  String? locale,
}) =>
    BloomI18n.instance.t(messageId, args: args, locale: locale);

/// Shorthand translation alias accepting positional [args].
///
/// Evaluates [messageId] on the global [BloomI18n.instance].
///
/// ```dart
/// final text = tr('welcome_banner', {'user': 'Bob'});
/// ```
///
/// See also:
/// - [t], the named-parameter translation function.
String tr(
  String messageId, [
  Map<String, Object>? args,
]) =>
    BloomI18n.instance.t(messageId, args: args);

/// Returns the global reactive locale signal from [BloomI18n.instance].
///
/// ```dart
/// print('Current locale: ${currentLocaleSignal.value}');
/// ```
Signal<String> get currentLocaleSignal => BloomI18n.instance.locale;

/// Changes the active locale globally on [BloomI18n.instance].
///
/// Updates the reactive signal, triggering automatic re-renders in observing [Live] components.
///
/// ```dart
/// setLocale('fr-FR');
/// ```
///
/// See also:
/// - [BloomI18n.setLocale], instance method.
/// - [loadLocale], for asynchronous catalog loading.
void setLocale(String locale) => BloomI18n.instance.setLocale(locale);

/// Asynchronously loads a catalog bundle for [locale] via [BloomI18n.instance].
///
/// ```dart
/// await loadLocale('de-DE');
/// setLocale('de-DE');
/// ```
///
/// See also:
/// - [BloomI18n.loadLocale], instance method.
/// - [BloomI18n.registerLoader], registers the loader callback.
Future<bool> loadLocale(String locale) =>
    BloomI18n.instance.loadLocale(locale);

/// Formats a localized date for the active locale on [BloomI18n.instance].
///
/// ```dart
/// final str = localizedDate(DateTime.now());
/// ```
///
/// See also:
/// - [formatDate], standalone date formatting function.
String localizedDate(DateTime date, [String? locale, String? pattern]) =>
    formatDate(date, locale: locale, pattern: pattern);

/// Formats a localized date and time for the active locale on [BloomI18n.instance].
///
/// ```dart
/// final str = localizedDateTime(DateTime.now());
/// ```
///
/// See also:
/// - [formatDateTime], standalone date-time formatting function.
String localizedDateTime(DateTime dateTime, [String? locale, String? pattern]) =>
    formatDateTime(dateTime, locale: locale, pattern: pattern);

/// Formats a localized relative time string for the active locale on [BloomI18n.instance].
///
/// ```dart
/// final str = localizedRelativeTime(DateTime.now().subtract(const Duration(minutes: 5)));
/// // Returns: "5 minutes ago"
/// ```
///
/// See also:
/// - [formatRelativeTime], standalone relative time formatting function.
String localizedRelativeTime(DateTime date, [DateTime? relativeTo, String? locale]) =>
    formatRelativeTime(date, relativeTo: relativeTo, locale: locale);

/// Formats a localized number for the active locale on [BloomI18n.instance].
///
/// ```dart
/// final str = localizedNumber(1234567.89); // "1,234,567.89"
/// ```
///
/// See also:
/// - [formatNumber], standalone number formatting function.
String localizedNumber(num value, [String? locale, int? decimalDigits]) =>
    formatNumber(value, locale: locale, decimalDigits: decimalDigits);

/// Formats a localized currency string for the active locale on [BloomI18n.instance].
///
/// ```dart
/// final str = localizedCurrency(19.99, 'USD'); // "$19.99"
/// ```
///
/// See also:
/// - [formatCurrency], standalone currency formatting function.
String localizedCurrency(num value, [String currency = 'USD', String? locale]) =>
    formatCurrency(value, currency: currency, locale: locale);

