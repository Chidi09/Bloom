// lib/src/router/metadata.dart
library;

import 'dart:convert';

/// OpenGraph metadata configuration for rich social media previews.
///
/// Example:
/// ```dart
/// const og = OpenGraph(
///   title: 'Bloom Framework',
///   description: 'Full-stack reactive framework for Flutter and pure Dart',
///   image: 'https://bloom.dev/og.png',
///   type: 'website',
/// );
/// ```
class OpenGraph {
  /// The title of the object as it should appear in the graph.
  final String? title;

  /// A short description of the content.
  final String? description;

  /// An image URL which should represent your object within the graph.
  final String? image;

  /// The type of the object (e.g., 'website', 'article'). Defaults to 'website'.
  final String? type;

  /// The canonical URL of the object.
  final String? url;

  /// If your object is part of a larger web site, the name of the entire site.
  final String? siteName;

  /// Creates an [OpenGraph] metadata configuration.
  const OpenGraph({
    this.title,
    this.description,
    this.image,
    this.type = 'website',
    this.url,
    this.siteName,
  });
}

/// Twitter Card metadata for rich Twitter social previews.
///
/// Example:
/// ```dart
/// const twitter = TwitterCard(
///   card: 'summary_large_image',
///   site: '@BloomFramework',
///   title: 'Bloom Framework',
///   description: 'Full-stack reactive framework',
/// );
/// ```
class TwitterCard {
  /// The card type: `summary`, `summary_large_image`, `app`, or `player`.
  final String card; // summary, summary_large_image, app, player

  /// The @username of website.
  final String? site;

  /// The @username of content creator.
  final String? creator;

  /// Title of the card.
  final String? title;

  /// Description of the card.
  final String? description;

  /// URL of the image to use in the card.
  final String? image;

  /// Creates a [TwitterCard] metadata configuration.
  const TwitterCard({
    this.card = 'summary_large_image',
    this.site,
    this.creator,
    this.title,
    this.description,
    this.image,
  });
}

/// Declarative SEO, OpenGraph, and Twitter Card metadata configuration for Bloom routes.
///
/// Used by SSR/SSG compilers to inject semantic `<meta>`, `<title>`, `<link rel="canonical">`,
/// and JSON-LD structured `<script>` tags into the rendered HTML `<head>`.
///
/// Example:
/// ```dart
/// const metadata = BloomRouteMetadata(
///   title: 'Documentation | Bloom',
///   description: 'Learn how to build modern apps with Bloom',
///   canonical: 'https://bloom.dev/docs',
///   openGraph: OpenGraph(title: 'Bloom Docs'),
/// );
/// final htmlHeadTags = metadata.renderHtmlTags();
/// ```
class BloomRouteMetadata {
  /// Document title displayed in browser tab and search snippets.
  final String? title;

  /// Meta description summary for search engine optimization.
  final String? description;

  /// Canonical URL for duplicate content indexing prevention.
  final String? canonical;

  /// OpenGraph metadata for social media platforms.
  final OpenGraph? openGraph;

  /// Twitter Card metadata configuration.
  final TwitterCard? twitterCard;

  /// Additional custom meta tag name-to-content mappings.
  final Map<String, String> metaTags;

  /// JSON-LD structured data payload.
  final Map<String, dynamic>? jsonLd;

  /// Creates a [BloomRouteMetadata] configuration.
  const BloomRouteMetadata({
    this.title,
    this.description,
    this.canonical,
    this.openGraph,
    this.twitterCard,
    this.metaTags = const {},
    this.jsonLd,
  });

  /// Renders SEO, OpenGraph, and Twitter Card HTML elements.
  String renderHtmlTags() {
    final buffer = StringBuffer();

    if (title != null && title!.isNotEmpty) {
      buffer.writeln('  <title>${_escapeHtml(title!)}</title>');
    }

    if (description != null && description!.isNotEmpty) {
      buffer.writeln('  <meta name="description" content="${_escapeHtml(description!)}" />');
    }

    if (canonical != null && canonical!.isNotEmpty) {
      buffer.writeln('  <link rel="canonical" href="${_escapeHtml(canonical!)}" />');
    }

    // OpenGraph
    if (openGraph != null) {
      if (openGraph!.title != null) {
        buffer.writeln('  <meta property="og:title" content="${_escapeHtml(openGraph!.title!)}" />');
      }
      if (openGraph!.description != null) {
        buffer.writeln('  <meta property="og:description" content="${_escapeHtml(openGraph!.description!)}" />');
      }
      if (openGraph!.image != null) {
        buffer.writeln('  <meta property="og:image" content="${_escapeHtml(openGraph!.image!)}" />');
      }
      if (openGraph!.type != null) {
        buffer.writeln('  <meta property="og:type" content="${_escapeHtml(openGraph!.type!)}" />');
      }
      if (openGraph!.url != null) {
        buffer.writeln('  <meta property="og:url" content="${_escapeHtml(openGraph!.url!)}" />');
      }
      if (openGraph!.siteName != null) {
        buffer.writeln('  <meta property="og:site_name" content="${_escapeHtml(openGraph!.siteName!)}" />');
      }
    }

    // Twitter Card
    if (twitterCard != null) {
      buffer.writeln('  <meta name="twitter:card" content="${_escapeHtml(twitterCard!.card)}" />');
      if (twitterCard!.title != null) {
        buffer.writeln('  <meta name="twitter:title" content="${_escapeHtml(twitterCard!.title!)}" />');
      }
      if (twitterCard!.description != null) {
        buffer.writeln('  <meta name="twitter:description" content="${_escapeHtml(twitterCard!.description!)}" />');
      }
      if (twitterCard!.image != null) {
        buffer.writeln('  <meta name="twitter:image" content="${_escapeHtml(twitterCard!.image!)}" />');
      }
      if (twitterCard!.site != null) {
        buffer.writeln('  <meta name="twitter:site" content="${_escapeHtml(twitterCard!.site!)}" />');
      }
      if (twitterCard!.creator != null) {
        buffer.writeln('  <meta name="twitter:creator" content="${_escapeHtml(twitterCard!.creator!)}" />');
      }
    }

    // Custom Meta Tags
    for (final entry in metaTags.entries) {
      buffer.writeln('  <meta name="${_escapeHtml(entry.key)}" content="${_escapeHtml(entry.value)}" />');
    }

    // JSON-LD Structured Data
    if (jsonLd != null && jsonLd!.isNotEmpty) {
      buffer.writeln('  <script type="application/ld+json">');
      buffer.writeln(const JsonEncoder.withIndent('    ').convert(jsonLd));
      buffer.writeln('  </script>');
    }

    return buffer.toString().trimRight();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
