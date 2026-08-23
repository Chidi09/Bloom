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

/// Caches an asynchronous component [loader], ensuring the loader executes at most once across renders.
///
/// Wraps an async component factory `Future<BloomNode> Function()` and memoizes its resulting
/// `Future`. Subsequent calls to [load] return the cached future immediately without repeating
/// network operations or deferred chunk downloads. To discard the cached result and force a reload,
/// call [reset].
///
/// ```dart
/// final lazySettings = BloomLazyComponent(() async {
///   return const Div(
///     className: 'settings-panel',
///     text: 'Account Settings',
///   );
/// });
/// final node = await lazySettings.load();
/// ```
class BloomLazyComponent {
  /// The asynchronous component factory that produces the [BloomNode].
  final Future<BloomNode> Function() loader;
  Future<BloomNode>? _cached;

  /// Creates a [BloomLazyComponent] wrapping the provided asynchronous [loader].
  BloomLazyComponent(this.loader);

  /// Returns the cached load [Future], invoking [loader] on the first call only.
  Future<BloomNode> load() => _cached ??= loader();

  /// Clears the cached [Future], forcing the next [load] call to re-execute [loader].
  void reset() {
    _cached = null;
  }
}

/// Creates a lazily loaded [BloomNode] descriptor that displays [fallback] until [loader] resolves.
///
/// Under the hood, this wraps [loader] in a [BloomLazyComponent] and returns a [Suspense] node.
/// Calling [lazy] itself does not initiate loading; loading starts automatically when the node is
/// mounted into the browser DOM or evaluated during streaming SSR ([renderToStreamWithSuspense]).
///
/// In browser applications, combine [lazy] with Dart's `deferred as` imports to split heavy
/// feature bundles into separate JavaScript chunks that load on demand.
///
/// ```dart
/// // Top-level deferred import:
/// // import 'editor_view.dart' deferred as editor;
///
/// BloomNode lazyEditor() => lazy(
///   () async {
///     // await editor.loadLibrary();
///     // return editor.EditorView();
///     return const Div(className: 'editor', text: 'Editor Ready');
///   },
///   fallback: const Div(
///     className: 'skeleton-placeholder',
///     text: 'Loading editor...',
///   ),
/// );
/// ```
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

