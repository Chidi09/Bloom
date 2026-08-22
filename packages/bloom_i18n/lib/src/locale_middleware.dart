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

/// Request wrapper carrying the resolved BCP-47 locale string.
///
/// Mirrors `ResolvedLocale` from `djangors-i18n`.
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

/// A parsed entry from an HTTP `Accept-Language` header with quality weighting.
class AcceptLanguageEntry implements Comparable<AcceptLanguageEntry> {
  /// The BCP-47 language tag or subtag (e.g. `'fr'`, `'en-US'`).
  final String tag;

  /// Quality value weight (`q=`) ranging between `0.0` and `1.0`.
  final double quality;

  /// Creates an [AcceptLanguageEntry] with the given language [tag] and [quality] weighting.
  const AcceptLanguageEntry(this.tag, [this.quality = 1.0]);


  @override
  int compareTo(AcceptLanguageEntry other) {
    // Descending order of quality value (highest quality first)
    final diff = other.quality.compareTo(quality);
    if (diff != 0) return diff;
    return 0;
  }

  @override
  String toString() => '$tag;q=$quality';
}

/// Parses the first valid BCP-47 language tag from an `Accept-Language` header value.
///
/// Faithfully ports `first_locale_tag` from `djangors-i18n`: extracts the first
/// comma-separated tag, strips parameters (such as `;q=...`), trims whitespace,
/// filters out empty strings and wildcard `*`, and normalizes the tag.
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

/// Parses an entire `Accept-Language` header, sorting entries by quality weight (`q=`)
/// in descending order and filtering out `q=0` and wildcards `*`.
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
/// Mirrors `LocaleLayer` from `djangors-i18n`. Inspects incoming HTTP requests for:
/// 1. Query parameter overrides (`?locale=` or `?lang=`)
/// 2. Header `Accept-Language` (evaluated by quality values or first tag)
/// 3. Configured [defaultLocale] (or `BloomEnv` fallback)
///
/// Attaches [ResolvedLocale] to the [BloomRequest] context for handlers to read.
class BloomLocaleMiddleware implements BloomMiddleware {
  /// Default fallback locale if no matching locale is found.
  final String defaultLocale;

  /// Optional list of supported locales to restrict resolution against.
  final List<String>? supportedLocales;

  /// Optional [BloomLocales] registry attached to requests.
  final BloomLocales? locales;

  /// Whether to use full RFC quality weighting when matching `Accept-Language` header.
  final bool useQualityValues;

  /// Parameter name for query overrides (e.g. `?locale=es`). Defaults to `'locale'`.
  final String queryParam;

  const BloomLocaleMiddleware({
    this.defaultLocale = 'en-US',
    this.supportedLocales,
    this.locales,
    this.useQualityValues = true,
    this.queryParam = 'locale',
  });

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

/// Convenience extensions on [BloomRequest] for reading the active locale.
extension BloomLocaleRequestExtension on BloomRequest {
  /// Returns the [ResolvedLocale] attached by [BloomLocaleMiddleware], or `null` if absent.
  ResolvedLocale? get resolvedLocale => _resolvedLocaleExpando[this];

  /// Returns the active BCP-47 locale tag string (e.g. `'en-US'`), falling back to `'en-US'`.
  String get locale => resolvedLocale?.languageTag ?? params['locale'] ?? 'en-US';

  /// Returns the [BloomLocales] registry attached by [BloomLocaleMiddleware], if configured.
  BloomLocales? get locales => _localesRegistryExpando[this];

  /// Translates [messageId] for this request's resolved locale.
  String t(String messageId, {Map<String, Object>? args}) {
    final registry = locales;
    if (registry == null) return messageId;
    return registry.translate(locale, messageId, args: args);
  }
}
