String _escXml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Single sitemap entry.
class SitemapEntry {
  final String loc;
  final String? lastmod; // YYYY-MM-DD
  final String? changefreq; // always, hourly, daily, weekly, monthly, yearly, never
  final double? priority; // 0.0 - 1.0

  const SitemapEntry(
    this.loc, {
    this.lastmod,
    this.changefreq,
    this.priority,
  });
}

/// Builder for XML sitemap documents (sitemaps.org protocol).
class SitemapBuilder {
  final List<SitemapEntry> _entries = [];

  /// Add an entry.
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

  /// Add a pre-built entry.
  void addEntry(SitemapEntry entry) => _entries.add(entry);

  /// Number of entries.
  int get length => _entries.length;

  /// Whether any entries have been added.
  bool get isEmpty => _entries.isEmpty;

  /// Build the XML string.
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

  /// Build a sitemap-index XML that references multiple sitemaps.
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

  /// Expose XML escaper for testing.
  static String escapeXml(String s) => _escXml(s);
}
