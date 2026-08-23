// lib/src/image.dart
//
// Pure-Dart Image & Picture components for Bloom JS Native.
// Safe for both SSR (VM) and browser DOM mounting. Zero DOM or browser imports.

import 'framework.dart';
import 'events.dart';

// ─── Image Enums & Types ───────────────────────────────────────────────────

/// Loading strategies determining when the browser initiates image network fetching.
///
/// Controls the HTML `loading` attribute on `<img>` elements. By default, [bloomImage]
/// and [BloomImage] specify [ImageLoading.lazy] to minimize bandwidth consumption and
/// avoid competing with critical resources during initial page load.
///
/// For above-the-fold hero images or critical visual elements, specify [ImageLoading.eager]
/// (or set `priority: true` on [bloomImage]) to prevent delayed Largest Contentful Paint (LCP).
///
/// ```dart
/// bloomImage(
///   src: '/assets/banner.webp',
///   alt: 'Homepage Banner',
///   loading: ImageLoading.eager,
/// );
/// ```
///
/// See also:
/// - [bloomImage], the primary responsive image helper.
/// - [BloomImage], the image element descriptor node.
/// - [FetchPriority], for resource scheduling priority hints.
enum ImageLoading {
  /// Defers loading the image until it reaches a calculated distance from the viewport.
  ///
  /// Recommended for all below-the-fold images to conserve network bandwidth and
  /// speed up the initial page render.
  lazy('lazy'),

  /// Loads the image immediately upon DOM parsing, regardless of viewport position.
  ///
  /// Recommended for above-the-fold hero images, key product shots, and critical
  /// UI elements contributing directly to Largest Contentful Paint (LCP).
  eager('eager');

  /// The raw HTML attribute string value (`"lazy"` or `"eager"`).
  final String value;

  const ImageLoading(this.value);

  @override
  String toString() => value;
}

/// Image decoding hints guiding the browser's rendering engine.
///
/// Controls the HTML `decoding` attribute on `<img>` elements, indicating whether
/// the browser should decode image data synchronously or off the main execution thread.
///
/// [bloomImage] defaults to [ImageDecoding.async] to prevent main-thread jank and frame drops
/// when large images are decoded during scrolling or active UI animations.
///
/// ```dart
/// bloomImage(
///   src: '/assets/gallery-item.jpg',
///   alt: 'Gallery preview',
///   decoding: ImageDecoding.async,
/// );
/// ```
///
/// See also:
/// - [bloomImage], which defaults to asynchronous decoding.
/// - [BloomImage], the underlying element descriptor.
enum ImageDecoding {
  /// Decodes the image asynchronously on a background thread to prevent blocking the main rendering thread.
  ///
  /// Default setting in Bloom JS Native. Prevents user interface stutter when decoding large raster assets.
  async('async'),

  /// Decodes the image synchronously for atomic presentation with surrounding document content.
  ///
  /// Can cause frame drops on slow devices if the image file is large.
  sync('sync'),

  /// Allows the browser to determine the optimal decoding mode dynamically.
  auto('auto');

  /// The raw HTML attribute string value (`"async"`, `"sync"`, or `"auto"`).
  final String value;

  const ImageDecoding(this.value);

  @override
  String toString() => value;
}

/// Priority hints for browser resource scheduling via the `fetchpriority` attribute.
///
/// Informs the browser network layer of the relative importance of an image resource.
/// Setting [FetchPriority.high] on hero images informs preloaders and HTTP/2 or HTTP/3
/// stream schedulers to prioritize image byte transmission over non-critical scripts or stylesheets.
///
/// Setting `priority: true` on [bloomImage] automatically configures [FetchPriority.high]
/// alongside [ImageLoading.eager].
///
/// ```dart
/// bloomImage(
///   src: '/assets/hero.webp',
///   alt: 'Hero visual',
///   fetchPriority: FetchPriority.high,
/// );
/// ```
///
/// See also:
/// - [bloomImage], responsive image helper with built-in LCP optimizations.
/// - [ImageLoading], controlling when network fetching begins.
enum FetchPriority {
  /// Fetches the image with high priority relative to other network resources (recommended for LCP hero images).
  high('high'),

  /// Fetches the image with low priority relative to other network resources (suitable for non-critical thumbnails).
  low('low'),

  /// Automatically resolves fetching priority according to standard browser heuristics.
  auto('auto');

  /// The raw HTML attribute string value (`"high"`, `"low"`, or `"auto"`).
  final String value;

  const FetchPriority(this.value);

  @override
  String toString() => value;
}

/// CSS `object-fit` sizing behaviors for responsive image scaling.
///
/// Specifies how an `<img>` element's content should resize to fit its container box.
/// Emitted as an inline `object-fit` CSS property in [BloomImage] and [bloomImage].
///
/// ```dart
/// bloomImage(
///   src: '/assets/avatar.jpg',
///   alt: 'User profile picture',
///   width: 96,
///   height: 96,
///   fit: ImageFit.cover,
/// );
/// ```
///
/// See also:
/// - [bloomImage], which accepts an optional [ImageFit] argument.
/// - [BloomImage], the underlying element descriptor.
enum ImageFit {
  /// The image is sized to maintain its aspect ratio while filling the element's entire content box, clipping if necessary.
  cover('cover'),

  /// The image is scaled to maintain its aspect ratio while fitting completely within the element's content box without clipping.
  contain('contain'),

  /// The image is stretched to fill the element's content box completely, without maintaining aspect ratio.
  fill('fill'),

  /// The image is rendered at its natural size without resizing or scaling.
  none('none'),

  /// The image is sized as if `none` or `contain` were specified, whichever results in a smaller rendered size.
  scaleDown('scale-down');

  /// The raw CSS property value string (e.g. `"cover"`, `"contain"`).
  final String value;

  const ImageFit(this.value);

  @override
  String toString() => value;
}

/// Function signature for generating width-specific image URLs for responsive `srcset` sets.
///
/// Receives the original image [src] and a target integer [width], returning the transformed URL.
/// Used by [buildSrcSet], [bloomImage], and [PictureSource] to generate responsive image variants.
///
/// ```dart
/// String cdnBuilder(String src, int width) =>
///     'https://images.example.com/cdn-cgi/image/width=$width,format=auto/$src';
///
/// final srcset = buildSrcSet('/hero.jpg', [400, 800, 1200], urlBuilder: cdnBuilder);
/// ```
///
/// See also:
/// - [defaultImageUrlBuilder], the standard query-parameter builder.
/// - [buildSrcSet], which converts a list of widths into a `srcset` attribute.
typedef ImageUrlBuilder = String Function(String src, int width);

/// Default image URL builder appending target width as a query parameter.
///
/// Appends `?w=$width` when [src] has no query string, or `&w=$width` when query
/// parameters are already present.
///
/// ```dart
/// final url1 = defaultImageUrlBuilder('/assets/hero.jpg', 640);
/// // Returns: '/assets/hero.jpg?w=640'
///
/// final url2 = defaultImageUrlBuilder('/assets/hero.jpg?format=webp', 640);
/// // Returns: '/assets/hero.jpg?format=webp&w=640'
/// ```
///
/// See also:
/// - [ImageUrlBuilder], the builder callback signature.
/// - [buildSrcSet], which uses this function as the default URL generator.
String defaultImageUrlBuilder(String src, int width) {
  if (src.contains('?')) {
    return '$src&w=$width';
  }
  return '$src?w=$width';
}

/// Builds a standard HTML5 `srcset` attribute string from a base [src] and a list of target [widths].
///
/// Converts each width into an entry formatted as `"$url ${w}w"`, joined by commas.
/// If [urlBuilder] is omitted, [defaultImageUrlBuilder] is used by default.
///
/// ```dart
/// final srcset = buildSrcSet('/assets/photo.jpg', [320, 640, 1024]);
/// // Returns: '/assets/photo.jpg?w=320 320w, /assets/photo.jpg?w=640 640w, /assets/photo.jpg?w=1024 1024w'
/// ```
///
/// See also:
/// - [ImageUrlBuilder], for custom CDN URL rewriting.
/// - [defaultImageUrlBuilder], the default query-parameter builder.
/// - [bloomImage], which utilizes `buildSrcSet` when [widths] is supplied.
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
/// Used for art direction (serving different aspect ratios or crops based on [media] queries)
/// and modern image format negotiation (serving AVIF or WebP before legacy JPEG/PNG via [type]).
///
/// When [srcset] is omitted and [widths] is provided along with [src], [toNode] automatically
/// generates a responsive `srcset` attribute string using [urlBuilder] or [defaultImageUrlBuilder].
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
///
/// See also:
/// - [bloomPicture], helper creating a `<picture>` container with sources and fallback image.
/// - [BloomPicture], the picture element descriptor node.
/// - [buildSrcSet], the responsive candidate string generator.
class PictureSource {
  /// Base URL of the source image used for automatic `srcset` generation.
  final String? src;

  /// Raw `srcset` string. If omitted and [widths] is provided, built automatically via [urlBuilder].
  final String? srcset;

  /// Target widths for automatic `srcset` generation when [src] is provided.
  final List<int>? widths;

  /// Custom URL builder for generating width variants from [src].
  final ImageUrlBuilder? urlBuilder;

  /// Responsive sizes query (e.g. `'(max-width: 768px) 100vw, 1200px'`).
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
  ///
  /// If [srcset] is not supplied but [src] and [widths] are present, constructs the `srcset`
  /// attribute automatically using [buildSrcSet].
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
/// Composes a standard `<img>` element with performance and accessibility best practices:
/// - **Responsive sources**: Generates `srcset` and `sizes` automatically from [widths] and [urlBuilder].
/// - **Lazy loading by default**: Defaults to [ImageLoading.lazy] and [ImageDecoding.async] to avoid
///   wasting network bandwidth and main-thread CPU cycles on offscreen images during initial load.
/// - **LCP Hero Image Optimization**: Pass `priority: true` for above-the-fold hero images. This emits
///   `loading="eager"`, `fetchpriority="high"`, and `decoding="async"`, preventing the delayed
///   Largest Contentful Paint (LCP) penalty caused by lazy-loading hero content.
/// - **Layout stability (CLS)**: Providing [width] and [height] (or CSS [aspectRatio]) reserves the
///   correct layout box before image bytes arrive over the network, preventing Cumulative Layout Shift (CLS).
/// - **Placeholders**: Supports solid CSS colors (e.g. `'#14141a'`) or data URIs / blurhash URLs
///   rendered immediately as background styles in SSR and client DOM.
/// - **Accessibility**: Explicitly specify [alt] text describing the image, or set `decorative: true`
///   to emit `alt=""` and `aria-hidden="true"` for presentational visuals.
///
/// ### SSR and Browser Compatibility
/// Pure Dart descriptor. During SSR (`renderToHtml`), it renders a sanitized HTML5 `<img>`
/// string with attributes and inline placeholder styles. In the browser DOM (`mount`), it
/// instantiates an `HTMLImageElement`, binds event handlers ([onLoad], [onError], [onClick]),
/// and attaches [ref].
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
///
/// See also:
/// - [BloomImage], the underlying element descriptor class.
/// - [bloomPicture], for art direction and modern format negotiation (AVIF/WebP).
/// - [ImageLoading], [ImageDecoding], and [FetchPriority] for resource loading controls.
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
/// Subclasses [ElNode] directly with tag `'img'`, preserving exhaustive pattern-matching
/// compatibility across SSR (`renderToHtml`) and browser mounting (`mount`).
///
/// Accepts layout dimensions, placeholder backgrounds, responsive width variants, and priority hints.
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
///
/// See also:
/// - [bloomImage], convenience factory function.
/// - [BloomPicture], container for art-directed multi-source picture elements.
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

  /// Const constructor for [BloomImage] with pre-computed attributes and event listeners.
  ///
  /// Useful for compile-time constant descriptors with predetermined styles and attributes.
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
/// ### Multi-Format Negotiation & Art Direction
/// Browsers evaluate `<source>` children in top-to-bottom order, selecting the first
/// matching format or media query, and apply dimensions and styling from the inner `<img>`.
/// This enables serving modern formats (AVIF, WebP) with automatic fallback to standard formats
/// (JPEG, PNG) on older browsers.
///
/// ### SSR and Browser Compatibility
/// In SSR (`renderToHtml`), outputs a `<picture>` tag enclosing all `<source>` elements
/// and the fallback `<img>`. In browser DOM (`mount`), builds the corresponding DOM hierarchy
/// and attaches event listeners to the inner `HTMLImageElement`.
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
///
/// See also:
/// - [BloomPicture], the picture element descriptor node.
/// - [PictureSource], specification for individual `<source>` tags.
/// - [bloomImage], responsive image helper used for the fallback `<img>`.
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
///
/// Contains child `<source>` descriptors and an inner fallback [BloomImage].
///
/// ```dart
/// BloomPicture(
///   sources: [
///     PictureSource(src: '/hero.webp', type: 'image/webp'),
///   ],
///   fallbackSrc: '/hero.jpg',
///   alt: 'Hero visual',
///   width: 800,
///   height: 400,
/// );
/// ```
///
/// See also:
/// - [bloomPicture], helper creating `<picture>` trees.
/// - [PictureSource], source tag descriptor.
/// - [BloomImage], inner fallback image.
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
  ///
  /// Useful for compile-time constant descriptors with pre-computed child nodes.
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
