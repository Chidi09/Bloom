// lib/src/lazy.dart
//
// Lazy component loading, analogous to React's `React.lazy()` +
// `<Suspense>`. Built as thin sugar over the framework's existing
// `SuspenseNode`/`Suspense` — no new rendering machinery is needed since
// SSR and browser mount already handle async resource nodes.
//
// The actual JS code-splitting boundary is Dart's own `deferred as` library
// import mechanism (dart2js/dartdevc compile each deferred library to its
// own loadable chunk). This file does not — and cannot — create that
// boundary generically; callers create it themselves at the import site:
//
//   import 'heavy_page.dart' deferred as heavy_page;
//
//   BloomNode heavyRoute() => lazy(
//         () async {
//           await heavy_page.loadLibrary();
//           return heavy_page.HeavyPage();
//         },
//         fallback: const Div(text: 'Loading…'),
//       );
//
// `lazy()` itself works with any `Future<BloomNode> Function()` loader —
// including one that never uses `deferred as` (useful in tests, or for
// components that are merely expensive to *construct*, not to *load*).
import 'framework.dart';

/// Wraps an async component [loader], caching its result so the component
/// is loaded at most once even across multiple renders/re-subscriptions.
class BloomLazyComponent {
  final Future<BloomNode> Function() loader;
  Future<BloomNode>? _cached;

  BloomLazyComponent(this.loader);

  /// Returns the cached load [Future], invoking [loader] on first call only.
  Future<BloomNode> load() => _cached ??= loader();

  /// Resets the cache, forcing the next [load] call to invoke [loader] again.
  void reset() {
    _cached = null;
  }
}

/// Creates a lazily-loaded [BloomNode]. Renders [fallback] until [loader]
/// resolves, then renders the loaded node — implemented as a [Suspense]
/// over a cached [BloomLazyComponent].
///
/// Calling [lazy] itself does not start loading; loading begins the first
/// time the returned node is rendered (SSR) or mounted (browser), matching
/// `SuspenseNode`'s existing resource-triggering semantics.
BloomNode lazy(
  Future<BloomNode> Function() loader, {
  required BloomNode fallback,
}) {
  final component = BloomLazyComponent(loader);
  return Suspense<BloomNode>(
    resource: component.load,
    builder: (node) => node,
    fallback: fallback,
  );
}
