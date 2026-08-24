// lib/src/locale_middleware.dart
import 'dart:async';
import 'package:bloom_server/bloom_server.dart';
import 'locales.dart';

/// Private Expando storing resolved locale attached to [BloomRequest] instances.
final Expando<ResolvedLocale> _resolvedLocaleExpando =
    Expando<ResolvedLocale>('BloomResolvedLocale');

/// Private Expando storing registry reference attached to [BloomRequest] instances.
final Expando<BloomLocales> _localesRegistryExpando =
    Expando<BloomLocales>('BloomLocalesRegistry');

/// An immutable value object encapsulating a resolved BCP-47 language tag.
///
/// Attached to [BloomRequest] instances by [BloomLocaleMiddleware] to represent
/// the negotiation result between client preferences and server support.
///
/// ### Example
///
/// ```dart
/// const resolved = ResolvedLocale('en-US');
/// print(resolved.languageTag); // "en-US"
/// print(resolved.toString()); // "en-US"
/// ```
class ResolvedLocale {
  /// The resolved BCP-47 language tag (e.g. `'en-US'`, `'fr-FR'`, `'de'`).
  final String languageTag;

  /// Creates a [ResolvedLocale] instance holding the given [languageTag].
  const ResolvedLocale(this.languageTag);

  /// Returns the [languageTag] string representation.
  @override
  String toString() => languageTag;

  /// Compares this [ResolvedLocale] to [other] by case-insensitive [languageTag] equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedLocale &&
          runtimeType == other.runtimeType &&
          languageTag.toLowerCase() == other.languageTag.toLowerCase();

  @override
  int get hashCode => languageTag.toLowerCase().hashCode;
}

/// A parsed entry from an HTTP `Accept-Language` header with quality weighting (`q=`).
///
/// Implements [Comparable] to sort entries in descending order of [quality]
/// (highest quality preferences first).
///
/// ### Example
///
/// ```dart
/// const entry = AcceptLanguageEntry('fr-CH', 0.8);
/// print(entry.tag); // "fr-CH"
/// print(entry.quality); // 0.8
/// print(entry.toString()); // "fr-CH;q=0.8"
/// ```
class AcceptLanguageEntry implements Comparable<AcceptLanguageEntry> {
  /// The BCP-47 language tag or subtag (e.g. `'fr'`, `'en-US'`).
  final String tag;

  /// Quality value weight (`q=`) ranging between `0.0` and `1.0`.
  final double quality;

  /// Creates an [AcceptLanguageEntry] with the given language [tag] and [quality] weighting.
  ///
  /// [quality] defaults to `1.0` if not specified.
  const AcceptLanguageEntry(this.tag, [this.quality = 1.0]);

  /// Compares this entry with [other] to sort by [quality] in descending order.
  @override
  int compareTo(AcceptLanguageEntry other) {
    // Descending order of quality value (highest quality first)
    final diff = other.quality.compareTo(quality);
    if (diff != 0) return diff;
    return 0;
  }

  /// Formats this entry as an `Accept-Language` token (e.g. `'en-US;q=0.9'`).
  @override
  String toString() => '$tag;q=$quality';
}

/// Parses the first valid BCP-47 language tag from an `Accept-Language` [header] value.
///
/// Extracts the first comma-separated tag, strips parameters (such as `;q=...`),
/// trims whitespace, filters out empty strings and wildcards (`*`), and validates
/// basic BCP-47 formatting.
///
/// Returns `null` if [header] is null, empty, or contains no valid tag.
///
/// ### Example
///
/// ```dart
/// print(firstLocaleTag('fr-CH, fr;q=0.9, en;q=0.8')); // "fr-CH"
/// print(firstLocaleTag('*;q=0.5')); // null
/// print(firstLocaleTag(null)); // null
/// ```
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

/// Parses an entire `Accept-Language` [header] string into a list of [AcceptLanguageEntry] objects.
///
/// Entries are sorted in descending order of quality value (`q=`), with entries having `q=0`
/// and wildcards (`*`) omitted.
///
/// Returns an empty list if [header] is null or contains no valid entries.
///
/// ### Example
///
/// ```dart
/// final entries = parseAcceptLanguage('da, en-gb;q=0.8, en;q=0.7');
/// for (final e in entries) {
///   print('${e.tag}: ${e.quality}');
/// }
/// // Output:
/// // da: 1.0
/// // en-gb: 0.8
/// // en: 0.7
/// ```
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

/// Helper validating basic BCP-47 language tag formatting.
bool _isValidLanguageTag(String tag) {
  final regex = RegExp(r'^[a-zA-Z]{1,8}(-[a-zA-Z0-9]{1,8})*$');
  return regex.hasMatch(tag);
}

/// Bloom server middleware resolving the request locale into request context.
///
/// Inspects incoming HTTP requests in order of priority:
/// 1. Query parameter overrides (`?locale=`, `?lang=`, or `?hl=`)
/// 2. `Accept-Language` HTTP request header (sorted by RFC quality weights `q=`)
/// 3. Environment default from `BloomEnv.getOrNull('DEFAULT_LOCALE')`
/// 4. Configured [defaultLocale]
///
/// When a locale is resolved:
/// - Attaches [ResolvedLocale] to [request.resolvedLocale] via request context.
/// - Injects the resolved tag into `request.params['locale']`.
/// - Attaches the optional [locales] registry to [request.locales] for `request.t()` calls.
/// - Appends `Content-Language: <resolvedTag>` to the outgoing [BloomResponse] headers.
///
/// ### Example
///
/// ```dart
/// import 'package:bloom_server/bloom_server.dart';
/// import 'package:bloom_i18n/bloom_i18n.dart';
///
/// void main() {
///   final locales = BloomLocales(defaultLocale: 'en-US');
///   locales.addLocale('en-US', {'msg': 'Hello!'});
///   locales.addLocale('es-ES', {'msg': '¡Hola!'});
///
///   final server = BloomServer();
///   server.use(BloomLocaleMiddleware(
///     defaultLocale: 'en-US',
///     supportedLocales: ['en-US', 'es-ES'],
///     locales: locales,
///   ));
///
///   server.get('/message', (req) {
///     return BloomResponse.ok(req.t('msg'));
///   });
/// }
/// ```
class BloomLocaleMiddleware implements BloomMiddleware {
  /// Default fallback locale if no matching locale is found in request headers or query params.
  final String defaultLocale;

  /// Optional list of supported BCP-47 locale tags to restrict resolution against.
  ///
  /// If provided, unsupported locales requested by the client will be ignored in
  /// favor of base language subtags or [defaultLocale].
  final List<String>? supportedLocales;

  /// Optional [BloomLocales] registry attached to requests for `request.t()` lookup.
  final BloomLocales? locales;

  /// Whether to evaluate RFC quality weighting (`q=`) when parsing `Accept-Language` headers.
  ///
  /// Defaults to `true`. If `false`, only the first tag in the header is considered.
  final bool useQualityValues;

  /// Parameter name checked for URL query overrides (e.g. `?locale=fr`).
  ///
  /// Defaults to `'locale'`. Falls back to checking `?lang=` and `?hl=`.
  final String queryParam;

  /// Creates a [BloomLocaleMiddleware] instance.
  ///
  /// - [defaultLocale]: Fallback locale tag (defaults to `'en-US'`).
  /// - [supportedLocales]: Optional whitelist of supported locale tags.
  /// - [locales]: Optional [BloomLocales] translation registry to attach to requests.
  /// - [useQualityValues]: Whether to respect `q=` weights (defaults to `true`).
  /// - [queryParam]: Query parameter name for locale override (defaults to `'locale'`).
  const BloomLocaleMiddleware({
    this.defaultLocale = 'en-US',
    this.supportedLocales,
    this.locales,
    this.useQualityValues = true,
    this.queryParam = 'locale',
  });

  /// Intercepts [request], resolves its client locale, attaches context, and sets
  /// the `Content-Language` header on the outgoing response.
  @override
  Future<BloomResponse?> handle(BloomRequest request, BloomNextFunction next) async {
    final effectiveDefault = _resolveDefaultLocale();
    final resolvedTag = _resolveRequestLocale(request, effectiveDefault);

    final resolvedLocale = ResolvedLocale(resolvedTag);
    _resolvedLocaleExpando[request] = resolvedLocale;

    if (locales != null) {
      _localesRegistryExpando[request] = locales;
    }

    // Attach convenience param for route handlers
    request.params['locale'] = resolvedTag;

    final response = await next();
    response.headers['Content-Language'] = resolvedTag;
    return response;
  }

  String _resolveDefaultLocale() {
    try {
      return BloomEnv.getOrNull('DEFAULT_LOCALE') ?? defaultLocale;
    } catch (_) {
      return defaultLocale;
    }
  }

  String _resolveRequestLocale(BloomRequest request, String fallback) {
    // 1. Query parameter override (e.g. ?locale=fr or ?lang=fr)
    final queryOverride = request.queryParams[queryParam] ??
        request.queryParams['lang'] ??
        request.queryParams['hl'];
    if (queryOverride != null && queryOverride.trim().isNotEmpty) {
      final clean = queryOverride.trim();
      if (_isSupported(clean)) return clean;
      final base = _extractBase(clean);
      if (base != null && _isSupported(base)) return base;
    }

    // 2. Accept-Language header
    final acceptLanguage = request.headers['accept-language'] ??
        request.headers['Accept-Language'] ??
        request.headers['ACCEPT-LANGUAGE'];

    if (acceptLanguage != null && acceptLanguage.trim().isNotEmpty) {
      if (useQualityValues) {
        final candidates = parseAcceptLanguage(acceptLanguage);
        for (final entry in candidates) {
          if (_isSupported(entry.tag)) {
            return entry.tag;
          }
          final base = _extractBase(entry.tag);
          if (base != null && _isSupported(base)) {
            return base;
          }
        }
      } else {
        final tag = firstLocaleTag(acceptLanguage);
        if (tag != null) {
          if (_isSupported(tag)) return tag;
          final base = _extractBase(tag);
          if (base != null && _isSupported(base)) return base;
        }
      }
    }

    return fallback;
  }

  bool _isSupported(String tag) {
    if (supportedLocales == null || supportedLocales!.isEmpty) {
      return true;
    }
    final normalized = tag.replaceAll('_', '-').toLowerCase();
    return supportedLocales!.any(
      (supported) => supported.replaceAll('_', '-').toLowerCase() == normalized,
    );
  }

  String? _extractBase(String tag) {
    if (tag.contains('-')) return tag.split('-').first;
    if (tag.contains('_')) return tag.split('_').first;
    return null;
  }
}

/// Convenience extensions on [BloomRequest] for reading the active locale and translating messages.
///
/// ### Example
///
/// ```dart
/// server.get('/dashboard', (req) {
///   print('Client locale: ${req.locale}');
///   final greeting = req.t('welcome_back', args: {'user': 'Alex'});
///   return BloomResponse.ok(greeting);
/// });
/// ```
extension BloomLocaleRequestExtension on BloomRequest {
  /// Returns the [ResolvedLocale] attached by [BloomLocaleMiddleware], or `null` if absent.
  ResolvedLocale? get resolvedLocale => _resolvedLocaleExpando[this];

  /// Returns the active BCP-47 locale tag string (e.g. `'en-US'`), falling back to `'en-US'`.
  String get locale => resolvedLocale?.languageTag ?? params['locale'] ?? 'en-US';

  /// Returns the [BloomLocales] registry attached by [BloomLocaleMiddleware], if configured.
  BloomLocales? get locales => _localesRegistryExpando[this];

  /// Translates [messageId] for this request's resolved [locale], interpolating optional [args].
  ///
  /// If no [BloomLocales] registry is attached to the request, returns the raw [messageId].
  ///
  /// Example:
  /// ```dart
  /// final title = req.t('dashboard.title');
  /// final welcome = req.t('dashboard.welcome', args: {'name': 'Sam'});
  /// ```
  String t(String messageId, {Map<String, Object>? args}) {
    final registry = locales;
    if (registry == null) return messageId;
    return registry.translate(locale, messageId, args: args);
  }
}
