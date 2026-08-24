// lib/src/catalog.dart
import 'dart:convert';
import 'package:intl/intl.dart';

/// A message catalog for a single locale.
///
/// Stores translation message strings indexed by message ID and evaluates them
/// using ICU MessageFormat-style patterns (interpolated arguments, plurals,
/// select/gender branches, formatted numbers, and dates).
///
/// Plain Dart maps or JSON files are used as the message source.
///
/// ### ICU MessageFormat Features Supported
///
/// - **Variable Interpolation**: `{name}` replaces `{name}` with `args['name']`.
/// - **Plurals**: `{count, plural, =0 {No items} =1 {1 item} other {# items}}` where `#`
///   is automatically replaced by the localized number representation.
/// - **Select / Gender**: `{gender, select, male {He} female {She} other {They}}`.
/// - **Formatted Numbers**: `{amount, number, currency}`, `{rate, number, percent}`.
/// - **Formatted Dates**: `{time, date, short}`, `{time, date, medium}`, `{time, date, long}`, `{time, date, full}`.
///
/// ### Example
///
/// ```dart
/// final catalog = BloomCatalog('en-US', {
///   'welcome': 'Hello, {name}!',
///   'cart_summary': '{itemCount, plural, =0 {Cart is empty} =1 {1 item in cart} other {# items in cart}}',
/// });
///
/// print(catalog.get('welcome', args: {'name': 'Alice'}));
/// // Output: "Hello, Alice!"
///
/// print(catalog.get('cart_summary', args: {'itemCount': 5}));
/// // Output: "5 items in cart"
/// ```
class BloomCatalog {
  /// The BCP-47 locale tag identifier for this catalog (e.g. `'en-US'`, `'fr-FR'`, `'de'`).
  final String locale;

  /// Internal message key-value store.
  final Map<String, String> _messages;

  /// Creates a [BloomCatalog] for the given [locale] from a map of [messages].
  ///
  /// Keys in [messages] are message IDs, and values are ICU MessageFormat pattern strings.
  ///
  /// Example:
  /// ```dart
  /// final catalog = BloomCatalog('en-US', {
  ///   'app_title': 'Bloom Dashboard',
  ///   'greeting': 'Welcome, {user}!',
  /// });
  /// ```
  BloomCatalog(this.locale, Map<String, String> messages)
      : _messages = Map<String, String>.from(messages);

  /// Creates a [BloomCatalog] for the given [locale] from a dynamic map [json] (e.g. decoded JSON).
  ///
  /// Non-null values are converted to strings via [Object.toString].
  ///
  /// Example:
  /// ```dart
  /// final catalog = BloomCatalog.fromJson('es-ES', {
  ///   'app_title': 'Panel de Bloom',
  ///   'item_count': '{count, plural, =0 {Sin elementos} =1 {1 elemento} other {# elementos}}',
  /// });
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

  /// Creates a [BloomCatalog] for the given [locale] by decoding a [jsonString].
  ///
  /// Throws a [FormatException] if [jsonString] does not decode into a JSON map object.
  ///
  /// Example:
  /// ```dart
  /// const rawJson = '{"greeting": "Hello!", "bye": "Goodbye!"}';
  /// final catalog = BloomCatalog.fromJsonString('en-US', rawJson);
  /// print(catalog.get('greeting')); // "Hello!"
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
    throw FormatException('Invalid JSON for BloomCatalog: expected a JSON object.');
  }

  /// Returns an unmodifiable view of all registered message ID to template mappings.
  ///
  /// Example:
  /// ```dart
  /// final catalog = BloomCatalog('en-US', {'key': 'Value'});
  /// print(catalog.messages.keys.toList()); // ['key']
  /// ```
  Map<String, String> get messages => Map.unmodifiable(_messages);

  /// Checks if a message pattern is registered for the specified [messageId].
  ///
  /// Returns `true` if defined, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final catalog = BloomCatalog('en-US', {'prompt': 'Enter name:'});
  /// print(catalog.has('prompt')); // true
  /// print(catalog.has('missing')); // false
  /// ```
  bool has(String messageId) => _messages.containsKey(messageId);

  /// Looks up and formats a translated message by [messageId], substituting [args]
  /// and evaluating ICU MessageFormat plural, select, number, and date patterns.
  ///
  /// Returns `null` if [messageId] is not found in this catalog.
  ///
  /// Example:
  /// ```dart
  /// final catalog = BloomCatalog('en-US', {
  ///   'items_left': '{count, plural, =0 {No items left} =1 {1 item left} other {# items left}}',
  /// });
  ///
  /// print(catalog.get('items_left', args: {'count': 0})); // "No items left"
  /// print(catalog.get('items_left', args: {'count': 3})); // "3 items left"
  /// print(catalog.get('unknown_key')); // null
  /// ```
  String? get(String messageId, {Map<String, Object>? args}) {
    final template = _messages[messageId];
    if (template == null) return null;
    return formatMessage(template, args: args, locale: locale);
  }

  /// Evaluates an ICU MessageFormat [template] string with [args] for the specified [locale].
  ///
  /// This static helper can be used directly without instantiating a [BloomCatalog].
  /// If [args] is omitted or empty and the [template] contains no braces (`{`),
  /// the [template] string is returned as-is for performance.
  ///
  /// Example:
  /// ```dart
  /// final formatted = BloomCatalog.formatMessage(
  ///   'Hello, {name}! You have {unread, plural, =0 {no unread emails} =1 {1 unread email} other {# unread emails}}.',
  ///   args: {'name': 'Sam', 'unread': 4},
  ///   locale: 'en-US',
  /// );
  /// print(formatted); // "Hello, Sam! You have 4 unread emails."
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
/// plurals, select/gender cases, and recursive sub-patterns.
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
            // Skip quoted segment inside brace
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

    // Replace '#' with the formatted number in plural branch
    final formattedCount = NumberFormat.decimalPattern(locale).format(count);
    final withHashSubstituted = _replaceHashSymbol(selectedTemplate, formattedCount);

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
      return NumberFormat.currency(locale: locale).format(count);
    } else if (style == 'percent') {
      return NumberFormat.percentPattern(locale).format(count);
    } else {
      return NumberFormat.decimalPattern(locale).format(count);
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
      return DateFormat.yMd(locale).format(date);
    } else if (style == 'medium') {
      return DateFormat.yMMMd(locale).format(date);
    } else if (style == 'long') {
      return DateFormat.yMMMMd(locale).format(date);
    } else if (style == 'full') {
      return DateFormat.yMMMMEEEEd(locale).format(date);
    }
    return DateFormat(formatStyle.trim(), locale).format(date);
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
      while (i < length && (str[i] == ' ' || str[i] == '\t' || str[i] == '\n' || str[i] == '\r')) {
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
