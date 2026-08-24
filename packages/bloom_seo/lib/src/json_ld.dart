import 'dart:convert';

String _escAttr(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#x27;');

/// Structured data helper for generating Schema.org JSON-LD scripts.
///
/// Provides factory constructors for common Schema.org types ([JsonLd.article],
/// [JsonLd.breadcrumb], [JsonLd.organization], [JsonLd.webSite]) as well as
/// custom structured data maps via [JsonLd.new].
///
/// When rendered via [toScriptTag], any nested `</script>` sequences are
/// automatically escaped to prevent script injection vulnerabilities.
///
/// ### Example
///
/// ```dart
/// final ld = JsonLd.article(
///   headline: 'Building Reactive Web Apps with Bloom',
///   description: 'A deep dive into reactive signals and SSG in Bloom.',
///   author: 'Bloom Engineering',
///   datePublished: '2026-08-24',
///   url: 'https://example.com/blog/reactive-apps',
/// );
///
/// // Inject into document head
/// final scriptTag = ld.toScriptTag(pretty: true);
/// ```
class JsonLd {
  /// The underlying Schema.org structured data payload.
  final Map<String, dynamic> data;

  /// Creates a [JsonLd] instance wrapping a custom Schema.org [data] map.
  const JsonLd(this.data);

  /// Emits a `<script type="application/ld+json">` tag containing JSON-serialized [data].
  ///
  /// Escapes closing `</script>` tags within the JSON payload as `<\/script>`
  /// to prevent XSS breakout when embedded in HTML documents.
  ///
  /// If [pretty] is `true`, the JSON string is formatted with 2-space indentation.
  String toScriptTag({bool pretty = false}) {
    final json = pretty
        ? const JsonEncoder.withIndent('  ').convert(data)
        : jsonEncode(data);
    // JSON-LD is inside a script tag — escape closing script to avoid XSS.
    final safe = json.replaceAll('</script>', '<\\/script>');
    return '<script type="application/ld+json">$safe</script>';
  }

  /// Returns the raw JSON string representation of [data].
  ///
  /// If [pretty] is `true`, formats the output with 2-space indentation.
  String toJson({bool pretty = false}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(data)
      : jsonEncode(data);

  // ── Factory helpers ───────────────────────────────────────────────

  /// Creates a Schema.org `Article` structured data object.
  ///
  /// - [headline]: Required title or headline of the article.
  /// - [description]: Optional summary or synopsis.
  /// - [author]: Optional author name (emitted as a `Person` entity).
  /// - [datePublished]: Optional publication timestamp in ISO 8601 / W3C format.
  /// - [dateModified]: Optional last modified timestamp in ISO 8601 / W3C format.
  /// - [image]: Optional primary image URL for the article.
  /// - [url]: Optional canonical URL of the article.
  ///
  /// ```dart
  /// final article = JsonLd.article(
  ///   headline: 'Announcing Bloom 1.0',
  ///   author: 'Bloom Core Team',
  ///   datePublished: '2026-08-24',
  ///   url: 'https://bloom.dev/news/1.0',
  /// );
  /// ```
  factory JsonLd.article({
    required String headline,
    String? description,
    String? author,
    String? datePublished,
    String? dateModified,
    String? image,
    String? url,
  }) {
    return JsonLd({
      '@context': 'https://schema.org',
      '@type': 'Article',
      'headline': headline,
      if (description != null) 'description': description,
      if (author != null) 'author': {'@type': 'Person', 'name': author},
      if (datePublished != null) 'datePublished': datePublished,
      if (dateModified != null) 'dateModified': dateModified,
      if (image != null) 'image': image,
      if (url != null) 'url': url,
    });
  }

  /// Creates a Schema.org `BreadcrumbList` structured data object.
  ///
  /// Each map in [items] must contain a `'name'` key (the breadcrumb label)
  /// and a `'url'` key (the target URL). Emits 1-indexed `ListItem` entries.
  ///
  /// ```dart
  /// final breadcrumbs = JsonLd.breadcrumb([
  ///   {'name': 'Home', 'url': 'https://example.com'},
  ///   {'name': 'Docs', 'url': 'https://example.com/docs'},
  ///   {'name': 'SEO', 'url': 'https://example.com/docs/seo'},
  /// ]);
  /// ```
  factory JsonLd.breadcrumb(List<Map<String, String>> items) {
    return JsonLd({
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      'itemListElement': [
        for (var i = 0; i < items.length; i++)
          {
            '@type': 'ListItem',
            'position': i + 1,
            'name': items[i]['name'],
            'item': items[i]['url'],
          },
      ],
    });
  }

  /// Creates a Schema.org `Organization` structured data object.
  ///
  /// - [name]: Required official name of the organization.
  /// - [url]: Required primary website URL of the organization.
  /// - [logo]: Optional logo image URL.
  ///
  /// ```dart
  /// final org = JsonLd.organization(
  ///   name: 'Bloom Framework',
  ///   url: 'https://bloom.dev',
  ///   logo: 'https://bloom.dev/logo.png',
  /// );
  /// ```
  factory JsonLd.organization({
    required String name,
    required String url,
    String? logo,
  }) {
    return JsonLd({
      '@context': 'https://schema.org',
      '@type': 'Organization',
      'name': name,
      'url': url,
      if (logo != null) 'logo': logo,
    });
  }

  /// Creates a Schema.org `WebSite` structured data object.
  ///
  /// - [name]: Required website name.
  /// - [url]: Required root URL of the website.
  /// - [description]: Optional brief description of the website.
  ///
  /// ```dart
  /// final site = JsonLd.webSite(
  ///   name: 'Bloom Documentation',
  ///   url: 'https://docs.bloom.dev',
  ///   description: 'Comprehensive guides and API reference for Bloom.',
  /// );
  /// ```
  factory JsonLd.webSite({
    required String name,
    required String url,
    String? description,
  }) {
    return JsonLd({
      '@context': 'https://schema.org',
      '@type': 'WebSite',
      'name': name,
      'url': url,
      if (description != null) 'description': description,
    });
  }

  /// Escapes special HTML characters (`&`, `<`, `>`, `"`, `'`) for safe inclusion
  /// within HTML attributes.
  static String escapeAttr(String s) => _escAttr(s);
}
