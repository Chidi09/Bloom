// lib/src/locales.dart
import 'catalog.dart';

/// A multi-locale registry managing message catalogs with fallback resolution.
///
/// Holds [BloomCatalog] instances mapped by locale identifier and evaluates
/// translations according to a deterministic 5-step fallback hierarchy:
/// 1. Exact requested locale (e.g. `'en-US'`)
/// 2. Base language subtag of requested locale (e.g. `'en'`)
/// 3. Default configured locale (e.g. `'en-US'`)
/// 4. Base language subtag of default locale (e.g. `'en'`)
/// 5. Raw message ID string as the ultimate fallback
///
/// ### Example
///
/// ```dart
/// final locales = BloomLocales(defaultLocale: 'en-US');
///
/// locales.addLocale('en-US', {
///   'greeting': 'Hello, {name}!',
///   'unread': '{count, plural, =0 {No messages} =1 {1 message} other {# messages}}',
/// });
///
/// locales.addLocale('es-ES', {
///   'greeting': '¡Hola, {name}!',
///   'unread': '{count, plural, =0 {Sin mensajes} =1 {1 mensaje} other {# mensajes}}',
/// });
///
/// // Exact match
/// print(locales.translate('es-ES', 'greeting', args: {'name': 'Carlos'}));
/// // Output: "¡Hola, Carlos!"
///
/// // Fallback to base language or default
/// print(locales.translate('fr-FR', 'greeting', args: {'name': 'Jean'}));
/// // Output: "Hello, Jean!" (fell back to en-US)
/// ```
class BloomLocales {
  /// The default fallback locale identifier tag (e.g. `'en-US'`).
  final String defaultLocale;

  /// Map of locale identifiers to catalogs.
  final Map<String, BloomCatalog> _catalogs = {};

  /// Creates a new [BloomLocales] registry with the specified [defaultLocale]
  /// and an optional initial map of [catalogs].
  ///
  /// Example:
  /// ```dart
  /// final locales = BloomLocales(
  ///   defaultLocale: 'en-US',
  ///   catalogs: {
  ///     'en-US': BloomCatalog('en-US', {'app': 'Bloom'}),
  ///   },
  /// );
  /// ```
  BloomLocales({
    this.defaultLocale = 'en-US',
    Map<String, BloomCatalog>? catalogs,
  }) {
    if (catalogs != null) {
      _catalogs.addAll(catalogs);
    }
  }

  /// Constructs and registers a new [BloomCatalog] for the specified [locale]
  /// from a map of [messages].
  ///
  /// Example:
  /// ```dart
  /// final locales = BloomLocales();
  /// locales.addLocale('fr-FR', {
  ///   'welcome': 'Bienvenue !',
  /// });
  /// ```
  void addLocale(String locale, Map<String, String> messages) {
    _catalogs[locale] = BloomCatalog(locale, messages);
  }

  /// Registers an already-constructed [BloomCatalog] instance into the registry.
  ///
  /// Uses [BloomCatalog.locale] as the registration key.
  ///
  /// Example:
  /// ```dart
  /// final locales = BloomLocales();
  /// final deCatalog = BloomCatalog('de-DE', {'welcome': 'Willkommen!'});
  /// locales.addCatalog(deCatalog);
  /// ```
  void addCatalog(BloomCatalog catalog) {
    _catalogs[catalog.locale] = catalog;
  }

  /// Constructs and registers a new [BloomCatalog] for the specified [locale]
  /// from a dynamic [json] map (e.g. decoded JSON).
  ///
  /// Example:
  /// ```dart
  /// final locales = BloomLocales();
  /// locales.addJson('it-IT', {
  ///   'welcome': 'Benvenuto!',
  /// });
  /// ```
  void addJson(String locale, Map<String, dynamic> json) {
    _catalogs[locale] = BloomCatalog.fromJson(locale, json);
  }

  /// Returns the [BloomCatalog] registered for [locale], or `null` if not found.
  ///
  /// Normalizes locale tags and performs case-insensitive matching if an exact
  /// match is not immediately present.
  ///
  /// Example:
  /// ```dart
  /// final locales = BloomLocales();
  /// locales.addLocale('en-US', {'hi': 'Hi'});
  /// final catalog = locales.getCatalog('en_us'); // returns en-US catalog
  /// ```
  BloomCatalog? getCatalog(String locale) =>
      _catalogs[locale] ?? _findCatalogNormalized(locale);

  /// Checks if a catalog is registered for the specified [locale].
  ///
  /// Returns `true` if a matching catalog is found, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final locales = BloomLocales();
  /// locales.addLocale('en-US', {'key': 'val'});
  /// print(locales.hasLocale('en-US')); // true
  /// print(locales.hasLocale('de-DE')); // false
  /// ```
  bool hasLocale(String locale) => getCatalog(locale) != null;

  /// Returns an unmodifiable list of all registered locale identifier tags.
  ///
  /// Example:
  /// ```dart
  /// final locales = BloomLocales();
  /// locales.addLocale('en-US', {});
  /// locales.addLocale('es-ES', {});
  /// print(locales.supportedLocales); // ['en-US', 'es-ES']
  /// ```
  List<String> get supportedLocales => List.unmodifiable(_catalogs.keys);

  /// Translates [messageId] for [locale], substituting optional [args] and
  /// evaluating ICU MessageFormat plural/select patterns.
  ///
  /// ### Fallback Resolution Order
  /// 1. Exact requested [locale] catalog (e.g. `'en-US'`)
  /// 2. Language-only subtag of requested [locale] (e.g. `'en'`)
  /// 3. Configured [defaultLocale] catalog (e.g. `'en-US'`)
  /// 4. Language-only subtag of [defaultLocale] (e.g. `'en'`)
  /// 5. The raw [messageId] string itself if no translation is found in any catalog.
  ///
  /// Example:
  /// ```dart
  /// final locales = BloomLocales(defaultLocale: 'en-US');
  /// locales.addLocale('en-US', {'title': 'Home'});
  /// locales.addLocale('es-ES', {'title': 'Inicio'});
  ///
  /// print(locales.translate('es-ES', 'title')); // "Inicio"
  /// print(locales.translate('de-DE', 'title')); // "Home" (fallback)
  /// print(locales.translate('en-US', 'missing_key')); // "missing_key"
  /// ```
  String translate(
    String? locale,
    String messageId, {
    Map<String, Object>? args,
  }) {
    // 1. Try requested locale
    if (locale != null && locale.trim().isNotEmpty) {
      final targetCat = _findCatalogNormalized(locale);
      if (targetCat != null) {
        final message = targetCat.get(messageId, args: args);
        if (message != null) return message;
      }

      // 2. Try language-only subtag of requested locale (e.g. 'en' for 'en-US')
      final langSubtag = _extractLanguageSubtag(locale);
      if (langSubtag != null && langSubtag != locale) {
        final langCat = _findCatalogNormalized(langSubtag);
        if (langCat != null) {
          final message = langCat.get(messageId, args: args);
          if (message != null) return message;
        }
      }
    }

    // 3. Try default locale
    final defaultCat = _findCatalogNormalized(defaultLocale);
    if (defaultCat != null) {
      final message = defaultCat.get(messageId, args: args);
      if (message != null) return message;
    }

    // 4. Try language-only subtag of default locale
    final defaultLangSubtag = _extractLanguageSubtag(defaultLocale);
    if (defaultLangSubtag != null && defaultLangSubtag != defaultLocale) {
      final langCat = _findCatalogNormalized(defaultLangSubtag);
      if (langCat != null) {
        final message = langCat.get(messageId, args: args);
        if (message != null) return message;
      }
    }

    // 5. Final fallback: raw message ID
    return messageId;
  }

  /// Shorthand alias for [translate], allowing positional [args].
  ///
  /// Example:
  /// ```dart
  /// final locales = BloomLocales(defaultLocale: 'en-US');
  /// locales.addLocale('en-US', {'greeting': 'Hello, {name}!'});
  /// print(locales.t('en-US', 'greeting', {'name': 'Mia'})); // "Hello, Mia!"
  /// ```
  String t(
    String? locale,
    String messageId, [
    Map<String, Object>? args,
  ]) =>
      translate(locale, messageId, args: args);

  /// Helper to lookup catalog case-insensitively with tag normalization.
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

  /// Extracts the base language subtag from a BCP-47 / POSIX locale string.
  String? _extractLanguageSubtag(String localeTag) {
    final delimiter = localeTag.contains('-') ? '-' : (localeTag.contains('_') ? '_' : null);
    if (delimiter != null) {
      final subtag = localeTag.split(delimiter).first.trim();
      if (subtag.isNotEmpty) return subtag;
    }
    return null;
  }
}
