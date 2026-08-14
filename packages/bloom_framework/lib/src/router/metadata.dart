// lib/src/router/metadata.dart
import 'dart:convert';

/// OpenGraph metadata for social media previews.
class OpenGraph {
  final String? title;
  final String? description;
  final String? image;
  final String? type;
  final String? url;
  final String? siteName;

  const OpenGraph({
    this.title,
    this.description,
    this.image,
    this.type = 'website',
    this.url,
    this.siteName,
  });
}

/// Twitter Card metadata.
class TwitterCard {
  final String card; // summary, summary_large_image, app, player
  final String? site;
  final String? creator;
  final String? title;
  final String? description;
  final String? image;

  const TwitterCard({
    this.card = 'summary_large_image',
    this.site,
    this.creator,
    this.title,
    this.description,
    this.image,
  });
}

/// Declarative SEO and OpenGraph metadata configuration for Bloom routes.
class BloomRouteMetadata {
  final String? title;
  final String? description;
  final String? canonical;
  final OpenGraph? openGraph;
  final TwitterCard? twitterCard;
  final Map<String, String> metaTags;
  final Map<String, dynamic>? jsonLd;

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
