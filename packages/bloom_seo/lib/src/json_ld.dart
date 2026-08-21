import 'dart:convert';

String _escAttr(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#x27;');

/// JSON-LD structured data helper.
///
/// ```dart
/// final ld = JsonLd.article(
///   headline: 'Hello World',
///   author: 'Bloom',
///   datePublished: '2026-08-21',
/// );
/// Head: ld.toScriptTag()
/// ```
class JsonLd {
  final Map<String, dynamic> data;

  const JsonLd(this.data);

  /// Emit a `<script type="application/ld+json">` tag.
  String toScriptTag({bool pretty = false}) {
    final json = pretty
        ? const JsonEncoder.withIndent('  ').convert(data)
        : jsonEncode(data);
    // JSON-LD is inside a script tag — escape closing script to avoid XSS.
    final safe = json.replaceAll('</script>', '<\\/script>');
    return '<script type="application/ld+json">$safe</script>';
  }

  /// Raw JSON string.
  String toJson({bool pretty = false}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(data)
      : jsonEncode(data);

  // ── Factory helpers ───────────────────────────────────────────────

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

  /// Expose attribute escaper for testing.
  static String escapeAttr(String s) => _escAttr(s);
}
