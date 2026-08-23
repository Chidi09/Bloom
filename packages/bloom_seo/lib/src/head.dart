import 'package:signals_core/signals_core.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#x27;');

/// Reactive head manager — drives <title> and <meta>/<link> tags from
/// signals so route changes update the document head.
///
/// Works standalone (SSR: call [renderToHtml]) and integrated with the
/// Bloom client router (phase 3: effect patches real DOM).
class HeadManager {
  Signal<String> title;
  Signal<String?> description;
  Signal<String?> canonical;
  Signal<String?> image;
  Signal<String> lang;

  // Open Graph
  Signal<String?> ogType;
  Signal<String?> ogTitle;
  Signal<String?> ogDescription;
  Signal<String?> ogImage;
  Signal<String?> ogUrl;

  // Twitter
  Signal<String?> twitterCard;
  Signal<String?> twitterSite;

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

  /// Update multiple fields at once (batched).
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

  /// Render head tags as an HTML fragment (for SSR `<head>` injection).
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

  /// Structured data helper — returns a map suitable for JSON-LD injection.
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

  /// Full HTML document wrapper for prerendered routes (convenience).
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

  /// Dispose all signals (call when manager is no longer needed).
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

/// Escape helper exposed for tests.
String escapeForHead(String s) => _esc(s);
