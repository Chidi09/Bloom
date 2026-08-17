// lib/src/locales.dart
import 'catalog.dart';

/// A multi-locale registry mirroring the `Locales` container from `djangors-i18n`.
///
/// Holds [BloomCatalog] instances mapped by locale identifier and performs
/// translation lookup with fallback resolution.
class BloomLocales {
  /// The default fallback locale string (e.g. `'en-US'`).
  final String defaultLocale;

  /// Map of locale identifiers to catalogs.
  final Map<String, BloomCatalog> _catalogs = {};

  /// Creates a new [BloomLocales] registry with the specified [defaultLocale].
  BloomLocales({
    this.defaultLocale = 'en-US',
    Map<String, BloomCatalog>? catalogs,
  }) {
    if (catalogs != null) {
      _catalogs.addAll(catalogs);
    }
  }

  /// Adds a map of message templates for the specified [locale].
  void addLocale(String locale, Map<String, String> messages) {
    _catalogs[locale] = BloomCatalog(locale, messages);
  }

  /// Adds an already-constructed [BloomCatalog] to the registry.
  void addCatalog(BloomCatalog catalog) {
    _catalogs[catalog.locale] = catalog;
  }

  /// Adds messages from a dynamic/JSON map for the specified [locale].
  void addJson(String locale, Map<String, dynamic> json) {
    _catalogs[locale] = BloomCatalog.fromJson(locale, json);
  }

  /// Returns the [BloomCatalog] registered for [locale], or `null` if not found.
  BloomCatalog? getCatalog(String locale) =>
      _catalogs[locale] ?? _findCatalogNormalized(locale);

  /// Checks if a catalog is registered for the specified [locale].
  bool hasLocale(String locale) => getCatalog(locale) != null;

  /// Returns a list of all registered locale identifier tags.
  List<String> get supportedLocales => List.unmodifiable(_catalogs.keys);

  /// Translates [messageId] for [locale], substituting optional [args].
  ///
  /// Fallback resolution order:
  /// 1. Exact requested [locale] catalog (e.g. `'en-US'`)
  /// 2. Language-only subtag of requested [locale] (e.g. `'en'`)
  /// 3. Configured [defaultLocale] catalog (e.g. `'en-US'`)
  /// 4. Language-only subtag of [defaultLocale] (e.g. `'en'`)
  /// 5. The raw [messageId] itself if no catalog or translation was found.
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

  /// Shorthand alias for [translate].
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
