String _escXml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Represents a single `<url>` record within an XML sitemap.
///
/// Complies with the [Sitemaps XML format 0.9](https://www.sitemaps.org/protocol.html).
///
/// ### Example
///
/// ```dart
/// const entry = SitemapEntry(
///   'https://example.com/pricing',
///   lastmod: '2026-08-24',
///   changefreq: 'monthly',
///   priority: 0.8,
/// );
/// ```
class SitemapEntry {
  /// The absolute URL of the page (required by sitemaps protocol).
  final String loc;

  /// The date of last modification of the page in W3C format (e.g. `'2026-08-24'`).
  final String? lastmod;

  /// How frequently the page is likely to change.
  ///
  /// Valid values defined by the protocol: `'always'`, `'hourly'`, `'daily'`,
  /// `'weekly'`, `'monthly'`, `'yearly'`, `'never'`.
  final String? changefreq;

  /// The priority of this URL relative to other URLs on your site.
  ///
  /// Valid values range from `0.0` to `1.0`. Serialized to one decimal place (e.g. `0.8`).
  final double? priority;

  /// Creates a [SitemapEntry] representing a single sitemap URL record.
  ///
  /// - [loc]: The target URL.
  /// - [lastmod]: Optional last modified date string (e.g. `'YYYY-MM-DD'`).
  /// - [changefreq]: Optional change frequency hint.
  /// - [priority]: Optional priority score between `0.0` and `1.0`.
  const SitemapEntry(
    this.loc, {
    this.lastmod,
    this.changefreq,
    this.priority,
  });
}

/// Builder for generating XML sitemaps and sitemap index files conforming to
/// the [Sitemaps XML format 0.9](https://www.sitemaps.org/protocol.html).
///
/// Automatically handles XML character entity escaping (`&`, `<`, `>`, `"`, `'`)
/// for all URLs and text fields.
///
/// ### Example: Single Sitemap
///
/// ```dart
/// final builder = SitemapBuilder()
///   ..add('https://example.com/', priority: 1.0, changefreq: 'daily')
///   ..add('https://example.com/about', priority: 0.5, changefreq: 'monthly');
///
/// final xml = builder.buildXml();
/// ```
///
/// ### Example: Sitemap Index
///
/// ```dart
/// final indexXml = SitemapBuilder.buildIndex([
///   'https://example.com/sitemaps/posts.xml',
///   'https://example.com/sitemaps/pages.xml',
/// ]);
/// ```
class SitemapBuilder {
  final List<SitemapEntry> _entries = [];

  /// Appends a new sitemap URL entry with optional metadata.
  ///
  /// - [loc]: The absolute URL of the page.
  /// - [lastmod]: Optional modification date (e.g. `'2026-08-24'`).
  /// - [changefreq]: Optional change frequency (`'always'`, `'hourly'`, `'daily'`, etc.).
  /// - [priority]: Optional priority score from `0.0` to `1.0`.
  ///
  /// ```dart
  /// sitemap.add(
  ///   'https://example.com/blog/hello-world',
  ///   lastmod: '2026-08-24',
  ///   changefreq: 'weekly',
  ///   priority: 0.7,
  /// );
  /// ```
  void add(
    String loc, {
    String? lastmod,
    String? changefreq,
    double? priority,
  }) {
    _entries.add(SitemapEntry(
      loc,
      lastmod: lastmod,
      changefreq: changefreq,
      priority: priority,
    ));
  }

  /// Appends an existing [SitemapEntry] to this builder.
  ///
  /// ```dart
  /// sitemap.addEntry(const SitemapEntry('https://example.com/contact'));
  /// ```
  void addEntry(SitemapEntry entry) => _entries.add(entry);

  /// The total number of sitemap entries currently registered.
  int get length => _entries.length;

  /// Whether no sitemap entries have been added to this builder.
  bool get isEmpty => _entries.isEmpty;

  /// Serializes all registered entries into a standard UTF-8 XML sitemap string.
  ///
  /// Produces a `<?xml ...?><urlset ...>...</urlset>` structure with all special
  /// characters safely escaped.
  String buildXml() {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
    for (final e in _entries) {
      buf.writeln('  <url>');
      buf.writeln('    <loc>${_escXml(e.loc)}</loc>');
      if (e.lastmod != null) {
        buf.writeln('    <lastmod>${_escXml(e.lastmod!)}</lastmod>');
      }
      if (e.changefreq != null) {
        buf.writeln('    <changefreq>${_escXml(e.changefreq!)}</changefreq>');
      }
      if (e.priority != null) {
        buf.writeln('    <priority>${e.priority!.toStringAsFixed(1)}</priority>');
      }
      buf.writeln('  </url>');
    }
    buf.write('</urlset>');
    return buf.toString();
  }

  /// Builds a `<sitemapindex>` XML document pointing to multiple sitemap URLs.
  ///
  /// Used when a site has more than 50,000 URLs or exceeds 50MB uncompressed,
  /// requiring splitting into multiple sitemap files.
  ///
  /// - [sitemapUrls]: List of absolute URLs to individual sitemap XML files.
  ///
  /// ```dart
  /// final index = SitemapBuilder.buildIndex([
  ///   'https://example.com/sitemap-1.xml',
  ///   'https://example.com/sitemap-2.xml',
  /// ]);
  /// ```
  static String buildIndex(List<String> sitemapUrls) {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
    for (final url in sitemapUrls) {
      buf.writeln('  <sitemap>');
      buf.writeln('    <loc>${_escXml(url)}</loc>');
      buf.writeln('  </sitemap>');
    }
    buf.write('</sitemapindex>');
    return buf.toString();
  }

  /// Escapes special XML characters (`&`, `<`, `>`, `"`, `'`) for safe inclusion
  /// within sitemap XML text nodes.
  static String escapeXml(String s) => _escXml(s);
}
