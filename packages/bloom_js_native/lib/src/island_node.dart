// lib/src/island_node.dart
//
// Pure-Dart half of the islands feature: the attribute contract, the
// hydration strategies, and the descriptor a SERVER renders to emit an
// island placeholder. This file must stay free of package:web so that
// server-side rendering can import it; the browser-side orchestrator
// that consumes these placeholders lives in islands.dart.

import 'dart:convert';

import 'framework.dart';


// ─── DOM Attribute Constants ────────────────────────────────────────────────

/// DOM attribute name used to identify an island placeholder and specify its registered name.
///
/// Placeholder elements carrying this attribute (e.g. `data-bloom-island="shopping-cart"`)
/// are discovered by [BloomIslandOrchestrator.scan] and hydrated on demand.
///
/// ```dart
/// Div(
///   attrs: {bloomIslandAttribute: 'user-profile'},
///   children: [/* static SSR fallback */],
/// )
/// ```
const String bloomIslandAttribute = 'data-bloom-island';

/// DOM attribute name specifying the [HydrationStrategy] for an island placeholder.
///
/// Accepted values match [HydrationStrategy.value] (e.g. `'immediate'`, `'visible'`, `'idle'`,
/// `'interaction'`, `'media'`, `'never'`).
///
/// ```dart
/// Div(
///   attrs: {
///     bloomIslandAttribute: 'comments-section',
///     bloomStrategyAttribute: 'visible',
///   },
/// )
/// ```
const String bloomStrategyAttribute = 'data-bloom-strategy';

/// DOM attribute name containing JSON-encoded props passed to the island's [BloomIslandBuilder].
///
/// Supports raw JSON strings or URI-encoded JSON strings.
///
/// ```dart
/// Div(
///   attrs: {
///     bloomIslandAttribute: 'product-card',
///     bloomPropsAttribute: '{"id": 42, "discount": true}',
///   },
/// )
/// ```
const String bloomPropsAttribute = 'data-bloom-props';

/// DOM attribute name specifying the `rootMargin` CSS string for the [HydrationStrategy.visible] observer.
///
/// Controls how far outside the viewport the placeholder is before hydration begins.
/// Defaults to `'200px'` if omitted.
///
/// ```dart
/// Div(
///   attrs: {
///     bloomIslandAttribute: 'feed-item',
///     bloomStrategyAttribute: 'visible',
///     bloomRootMarginAttribute: '300px',
///   },
/// )
/// ```
const String bloomRootMarginAttribute = 'data-bloom-root-margin';

/// DOM attribute name specifying the CSS media query string for [HydrationStrategy.media].
///
/// The island hydrates only when `window.matchMedia(query).matches` evaluates to `true`.
///
/// ```dart
/// Div(
///   attrs: {
///     bloomIslandAttribute: 'desktop-navigation',
///     bloomStrategyAttribute: 'media',
///     bloomMediaAttribute: '(min-width: 1024px)',
///   },
/// )
/// ```
const String bloomMediaAttribute = 'data-bloom-media';

/// DOM attribute name added to an island placeholder element once hydration is complete.
///
/// Prevents redundant hydration passes and indicates active client-side reactivity.
///
/// ```dart
/// // Set to 'true' upon successful hydration:
/// // <div data-bloom-island="menu" data-bloom-hydrated="true">...</div>
/// ```
const String bloomHydratedAttribute = 'data-bloom-hydrated';

// ─── Enums & Types ───────────────────────────────────────────────────────────

/// Hydration trigger strategies for Bloom islands.
///
/// Defines the policy and trigger condition determining when a server-rendered island placeholder
/// is hydrated into an active, interactive DOM subtree.
///
/// ```dart
/// BloomIsland(
///   name: 'image-gallery',
///   strategy: HydrationStrategy.visible,
///   child: const Div(text: 'Loading gallery...'),
/// )
/// ```
enum HydrationStrategy {
  /// Hydrates immediately when the document is scanned by [BloomIslandOrchestrator].
  ///
  /// Best for above-the-fold critical UI elements such as primary navigation or alert banners.
  immediate('immediate'),

  /// Hydrates when the placeholder element enters or approaches the browser viewport.
  ///
  /// Uses a high-performance `IntersectionObserver` with a configurable root margin
  /// (specified via [bloomRootMarginAttribute] or [BloomIslandOrchestrator.defaultRootMargin]).
  /// Ideal for below-the-fold widgets, comment sections, and content feeds.
  visible('visible'),

  /// Hydrates when the browser main thread is idle using `requestIdleCallback`.
  ///
  /// Falls back gracefully to a delayed timer in environments where `requestIdleCallback`
  /// is unavailable. Ideal for secondary interactive elements (e.g. analytics panels, footer widgets).
  idle('idle'),

  /// Hydrates upon the first user interaction targeting the placeholder element.
  ///
  /// Listens for `pointerenter`, `pointerdown`, `focusin`, `keydown`, and `touchstart` events.
  /// Once triggered, removes all event listeners and performs in-place hydration.
  /// Ideal for menus, search bars, and dropdown dialogs.
  interaction('interaction'),

  /// Hydrates only when a CSS media query matches (e.g. desktop-only sidebars or mobile-only drawers).
  ///
  /// Evaluates `window.matchMedia` with the query configured in [bloomMediaAttribute].
  /// If the query does not match initially, observes media changes and hydrates as soon as it matches.
  media('media'),

  /// Never hydrates automatically; the server-rendered HTML markup remains purely static.
  ///
  /// Useful for conditionally rendering interactive components as static content on pages
  /// where client JavaScript is not required.
  never('never');

  /// The raw serialized string value corresponding to this strategy.
  final String value;

  const HydrationStrategy(this.value);

  /// Parses a strategy name string into a [HydrationStrategy], supporting common aliases.
  ///
  /// Maps `'load'` or `'eager'` to [immediate], `'intersect'` or `'lazy'` to [visible],
  /// `'defer'` to [idle], and `'event'` or `'interact'` to [interaction].
  /// Returns [defaultStrategy] (defaulting to [immediate]) if [value] is null or unrecognized.
  ///
  /// ```dart
  /// final strategy = HydrationStrategy.parse('visible'); // HydrationStrategy.visible
  /// ```
  static HydrationStrategy parse(
    String? value, {
    HydrationStrategy defaultStrategy = HydrationStrategy.immediate,
  }) {
    if (value == null || value.trim().isEmpty) return defaultStrategy;
    return switch (value.toLowerCase().trim()) {
      'immediate' || 'load' || 'eager' => HydrationStrategy.immediate,
      'visible' || 'intersect' || 'lazy' => HydrationStrategy.visible,
      'idle' || 'defer' => HydrationStrategy.idle,
      'interaction' || 'event' || 'interact' => HydrationStrategy.interaction,
      'media' || 'query' => HydrationStrategy.media,
      'never' || 'static' || 'none' => HydrationStrategy.never,
      _ => defaultStrategy,
    };
  }

  @override
  String toString() => value;
}

// ─── Server-Side Descriptor Wrapper ─────────────────────────────────────────

/// Emits a server-rendered island placeholder element configured with the given hydration strategy and props.
///
/// Wraps [child] (or [children]) inside an element tagged with [bloomIslandAttribute] matching [name].
/// During server-side rendering (`renderToHtml`), the static HTML markup of [child] is emitted into the stream
/// alongside serialized [props] and strategy metadata. In the browser, [BloomIslandOrchestrator] discovers
/// the placeholder and hydrates the interactive subtree in place.
///
/// ### Example
///
/// **Server-Side SSR Rendering**:
/// ```dart
/// BloomIsland(
///   name: 'counter',
///   strategy: HydrationStrategy.visible,
///   props: {'initialCount': 5},
///   child: Div(
///     className: 'counter-box',
///     children: [
///       const Span(text: 'Count: 5'),
///       Button(text: '+1'),
///     ],
///   ),
/// )
/// ```
///
/// **Client-Side Registration & Hydration**:
/// ```dart
/// registerIsland('counter', (props) {
///   final count = signal(props['initialCount'] as int? ?? 0);
///   return Div(
///     className: 'counter-box',
///     children: [
///       Live(() => Span(text: 'Count: ${count.value}')),
///       Button(text: '+1', on: {'click': (_) => count.value++}),
///     ],
///   );
/// });
///
/// void main() {
///   orchestrateIslands();
/// }
/// ```
class BloomIsland extends ElNode {
  /// Creates a server-side island placeholder descriptor.
  BloomIsland({
    required String name,
    BloomNode? child,
    List<BloomNode>? children,
    HydrationStrategy strategy = HydrationStrategy.immediate,
    Map<String, dynamic>? props,
    String? rootMargin,
    String? media,
    String tag = 'div',
    String? className,
    String? style,
    Map<String, String>? attrs,
  }) : super(
          tag,
          className: className,
          style: style,
          attrs: {
            if (attrs != null) ...attrs,
            bloomIslandAttribute: name,
            if (strategy != HydrationStrategy.immediate)
              bloomStrategyAttribute: strategy.value,
            if (props != null && props.isNotEmpty)
              bloomPropsAttribute: jsonEncode(props),
            if (rootMargin != null)
              bloomRootMarginAttribute: rootMargin,
            if (media != null)
              bloomMediaAttribute: media,
          },
          children: [
            if (child != null) child,
            if (children != null) ...children,
          ],
        );
}

/// Helper function to construct a [BloomIsland] placeholder descriptor.
///
/// Convenience functional DSL alternative to `BloomIsland(...)`.
///
/// ```dart
/// final node = bloomIsland(
///   name: 'user-badge',
///   props: {'name': 'Alice'},
///   child: Span(text: 'Alice'),
/// );
/// ```
BloomIsland bloomIsland({
  required String name,
  BloomNode? child,
  List<BloomNode>? children,
  HydrationStrategy strategy = HydrationStrategy.immediate,
  Map<String, dynamic>? props,
  String? rootMargin,
  String? media,
  String tag = 'div',
  String? className,
  String? style,
  Map<String, String>? attrs,
}) =>
    BloomIsland(
      name: name,
      child: child,
      children: children,
      strategy: strategy,
      props: props,
      rootMargin: rootMargin,
      media: media,
      tag: tag,
      className: className,
      style: style,
      attrs: attrs,
    );
