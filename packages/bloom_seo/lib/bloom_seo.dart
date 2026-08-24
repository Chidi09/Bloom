/// SEO, reactive head metadata, structured data (JSON-LD), and sitemap generator for Bloom.
///
/// This library provides first-class search engine optimization and document
/// metadata primitives designed for full-stack Bloom applications:
///
/// - **Reactive Head Management**: [HeadManager] drives `<title>`, `<meta>`,
///   Open Graph, and Twitter tags from fine-grained signals (`Signal<T>`).
/// - **Structured Data (JSON-LD)**: [JsonLd] creates Schema.org structured data
///   (articles, breadcrumbs, organizations, websites) with safe script tag escaping.
/// - **Sitemaps**: [SitemapBuilder] generates protocol-compliant XML sitemaps
///   and sitemap index files.
/// - **Static Pre-rendering & SSG**: [prerenderRoute] and [prerenderRoutes]
///   render pure Dart [BloomNode] UI trees into static HTML documents.
/// - **Social Image Routing**: [ogImagePath] constructs asset paths for generated
///   social preview cards.
///
/// ### End-to-End Example
///
/// ```dart
/// import 'package:bloom_js_native/bloom_js_native.dart';
/// import 'package:bloom_seo/bloom_seo.dart';
///
/// void main() {
///   // 1. Configure reactive head metadata
///   final head = HeadManager(
///     initialTitle: 'Bloom SEO Guide',
///     initialDescription: 'Master reactive SEO and SSG in Bloom applications.',
///     initialCanonical: 'https://example.com/guide',
///     initialImage: 'https://example.com/images/cover.png',
///   );
///
///   // 2. Build JSON-LD structured data
///   final articleLd = JsonLd.article(
///     headline: 'Bloom SEO Guide',
///     author: 'Bloom Team',
///     datePublished: '2026-08-24',
///     url: 'https://example.com/guide',
///   );
///
///   // 3. Prerender route to static HTML
///   final html = prerenderRoute(
///     body: H1(text: 'Bloom SEO Guide'),
///     head: head,
///     extraHead: articleLd.toScriptTag(),
///   );
///
///   // 4. Generate XML sitemap
///   final sitemap = SitemapBuilder()
///     ..add(
///       'https://example.com/guide',
///       lastmod: '2026-08-24',
///       changefreq: 'weekly',
///       priority: 0.8,
///     );
///   final sitemapXml = sitemap.buildXml();
/// }
/// ```
library;

export 'src/head.dart';
export 'src/json_ld.dart';
export 'src/sitemap.dart';
export 'src/prerender.dart';
export 'src/og_image_helper.dart';
