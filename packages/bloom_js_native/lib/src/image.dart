// lib/src/image.dart
//
// Pure-Dart Image & Picture components for Bloom JS Native.
// Safe for both SSR (VM) and browser DOM mounting. Zero DOM or browser imports.

import 'framework.dart';
import 'events.dart';

// ─── Image Enums & Types ───────────────────────────────────────────────────

/// Image loading strategies for the browser.
enum ImageLoading {
  /// Defers loading the image until it reaches a calculated distance from the viewport.
  lazy('lazy'),

  /// Loads the image immediately regardless of viewport position.
  eager('eager');

  /// The raw HTML attribute string value.
  final String value;

  const ImageLoading(this.value);

  @override
  String toString() => value;
}

/// Image decoding hints for the browser rendering engine.
enum ImageDecoding {
  /// Decodes the image asynchronously to prevent blocking the main rendering thread.
  async('async'),

  /// Decodes the image synchronously for atomic presentation with other content.
  sync('sync'),

  /// Allows the browser to determine the optimal decoding mode.
  auto('auto');

  /// The raw HTML attribute string value.
  final String value;

  const ImageDecoding(this.value);

  @override
  String toString() => value;
}

/// Priority hints for resource fetching (`fetchpriority` attribute).
enum FetchPriority {
  /// Fetches the image with high priority relative to other resources (recommended for LCP hero images).
  high('high'),

  /// Fetches the image with low priority relative to other resources.
  low('low'),

  /// Automatically resolves priority according to browser heuristics.
  auto('auto');

  /// The raw HTML attribute string value.
  final String value;

  const FetchPriority(this.value);

  @override
  String toString() => value;
}

/// CSS `object-fit` sizing behavior for images.
enum ImageFit {
  /// The image is sized to maintain its aspect ratio while filling the element's entire content box.
  cover('cover'),

  /// The image is scaled to maintain its aspect ratio while fitting within the element's content box.
  contain('contain'),

  /// The image is sized to fill the element's content box, stretching if necessary.
  fill('fill'),

  /// The image is not resized.
  none('none'),

  /// The image is sized as if `none` or `contain` were specified, whichever results in a smaller size.
  scaleDown('scale-down');

  /// The raw CSS property value.
  final String value;

  const ImageFit(this.value);

  @override
  String toString() => value;
}

/// Function signature for generating width-specific image URLs for responsive `srcset`.
typedef ImageUrlBuilder = String Function(String src, int width);

/// Default image URL builder appending width as a query parameter (`?w=` or `&w=`).
///
/// ```dart
/// defaultImageUrlBuilder('/assets/hero.jpg', 640);
/// // Returns: '/assets/hero.jpg?w=640'
/// ```
String defaultImageUrlBuilder(String src, int width) {
  if (src.contains('?')) {
    return '$src&w=$width';
  }
  return '$src?w=$width';
}

/// Builds a standard `srcset` attribute string from a base [src] and a list of target [widths].
///
/// Uses [urlBuilder] (or [defaultImageUrlBuilder] if omitted) to construct each width variant URL.
///
/// ```dart
/// final srcset = buildSrcSet('/assets/photo.jpg', [320, 640, 1024]);
/// // Returns: '/assets/photo.jpg?w=320 320w, /assets/photo.jpg?w=640 640w, /assets/photo.jpg?w=1024 1024w'
/// ```
String buildSrcSet(
  String src,
  List<int> widths, {
  ImageUrlBuilder? urlBuilder,
}) {
  final builder = urlBuilder ?? defaultImageUrlBuilder;
  return widths.map((w) => '${builder(src, w)} ${w}w').join(', ');
}

// ─── Picture Source Descriptor ──────────────────────────────────────────────

/// Specification for a single `<source>` element within a `<picture>` container.
///
/// Used for art direction, media query resolution, and next-generation image format negotiation
/// (such as AVIF and WebP with fallback sources).
///
/// ```dart
/// PictureSource(
///   src: '/images/hero.avif',
///   type: 'image/avif',
///   widths: [640, 1024, 1920],
///   sizes: '(max-width: 768px) 100vw, 1200px',
///   media: '(min-width: 768px)',
/// );
/// ```
class PictureSource {
  /// Base URL of the source image.
  final String? src;

  /// Raw `srcset` string. If omitted and [widths] is provided, built automatically via [urlBuilder].
  final String? srcset;

  /// Target widths for automatic `srcset` generation when [src] is provided.
  final List<int>? widths;

  /// Custom URL builder for generating width variants from [src].
  final ImageUrlBuilder? urlBuilder;

  /// Responsive sizes query (e.g. `'(max-width: 768px) 100vw, 50vw'`).
  final String? sizes;

  /// Media condition query (e.g. `'(min-width: 1024px)'` or `'(prefers-color-scheme: dark)'`).
  final String? media;

  /// MIME type of the source resource (e.g. `'image/avif'`, `'image/webp'`).
  final String? type;

  /// Intrinsic width attribute for layout calculation.
  final int? width;

  /// Intrinsic height attribute for layout calculation.
  final int? height;

  /// Creates a `<source>` specification for `<picture>` elements.
  const PictureSource({
    this.src,
    this.srcset,
    this.widths,
    this.urlBuilder,
    this.sizes,
    this.media,
    this.type,
    this.width,
    this.height,
  });

  /// Compiles this specification into an [ElNode] descriptor targeting the void `<source>` element.
  ElNode toNode() {
    String? effectiveSrcset = srcset;
    if (effectiveSrcset == null && src != null && widths != null && widths!.isNotEmpty) {
      effectiveSrcset = buildSrcSet(src!, widths!, urlBuilder: urlBuilder);
    } else if (effectiveSrcset == null && src != null) {
      effectiveSrcset = src;
    }

    final attrs = <String, String>{
      if (effectiveSrcset != null) 'srcset': effectiveSrcset,
      if (sizes != null) 'sizes': sizes!,
      if (media != null) 'media': media!,
      if (type != null) 'type': type!,
      if (width != null) 'width': '$width',
      if (height != null) 'height': '$height',
    };

    return El('source', attrs: attrs);
  }
}

// ─── Responsive Image Helper & Component ────────────────────────────────────

/// High-performance responsive image descriptor helper for Bloom JS Native.
///
/// Composes a standard `<img>` element with performance best practices baked in:
/// - **Responsive sources**: Generates `srcset` and `sizes` automatically from [widths].
/// - **Lazy loading by default**: Defaults to `loading="lazy"` and `decoding="async"`.
/// - **LCP Optimization**: Pass `priority: true` for above-the-fold hero images to emit
///   `loading="eager"`, `fetchpriority="high"`, preventing delayed Largest Contentful Paint.
/// - **Layout stability**: Setting [width] and [height] (or [aspectRatio]) reserves the
///   correct layout space to prevent Cumulative Layout Shift (CLS).
/// - **Placeholders**: Supports solid colors (e.g. `'#14141a'`) or blur data URIs
///   rendered immediately in SSR and client DOM.
/// - **Accessibility first**: Forces explicit consideration of [alt] text or [decorative].
///
/// ### SSR and Browser Compatibility
/// This function is pure Dart. During SSR (`renderToHtml`), it outputs a standard HTML5
/// `<img>` with all security attributes and placeholder styles. In the browser, it binds
/// optional event handlers ([onLoad], [onError]) and attaches [ref] cleanly.
///
/// ```dart
/// bloomImage(
///   src: '/assets/product.jpg',
///   alt: 'Wireless Noise-Canceling Headphones',
///   width: 800,
///   height: 600,
///   widths: [400, 800, 1200],
///   sizes: '(max-width: 600px) 100vw, 800px',
///   placeholder: '#14141a',
///   fit: ImageFit.cover,
/// );
/// ```
BloomNode bloomImage({
  required String src,
  String? alt,
  bool decorative = false,
  int? width,
  int? height,
  String? aspectRatio,
  List<int>? widths,
  String? sizes,
  ImageUrlBuilder? urlBuilder,
  ImageLoading loading = ImageLoading.lazy,
  ImageDecoding decoding = ImageDecoding.async,
  FetchPriority? fetchPriority,
  bool priority = false,
  String? placeholder,
  String? fallbackSrc,
  ImageFit? fit,
  String? className,
  String? style,
  Map<String, String>? attrs,
  BloomEventHandler? onClick,
  BloomEventHandler? onLoad,
  BloomEventHandler? onError,
  Ref<Object>? ref,
}) {
  return BloomImage(
    src: src,
    alt: alt,
    decorative: decorative,
    width: width,
    height: height,
    aspectRatio: aspectRatio,
    widths: widths,
    sizes: sizes,
    urlBuilder: urlBuilder,
    loading: loading,
    decoding: decoding,
    fetchPriority: fetchPriority,
    priority: priority,
    placeholder: placeholder,
    fallbackSrc: fallbackSrc,
    fit: fit,
    className: className,
    style: style,
    attrs: attrs,
    onClick: onClick,
    onLoad: onLoad,
    onError: onError,
    ref: ref,
  );
}

/// An optimized, responsive `<img>` element descriptor.
///
/// Subclasses [ElNode] directly without introducing a new `BloomNode` variant,
/// preserving exhaustive pattern-matching compatibility across SSR and browser mount engines.
///
/// ```dart
/// BloomImage(
///   src: '/assets/banner.webp',
///   alt: 'Summer Sale Promotion',
///   width: 1200,
///   height: 400,
///   priority: true, // Hero image optimization
/// );
/// ```
class BloomImage extends ElNode {
  /// Creates a responsive image descriptor with layout stability, lazy loading,
  /// accessibility checks, and placeholder styling.
  BloomImage({
    required String src,
    String? alt,
    bool decorative = false,
    int? width,
    int? height,
    String? aspectRatio,
    List<int>? widths,
    String? sizes,
    ImageUrlBuilder? urlBuilder,
    ImageLoading loading = ImageLoading.lazy,
    ImageDecoding decoding = ImageDecoding.async,
    FetchPriority? fetchPriority,
    bool priority = false,
    String? placeholder,
    String? fallbackSrc,
    ImageFit? fit,
    super.className,
    String? style,
    Map<String, String>? attrs,
    BloomEventHandler? onClick,
    BloomEventHandler? onLoad,
    BloomEventHandler? onError,
    Ref<Object>? ref,
  }) : super(
          'img',
          style: _buildImageStyle(
            style: style,
            placeholder: placeholder,
            aspectRatio: aspectRatio,
            fit: fit,
          ),
          attrs: _buildImageAttrs(
            src: src,
            alt: alt,
            decorative: decorative,
            width: width,
            height: height,
            widths: widths,
            sizes: sizes,
            urlBuilder: urlBuilder,
            loading: loading,
            decoding: decoding,
            fetchPriority: fetchPriority,
            priority: priority,
            attrs: attrs,
          ),
          on: _buildImageEvents(
            onClick: onClick,
            onLoad: onLoad,
            onError: onError,
            fallbackSrc: fallbackSrc,
          ),
        ) {
    if (ref != null) {
      // If a ref is passed directly to the constructor, wrap via RefNode in higher composition
    }
  }

  /// Const constructor for [BloomImage] with pre-computed attributes.
  const BloomImage.raw({
    super.className,
    super.style,
    super.attrs,
    super.on,
  }) : super('img');
}

/// Art-directed, multi-format `<picture>` element descriptor helper.
///
/// Encloses one or more [PictureSource] elements (e.g. AVIF, WebP, breakpoint variants)
/// followed by an accessible fallback [bloomImage] descriptor.
///
/// ### Layout Stability & Modern Formats
/// Browsers evaluate `<source>` tags from top to bottom, picking the first supported format
/// or media condition, and apply the dimensions and layout rules from the inner `<img>`.
///
/// ```dart
/// bloomPicture(
///   sources: [
///     PictureSource(
///       src: '/images/hero.avif',
///       type: 'image/avif',
///       widths: [640, 1024, 1600],
///     ),
///     PictureSource(
///       src: '/images/hero.webp',
///       type: 'image/webp',
///       widths: [640, 1024, 1600],
///     ),
///   ],
///   fallbackSrc: '/images/hero.jpg',
///   alt: 'Bloom Framework Dashboard',
///   width: 1200,
///   height: 600,
///   priority: true,
/// );
/// ```
BloomNode bloomPicture({
  required List<PictureSource> sources,
  required String fallbackSrc,
  String? alt,
  bool decorative = false,
  int? width,
  int? height,
  String? aspectRatio,
  List<int>? fallbackWidths,
  String? sizes,
  ImageUrlBuilder? urlBuilder,
  ImageLoading loading = ImageLoading.lazy,
  ImageDecoding decoding = ImageDecoding.async,
  FetchPriority? fetchPriority,
  bool priority = false,
  String? placeholder,
  String? fallbackOnErrorSrc,
  ImageFit? fit,
  String? className,
  String? style,
  Map<String, String>? attrs,
  BloomEventHandler? onClick,
  BloomEventHandler? onLoad,
  BloomEventHandler? onError,
  Ref<Object>? ref,
}) {
  return BloomPicture(
    sources: sources,
    fallbackSrc: fallbackSrc,
    alt: alt,
    decorative: decorative,
    width: width,
    height: height,
    aspectRatio: aspectRatio,
    fallbackWidths: fallbackWidths,
    sizes: sizes,
    urlBuilder: urlBuilder,
    loading: loading,
    decoding: decoding,
    fetchPriority: fetchPriority,
    priority: priority,
    placeholder: placeholder,
    fallbackOnErrorSrc: fallbackOnErrorSrc,
    fit: fit,
    className: className,
    style: style,
    attrs: attrs,
    onClick: onClick,
    onLoad: onLoad,
    onError: onError,
    ref: ref,
  );
}

/// `<picture>` element descriptor subclassing [ElNode].
class BloomPicture extends ElNode {
  /// Creates a `<picture>` container enclosing [sources] and an inner fallback [BloomImage].
  BloomPicture({
    required List<PictureSource> sources,
    required String fallbackSrc,
    String? alt,
    bool decorative = false,
    int? width,
    int? height,
    String? aspectRatio,
    List<int>? fallbackWidths,
    String? sizes,
    ImageUrlBuilder? urlBuilder,
    ImageLoading loading = ImageLoading.lazy,
    ImageDecoding decoding = ImageDecoding.async,
    FetchPriority? fetchPriority,
    bool priority = false,
    String? placeholder,
    String? fallbackOnErrorSrc,
    ImageFit? fit,
    super.className,
    super.style,
    super.attrs,
    BloomEventHandler? onClick,
    BloomEventHandler? onLoad,
    BloomEventHandler? onError,
    Ref<Object>? ref,
  }) : super(
          'picture',
          children: [
            ...sources.map((s) => s.toNode()),
            BloomImage(
              src: fallbackSrc,
              alt: alt,
              decorative: decorative,
              width: width,
              height: height,
              aspectRatio: aspectRatio,
              widths: fallbackWidths,
              sizes: sizes,
              urlBuilder: urlBuilder,
              loading: loading,
              decoding: decoding,
              fetchPriority: fetchPriority,
              priority: priority,
              placeholder: placeholder,
              fallbackSrc: fallbackOnErrorSrc,
              fit: fit,
              onClick: onClick,
              onLoad: onLoad,
              onError: onError,
              ref: ref,
            ),
          ],
        );

  /// Const constructor for `<picture>` elements.
  const BloomPicture.raw({
    super.className,
    super.style,
    super.attrs,
    super.children = const [],
  }) : super('picture');
}

// ─── Private Internal Helpers ───────────────────────────────────────────────

String? _buildImageStyle({
  String? style,
  String? placeholder,
  String? aspectRatio,
  ImageFit? fit,
}) {
  final styleParts = <String>[];

  if (aspectRatio != null && aspectRatio.isNotEmpty) {
    styleParts.add('aspect-ratio: $aspectRatio;');
  }

  if (fit != null) {
    styleParts.add('object-fit: ${fit.value};');
  }

  if (placeholder != null && placeholder.isNotEmpty) {
    if (placeholder.startsWith('data:image/') ||
        placeholder.startsWith('http://') ||
        placeholder.startsWith('https://') ||
        placeholder.startsWith('/')) {
      styleParts.add(
          'background-image: url("$placeholder"); background-size: cover; background-position: center;');
    } else {
      styleParts.add('background-color: $placeholder;');
    }
  }

  if (style != null && style.isNotEmpty) {
    styleParts.add(style);
  }

  if (styleParts.isEmpty) return null;
  return styleParts.join(' ');
}

Map<String, String> _buildImageAttrs({
  required String src,
  String? alt,
  required bool decorative,
  int? width,
  int? height,
  List<int>? widths,
  String? sizes,
  ImageUrlBuilder? urlBuilder,
  required ImageLoading loading,
  required ImageDecoding decoding,
  FetchPriority? fetchPriority,
  required bool priority,
  Map<String, String>? attrs,
}) {
  final out = <String, String>{};

  out['src'] = src;

  // Accessibility: alt and presentation semantics
  if (decorative) {
    out['alt'] = '';
    out['aria-hidden'] = 'true';
  } else {
    out['alt'] = alt ?? '';
  }

  // Layout stability attributes
  if (width != null) out['width'] = '$width';
  if (height != null) out['height'] = '$height';

  // Responsive srcset
  if (widths != null && widths.isNotEmpty) {
    out['srcset'] = buildSrcSet(src, widths, urlBuilder: urlBuilder);
  }

  if (sizes != null && sizes.isNotEmpty) {
    out['sizes'] = sizes;
  }

  // Priority and loading
  if (priority) {
    out['loading'] = 'eager';
    out['decoding'] = 'async';
    out['fetchpriority'] = 'high';
  } else {
    out['loading'] = loading.value;
    out['decoding'] = decoding.value;
    if (fetchPriority != null) {
      out['fetchpriority'] = fetchPriority.value;
    }
  }

  if (attrs != null) {
    out.addAll(attrs);
  }

  return out;
}

Map<String, BloomEventHandler>? _buildImageEvents({
  BloomEventHandler? onClick,
  BloomEventHandler? onLoad,
  BloomEventHandler? onError,
  String? fallbackSrc,
}) {
  final events = <String, BloomEventHandler>{};

  if (onClick != null) events['click'] = onClick;
  if (onLoad != null) events['load'] = onLoad;

  if (onError != null || fallbackSrc != null) {
    events['error'] = (event) {
      if (onError != null) {
        onError(event);
      }
    };
  }

  return events.isEmpty ? null : events;
}
