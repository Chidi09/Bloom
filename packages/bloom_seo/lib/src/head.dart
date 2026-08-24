import 'package:signals_core/signals_core.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#x27;');

/// Reactive document head manager — drives `<title>`, `<meta>`, Open Graph,
/// and Twitter tags from fine-grained reactive signals.
///
/// [HeadManager] can be used both standalone during Server-Side Rendering (SSR)
/// via [renderToHtml] / [wrapDocument], and in interactive client applications
/// where signal mutations trigger reactive updates.
///
/// ### Tag Cascading & Defaults
///
/// When rendered via [renderToHtml]:
/// - `ogTitle` falls back to [title] if not explicitly set.
/// - `ogDescription` falls back to [description] if not explicitly set.
/// - `ogImage` falls back to [image] if not explicitly set.
/// - `ogUrl` falls back to [canonical] if not explicitly set.
/// - `ogType` defaults to `'website'` if omitted.
///
/// ### Example
///
/// ```dart
/// final head = HeadManager(
///   initialTitle: 'Blog Post Title',
///   initialDescription: 'An insightful technical article.',
///   initialCanonical: 'https://example.com/posts/hello',
///   initialImage: 'https://example.com/images/hello.png',
/// );
///
/// // Update multiple fields atomically
/// head.update(
///   title: 'Updated Post Title',
///   ogType: 'article',
/// );
///
/// // Render tags for SSR <head> injection
/// final tagsHtml = head.renderToHtml();
///
/// // Or wrap complete HTML document
/// final fullHtml = head.wrapDocument('<h1>Hello World</h1>');
///
/// // Dispose signals when finished
/// head.dispose();
/// ```
class HeadManager {
  /// Reactive signal storing the document title.
  ///
  /// Renders as `<title>` and serves as the default fallback for [ogTitle].
  Signal<String> title;

  /// Reactive signal storing the meta description (`<meta name="description">`).
  ///
  /// Serves as the default fallback for [ogDescription].
  Signal<String?> description;

  /// Reactive signal storing the canonical URL (`<link rel="canonical">`).
  ///
  /// Serves as the default fallback for [ogUrl].
  Signal<String?> canonical;

  /// Reactive signal storing the primary preview image URL.
  ///
  /// Serves as the default fallback for [ogImage].
  Signal<String?> image;

  /// Reactive signal storing the HTML `lang` attribute (e.g. `'en'`).
  ///
  /// Used by [wrapDocument] to set `<html lang="...">`.
  Signal<String> lang;

  // Open Graph

  /// Reactive signal storing the Open Graph type (e.g. `'website'`, `'article'`).
  ///
  /// Renders as `<meta property="og:type">`. Defaults to `'website'` if unset.
  Signal<String?> ogType;

  /// Reactive signal storing the Open Graph title (`<meta property="og:title">`).
  ///
  /// Falls back to [title] when null or empty.
  Signal<String?> ogTitle;

  /// Reactive signal storing the Open Graph description (`<meta property="og:description">`).
  ///
  /// Falls back to [description] when null.
  Signal<String?> ogDescription;

  /// Reactive signal storing the Open Graph image URL (`<meta property="og:image">`).
  ///
  /// Falls back to [image] when null.
  Signal<String?> ogImage;

  /// Reactive signal storing the Open Graph URL (`<meta property="og:url">`).
  ///
  /// Falls back to [canonical] when null.
  Signal<String?> ogUrl;

  // Twitter

  /// Reactive signal storing the Twitter Card type (e.g. `'summary_large_image'`).
  ///
  /// Renders as `<meta name="twitter:card">`.
  Signal<String?> twitterCard;

  /// Reactive signal storing the Twitter author / site handle (e.g. `'@bloom_framework'`).
  ///
  /// Renders as `<meta name="twitter:site">`.
  Signal<String?> twitterSite;

  /// Creates a new [HeadManager] instance with optional initial signal values.
  ///
  /// - [initialTitle]: Default document title (defaults to empty string `''`).
  /// - [initialDescription]: Optional initial meta description.
  /// - [initialCanonical]: Optional initial canonical URL.
  /// - [initialImage]: Optional initial preview image URL.
  /// - [initialLang]: Document language code (defaults to `'en'`).
  /// - [initialOgType]: Optional initial Open Graph type (e.g. `'website'`).
  /// - [initialOgTitle]: Optional explicit Open Graph title.
  /// - [initialOgDescription]: Optional explicit Open Graph description.
  /// - [initialOgImage]: Optional explicit Open Graph image URL.
  /// - [initialOgUrl]: Optional explicit Open Graph URL.
  /// - [initialTwitterCard]: Optional Twitter card format (e.g. `'summary_large_image'`).
  /// - [initialTwitterSite]: Optional Twitter site handle (e.g. `'@bloom'`).
  HeadManager({
    String initialTitle = '',
    String? initialDescription,
    String? initialCanonical,
    String? initialImage,
    String initialLang = 'en',
    String? initialOgType,
    String? initialOgTitle,
    String? initialOgDescription,
    String? initialOgImage,
    String? initialOgUrl,
    String? initialTwitterCard,
    String? initialTwitterSite,
  })  : title = signal(initialTitle),
        description = signal(initialDescription),
        canonical = signal(initialCanonical),
        image = signal(initialImage),
        lang = signal(initialLang),
        ogType = signal(initialOgType),
        ogTitle = signal(initialOgTitle),
        ogDescription = signal(initialOgDescription),
        ogImage = signal(initialOgImage),
        ogUrl = signal(initialOgUrl),
        twitterCard = signal(initialTwitterCard),
        twitterSite = signal(initialTwitterSite);

  /// Updates multiple head metadata fields in a single atomic batch.
  ///
  /// Any non-null argument assigns its value to the corresponding signal
  /// within a `batch(...)` block, triggering at most one notification to
  /// reactive listeners.
  ///
  /// ```dart
  /// head.update(
  ///   title: 'New Page Title',
  ///   description: 'Updated meta description.',
  ///   ogImage: '/generated/og/new-page.png',
  /// );
  /// ```
  void update({
    String? title,
    String? description,
    String? canonical,
    String? image,
    String? ogType,
    String? ogTitle,
    String? ogDescription,
    String? ogImage,
    String? ogUrl,
    String? twitterCard,
    String? twitterSite,
  }) {
    batch(() {
      if (title != null) this.title.value = title;
      if (description != null) this.description.value = description;
      if (canonical != null) this.canonical.value = canonical;
      if (image != null) this.image.value = image;
      if (ogType != null) this.ogType.value = ogType;
      if (ogTitle != null) this.ogTitle.value = ogTitle;
      if (ogDescription != null) this.ogDescription.value = ogDescription;
      if (ogImage != null) this.ogImage.value = ogImage;
      if (ogUrl != null) this.ogUrl.value = ogUrl;
      if (twitterCard != null) this.twitterCard.value = twitterCard;
      if (twitterSite != null) this.twitterSite.value = twitterSite;
    });
  }

  /// Renders current head tags as an HTML fragment suitable for `<head>` injection.
  ///
  /// All text values and attribute contents are safely escaped against XSS.
  /// Applies automatic fallback resolution:
  /// - Open Graph title falls back to [title].
  /// - Open Graph description falls back to [description].
  /// - Open Graph image falls back to [image].
  /// - Open Graph URL falls back to [canonical].
  /// - Open Graph type defaults to `'website'`.
  ///
  /// Returns a trimmed, newline-delimited HTML fragment.
  String renderToHtml() {
    final buf = StringBuffer();

    final t = title.value;
    if (t.isNotEmpty) buf.writeln('<title>${_esc(t)}</title>');

    final desc = description.value;
    if (desc != null && desc.isNotEmpty) {
      buf.writeln('<meta name="description" content="${_esc(desc)}">');
    }

    final can = canonical.value;
    if (can != null && can.isNotEmpty) {
      buf.writeln('<link rel="canonical" href="${_esc(can)}">');
    }

    // Open Graph
    final oType = ogType.value ?? 'website';
    buf.writeln('<meta property="og:type" content="${_esc(oType)}">');
    final oTitle = ogTitle.value ?? title.value;
    if (oTitle.isNotEmpty) {
      buf.writeln('<meta property="og:title" content="${_esc(oTitle)}">');
    }
    final oDesc = ogDescription.value ?? description.value;
    if (oDesc != null && oDesc.isNotEmpty) {
      buf.writeln('<meta property="og:description" content="${_esc(oDesc)}">');
    }
    final oImg = ogImage.value ?? image.value;
    if (oImg != null && oImg.isNotEmpty) {
      buf.writeln('<meta property="og:image" content="${_esc(oImg)}">');
    }
    final oUrl = ogUrl.value ?? canonical.value;
    if (oUrl != null && oUrl.isNotEmpty) {
      buf.writeln('<meta property="og:url" content="${_esc(oUrl)}">');
    }

    // Twitter
    final twCard = twitterCard.value;
    if (twCard != null && twCard.isNotEmpty) {
      buf.writeln('<meta name="twitter:card" content="${_esc(twCard)}">');
    }
    final twSite = twitterSite.value;
    if (twSite != null && twSite.isNotEmpty) {
      buf.writeln('<meta name="twitter:site" content="${_esc(twSite)}">');
    }

    return buf.toString().trim();
  }

  /// Exports current head metadata as a structured `Map<String, dynamic>`.
  ///
  /// Useful for telemetry, JSON serialization, or passing metadata to
  /// external layout engines.
  Map<String, dynamic> toMetaMap() => {
        'title': title.value,
        'description': description.value,
        'canonical': canonical.value,
        'image': image.value,
        'lang': lang.value,
        'og': {
          'type': ogType.value,
          'title': ogTitle.value,
          'description': ogDescription.value,
          'image': ogImage.value,
          'url': ogUrl.value,
        },
        'twitter': {
          'card': twitterCard.value,
          'site': twitterSite.value,
        },
      };

  /// Wraps [bodyHtml] in a complete HTML document structure (`<!DOCTYPE html>`).
  ///
  /// Injects:
  /// - `<html lang="...">` with the escaped [lang] signal value.
  /// - Standard `<meta charset="utf-8">` and viewport meta tags.
  /// - Rendered head tags from [renderToHtml].
  /// - Optional [extraHead] content (such as font stylesheets, JSON-LD scripts, etc.).
  /// - The provided [bodyHtml] inside `<body>...</body>`.
  ///
  /// ```dart
  /// final fullHtml = head.wrapDocument(
  ///   '<div>Hello World</div>',
  ///   extraHead: '<link rel="stylesheet" href="/styles.css">',
  /// );
  /// ```
  String wrapDocument(String bodyHtml, {String? extraHead}) {
    final headHtml = renderToHtml();
    final extra = extraHead != null ? '\n$extraHead' : '';
    return '''<!DOCTYPE html>
<html lang="${_esc(lang.value)}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
$headHtml$extra
</head>
<body>
$bodyHtml
</body>
</html>''';
  }

  /// Disposes all internal signals managed by this instance.
  ///
  /// Call this when the [HeadManager] is no longer needed to release
  /// signal listeners and prevent memory leaks.
  void dispose() {
    title.dispose();
    description.dispose();
    canonical.dispose();
    image.dispose();
    lang.dispose();
    ogType.dispose();
    ogTitle.dispose();
    ogDescription.dispose();
    ogImage.dispose();
    ogUrl.dispose();
    twitterCard.dispose();
    twitterSite.dispose();
  }
}

/// Escapes HTML special characters (`&`, `<`, `>`, `"`, `'`) for safe inclusion
/// within `<head>` tags and attribute strings.
String escapeForHead(String s) => _esc(s);
