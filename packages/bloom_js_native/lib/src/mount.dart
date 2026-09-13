import 'dart:async';
import 'dart:js_interop';

import 'package:signals_core/signals_core.dart';
import 'package:web/web.dart' as web;

import 'dev_error_overlay.dart';
import 'devtools.dart';
import 'events.dart';
import 'framework.dart';
import 'hydration_contract.dart';

/// When `true`, uncaught errors thrown while mounting or rendering a tree display
/// a full-screen visual error overlay ([renderDevErrorOverlay]) in the browser DOM
/// instead of propagating and throwing.
///
/// Intended to be enabled in development environments (e.g. by `bloom js dev` or dev
/// bootstrap scripts) to provide immediate in-browser diagnostics. Defaults to `false`
/// in production builds.
///
/// ```dart
/// void main() {
///   bloomDevErrorOverlayEnabled = true;
///   mount(App(), '#app');
/// }
/// ```
bool bloomDevErrorOverlayEnabled = false;

/// When `true`, active mounted applications ([BloomMountHandle]) are tracked to enable
/// clean in-page teardown and remounting during hot reload development cycles.
///
/// Intended to be enabled in development environments (e.g. by `bloom js dev --experimental-ddc`
/// or dev bootstrap scripts) to support fast in-page hot remounting without full page navigation.
/// Defaults to `false` in production builds.
///
/// ```dart
/// void main() {
///   bloomHotReloadTrackingEnabled = true;
///   mount(App(), '#app');
/// }
/// ```
bool bloomHotReloadTrackingEnabled = false;

/// Tracks the most recently mounted application handle during development hot-reload sessions.
BloomMountHandle? _activeDevMountHandle;

/// Determines whether hot-reload active-mount tracking is currently active.
///
/// Returns `true` if [bloomHotReloadTrackingEnabled] was explicitly set in Dart or if the
/// DDC dev bootstrap script injected the `window.__BLOOM_DDC_HOT_REMOUNT__` marker.
bool isHotReloadTrackingActive() {
  if (bloomHotReloadTrackingEnabled) return true;
  try {
    final win = web.window as JSAny;
    return _jsGetBool(win, '__BLOOM_DDC_HOT_REMOUNT__') ?? false;
  } catch (_) {
    return false;
  }
}

bool _isHotReloadTrackingActive() => isHotReloadTrackingActive();

/// Bridges teardown and error reporting hooks onto `window` for dev bootstrap scripts.
void _installHotReloadHooks() {
  try {
    final win = web.window as JSAny;
    _reflectSet(
      win,
      '__bloomDisposeActiveMount',
      (() {
        bloomDisposeActiveMount();
      }).toJS,
    );
    _reflectSet(
      win,
      '__bloomReportUnhandledError',
      ((JSString? msg, JSString? stack) {
        final message = msg?.toDart ?? 'Unknown error';
        final stackTrace = stack?.toDart ?? '';
        _reportUnhandledError(message, StackTrace.fromString(stackTrace));
      }).toJS,
    );
  } catch (_) {}
}

/// Disposes the currently active mounted application tracked by development hot reload,
/// tearing down its DOM elements, disposing all reactive signal effects, and clearing
/// the active mount handle reference.
///
/// Called automatically by the browser dev bootstrap script during DDC hot remount cycles.
void bloomDisposeActiveMount() {
  if (_activeDevMountHandle != null && !_activeDevMountHandle!.isDisposed) {
    try {
      _activeDevMountHandle!.dispose();
    } catch (_) {}
  }
  _activeDevMountHandle = null;
}

/// Optional Content-Security-Policy (CSP) nonce applied to `<style>` elements
/// created and injected by the framework.
///
/// When non-null, every `<style>` element injected into `document.head` (such as
/// [StyleNode] stylesheets or [AnimatedNode] `@keyframes` rules) receives a
/// `nonce="$bloomStyleNonce"` attribute. Defaults to `null`.
///
/// ```dart
/// void main() {
///   bloomStyleNonce = 'rAnd0mN0nc3';
///   mount(App(), '#app');
/// }
/// ```
String? bloomStyleNonce;

/// Tracks animation names whose `@keyframes` `<style>` element has already
/// been injected into `document.head` for the lifetime of this page.
final Set<String> _injectedAnimationNames = {};

/// Key used in Zone values to propagate the current ambient [_ErrorBoundaryHandler].
final Object _errorBoundaryZoneKey = Object();

/// Reports an unhandled error to DevTools and optionally renders the dev error overlay.
void _reportUnhandledError(Object error, StackTrace stackTrace) {
  BloomJsDevTools.notify('mount-error', {
    'error': error.toString(),
    'stackTrace': stackTrace.toString(),
  });
  if (bloomDevErrorOverlayEnabled || _isHotReloadTrackingActive()) {
    final overlayHost = web.document.createElement('div');
    overlayHost.innerHTML = renderDevErrorOverlay(error, stackTrace).toJS;
    (web.document.body ?? web.document.documentElement)?.appendChild(overlayHost);
  }
}

/// Handler for the nearest enclosing ErrorBoundary in scope.
class _ErrorBoundaryHandler {
  final _Sentinel sentinel;
  final _Region inner;
  final BloomNode Function(Object error, StackTrace stackTrace) fallback;
  final _ErrorBoundaryHandler? parentBoundary;
  bool isFailed = false;

  _ErrorBoundaryHandler({
    required this.sentinel,
    required this.inner,
    required this.fallback,
    this.parentBoundary,
  });

  void handleError(Object error, StackTrace stackTrace) {
    if (isFailed) {
      if (parentBoundary != null) {
        parentBoundary!.handleError(error, stackTrace);
      } else {
        _reportUnhandledError(error, stackTrace);
      }
      return;
    }
    isFailed = true;

    inner.reset();
    sentinel.clear();

    try {
      final fallbackNode = fallback(error, stackTrace);
      final fallbackNodes = runZoned(
        () => _mountNode(fallbackNode, inner),
        zoneValues: {_errorBoundaryZoneKey: parentBoundary},
      );
      sentinel.appendAll(fallbackNodes);
    } catch (fallbackErr, fallbackStack) {
      inner.reset();
      sentinel.clear();
      if (parentBoundary != null) {
        parentBoundary!.handleError(fallbackErr, fallbackStack);
      } else {
        _reportUnhandledError(fallbackErr, fallbackStack);
      }
    }
  }
}

// ── Public API ──────────────────────────────────────────────────────────

/// Handle representing an active Bloom application mounted in the browser DOM.
///
/// Returned by [mount], [mountToElement], [hydrate], and [hydrateElement].
/// The caller owns this handle and is responsible for calling [unmount] or [dispose]
/// when the mounted subtree is no longer needed (e.g. during page unload or route change).
///
/// Disposing the handle detaches all child DOM elements from the host container, cancels
/// all reactive signals effects and listeners created during mount, and marks [isDisposed]
/// as `true`.
///
/// ```dart
/// final handle = mount(App(), '#app');
///
/// // Later, when tearing down:
/// handle.unmount();
/// ```
class BloomMountHandle {
  final web.Element _root;
  final List<void Function()> _disposers;
  bool _disposed = false;

  /// Creates a [BloomMountHandle] for [_root] holding the given [_disposers] cleanup functions.
  BloomMountHandle(this._root, this._disposers);

  /// Removes all child DOM elements from the host container and disposes all reactive effects.
  ///
  /// Convenience alias for [dispose].
  void unmount() => dispose();

  /// Disposes all reactive effects and empties the container DOM element (`root.textContent = ''`).
  ///
  /// Safe to call multiple times; subsequent calls on a disposed handle are no-ops.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final d in _disposers) {
      try {
        d();
      } catch (_) {}
    }
    _disposers.clear();
    _root.textContent = '';
  }

  /// Whether this handle has already been disposed.
  bool get isDisposed => _disposed;
}

/// Mounts a [BloomNode] descriptor tree into the DOM element matching [selector].
///
/// Looks up the host element via `web.document.querySelector(selector)` and delegates
/// to [mountToElement]. Throws a [StateError] if [selector] matches no element in the document.
///
/// The caller owns the returned [BloomMountHandle] and should call [BloomMountHandle.unmount]
/// when the application is detached.
///
/// ```dart
/// void main() {
///   final handle = mount(
///     Div(
///       className: 'container',
///       children: [
///         const H1(text: 'Bloom Web App'),
///         Live(() => P(text: 'Current count: ${count.value}')),
///       ],
///     ),
///     '#app',
///   );
/// }
/// ```
BloomMountHandle mount(BloomNode node, String selector) {
  final root = web.document.querySelector(selector);
  if (root == null) {
    throw StateError('Bloom mount: selector "$selector" matched no element.');
  }
  return mountToElement(node, root);
}

/// Mounts a [BloomNode] descriptor tree directly into the provided DOM [root] element.
///
/// Instantiates real DOM elements, sets up event handlers, and establishes reactive
/// signal subscriptions managed by an internal cleanup scope (`_Region`). Appends the
/// resulting DOM nodes to [root].
///
/// Returns a [BloomMountHandle] holding cleanup disposers. If mounting fails with an
/// uncaught exception and [bloomDevErrorOverlayEnabled] is active, renders an in-browser
/// error overlay into [root].
///
/// ```dart
/// final container = web.document.getElementById('my-widget')!;
/// final handle = mountToElement(
///   Button(
///     text: 'Click Me',
///     on: {'click': (e) => print('Clicked')},
///   ),
///   container,
/// );
/// ```
BloomMountHandle mountToElement(BloomNode node, web.Element root) {
  final region = _Region();
  try {
    final domNodes = _mountNode(node, region);
    for (final n in domNodes) {
      root.appendChild(n);
    }
    final handle = BloomMountHandle(root, region.disposers.toList());
    if (_isHotReloadTrackingActive()) {
      _activeDevMountHandle = handle;
      _installHotReloadHooks();
    }
    return handle;
  } catch (error, stackTrace) {
    for (final d in region.disposers) {
      try {
        d();
      } catch (_) {}
    }
    BloomJsDevTools.notify('mount-error', {
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
    });
    if (bloomDevErrorOverlayEnabled || _isHotReloadTrackingActive()) {
      root.textContent = '';
      final overlayHost = web.document.createElement('div');
      overlayHost.innerHTML = renderDevErrorOverlay(error, stackTrace).toJS;
      root.appendChild(overlayHost);
      final handle = BloomMountHandle(root, []);
      if (_isHotReloadTrackingActive()) {
        _activeDevMountHandle = handle;
        _installHotReloadHooks();
      }
      return handle;
    }
    rethrow;
  }
}

/// Attaches a synthetic [BloomEvent] listener of the given [type] to DOM element [el].
///
/// Bridges native browser events into strongly typed [BloomEvent]s received by [handler].
/// Used internally by element mounting and exposed so that [hydrateElement] in `hydrate.dart`
/// can attach event handlers to pre-existing server-rendered DOM elements without duplicating
/// JS event-wrapping logic.
///
/// ```dart
/// final button = web.document.querySelector('button.submit')!;
/// attachBloomListener(button, 'click', (event) {
///   event.preventDefault();
///   print('Button clicked with type: ${event.type}');
/// });
/// ```
void attachBloomListener(web.Element el, String type, BloomEventHandler handler) =>
    _attachListener(el, type, handler);

// ── Internal mount helpers ────────────────────────────────────────────

/// A scoped set of disposers owned by one reactive boundary.
///
/// When a Live/Show/ForEach region re-renders, its previous child subtree's
/// effects are disposed first — otherwise nested reactive boundaries would
/// accumulate zombie signal subscriptions on every update (leak).
class _Region {
  final Set<void Function()> disposers = {};
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  _Region() {
    BloomJsDevTools.activeRegionCount++;
  }

  void add(void Function() d) {
    if (_isDisposed) return;
    disposers.add(d);
  }

  void disposeAll() {
    if (_isDisposed) return;
    _isDisposed = true;
    BloomJsDevTools.activeRegionCount =
        (BloomJsDevTools.activeRegionCount - 1).clamp(0, 10000000);
    for (final d in disposers) {
      try {
        d();
      } catch (_) {}
    }
    disposers.clear();
  }

  /// Tears down everything registered so far, same as [disposeAll], but
  /// leaves the region usable afterward: [isDisposed] stays `false` and
  /// [add] keeps accepting new disposers.
  ///
  /// Reactive rebuild sites (`Live`, `Show`, `ForEach`, `Suspense` error
  /// recovery, `ErrorBoundary` fallback mounting, `Memo`) reuse a single
  /// long-lived `_Region` across many renders and need to clear the
  /// *previous* render's registrations before mounting the next one. Calling
  /// [disposeAll] for that "soft reset" permanently marks the region
  /// disposed, so anything mounted into it afterward — including the very
  /// content this reset was clearing the way for — finds [isDisposed] true
  /// from the moment it exists. Async work (e.g. a `Suspense` `resource`
  /// future) that checks `region.isDisposed` before applying its result then
  /// silently no-ops forever, even though the region was never actually torn
  /// down. Use [reset] for this in-place-rebuild case and reserve
  /// [disposeAll] for genuine final teardown.
  void reset() {
    if (_isDisposed) return;
    for (final d in disposers) {
      try {
        d();
      } catch (_) {}
    }
    disposers.clear();
  }
}

/// Mount a single [BloomNode] and return the created DOM nodes.
/// Side-effect: registers disposers into [region] for reactive boundaries.
List<web.Node> _mountNode(
  BloomNode node,
  _Region region,
) {
  switch (node) {
    case TextNode(:final text):
      return [web.document.createTextNode(text)];

    case RawHtmlNode(:final html):
      // Trusted-HTML escape hatch. Never pass user input here.
      final host = web.document.createElement('span');
      host.innerHTML = html.toJS;
      return [host];

    case ElNode(:final tag, :final text, :final className, :final style, :final attrs, :final on, :final children):
      final el = web.document.createElement(tag);
      if (className != null) el.className = className;
      if (style != null) el.setAttribute('style', style);
      if (attrs != null) {
        for (final e in attrs.entries) {
          el.setAttribute(e.key, e.value);
        }
      }
      if (on != null) {
        for (final entry in on.entries) {
          _attachListener(el, entry.key, entry.value);
        }
      }
      if (text != null) {
        el.appendChild(web.document.createTextNode(text));
      }
      for (final child in children) {
        final childNodes = _mountNode(child, region);
        for (final cn in childNodes) {
          el.appendChild(cn);
        }
      }
      return [el];

    case FragmentNode(:final children):
      final out = <web.Node>[];
      for (final c in children) {
        out.addAll(_mountNode(c, region));
      }
      return out;

    case LiveNode(:final builder):
      final sentinel = _Sentinel('live');
      final initial = _bindSentinelRegion(sentinel, region, builder);
      return [sentinel.start, ...initial, sentinel.end];

    case MemoNode():
      final sentinel = _Sentinel('memo');
      final initial = _bindMemoRegion(
        sentinel,
        region,
        node.dependencyErased,
        node.builderErased,
      );
      return [sentinel.start, ...initial, sentinel.end];

    case ShowNode(:final child, :final fallback):
      final sentinel = _Sentinel('show');
      final initial = _bindSentinelRegion(
        sentinel,
        region,
        () => node.when() ? child : (fallback ?? FragmentNode(const [])),
      );
      return [sentinel.start, ...initial, sentinel.end];

    case ForEachNode():
      final sentinel = _Sentinel('foreach');
      List<web.Node> initial = const [];
      final keyFnErased = node.keyFnErased;
      if (keyFnErased != null) {
        initial = _bindKeyedForEachSentinel(
          sentinel,
          region,
          node.itemsErased,
          keyFnErased,
          node.builderErased,
        );
      } else {
        initial = _bindSentinelRegion<List<BloomNode>>(
          sentinel,
          region,
          () => node.buildChildren(),
          wrap: (children) => FragmentNode(children),
        );
      }
      return [sentinel.start, ...initial, sentinel.end];

    case StyleNode(:final css):
      final el = web.document.createElement('style');
      if (bloomStyleNonce != null) {
        el.setAttribute('nonce', bloomStyleNonce!);
      }
      el.textContent = css;
      return [el];

    case MountNode(:final child, :final onMount, :final onUnmount):
      final nodes = _mountNode(child, region);
      if (onMount != null) {
        Future.microtask(onMount);
      }
      if (onUnmount != null) {
        region.add(onUnmount);
      }
      return nodes;

    case RefNode(:final ref, :final child):
      final nodes = _mountNode(child, region);
      for (final n in nodes) {
        if (n.isA<web.Element>()) {
          ref.attach(n as web.Element);
          region.add(ref.detach);
          break;
        }
      }
      return nodes;

    case AnimatedNode(:final child, :final animation):
      if (_injectedAnimationNames.add(animation.name)) {
        final styleEl = web.document.createElement('style');
        if (bloomStyleNonce != null) {
          styleEl.setAttribute('nonce', bloomStyleNonce!);
        }
        styleEl.textContent = animation.toKeyframesCSS();
        web.document.head?.appendChild(styleEl);
      }
      final wrapper = web.document.createElement('div');
      wrapper.setAttribute('style', animation.toInlineStyle());
      final childNodes = _mountNode(child, region);
      for (final cn in childNodes) {
        wrapper.appendChild(cn);
      }
      return [wrapper];

    case ContextProviderNode(:final context, :final value, :final child):
      return runZoned(
        () => _mountNode(child, region),
        zoneValues: {context.zoneKey: value},
      );

    case ErrorBoundaryNode(:final builder, :final fallback):
      final sentinel = _Sentinel('error-boundary');
      final inner = _Region();
      final parentBoundary = Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;
      final handler = _ErrorBoundaryHandler(
        sentinel: sentinel,
        inner: inner,
        fallback: fallback,
        parentBoundary: parentBoundary,
      );
      List<web.Node> initial;
      try {
        final node = runZoned(
          builder,
          zoneValues: {_errorBoundaryZoneKey: handler},
        );
        initial = runZoned(
          () => _mountNode(node, inner),
          zoneValues: {_errorBoundaryZoneKey: handler},
        );
      } catch (err, stack) {
        handler.isFailed = true;
        inner.reset();
        try {
          final fallbackNode = fallback(err, stack);
          initial = runZoned(
            () => _mountNode(fallbackNode, inner),
            zoneValues: {_errorBoundaryZoneKey: parentBoundary},
          );
        } catch (fallbackErr, fallbackStack) {
          inner.reset();
          initial = const [];
          if (parentBoundary != null) {
            parentBoundary.handleError(fallbackErr, fallbackStack);
          } else {
            _reportUnhandledError(fallbackErr, fallbackStack);
          }
        }
      }
      region.add(inner.disposeAll);
      return [sentinel.start, ...initial, sentinel.end];

    case PortalNode(:final child, :final targetSelector):
      final targetEl = web.document.querySelector(targetSelector) ?? web.document.body!;
      final childNodes = _mountNode(child, region);
      for (final n in childNodes) {
        targetEl.appendChild(n);
        region.add(() => n.parentNode?.removeChild(n));
      }
      final comment = web.document.createComment(' portal:$targetSelector ');
      return [comment];

    case SuspenseNode(:final fallback, :final errorBuilder):
      final sentinel = _Sentinel('suspense');
      final inner = _Region();
      final boundary = Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;
      final fallbackNodes = _mountNode(fallback, inner);

      void handleSuspenseError(Object error, StackTrace stackTrace) {
        if (region.isDisposed) return;
        inner.reset();
        sentinel.clear();
        if (errorBuilder != null) {
          try {
            final errorNode = errorBuilder(error, stackTrace);
            final errorNodes = runZoned(
              () => _mountNode(errorNode, inner),
              zoneValues: {_errorBoundaryZoneKey: boundary},
            );
            sentinel.appendAll(errorNodes);
          } catch (ebErr, ebStack) {
            inner.reset();
            sentinel.clear();
            if (boundary != null) {
              boundary.handleError(ebErr, ebStack);
            } else {
              _reportUnhandledError(ebErr, ebStack);
            }
          }
        } else {
          if (boundary != null) {
            boundary.handleError(error, stackTrace);
          } else {
            _reportUnhandledError(error, stackTrace);
          }
        }
      }

      // Erased views: reading `resource`/`builder` straight off the pattern
      // match casts them to `Function(dynamic)`, which throws for any
      // `Suspense<T>` with a concrete `T`. See [SuspenseNode.builderErased].
      try {
        node.resourceErased().then((data) {
          if (!region.isDisposed) {
            try {
              inner.reset();
              sentinel.clear();
              final loadedNode = node.builderErased(data);
              final loadedNodes = runZoned(
                () => _mountNode(loadedNode, inner),
                zoneValues: {_errorBoundaryZoneKey: boundary},
              );
              sentinel.appendAll(loadedNodes);
            } catch (err, stack) {
              handleSuspenseError(err, stack);
            }
          }
        }, onError: (Object err, StackTrace stack) {
          handleSuspenseError(err, stack);
        });
      } catch (err, stack) {
        handleSuspenseError(err, stack);
      }

      region.add(inner.disposeAll);
      return [sentinel.start, ...fallbackNodes, sentinel.end];
  }
}

/// A pair of comment nodes that bracket a reactive DOM region.
/// Used instead of a wrapper `<span>` to avoid polluting CSS layout.
class _Sentinel {
  final web.Comment start;
  final web.Comment end;

  _Sentinel(String label)
      : start = web.document.createComment(' bloom:$label '),
        end = web.document.createComment(' /bloom:$label ');

  /// Adopts pre-existing SSR marker comments as this region's brackets.
  ///
  /// Used by hydration to attach reactive behavior to server-rendered DOM
  /// without discarding nodes. Marker matching is whitespace-insensitive, so
  /// SSR output (`<!--bloom:live-->`) and mount sentinels
  /// (`<!-- bloom:live -->`) adopt identically.
  _Sentinel.adopt(this.start, this.end);

  /// All child nodes between start and end (exclusive).
  List<web.Node> get childNodes {
    final result = <web.Node>[];
    var current = start.nextSibling;
    while (current != null && current != end) {
      result.add(current);
      current = current.nextSibling;
    }
    return result;
  }

  /// Remove all children between the sentinel comments.
  void clear() {
    for (final n in childNodes) {
      n.parentNode?.removeChild(n);
    }
  }

  /// Insert a list of nodes before the end sentinel.
  void appendAll(List<web.Node> nodes) {
    for (final n in nodes) {
      end.parentNode?.insertBefore(n, end);
    }
  }
}

/// Returns the index path from [roots] down to [target], or `null` if
/// [target] is not a descendant of (or one of) [roots]. Used by the focus
/// guard in [_bindSentinelRegion] to relocate a focused element's
/// equivalent position after a region rebuild.
List<int>? _pathToNode(List<web.Node> roots, web.Node target) {
  for (var i = 0; i < roots.length; i++) {
    final found = _searchPath(roots[i], target, [i]);
    if (found != null) return found;
  }
  return null;
}

List<int>? _searchPath(web.Node node, web.Node target, List<int> soFar) {
  if (identical(node, target)) return soFar;
  final children = node.childNodes;
  for (var i = 0; i < children.length; i++) {
    final found = _searchPath(children.item(i)!, target, [...soFar, i]);
    if (found != null) return found;
  }
  return null;
}

/// Inverse of [_pathToNode]: walks [path] down from [roots] to find the
/// node at the same structural position in a freshly rebuilt tree.
web.Node? _nodeAtPath(List<web.Node> roots, List<int> path) {
  if (path.isEmpty || path[0] >= roots.length) return null;
  web.Node current = roots[path[0]];
  for (var i = 1; i < path.length; i++) {
    final children = current.childNodes;
    if (path[i] >= children.length) return null;
    current = children.item(path[i])!;
  }
  return current;
}

(int, int)? _selectionRange(web.Element el) {
  try {
    if (el.isA<web.HTMLInputElement>()) {
      final input = el as web.HTMLInputElement;
      final s = input.selectionStart;
      final e = input.selectionEnd;
      if (s != null && e != null) return (s, e);
    } else if (el.isA<web.HTMLTextAreaElement>()) {
      final textarea = el as web.HTMLTextAreaElement;
      return (textarea.selectionStart, textarea.selectionEnd);
    }
  } catch (_) {}
  return null;
}

void _setSelectionRange(web.Element el, int start, int end) {
  try {
    if (el.isA<web.HTMLInputElement>()) {
      (el as web.HTMLInputElement).setSelectionRange(start, end);
    } else if (el.isA<web.HTMLTextAreaElement>()) {
      (el as web.HTMLTextAreaElement).setSelectionRange(start, end);
    }
  } catch (_) {}
}


/// Whether [n] is guaranteed to mount to exactly one DOM node.
///
/// Only these four descriptor kinds have a 1:1 descriptor-to-DOM-node
/// relationship (see the corresponding branches of [_mountNode]): text nodes,
/// elements, `<style>` blocks, and the raw-HTML `<span>` host. Everything else
/// either wraps its content in sentinel comments (the reactive nodes) or may
/// emit sibling nodes (e.g. [AnimatedNode] can emit a keyframes `<style>`
/// alongside its wrapper), so index-aligned child patching is unsound for them.
bool _isSingleNodeDescriptor(BloomNode n) =>
    n is TextNode || n is ElNode || n is StyleNode || n is RawHtmlNode;

/// Attempts to update [existingDom] in place to match [newDesc].
///
/// Returns `true` if the patch succeeded. Returns `false` if the two descriptors
/// are structurally incompatible, in which case [existingDom] is left untouched
/// and the caller must fall back to destroy-and-recreate.
bool _patchNode(
  web.Node existingDom,
  BloomNode oldDesc,
  BloomNode newDesc,
  _Region region,
) {
  if (identical(oldDesc, newDesc)) return true;

  if (oldDesc is TextNode && newDesc is TextNode) {
    if (existingDom.nodeType != web.Node.TEXT_NODE) return false;
    if (oldDesc.text != newDesc.text) {
      existingDom.textContent = newDesc.text;
    }
    return true;
  }

  if (oldDesc is StyleNode && newDesc is StyleNode) {
    if (!existingDom.isA<web.Element>()) return false;
    final el = existingDom as web.Element;
    if (el.tagName.toLowerCase() != 'style') return false;
    if (oldDesc.css != newDesc.css) {
      el.textContent = newDesc.css;
    }
    return true;
  }

  if (oldDesc is RawHtmlNode && newDesc is RawHtmlNode) {
    if (!existingDom.isA<web.Element>()) return false;
    final host = existingDom as web.Element;
    if (oldDesc.html != newDesc.html) {
      host.innerHTML = newDesc.html.toJS;
    }
    return true;
  }

  if (oldDesc is ElNode && newDesc is ElNode) {
    if (oldDesc.tag != newDesc.tag) return false;
    if (!existingDom.isA<web.Element>()) return false;
    final el = existingDom as web.Element;
    if (el.tagName.toLowerCase() != oldDesc.tag.toLowerCase()) return false;

    // Child patching below aligns descriptor index to child-DOM index 1:1. That
    // holds only while every child mounts to exactly one node. A reactive or
    // effectful child (Live/Show/ForEach/Suspense/...) mounts to a sentinel
    // comment pair wrapping its content — several DOM nodes for one descriptor
    // — so the indices desync and we would patch descriptors against unrelated
    // DOM, orphan the old region's nodes, and leak its effect. Bail out to the
    // caller's destroy-and-recreate path instead. Checked up front, before any
    // mutation, because returning false must leave `existingDom` untouched.
    for (final c in oldDesc.children) {
      if (!_isSingleNodeDescriptor(c)) return false;
    }
    for (final c in newDesc.children) {
      if (!_isSingleNodeDescriptor(c)) return false;
    }

    // className: if changed, set class attribute; if new is null, remove class
    if (oldDesc.className != newDesc.className) {
      if (newDesc.className != null) {
        el.className = newDesc.className!;
      } else {
        el.removeAttribute('class');
      }
    }

    // style: if changed, set style attribute; if null, remove it
    if (oldDesc.style != newDesc.style) {
      if (newDesc.style != null) {
        el.setAttribute('style', newDesc.style!);
      } else {
        el.removeAttribute('style');
      }
    }

    // attrs: set new/changed attrs, remove deleted attrs
    final oldAttrs = oldDesc.attrs ?? const <String, String>{};
    final newAttrs = newDesc.attrs ?? const <String, String>{};
    for (final key in oldAttrs.keys) {
      if (!newAttrs.containsKey(key)) {
        el.removeAttribute(key);
      }
    }
    for (final entry in newAttrs.entries) {
      if (!oldAttrs.containsKey(entry.key) || oldAttrs[entry.key] != entry.value) {
        el.setAttribute(entry.key, entry.value);
      }
    }

    // Event handlers: update new/changed handlers, remove deleted handlers
    final oldOn = oldDesc.on ?? const <String, BloomEventHandler>{};
    final newOn = newDesc.on ?? const <String, BloomEventHandler>{};
    for (final key in oldOn.keys) {
      if (!newOn.containsKey(key)) {
        _removeListener(el, key);
      }
    }
    for (final entry in newOn.entries) {
      _attachListener(el, entry.key, entry.value);
    }

    // Children & text sugar
    final oldChildren = <BloomNode>[
      if (oldDesc.text != null) TextNode(oldDesc.text!),
      ...oldDesc.children,
    ];
    final newChildren = <BloomNode>[
      if (newDesc.text != null) TextNode(newDesc.text!),
      ...newDesc.children,
    ];

    final domChildren = <web.Node>[];
    for (var i = 0; i < el.childNodes.length; i++) {
      domChildren.add(el.childNodes.item(i)!);
    }

    final commonLength = oldChildren.length < newChildren.length
        ? oldChildren.length
        : newChildren.length;

    for (var i = 0; i < commonLength; i++) {
      if (i < domChildren.length) {
        final existingChild = domChildren[i];
        final patched = _patchNode(
          existingChild,
          oldChildren[i],
          newChildren[i],
          region,
        );
        if (!patched) {
          final newMounted = _mountNode(newChildren[i], region);
          if (newMounted.isNotEmpty) {
            el.replaceChild(newMounted[0], existingChild);
            var prev = newMounted[0];
            for (var j = 1; j < newMounted.length; j++) {
              el.insertBefore(newMounted[j], prev.nextSibling);
              prev = newMounted[j];
            }
          } else {
            el.removeChild(existingChild);
          }
        }
      } else {
        final newMounted = _mountNode(newChildren[i], region);
        for (final n in newMounted) {
          el.appendChild(n);
        }
      }
    }

    if (newChildren.length < oldChildren.length) {
      for (var i = newChildren.length; i < domChildren.length; i++) {
        if (domChildren[i].parentNode == el) {
          el.removeChild(domChildren[i]);
        }
      }
    } else if (newChildren.length > oldChildren.length) {
      for (var i = oldChildren.length; i < newChildren.length; i++) {
        final extraNodes = _mountNode(newChildren[i], region);
        for (final n in extraNodes) {
          el.appendChild(n);
        }
      }
    }

    return true;
  }

  return false;
}

class _KeyedEntry {
  final String key;
  final List<web.Node> domNodes;
  final _Region region;
  BloomNode descriptor;

  _KeyedEntry({
    required this.key,
    required this.domNodes,
    required this.region,
    required this.descriptor,
  });
}

/// Keyed list reconciler state shared by fresh mounts and hydration.
///
/// [mountInitial] builds the first render's DOM. [reconcile] patches,
/// inserts, removes, and reorders on subsequent updates. Hydration fills
/// [activeEntries] from existing server-rendered DOM and then uses the same
/// [reconcile] for all later updates, so post-hydration reordering reuses
/// nodes exactly like a fresh mount.
class _KeyedListController {
  final _Sentinel sentinel;
  final Map<String, _KeyedEntry> activeEntries = {};
  final List<Object?> Function() itemsFn;
  final String Function(Object? item) keyFn;
  final BloomNode Function(Object? item) builderFn;
  final _ErrorBoundaryHandler? boundary;

  _KeyedListController({
    required this.sentinel,
    required this.itemsFn,
    required this.keyFn,
    required this.builderFn,
    required this.boundary,
  });

  /// Builds and returns the initial DOM nodes (fresh-mount path).
  List<web.Node> mountInitial() {
    final initialNodes = <web.Node>[];
    for (final item in itemsFn()) {
      final key = keyFn(item);
      final itemRegion = _Region();
      final descriptor = builderFn(item);
      final domNodes = runZoned(
        () => _mountNode(descriptor, itemRegion),
        zoneValues: {_errorBoundaryZoneKey: boundary},
      );
      final entry = _KeyedEntry(
        key: key,
        domNodes: domNodes,
        region: itemRegion,
        descriptor: descriptor,
      );
      activeEntries[key] = entry;
      initialNodes.addAll(domNodes);
    }
    return initialNodes;
  }

  /// Reconciles DOM against the current items (update path).
  void reconcile() {
    try {
      final items = itemsFn();
      final newKeys = <String>{};
      final newOrder = <_KeyedEntry>[];

      for (final item in items) {
        final key = keyFn(item);
        newKeys.add(key);

        if (activeEntries.containsKey(key)) {
          final existing = activeEntries[key]!;
          final descriptor = builderFn(item);

          var patched = false;
          if (existing.domNodes.length == 1) {
            patched = _patchNode(
              existing.domNodes.first,
              existing.descriptor,
              descriptor,
              existing.region,
            );
          }

          if (patched) {
            existing.descriptor = descriptor;
            newOrder.add(existing);
          } else {
            existing.region.disposeAll();
            final newDomNodes = runZoned(
              () => _mountNode(descriptor, existing.region),
              zoneValues: {_errorBoundaryZoneKey: boundary},
            );

            final parent = sentinel.end.parentNode;
            if (parent != null) {
              for (final n in existing.domNodes) {
                if (n.parentNode == parent) parent.removeChild(n);
              }
              for (final n in newDomNodes) {
                parent.insertBefore(n, sentinel.end);
              }
            }

            final updated = _KeyedEntry(
              key: key,
              domNodes: newDomNodes,
              region: existing.region,
              descriptor: descriptor,
            );
            activeEntries[key] = updated;
            newOrder.add(updated);
          }
        } else {
          final itemRegion = _Region();
          final descriptor = builderFn(item);
          final domNodes = runZoned(
            () => _mountNode(descriptor, itemRegion),
            zoneValues: {_errorBoundaryZoneKey: boundary},
          );
          final entry = _KeyedEntry(
            key: key,
            domNodes: domNodes,
            region: itemRegion,
            descriptor: descriptor,
          );
          activeEntries[key] = entry;
          newOrder.add(entry);
          final parent = sentinel.end.parentNode;
          if (parent != null) {
            for (final n in domNodes) {
              parent.insertBefore(n, sentinel.end);
            }
          }
        }
      }

      // Remove deleted keys & dispose their regions
      final toRemove = activeEntries.keys.where((k) => !newKeys.contains(k)).toList();
      for (final k in toRemove) {
        final entry = activeEntries.remove(k)!;
        entry.region.disposeAll();
        final parent = sentinel.end.parentNode;
        if (parent != null) {
          for (final n in entry.domNodes) {
            if (n.parentNode == parent) {
              parent.removeChild(n);
            }
          }
        }
      }

      // Reorder DOM nodes in container to match newOrder
      for (var i = 0; i < newOrder.length; i++) {
        final entry = newOrder[i];
        for (final n in entry.domNodes) {
          sentinel.end.parentNode?.insertBefore(n, sentinel.end);
        }
      }
    } catch (err, stack) {
      for (final entry in activeEntries.values) {
        entry.region.disposeAll();
      }
      activeEntries.clear();
      sentinel.clear();
      final errorBoundary = boundary;
      if (errorBoundary != null) {
        errorBoundary.handleError(err, stack);
      } else {
        _reportUnhandledError(err, stack);
      }
    }
  }

  /// Releases every per-item region and clears tracking state.
  void disposeAll() {
    for (final entry in activeEntries.values) {
      entry.region.disposeAll();
    }
    activeEntries.clear();
  }
}

/// Keyed list reconciler. Takes [ForEachNode]'s type-erased closure views
/// rather than the node itself — see the note on [ForEachNode.keyFnErased]
/// for why the raw generic fields cannot be read from this call site.
List<web.Node> _bindKeyedForEachSentinel(
  _Sentinel sentinel,
  _Region parentRegion,
  List<Object?> Function() itemsFn,
  String Function(Object? item) keyFn,
  BloomNode Function(Object? item) builderFn,
) {
  final boundary = Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;
  final controller = _KeyedListController(
    sentinel: sentinel,
    itemsFn: itemsFn,
    keyFn: keyFn,
    builderFn: builderFn,
    boundary: boundary,
  );
  // The effect's synchronous initial run happens while mounting is still
  // building bottom-up (sentinels not yet attached), so the initial build
  // runs inside it and hands its nodes back to the caller — exactly the
  // pre-refactor semantics: one builder evaluation per item, with the item
  // closures' signal reads tracked by this effect (a throw inside an item
  // builder on update still reaches the enclosing error boundary).
  var isFirstRun = true;
  var initialNodes = const <web.Node>[];
  final stop = effect(() {
    if (isFirstRun) {
      isFirstRun = false;
      initialNodes = controller.mountInitial();
      return;
    }
    controller.reconcile();
  });

  parentRegion.add(() {
    stop();
    controller.disposeAll();
  });

  return initialNodes;
}

/// Reactive memo region: re-evaluates [dependency] inside an effect and
/// only rebuilds / patches when the dependency value changes (`!=`).
List<web.Node> _bindMemoRegion(
  _Sentinel sentinel,
  _Region parentRegion,
  Object? Function() dependencyFn,
  BloomNode Function(Object? value) builderFn,
) {
  final inner = _Region();
  var isFirstRun = true;
  var hasPrevValue = false;
  Object? prevValue;
  BloomNode? prevDescriptor;
  List<web.Node> currentNodes = const [];
  List<web.Node> initialNodes = const [];
  final boundary = Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;

  void renderRegion() {
    try {
      final value = dependencyFn();
      if (!isFirstRun && hasPrevValue && prevValue == value) {
        return;
      }

      final newDescriptor = builderFn(value);

      if (!isFirstRun && prevDescriptor != null && currentNodes.length == 1) {
        final patched = _patchNode(
          currentNodes.first,
          prevDescriptor!,
          newDescriptor,
          inner,
        );
        if (patched) {
          prevDescriptor = newDescriptor;
          prevValue = value;
          hasPrevValue = true;
          return;
        }
      }

      inner.reset();
      final nodes = runZoned(
        () => _mountNode(newDescriptor, inner),
        zoneValues: {_errorBoundaryZoneKey: boundary},
      );
      if (isFirstRun) {
        initialNodes = nodes;
      } else {
        sentinel.clear();
        sentinel.appendAll(nodes);
      }
      currentNodes = nodes;
      prevDescriptor = newDescriptor;
      prevValue = value;
      hasPrevValue = true;
    } catch (err, stack) {
      inner.reset();
      if (isFirstRun) {
        rethrow;
      }
      sentinel.clear();
      if (boundary != null) {
        boundary.handleError(err, stack);
      } else {
        _reportUnhandledError(err, stack);
      }
    }
  }

  final stop = effect(() {
    renderRegion();
    isFirstRun = false;
  });

  parentRegion.add(() {
    stop();
    inner.disposeAll();
  });

  return initialNodes;
}

/// Shared sentinel reactive-region binding: re-renders between comments
/// whenever signals read inside [build] change.
List<web.Node> _bindSentinelRegion<T>(
  _Sentinel sentinel,
  _Region parentRegion,
  T Function() build, {
  BloomNode Function(T value)? wrap,
}) {
  final inner = _Region();
  var isFirstRun = true;
  List<web.Node> initialNodes = const [];
  final boundary = Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;

  void renderRegion() {
    try {
      // Framework-level focus guard: this region replaces its whole DOM
      // subtree on every rebuild (no diffing), so a form control that reads
      // its own bound signal for rendering — and is focused when that same
      // signal changes (typing into a controlled `<input>` is the common
      // case) — gets destroyed and recreated on every keystroke, silently
      // dropping focus. Capture the focused element's position (and text
      // selection) within this region before the old nodes are torn down,
      // then try to restore focus onto whatever sits at that same position
      // in the freshly rebuilt tree. This is a best-effort structural-path
      // match, not real reconciliation — if the shape of the rebuilt tree
      // has changed (a different element there now), it just no-ops.
      web.Element? focusedEl;
      List<int>? focusPath;
      int? selStart;
      int? selEnd;
      if (!isFirstRun) {
        final active = web.document.activeElement;
        if (active != null) {
          final path = _pathToNode(sentinel.childNodes, active);
          if (path != null) {
            focusedEl = active;
            focusPath = path;
            final range = _selectionRange(active);
            if (range != null) {
              selStart = range.$1;
              selEnd = range.$2;
            }
          }
        }
      }

      inner.reset();
      final value = build();
      final node = wrap == null ? value as BloomNode : wrap(value);
      final nodes = runZoned(
        () => _mountNode(node, inner),
        zoneValues: {_errorBoundaryZoneKey: boundary},
      );
      if (isFirstRun) {
        // The sentinel comments are not attached to the document yet on the
        // effect's synchronous initial run (mounting is still building the
        // node tree bottom-up), so appendAll's insertBefore(..., sentinel.end)
        // would silently no-op. Hand the initial nodes back to the caller to
        // splice in alongside the sentinel comments instead.
        initialNodes = nodes;
      } else {
        sentinel.clear();
        sentinel.appendAll(nodes);
        if (focusPath != null) {
          final replacement = _nodeAtPath(nodes, focusPath);
          if (replacement != null &&
              replacement.isA<web.HTMLElement>() &&
              (replacement as web.HTMLElement).tagName == focusedEl!.tagName) {
            replacement.focus();
            if (selStart != null && selEnd != null) {
              _setSelectionRange(replacement, selStart, selEnd);
            }
          }
        }
      }
    } catch (err, stack) {
      inner.reset();
      if (isFirstRun) {
        rethrow;
      }
      sentinel.clear();
      if (boundary != null) {
        boundary.handleError(err, stack);
      } else {
        _reportUnhandledError(err, stack);
      }
    }
  }

  final stop = effect(() {
    renderRegion();
    isFirstRun = false;
  });

  parentRegion.add(() {
    stop();
    inner.disposeAll();
  });

  return initialNodes;
}

const String _bloomHandlersProp = '__bloom_handlers__';

Map<String, BloomEventHandler?> _getOrCreateHandlersMap(web.Element el) {
  final jsEl = el as JSAny;
  final boxed = _reflectGet(jsEl, _bloomHandlersProp);
  if (boxed != null && boxed.isA<JSBoxedDartObject>()) {
    final dartObj = (boxed as JSBoxedDartObject).toDart;
    if (dartObj is Map<String, BloomEventHandler?>) {
      return dartObj;
    }
  }
  final map = <String, BloomEventHandler?>{};
  _reflectSet(jsEl, _bloomHandlersProp, map.toJSBox);
  return map;
}

Map<String, BloomEventHandler?>? _getHandlersMap(web.Element el) {
  final jsEl = el as JSAny;
  final boxed = _reflectGet(jsEl, _bloomHandlersProp);
  if (boxed != null && boxed.isA<JSBoxedDartObject>()) {
    final dartObj = (boxed as JSBoxedDartObject).toDart;
    if (dartObj is Map<String, BloomEventHandler?>) {
      return dartObj;
    }
  }
  return null;
}

void _attachListener(
  web.Element el,
  String type,
  BloomEventHandler handler,
) {
  final handlers = _getOrCreateHandlersMap(el);
  final alreadyAttached = handlers.containsKey(type);
  handlers[type] = handler;

  if (!alreadyAttached) {
    void listener(web.Event e) {
      final activeHandler = handlers[type];
      if (activeHandler != null) {
        final bloomEvent = _wrapEvent(type, e);
        activeHandler(bloomEvent);
        if (bloomEvent.defaultPrevented) e.preventDefault();
        if (bloomEvent.propagationStopped) e.stopPropagation();
      }
    }

    el.addEventListener(type, listener.toJS);
  }
}

void _removeListener(
  web.Element el,
  String type,
) {
  final handlers = _getHandlersMap(el);
  if (handlers != null && handlers.containsKey(type)) {
    handlers[type] = null;
  }
}

BloomEvent _wrapEvent(String type, web.Event e) {
  String? value;
  bool? checked;
  String? key;
  String? code;
  bool shiftKey = false;
  bool ctrlKey = false;
  bool altKey = false;
  bool metaKey = false;
  double? clientX;
  double? clientY;
  double? offsetX;
  double? offsetY;
  int? button;
  List<String>? files;
  String? dataTransfer;

  // Try to read value/checked from target for input-like events.
  try {
    final target = e.target;
    if (target != null) {
      // Use JS interop to read .value / .checked without tight typing.
      final jsTarget = target as JSAny;
      value = _jsGetString(jsTarget, 'value');
      checked = _jsGetBool(jsTarget, 'checked');
    }
  } catch (_) {}

  try {
    final jsEvent = e as JSAny;
    key = _jsGetString(jsEvent, 'key');
    code = _jsGetString(jsEvent, 'code');
    shiftKey = _jsGetBool(jsEvent, 'shiftKey') ?? false;
    ctrlKey = _jsGetBool(jsEvent, 'ctrlKey') ?? false;
    altKey = _jsGetBool(jsEvent, 'altKey') ?? false;
    metaKey = _jsGetBool(jsEvent, 'metaKey') ?? false;
    clientX = _jsGetDouble(jsEvent, 'clientX');
    clientY = _jsGetDouble(jsEvent, 'clientY');
    offsetX = _jsGetDouble(jsEvent, 'offsetX');
    offsetY = _jsGetDouble(jsEvent, 'offsetY');
    button = _jsGetInt(jsEvent, 'button');
    dataTransfer = _jsGetString(jsEvent, 'dataTransfer');
    files = _jsGetFileNames(jsEvent);
  } catch (_) {}

  return BloomEvent(
    type: type,
    value: value,
    checked: checked,
    rawTarget: e.target as JSAny?,
    key: key,
    code: code,
    shiftKey: shiftKey,
    ctrlKey: ctrlKey,
    altKey: altKey,
    metaKey: metaKey,
    clientX: clientX,
    clientY: clientY,
    offsetX: offsetX,
    offsetY: offsetY,
    button: button,
    files: files,
    dataTransfer: dataTransfer,
    preventDefaultFn: () => e.preventDefault(),
    stopPropagationFn: () => e.stopPropagation(),
  );
}

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

@JS('Reflect.set')
external bool _reflectSet(JSAny target, String key, JSAny? value);

String? _jsGetString(JSAny target, String key) {
  try {
    final v = _reflectGet(target, key);
    if (v == null) return null;
    if (v.isA<JSString>()) return (v as JSString).toDart;
    return null;
  } catch (_) {
    return null;
  }
}

bool? _jsGetBool(JSAny target, String key) {
  try {
    final v = _reflectGet(target, key);
    if (v == null) return null;
    if (v.isA<JSBoolean>()) return (v as JSBoolean).toDart;
    return null;
  } catch (_) {
    return null;
  }
}

double? _jsGetDouble(JSAny target, String key) {
  try {
    final v = _reflectGet(target, key);
    if (v == null) return null;
    if (v.isA<JSNumber>()) return (v as JSNumber).toDartDouble;
    return null;
  } catch (_) {
    return null;
  }
}

int? _jsGetInt(JSAny target, String key) {
  final d = _jsGetDouble(target, key);
  return d?.toInt();
}

List<String>? _jsGetFileNames(JSAny event) {
  try {
    final target = _reflectGet(event, 'target');
    if (target == null) return null;
    final filesObj = _reflectGet(target, 'files');
    if (filesObj == null) return null;
    final length = _jsGetInt(filesObj, 'length') ?? 0;
    if (length == 0) return null;
    final names = <String>[];
    for (var i = 0; i < length; i++) {
      final file = _reflectGet(filesObj, '$i');
      if (file != null) {
        final name = _jsGetString(file, 'name');
        if (name != null) names.add(name);
      }
    }
    return names.isEmpty ? null : names;
  } catch (_) {
    return null;
  }
}

// ── Reactive hydration ────────────────────────────────────────────────
//
// Attaches reactive behavior to server-rendered DOM instead of discarding
// it. SSR wraps reactive subtrees in `<!--bloom:<label>-->` markers (see
// `hydration_contract.dart`); this engine matches those markers to the
// descriptor tree, hydrates content in place, and binds the same sentinel
// regions and effects a fresh mount would create.
//
// Recovery rule: mismatches recover at the smallest marker-delimited
// boundary (clear + remount inside adopted sentinels). Markerless legacy
// output hydrates positionally when the structure matches and escalates to
// the nearest delimited ancestor otherwise. diagnostics flow through
// [HydrationMismatch] handlers and DevTools; hydration never throws.

/// Reports a [HydrationMismatch] observed while hydrating.
typedef HydrationMismatchHandler = void Function(HydrationMismatch mismatch);

/// Global mismatch handler invoked alongside any per-call `onMismatch`.
/// Null by default (mismatches still reach DevTools).
HydrationMismatchHandler? bloomHydrationMismatchHandler;

/// When `true` (default), hydration preserves pre-hydration form-control
/// state: `value`/`checked` attributes from SSR never overwrite what the
/// user typed, checked, or selected before hydration ran. Conflicts are
/// reported as mismatches with recovery `preserved pre-hydration input`.
bool bloomHydrationPreserveFormState = true;

/// Hydrates server-rendered DOM inside [container] against [root].
///
/// Attaches listeners, refs, lifecycle hooks, and reactive regions to the
/// existing nodes. Falls back to a clean full mount (previous behavior) only
/// when the root structure itself mismatches.
BloomMountHandle hydrateToElement(
  BloomNode root,
  web.Element container, {
  HydrationMismatchHandler? onMismatch,
}) {
  final region = _Region();
  final hctx = _HydrationContext(onMismatch: onMismatch);
  try {
    final sibs = _liveChildren(container);
    final consumed = _hydrateNode(root, sibs, 0, container, region, hctx);
    if (consumed != sibs.length) {
      throw _HydrationAbort(
        'root with exactly ${sibs.length} top-level nodes',
        'consumed $consumed nodes',
      );
    }
    return BloomMountHandle(container, region.disposers.toList());
  } catch (e) {
    if (e is _HydrationAbort) {
      hctx.report(
        boundary: 'root',
        expected: e.expected,
        actual: e.actual,
        recovery: 'remounted target',
      );
    } else {
      hctx.report(
        boundary: 'root',
        expected: 'hydratable DOM',
        actual: '${e.runtimeType}: $e',
        recovery: 'remounted target',
      );
    }
    for (final d in region.disposers) {
      try {
        d();
      } catch (_) {}
    }
    if (container.childNodes.length > 0) container.textContent = '';
    return mountToElement(root, container);
  }
}

/// Per-hydration-pass diagnostics context (path + boundary tracking).
class _HydrationContext {
  final HydrationMismatchHandler? onMismatch;
  final List<String> _path = [];
  final List<String> _boundaries = ['root'];

  _HydrationContext({this.onMismatch});

  String get path => _path.isEmpty ? 'root' : _path.join('/');
  String get boundary => _boundaries.isEmpty ? 'root' : _boundaries.last;

  void push(String segment) => _path.add(segment);
  void pop() {
    if (_path.isNotEmpty) _path.removeLast();
  }

  T withBoundary<T>(String label, T Function() body) {
    _boundaries.add(label);
    try {
      return body();
    } finally {
      _boundaries.removeLast();
    }
  }

  void report({
    required String boundary,
    required String expected,
    required String actual,
    required String recovery,
  }) {
    final mismatch = HydrationMismatch(
      path: path,
      boundary: boundary,
      expected: expected,
      actual: actual,
      recovery: recovery,
    );
    try {
      onMismatch?.call(mismatch);
    } catch (_) {}
    try {
      bloomHydrationMismatchHandler?.call(mismatch);
    } catch (_) {}
    try {
      BloomJsDevTools.notify('hydration-mismatch', {
        'path': mismatch.path,
        'boundary': mismatch.boundary,
        'expected': mismatch.expected,
        'actual': mismatch.actual,
        'recovery': mismatch.recovery,
      });
    } catch (_) {}
  }
}

/// Thrown to escalate a hydration failure to the nearest marker-delimited
/// ancestor (or the root, which remounts). Never surfaces to callers.
class _HydrationAbort implements Exception {
  final String expected;
  final String actual;
  _HydrationAbort(this.expected, this.actual);
  @override
  String toString() => 'HydrationAbort(expected $expected, found $actual)';
}

List<web.Node> _liveChildren(web.Node parent) {
  final out = <web.Node>[];
  final kids = parent.childNodes;
  for (var i = 0; i < kids.length; i++) {
    out.add(kids.item(i)!);
  }
  return out;
}

bool _isCommentNode(web.Node n) => n.nodeType == web.Node.COMMENT_NODE;

String _commentText(web.Node n) => (n as web.Comment).data;

/// Locates an open/close marker pair for [label] at [index], nesting-aware.
///
/// Returns null when [sibs[index]] is not the opening marker or the closing
/// marker is missing (markerless legacy output takes the positional path).
({int open, int close})? _findMarkerSpan(
  List<web.Node> sibs,
  int index,
  String label,
) {
  if (index >= sibs.length || !_isCommentNode(sibs[index])) return null;
  if (!isMarkerOpen(_commentText(sibs[index]), label)) return null;
  var depth = 0;
  for (var i = index; i < sibs.length; i++) {
    final n = sibs[i];
    if (!_isCommentNode(n)) continue;
    final data = normalizeMarkerData(_commentText(n));
    if (data == label) {
      depth++;
    } else if (data == '/$label') {
      depth--;
      if (depth == 0) return (open: index, close: i);
    }
  }
  return null;
}

String _describeNode(BloomNode node) {
  switch (node) {
    case TextNode():
      return 'Text';
    case RawHtmlNode():
      return 'Raw';
    case StyleNode():
      return 'Style';
    case SvgNode(:final tag):
      return 'Svg:$tag';
    case ElNode(:final tag):
      return tag;
    case FragmentNode():
      return 'Fragment';
    case LiveNode():
      return 'Live';
    case MemoNode():
      return 'Memo';
    case ShowNode():
      return 'Show';
    case ForEachNode():
      return 'ForEach';
    case MountNode():
      return 'Mount';
    case RefNode():
      return 'Ref';
    case AnimatedNode():
      return 'Animated';
    case ContextProviderNode():
      return 'Context';
    case ErrorBoundaryNode():
      return 'ErrorBoundary';
    case PortalNode():
      return 'Portal';
    case SuspenseNode():
      return 'Suspense';
  }
}

/// Hydrates [desc] against `sibs[index]`; returns snapshot nodes consumed.
///
/// Throws [_HydrationAbort] on any structural mismatch. May patch
/// attributes/text in place before throwing; ancestors recover by clearing
/// their span, so partial updates never leak into the final DOM.
int _hydrateNode(
  BloomNode desc,
  List<web.Node> sibs,
  int index,
  web.Node parentLive,
  _Region region,
  _HydrationContext hctx,
) {
  hctx.push('${_describeNode(desc)}[$index]');
  try {
    switch (desc) {
      case TextNode(:final text):
        if (index >= sibs.length) {
          throw _HydrationAbort('text node', 'missing node');
        }
        final existing = sibs[index];
        if (existing.nodeType != web.Node.TEXT_NODE) {
          throw _HydrationAbort('text node', _describeDom(existing));
        }
        if (existing.textContent != text) existing.textContent = text;
        return 1;

      case RawHtmlNode():
        if (index >= sibs.length) {
          throw _HydrationAbort('raw-html host', 'missing node');
        }
        return 1;

      case StyleNode(:final css):
        if (index >= sibs.length) {
          throw _HydrationAbort('element <style>', 'missing node');
        }
        final existing = sibs[index];
        if (existing.nodeType != web.Node.ELEMENT_NODE ||
            (existing as web.Element).tagName.toLowerCase() != 'style') {
          throw _HydrationAbort('element <style>', _describeDom(existing));
        }
        if (existing.textContent != css) existing.textContent = css;
        return 1;

      case FragmentNode(:final children):
        var consumed = 0;
        for (final child in children) {
          consumed += _hydrateNode(
              child, sibs, index + consumed, parentLive, region, hctx);
        }
        return consumed;

      case SvgNode(
          :final tag,
          :final text,
          :final className,
          :final style,
          :final attrs,
          :final children
        ):
        return _hydrateElement(tag, text, className, style, attrs, null,
            children, sibs, index, parentLive, region, hctx);

      case ElNode(
          :final tag,
          :final text,
          :final className,
          :final style,
          :final attrs,
          :final on,
          :final children
        ):
        return _hydrateElement(tag, text, className, style, attrs, on,
            children, sibs, index, parentLive, region, hctx);

      case LiveNode(:final builder):
        return _hydrateLive(node: desc, builder: builder, sibs: sibs,
            index: index, parentLive: parentLive, region: region, hctx: hctx);

      case MemoNode():
        return _hydrateMemo(node: desc, sibs: sibs, index: index,
            parentLive: parentLive, region: region, hctx: hctx);

      case ShowNode(:final child, :final fallback):
        return _hydrateShow(
            when: desc.when, child: child, fallback: fallback, sibs: sibs,
            index: index, parentLive: parentLive, region: region, hctx: hctx);

      case ForEachNode():
        return _hydrateForEach(node: desc, sibs: sibs, index: index,
            parentLive: parentLive, region: region, hctx: hctx);

      case MountNode(:final child, :final onMount, :final onUnmount):
        final consumed =
            _hydrateNode(child, sibs, index, parentLive, region, hctx);
        if (onMount != null) Future.microtask(onMount);
        if (onUnmount != null) region.add(onUnmount);
        return consumed;

      case RefNode(:final ref, :final child):
        final consumed =
            _hydrateNode(child, sibs, index, parentLive, region, hctx);
        for (var i = index; i < index + consumed && i < sibs.length; i++) {
          final n = sibs[i];
          if (n.isA<web.Element>()) {
            ref.attach(n as web.Element);
            region.add(ref.detach);
            break;
          }
        }
        return consumed;

      case AnimatedNode(:final child, :final animation):
        return _hydrateAnimated(
            child: child, animationName: animation.name,
            inlineStyle: animation.toInlineStyle(), sibs: sibs, index: index,
            parentLive: parentLive, region: region, hctx: hctx);

      case ContextProviderNode(:final context, :final value, :final child):
        return runZoned(
          () => _hydrateNode(child, sibs, index, parentLive, region, hctx),
          zoneValues: {context.zoneKey: value},
        );

      case ErrorBoundaryNode(:final builder, :final fallback):
        return _hydrateErrorBoundary(builder: builder, fallback: fallback,
            sibs: sibs, index: index, parentLive: parentLive, region: region,
            hctx: hctx);

      case PortalNode(:final child, :final targetSelector):
        return _hydratePortal(child: child, targetSelector: targetSelector,
            sibs: sibs, index: index, parentLive: parentLive, region: region,
            hctx: hctx);

      case SuspenseNode():
        return _hydrateSuspense(node: desc, sibs: sibs, index: index,
            parentLive: parentLive, region: region, hctx: hctx);
    }
  } finally {
    hctx.pop();
  }
}

String _describeDom(web.Node n) {
  if (n.nodeType == web.Node.TEXT_NODE) return 'text node';
  if (n.nodeType == web.Node.COMMENT_NODE) {
    return 'comment <!--${_commentText(n).trim()}-->';
  }
  if (n.isA<web.Element>()) {
    return 'element <${(n as web.Element).tagName.toLowerCase()}>';
  }
  return 'node type ${n.nodeType}';
}

int _hydrateElement(
  String tag,
  String? text,
  String? className,
  String? style,
  Map<String, String>? attrs,
  Map<String, BloomEventHandler>? on,
  List<BloomNode> children,
  List<web.Node> sibs,
  int index,
  web.Node parentLive,
  _Region region,
  _HydrationContext hctx,
) {
  if (index >= sibs.length) {
    throw _HydrationAbort('element <$tag>', 'missing node');
  }
  final existing = sibs[index];
  if (existing.nodeType != web.Node.ELEMENT_NODE) {
    throw _HydrationAbort('element <$tag>', _describeDom(existing));
  }
  final el = existing as web.Element;
  if (el.tagName.toLowerCase() != tag.toLowerCase()) {
    throw _HydrationAbort('element <$tag>', _describeDom(existing));
  }

  if ((className ?? '') != el.className) el.className = className ?? '';
  if (style != null) {
    if (el.getAttribute('style') != style) el.setAttribute('style', style);
  } else if (el.hasAttribute('style')) {
    el.removeAttribute('style');
  }
  if (attrs != null) {
    final preserve =
        bloomHydrationPreserveFormState && _isFormControlTag(tag);
    for (final e in attrs.entries) {
      if (preserve && _isPreservedFormAttr(e.key)) {
        _syncFormAttr(el, e.key, e.value, hctx);
        continue;
      }
      if (el.getAttribute(e.key) != e.value) {
        el.setAttribute(e.key, e.value);
      }
    }
  }
  if (on != null) {
    for (final entry in on.entries) {
      attachBloomListener(el, entry.key, entry.value);
    }
  }

  final kids = _liveChildren(el);
  var consumed = 0;
  if (text != null) {
    if (kids.isEmpty || kids[0].nodeType != web.Node.TEXT_NODE) {
      throw _HydrationAbort('text "$text"', kids.isEmpty ? 'no children' : _describeDom(kids[0]));
    }
    if (kids[0].textContent != text) kids[0].textContent = text;
    consumed = 1;
  }
  for (final child in children) {
    consumed += _hydrateNode(child, kids, consumed, el, region, hctx);
  }
  if (consumed != kids.length) {
    throw _HydrationAbort(
      'element <$tag> with exactly ${kids.length} children',
      'consumed $consumed children',
    );
  }
  return 1;
}

bool _isFormControlTag(String tag) {
  final t = tag.toLowerCase();
  return t == 'input' || t == 'textarea' || t == 'select';
}

bool _isPreservedFormAttr(String name) {
  final n = name.toLowerCase();
  return n == 'value' || n == 'checked' || n == 'selected';
}

/// Syncs a form-control attribute without clobbering user-edited state.
void _syncFormAttr(
    web.Element el, String name, String desired, _HydrationContext hctx) {
  final lower = name.toLowerCase();
  if (lower == 'checked') {
    final prop = _jsGetBool(el as JSAny, 'checked');
    if (prop != true) {
      hctx.report(
        boundary: hctx.boundary,
        expected: 'attribute checked="$desired"',
        actual: 'pre-hydration unchecked control',
        recovery: 'preserved pre-hydration input',
      );
    }
    return;
  }
  if (lower == 'value') {
    final prop = _jsGetString(el as JSAny, 'value');
    if (prop != desired) {
      hctx.report(
        boundary: hctx.boundary,
        expected: 'attribute value="$desired"',
        actual: 'pre-hydration input "${prop ?? ''}"',
        recovery: 'preserved pre-hydration input',
      );
    }
    return;
  }
  if (el.getAttribute(name) != desired) el.setAttribute(name, desired);
}

// ── Boundary hydration ──────────────────────────────────────────────

/// Inserts an empty marker pair at [index] and returns the adopted sentinel.
///
/// Markerless legacy output hydrates positionally first; the caller relocates
/// [sentinel.end] past the consumed nodes once the span is known.
_Sentinel _insertBoundaryMarkers(
  web.Node parentLive,
  List<web.Node> sibs,
  int index,
  String label,
) {
  final openC = web.document.createComment(' $label ');
  final closeC = web.document.createComment(' /$label ');
  final ref = index < sibs.length ? sibs[index] : null;
  parentLive.insertBefore(openC, ref);
  parentLive.insertBefore(closeC, ref);
  return _Sentinel.adopt(openC, closeC);
}

/// Moves [sentinel.end] to just past `sibs[index + consumed - 1]` in live DOM.
void _relocateEndMarker(
  _Sentinel sentinel,
  web.Node parentLive,
  List<web.Node> sibs,
  int index,
  int consumed,
) {
  final afterRef =
      index + consumed < sibs.length ? sibs[index + consumed] : null;
  parentLive.insertBefore(sentinel.end, afterRef);
}

int _hydrateLive({
  required LiveNode node,
  required BloomNode Function() builder,
  required List<web.Node> sibs,
  required int index,
  required web.Node parentLive,
  required _Region region,
  required _HydrationContext hctx,
}) {
  const label = hydrationMarkerLive;
  final span = _findMarkerSpan(sibs, index, label);
  if (span != null) {
    final sentinel = _Sentinel.adopt(
      sibs[span.open] as web.Comment,
      sibs[span.close] as web.Comment,
    );
    final content = sibs.sublist(span.open + 1, span.close);
    _bindMarkerHydratedRegion(
      sentinel: sentinel, parentRegion: region, build: builder,
      content: content, hctx: hctx, label: label,
    );
    return span.close - span.open + 1;
  }
  final sentinel = _insertBoundaryMarkers(parentLive, sibs, index, label);
  final inner = _Region();
  late final int consumed;
  try {
    final target = builder();
    consumed = hctx.withBoundary(label, () =>
        _hydrateNode(target, sibs, index, parentLive, inner, hctx));
  } catch (_) {
    inner.disposeAll();
    rethrow;
  }
  _relocateEndMarker(sentinel, parentLive, sibs, index, consumed);
  _bindTrackingRegion(
      sentinel: sentinel, parentRegion: region, inner: inner,
      build: builder, hctx: hctx, label: label);
  return consumed;
}

/// Generic marker-adopted region: hydrates [content] on the effect's first
/// run (single builder evaluation with proper signal tracking), rebuilds
/// normally afterwards. Content failures remount inside the adopted span.
void _bindMarkerHydratedRegion({
  required _Sentinel sentinel,
  required _Region parentRegion,
  required BloomNode Function() build,
  required List<web.Node> content,
  required _HydrationContext hctx,
  required String label,
}) {
  final inner = _Region();
  final errorBoundary =
      Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;
  var isFirstRun = true;

  void renderRegion() {
    try {
      if (isFirstRun) {
        isFirstRun = false;
        final target =
            runZoned(build, zoneValues: {_errorBoundaryZoneKey: errorBoundary});
        try {
          hctx.withBoundary(label, () {
            final parentLive = sentinel.start.parentNode ?? sentinel.end.parentNode;
            if (parentLive == null) {
              throw _HydrationAbort('attached boundary', 'detached markers');
            }
            final consumed = _hydrateNode(
                target, content, 0, parentLive, inner, hctx);
            if (consumed != content.length) {
              throw _HydrationAbort('exact boundary content',
                  'consumed $consumed of ${content.length}');
            }
          });
        } catch (abort) {
          hctx.report(
            boundary: label,
            expected: abort is _HydrationAbort ? abort.expected : 'hydratable content',
            actual: abort is _HydrationAbort ? abort.actual : '$abort',
            recovery: 'remounted boundary',
          );
          inner.reset();
          final fresh = runZoned(() => _mountNode(target, inner),
              zoneValues: {_errorBoundaryZoneKey: errorBoundary});
          sentinel.clear();
          sentinel.appendAll(fresh);
        }
        return;
      }
      inner.reset();
      final target =
          runZoned(build, zoneValues: {_errorBoundaryZoneKey: errorBoundary});
      final nodes = runZoned(() => _mountNode(target, inner),
          zoneValues: {_errorBoundaryZoneKey: errorBoundary});
      sentinel.clear();
      sentinel.appendAll(nodes);
    } catch (err, stack) {
      inner.reset();
      final boundary = Zone.current[_errorBoundaryZoneKey]
          as _ErrorBoundaryHandler?;
      if (boundary != null) {
        boundary.handleError(err, stack);
      } else {
        _reportUnhandledError(err, stack);
      }
    }
  }

  final stop = effect(() => renderRegion());
  parentRegion.add(() {
    stop();
    inner.disposeAll();
  });
}

/// Tracking-only binder for positionally-hydrated content.
///
/// The content was already hydrated eagerly (span discovered); the effect's
/// first run re-evaluates [build] purely to establish signal tracking, then
/// returns. Later runs rebuild normally with focus preservation. Builders
/// must be pure — marker-emitting SSR avoids this path entirely.
void _bindTrackingRegion({
  required _Sentinel sentinel,
  required _Region parentRegion,
  required _Region inner,
  required BloomNode Function() build,
  required _HydrationContext hctx,
  required String label,
}) {
  final errorBoundary =
      Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;
  var skipFirst = true;

  void renderRegion() {
    try {
      if (skipFirst) {
        skipFirst = false;
        runZoned(build, zoneValues: {_errorBoundaryZoneKey: errorBoundary});
        return;
      }
      web.Element? focusedEl;
      List<int>? focusPath;
      int? selStart;
      int? selEnd;
      final active = web.document.activeElement;
      if (active != null) {
        final path = _pathToNode(sentinel.childNodes, active);
        if (path != null) {
          focusedEl = active;
          focusPath = path;
          final range = _selectionRange(active);
          if (range != null) {
            selStart = range.$1;
            selEnd = range.$2;
          }
        }
      }
      inner.reset();
      final target =
          runZoned(build, zoneValues: {_errorBoundaryZoneKey: errorBoundary});
      final nodes = runZoned(() => _mountNode(target, inner),
          zoneValues: {_errorBoundaryZoneKey: errorBoundary});
      sentinel.clear();
      sentinel.appendAll(nodes);
      if (focusPath != null) {
        final replacement = _nodeAtPath(nodes, focusPath);
        if (replacement != null &&
            replacement.isA<web.HTMLElement>() &&
            (replacement as web.HTMLElement).tagName == focusedEl!.tagName) {
          replacement.focus();
          if (selStart != null && selEnd != null) {
            _setSelectionRange(replacement, selStart, selEnd);
          }
        }
      }
    } catch (err, stack) {
      inner.reset();
      final boundary = Zone.current[_errorBoundaryZoneKey]
          as _ErrorBoundaryHandler?;
      if (boundary != null) {
        boundary.handleError(err, stack);
      } else {
        _reportUnhandledError(err, stack);
      }
    }
  }

  final stop = effect(() => renderRegion());
  parentRegion.add(() {
    stop();
    inner.disposeAll();
  });
}

int _hydrateMemo({
  required MemoNode<dynamic> node,
  required List<web.Node> sibs,
  required int index,
  required web.Node parentLive,
  required _Region region,
  required _HydrationContext hctx,
}) {
  const label = hydrationMarkerMemo;
  final dependency = node.dependencyErased;
  final builder = node.builderErased;
  final span = _findMarkerSpan(sibs, index, label);
  if (span != null) {
    final sentinel = _Sentinel.adopt(
      sibs[span.open] as web.Comment,
      sibs[span.close] as web.Comment,
    );
    _bindHydratedMemoRegion(
      sentinel: sentinel, parentRegion: region, dependencyFn: dependency,
      builderFn: builder, content: sibs.sublist(span.open + 1, span.close),
      prehydrated: null, hctx: hctx,
    );
    return span.close - span.open + 1;
  }
  final sentinel = _insertBoundaryMarkers(parentLive, sibs, index, label);
  final inner = _Region();
  late final int consumed;
  Object? initialValue;
  try {
    initialValue = dependency();
    final target = builder(initialValue);
    consumed = hctx.withBoundary(label, () =>
        _hydrateNode(target, sibs, index, parentLive, inner, hctx));
  } catch (_) {
    inner.disposeAll();
    rethrow;
  }
  _relocateEndMarker(sentinel, parentLive, sibs, index, consumed);
  _bindHydratedMemoRegion(
    sentinel: sentinel, parentRegion: region, dependencyFn: dependency,
    builderFn: builder, content: const [], innerOverride: inner,
    prehydrated: (value: initialValue, hasValue: true), hctx: hctx,
  );
  return consumed;
}

/// Memo binder with hydration support.
///
/// Marker path ([content] non-empty, [prehydrated] null) hydrates on the
/// effect's first run, then applies memo comparison. Positional path passes
/// the eagerly-hydrated [innerOverride] region plus the [prehydrated]
/// dependency value so the first run only establishes tracking.
void _bindHydratedMemoRegion({
  required _Sentinel sentinel,
  required _Region parentRegion,
  required Object? Function() dependencyFn,
  required BloomNode Function(Object? value) builderFn,
  required List<web.Node> content,
  _Region? innerOverride,
  ({Object? value, bool hasValue})? prehydrated,
  required _HydrationContext hctx,
}) {
  const label = hydrationMarkerMemo;
  final inner = innerOverride ?? _Region();
  var isFirstRun = true;
  var hasPrevValue = prehydrated?.hasValue ?? false;
  Object? prevValue = prehydrated?.value;
  BloomNode? prevDescriptor;
  List<web.Node> currentNodes = const [];
  final errorBoundary =
      Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;

  void renderRegion() {
    try {
      final value = dependencyFn();
      if (!isFirstRun && hasPrevValue && prevValue == value) return;

      if (isFirstRun && prehydrated == null) {
        isFirstRun = false;
        final newDescriptor = builderFn(value);
        try {
          hctx.withBoundary(label, () {
            final parentLive =
                sentinel.start.parentNode ?? sentinel.end.parentNode;
            if (parentLive == null) {
              throw _HydrationAbort('attached boundary', 'detached markers');
            }
            final consumed = _hydrateNode(
                newDescriptor, content, 0, parentLive, inner, hctx);
            if (consumed != content.length) {
              throw _HydrationAbort('exact boundary content',
                  'consumed $consumed of ${content.length}');
            }
          });
        } catch (abort) {
          hctx.report(
            boundary: label,
            expected: abort is _HydrationAbort ? abort.expected : 'hydratable content',
            actual: abort is _HydrationAbort ? abort.actual : '$abort',
            recovery: 'remounted boundary',
          );
          inner.reset();
          final fresh = runZoned(() => _mountNode(newDescriptor, inner),
              zoneValues: {_errorBoundaryZoneKey: errorBoundary});
          sentinel.clear();
          sentinel.appendAll(fresh);
          currentNodes = fresh;
        }
        prevDescriptor = newDescriptor;
        prevValue = value;
        hasPrevValue = true;
        return;
      }

      isFirstRun = false;
      final newDescriptor = builderFn(value);
      if (hasPrevValue && prevValue == value && prevDescriptor != null) {
        // Tracking-only run (positional path): dependency already seen.
        prevDescriptor = newDescriptor;
        return;
      }
      if (prevDescriptor != null && currentNodes.length == 1) {
        final patched = _patchNode(
            currentNodes.first, prevDescriptor!, newDescriptor, inner);
        if (patched) {
          prevDescriptor = newDescriptor;
          prevValue = value;
          hasPrevValue = true;
          return;
        }
      }
      inner.reset();
      final nodes = runZoned(() => _mountNode(newDescriptor, inner),
          zoneValues: {_errorBoundaryZoneKey: errorBoundary});
      if (prehydrated != null && currentNodes.isEmpty) {
        // Positional path: content already hydrated in place; adopt the
        // live nodes between the inserted sentinels as the current set.
        currentNodes = sentinel.childNodes;
        prevDescriptor = newDescriptor;
        prevValue = value;
        hasPrevValue = true;
        return;
      }
      sentinel.clear();
      sentinel.appendAll(nodes);
      currentNodes = nodes;
      prevDescriptor = newDescriptor;
      prevValue = value;
      hasPrevValue = true;
    } catch (err, stack) {
      inner.reset();
      final boundary = Zone.current[_errorBoundaryZoneKey]
          as _ErrorBoundaryHandler?;
      if (boundary != null) {
        boundary.handleError(err, stack);
      } else {
        _reportUnhandledError(err, stack);
      }
    }
  }

  final stop = effect(() => renderRegion());
  parentRegion.add(() {
    stop();
    inner.disposeAll();
  });
}

int _hydrateShow({
  required bool Function() when,
  required BloomNode child,
  required BloomNode? fallback,
  required List<web.Node> sibs,
  required int index,
  required web.Node parentLive,
  required _Region region,
  required _HydrationContext hctx,
}) {
  const label = hydrationMarkerShow;
  BloomNode active() => when() ? child : (fallback ?? const FragmentNode([]));
  final span = _findMarkerSpan(sibs, index, label);
  if (span != null) {
    final sentinel = _Sentinel.adopt(
      sibs[span.open] as web.Comment,
      sibs[span.close] as web.Comment,
    );
    final content = sibs.sublist(span.open + 1, span.close);
    _bindMarkerHydratedRegion(
      sentinel: sentinel, parentRegion: region, build: active,
      content: content, hctx: hctx, label: label,
    );
    return span.close - span.open + 1;
  }
  final sentinel = _insertBoundaryMarkers(parentLive, sibs, index, label);
  final inner = _Region();
  late final int consumed;
  try {
    consumed = hctx.withBoundary(label, () =>
        _hydrateNode(active(), sibs, index, parentLive, inner, hctx));
  } catch (_) {
    inner.disposeAll();
    rethrow;
  }
  _relocateEndMarker(sentinel, parentLive, sibs, index, consumed);
  _bindTrackingRegion(
      sentinel: sentinel, parentRegion: region, inner: inner,
      build: active, hctx: hctx, label: label);
  return consumed;
}

int _hydrateForEach({
  required ForEachNode<dynamic> node,
  required List<web.Node> sibs,
  required int index,
  required web.Node parentLive,
  required _Region region,
  required _HydrationContext hctx,
}) {
  const label = hydrationMarkerForEach;
  final keyFn = node.keyFnErased;
  final span = _findMarkerSpan(sibs, index, label);
  if (keyFn != null) {
    return _hydrateKeyedForEach(
      itemsFn: node.itemsErased, keyFn: keyFn, builderFn: node.builderErased,
      span: span, sibs: sibs, index: index, parentLive: parentLive,
      region: region, hctx: hctx,
    );
  }
  // Unkeyed: same region semantics as Live over the built child list.
  BloomNode build() => FragmentNode(node.buildChildren());
  if (span != null) {
    final sentinel = _Sentinel.adopt(
      sibs[span.open] as web.Comment,
      sibs[span.close] as web.Comment,
    );
    final content = sibs.sublist(span.open + 1, span.close);
    _bindMarkerHydratedRegion(
      sentinel: sentinel, parentRegion: region, build: build,
      content: content, hctx: hctx, label: label,
    );
    return span.close - span.open + 1;
  }
  final sentinel = _insertBoundaryMarkers(parentLive, sibs, index, label);
  final inner = _Region();
  late final int consumed;
  try {
    consumed = hctx.withBoundary(label, () =>
        _hydrateNode(build(), sibs, index, parentLive, inner, hctx));
  } catch (_) {
    inner.disposeAll();
    rethrow;
  }
  _relocateEndMarker(sentinel, parentLive, sibs, index, consumed);
  _bindTrackingRegion(
      sentinel: sentinel, parentRegion: region, inner: inner,
      build: build, hctx: hctx, label: label);
  return consumed;
}

/// Hydrates a keyed list: matches `bloom:key` item markers when present,
/// falls back to positional hydration for markerless output.
int _hydrateKeyedForEach({
  required List<Object?> Function() itemsFn,
  required String Function(Object? item) keyFn,
  required BloomNode Function(Object? item) builderFn,
  required ({int open, int close})? span,
  required List<web.Node> sibs,
  required int index,
  required web.Node parentLive,
  required _Region region,
  required _HydrationContext hctx,
}) {
  const label = hydrationMarkerForEach;
  final errorBoundary =
      Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;
  if (span != null) {
    final sentinel = _Sentinel.adopt(
      sibs[span.open] as web.Comment,
      sibs[span.close] as web.Comment,
    );
    final content = sibs.sublist(span.open + 1, span.close);
    final controller = _KeyedListController(
      sentinel: sentinel, itemsFn: itemsFn, keyFn: keyFn,
      builderFn: builderFn, boundary: errorBoundary,
    );
    var isFirstRun = true;
    final stop = effect(() {
      if (!isFirstRun) {
        controller.reconcile();
        return;
      }
      isFirstRun = false;
      try {
        _hydrateKeyedItems(
          itemsFn: itemsFn, keyFn: keyFn, builderFn: builderFn,
          content: content, parentLive: sentinel.start.parentNode,
          controller: controller, hctx: hctx,
        );
      } catch (abort) {
        hctx.report(
          boundary: label,
          expected: abort is _HydrationAbort ? abort.expected : 'hydratable items',
          actual: abort is _HydrationAbort ? abort.actual : '$abort',
          recovery: 'remounted boundary',
        );
        controller.disposeAll();
        final fresh = controller.mountInitial();
        sentinel.clear();
        sentinel.appendAll(fresh);
      }
    });
    region.add(() {
      stop();
      controller.disposeAll();
    });
    return span.close - span.open + 1;
  }
  // Markerless: insert markers, hydrate eagerly, track afterwards.
  final sentinel = _insertBoundaryMarkers(parentLive, sibs, index, label);
  final controller = _KeyedListController(
    sentinel: sentinel, itemsFn: itemsFn, keyFn: keyFn,
    builderFn: builderFn, boundary: errorBoundary,
  );
  late final int consumed;
  try {
    consumed = hctx.withBoundary(label, () {
      var cursor = index;
      var total = 0;
      for (final item in itemsFn()) {
        final descriptor =
            runZoned(() => builderFn(item), zoneValues: {_errorBoundaryZoneKey: errorBoundary});
        final itemRegion = _Region();
        final used = _hydrateNode(
            descriptor, sibs, cursor, parentLive, itemRegion, hctx);
        controller.activeEntries[keyFn(item)] = _KeyedEntry(
          key: keyFn(item),
          domNodes: sibs.sublist(cursor, cursor + used),
          region: itemRegion,
          descriptor: descriptor,
        );
        cursor += used;
        total += used;
      }
      return total;
    });
  } catch (_) {
    controller.disposeAll();
    rethrow;
  }
  _relocateEndMarker(sentinel, parentLive, sibs, index, consumed);
  // Tracking run mirrors the fresh mount's first run: the item closures'
  // reads belong to this effect so update-time throws reach the boundary.
  var skipFirst = true;
  final stop = effect(() {
    if (skipFirst) {
      skipFirst = false;
      for (final item in itemsFn()) {
        keyFn(item);
        builderFn(item);
      }
      return;
    }
    controller.reconcile();
  });
  region.add(() {
    stop();
    controller.disposeAll();
  });
  return consumed;
}

/// Hydrates keyed items between adopted foreach markers.
void _hydrateKeyedItems({
  required List<Object?> Function() itemsFn,
  required String Function(Object? item) keyFn,
  required BloomNode Function(Object? item) builderFn,
  required List<web.Node> content,
  required web.Node? parentLive,
  required _KeyedListController controller,
  required _HydrationContext hctx,
}) {
  if (parentLive == null) {
    throw _HydrationAbort('attached boundary', 'detached markers');
  }
  final errorBoundary = controller.boundary;
  final items = itemsFn();
  final byKey = <String, Object?>{};
  for (final item in items) {
    byKey[keyFn(item)] = item;
  }
  // Split content by key markers when present; otherwise positional.
  final segments = _splitKeySegments(content);
  if (segments != null) {
    if (segments.length != items.length) {
      throw _HydrationAbort(
        'foreach with exactly ${items.length} keyed items',
        '${segments.length} keyed segments',
      );
    }
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final item = byKey[seg.key];
      if (item == null) {
        throw _HydrationAbort(
            'keyed item "${seg.key}"', 'no matching client item');
      }
      final expectedKey = keyFn(items[i]);
      final descriptor = runZoned(() => builderFn(item),
          zoneValues: {_errorBoundaryZoneKey: errorBoundary});
      final itemRegion = _Region();
      final used = _hydrateNode(
          descriptor, content, seg.start, parentLive, itemRegion, hctx);
      if (seg.start + used != seg.end) {
        itemRegion.disposeAll();
        throw _HydrationAbort('exact keyed item "${seg.key}"',
            'consumed $used of ${seg.end - seg.start} nodes');
      }
      if (seg.key != expectedKey) {
        // Same set, different order: hydrated in place; future reconciles
        // will reorder by key. Record for diagnostics.
        hctx.report(
          boundary: hydrationMarkerForEach,
          expected: 'SSR order position $i key "$expectedKey"',
          actual: 'SSR key "${seg.key}" (hydrated in place; reconciler owns order)',
          recovery: 'kept SSR order until next update',
        );
      }
      controller.activeEntries[seg.key] = _KeyedEntry(
        key: seg.key,
        domNodes: content.sublist(seg.start, seg.end),
        region: itemRegion,
        descriptor: descriptor,
      );
    }
    return;
  }
  // Positional fallback within a delimited foreach span.
  var cursor = 0;
  for (final item in items) {
    final descriptor = runZoned(() => builderFn(item),
        zoneValues: {_errorBoundaryZoneKey: errorBoundary});
    final itemRegion = _Region();
    final used =
        _hydrateNode(descriptor, content, cursor, parentLive, itemRegion, hctx);
    controller.activeEntries[keyFn(item)] = _KeyedEntry(
      key: keyFn(item),
      domNodes: content.sublist(cursor, cursor + used),
      region: itemRegion,
      descriptor: descriptor,
    );
    cursor += used;
  }
  if (cursor != content.length) {
    throw _HydrationAbort(
        'foreach with exactly ${content.length} item nodes',
        'consumed $cursor nodes');
  }
}

class _KeySegment {
  final String key;
  final int start;
  final int end;
  _KeySegment(this.key, this.start, this.end);
}

/// Splits [content] into key-delimited segments, or null when no key
/// markers are present (markerless legacy output inside a delimited span).
List<_KeySegment>? _splitKeySegments(List<web.Node> content) {
  final out = <_KeySegment>[];
  var i = 0;
  var sawMarker = false;
  while (i < content.length) {
    final n = content[i];
    if (!_isCommentNode(n)) {
      if (out.isEmpty && !sawMarker) return null;
      throw _HydrationAbort('keyed item marker', _describeDom(n));
    }
    final key = parseKeyMarker(_commentText(n));
    if (key == null) {
      if (out.isEmpty && !sawMarker) return null;
      throw _HydrationAbort('keyed item marker', 'comment <!--${normalizeMarkerData(_commentText(n))}-->');
    }
    sawMarker = true;
    var depth = 0;
    var j = i + 1;
    for (; j < content.length; j++) {
      final m = content[j];
      if (!_isCommentNode(m)) continue;
      final data = normalizeMarkerData(_commentText(m));
      if (data.startsWith(hydrationMarkerKeyPrefix)) depth++;
      if (data == hydrationMarkerKeyClose) {
        if (depth == 0) break;
        depth--;
      }
    }
    if (j >= content.length) {
      throw _HydrationAbort('closed keyed item "$key"', 'missing close marker');
    }
    out.add(_KeySegment(key, i + 1, j));
    i = j + 1;
  }
  return sawMarker ? out : null;
}

int _hydrateAnimated({
  required BloomNode child,
  required String animationName,
  required String inlineStyle,
  required List<web.Node> sibs,
  required int index,
  required web.Node parentLive,
  required _Region region,
  required _HydrationContext hctx,
}) {
  var cursor = index;
  var consumed = 0;
  // SSR may emit a <style> keyframes block immediately before the wrapper.
  if (cursor < sibs.length &&
      sibs[cursor].nodeType == web.Node.ELEMENT_NODE &&
      (sibs[cursor] as web.Element).tagName.toLowerCase() == 'style') {
    consumed += 1;
    cursor += 1;
  }
  if (cursor >= sibs.length) {
    throw _HydrationAbort('animated wrapper <div>', 'missing node');
  }
  final wrapper = sibs[cursor];
  if (wrapper.nodeType != web.Node.ELEMENT_NODE ||
      (wrapper as web.Element).tagName.toLowerCase() != 'div') {
    throw _HydrationAbort('animated wrapper <div>', _describeDom(wrapper));
  }
  if (wrapper.getAttribute('style') != inlineStyle) {
    wrapper.setAttribute('style', inlineStyle);
  }
  _injectedAnimationNames.add(animationName);
  final kids = _liveChildren(wrapper);
  final used = _hydrateNode(child, kids, 0, wrapper, region, hctx);
  if (used != kids.length) {
    throw _HydrationAbort(
        'animated content with exactly ${kids.length} nodes',
        'consumed $used nodes');
  }
  return consumed + 1;
}

int _hydrateErrorBoundary({
  required BloomNode Function() builder,
  required BloomNode Function(Object error, StackTrace stackTrace) fallback,
  required List<web.Node> sibs,
  required int index,
  required web.Node parentLive,
  required _Region region,
  required _HydrationContext hctx,
}) {
  const label = hydrationMarkerErrorBoundary;
  final parentBoundary =
      Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;
  final span = _findMarkerSpan(sibs, index, label);
  if (span == null) {
    // Markerless: hydrate child positionally; builder errors hydrate the
    // fallback instead (mirrors SSR). Future errors have no adopted span to
    // recover into, so they propagate to the enclosing boundary.
    try {
      final target = builder();
      return _hydrateNode(target, sibs, index, parentLive, region, hctx);
    } catch (err, stack) {
      final target = fallback(err, stack);
      return _hydrateNode(target, sibs, index, parentLive, region, hctx);
    }
  }
  final sentinel = _Sentinel.adopt(
    sibs[span.open] as web.Comment,
    sibs[span.close] as web.Comment,
  );
  final content = sibs.sublist(span.open + 1, span.close);
  final inner = _Region();
  final handler = _ErrorBoundaryHandler(
    sentinel: sentinel,
    inner: inner,
    fallback: fallback,
    parentBoundary: parentBoundary,
  );
  try {
    final target = runZoned(builder,
        zoneValues: {_errorBoundaryZoneKey: handler});
    try {
      hctx.withBoundary(label, () {
        final parent = sentinel.start.parentNode ?? sentinel.end.parentNode;
        if (parent == null) {
          throw _HydrationAbort('attached boundary', 'detached markers');
        }
        final consumed =
            _hydrateNode(target, content, 0, parent, inner, hctx);
        if (consumed != content.length) {
          throw _HydrationAbort('exact boundary content',
              'consumed $consumed of ${content.length}');
        }
      });
    } catch (abort) {
      hctx.report(
        boundary: label,
        expected: abort is _HydrationAbort ? abort.expected : 'hydratable content',
        actual: abort is _HydrationAbort ? abort.actual : '$abort',
        recovery: 'remounted boundary',
      );
      inner.reset();
      final fresh = runZoned(() => _mountNode(target, inner),
          zoneValues: {_errorBoundaryZoneKey: handler});
      sentinel.clear();
      sentinel.appendAll(fresh);
    }
  } catch (err, stack) {
    handler.isFailed = true;
    inner.reset();
    try {
      final fallbackNode = fallback(err, stack);
      final fresh = runZoned(() => _mountNode(fallbackNode, inner),
          zoneValues: {_errorBoundaryZoneKey: parentBoundary});
      sentinel.clear();
      sentinel.appendAll(fresh);
    } catch (fallbackErr, fallbackStack) {
      inner.reset();
      sentinel.clear();
      if (parentBoundary != null) {
        parentBoundary.handleError(fallbackErr, fallbackStack);
      } else {
        _reportUnhandledError(fallbackErr, fallbackStack);
      }
    }
  }
  region.add(inner.disposeAll);
  return span.close - span.open + 1;
}

int _hydratePortal({
  required BloomNode child,
  required String targetSelector,
  required List<web.Node> sibs,
  required int index,
  required web.Node parentLive,
  required _Region region,
  required _HydrationContext hctx,
}) {
  // Portal content lives outside the hydrated subtree by design; the
  // server <template> is replaced with the mount-style marker comment and
  // the content mounts fresh into the target. Surrounding DOM is preserved.
  if (index >= sibs.length ||
      sibs[index].nodeType != web.Node.ELEMENT_NODE ||
      (sibs[index] as web.Element).tagName.toLowerCase() != 'template') {
    throw _HydrationAbort('portal <template>',
        index >= sibs.length ? 'missing node' : _describeDom(sibs[index]));
  }
  final template = sibs[index] as web.Element;
  final targetEl =
      web.document.querySelector(targetSelector) ?? web.document.body!;
  final childNodes = _mountNode(child, region);
  for (final n in childNodes) {
    targetEl.appendChild(n);
    region.add(() => n.parentNode?.removeChild(n));
  }
  final marker = web.document.createComment(' portal:$targetSelector ');
  template.parentNode?.replaceChild(marker, template);
  return 1;
}

int _hydrateSuspense({
  required SuspenseNode<dynamic> node,
  required List<web.Node> sibs,
  required int index,
  required web.Node parentLive,
  required _Region region,
  required _HydrationContext hctx,
}) {
  const label = hydrationMarkerSuspense;
  final boundary =
      Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;
  final dynamic dynNode = node;

  // Case 1 — streaming shell: <div id="bloom-suspense-N">fallback</div>.
  // Claim it so a late server patch script (null-guarded
  // getElementById) no-ops instead of destroying hydrated state; the client
  // region re-runs resource and patches itself on resolve.
  if (index < sibs.length &&
      sibs[index].nodeType == web.Node.ELEMENT_NODE) {
    final el = sibs[index] as web.Element;
    final id = el.getAttribute('id') ?? '';
    if (id.startsWith('bloom-suspense-')) {
      el.removeAttribute('id');
      try {
        el.setAttribute(suspenseClaimedAttribute, id);
      } catch (_) {}
      final inner = _Region();
      try {
        hctx.withBoundary(label, () {
          final kids = _liveChildren(el);
          final consumed = _hydrateNode(
              node.fallback, kids, 0, el, inner, hctx);
          if (consumed != kids.length) {
            throw _HydrationAbort('suspense fallback with exactly ${kids.length} nodes',
                'consumed $consumed nodes');
          }
        });
      } catch (abort) {
        hctx.report(
          boundary: label,
          expected: abort is _HydrationAbort ? abort.expected : 'hydratable fallback',
          actual: abort is _HydrationAbort ? abort.actual : '$abort',
          recovery: 'remounted boundary',
        );
        inner.reset();
        el.textContent = '';
        final fresh = runZoned(() => _mountNode(node.fallback, inner),
            zoneValues: {_errorBoundaryZoneKey: boundary});
        for (final n in fresh) {
          el.appendChild(n);
        }
      }
      _attachSuspenseContinuation(
        resource: dynNode.resourceErased as Future<Object?> Function(),
        builder: dynNode.builderErased as BloomNode Function(Object? data),
        errorBuilder: node.errorBuilder,
        replace: (fresh) {
          el.textContent = '';
          for (final n in fresh) {
            el.appendChild(n);
          }
        },
        inner: inner,
        ownerRegion: region,
        boundary: boundary,
        hctx: hctx,
      );
      return 1;
    }
  }

  // Case 2 — sync SSR markers: hydrate the fallback in the adopted span.
  final span = _findMarkerSpan(sibs, index, label);
  if (span != null) {
    final sentinel = _Sentinel.adopt(
      sibs[span.open] as web.Comment,
      sibs[span.close] as web.Comment,
    );
    final content = sibs.sublist(span.open + 1, span.close);
    final inner = _Region();
    try {
      hctx.withBoundary(label, () {
        final parent = sentinel.start.parentNode ?? sentinel.end.parentNode;
        if (parent == null) {
          throw _HydrationAbort('attached boundary', 'detached markers');
        }
        final consumed =
            _hydrateNode(node.fallback, content, 0, parent, inner, hctx);
        if (consumed != content.length) {
          throw _HydrationAbort('exact boundary content',
              'consumed $consumed of ${content.length}');
        }
      });
    } catch (abort) {
      hctx.report(
        boundary: label,
        expected: abort is _HydrationAbort ? abort.expected : 'hydratable fallback',
        actual: abort is _HydrationAbort ? abort.actual : '$abort',
        recovery: 'remounted boundary',
      );
      inner.reset();
      final fresh = runZoned(() => _mountNode(node.fallback, inner),
          zoneValues: {_errorBoundaryZoneKey: boundary});
      sentinel.clear();
      sentinel.appendAll(fresh);
    }
    _attachSuspenseContinuation(
      resource: dynNode.resourceErased as Future<Object?> Function(),
      builder: dynNode.builderErased as BloomNode Function(Object? data),
      errorBuilder: node.errorBuilder,
      replace: (fresh) {
        sentinel.clear();
        sentinel.appendAll(fresh);
      },
      inner: inner,
      ownerRegion: region,
      boundary: boundary,
      hctx: hctx,
    );
    return span.close - span.open + 1;
  }

  // Case 3 — no shell at all (resolved-before-hydrate content or legacy
  // output): positional fallback hydration usually mismatches and escalates
  // to the nearest delimited ancestor, which remounts a live Suspense region
  // (resource re-runs; dehydrated query caches resolve instantly).
  final sentinel = _insertBoundaryMarkers(parentLive, sibs, index, label);
  final inner = _Region();
  late final int consumed;
  try {
    consumed = hctx.withBoundary(label, () =>
        _hydrateNode(node.fallback, sibs, index, parentLive, inner, hctx));
  } catch (_) {
    inner.disposeAll();
    rethrow;
  }
  _relocateEndMarker(sentinel, parentLive, sibs, index, consumed);
  _attachSuspenseContinuation(
    resource: dynNode.resourceErased as Future<Object?> Function(),
    builder: dynNode.builderErased as BloomNode Function(Object? data),
    errorBuilder: node.errorBuilder,
    replace: (fresh) {
      sentinel.clear();
      sentinel.appendAll(fresh);
    },
    inner: inner,
    ownerRegion: region,
    boundary: boundary,
    hctx: hctx,
  );
  return consumed;
}

/// Attaches a Suspense resource continuation to already-hydrated fallback.
///
/// The resource runs exactly once per hydration (never re-fired by the
/// hydrate pass itself). On resolve the [replace] callback swaps fallback
/// for the resolved content; on reject the error builder or enclosing
/// boundary handles it, leaving the fallback in place otherwise.
void _attachSuspenseContinuation({
  required Future<Object?> Function() resource,
  required BloomNode Function(Object? data) builder,
  required BloomNode Function(Object error, StackTrace stackTrace)? errorBuilder,
  required void Function(List<web.Node> fresh) replace,
  required _Region inner,
  required _Region ownerRegion,
  required _ErrorBoundaryHandler? boundary,
  required _HydrationContext hctx,
}) {
  void handleSuspenseError(Object error, StackTrace stackTrace) {
    if (ownerRegion.isDisposed) return;
    if (errorBuilder != null) {
      try {
        inner.reset();
        final errorNode = errorBuilder(error, stackTrace);
        final errorNodes = runZoned(() => _mountNode(errorNode, inner),
            zoneValues: {_errorBoundaryZoneKey: boundary});
        replace(errorNodes);
      } catch (ebErr, ebStack) {
        inner.reset();
        if (boundary != null) {
          boundary.handleError(ebErr, ebStack);
        } else {
          _reportUnhandledError(ebErr, ebStack);
        }
      }
    } else {
      if (boundary != null) {
        boundary.handleError(error, stackTrace);
      } else {
        _reportUnhandledError(error, stackTrace);
      }
    }
  }

  try {
    resource().then((data) {
      if (ownerRegion.isDisposed) return;
      try {
        // Detached by a racing server patch or teardown: don't resurrect.
        inner.reset();
        final loadedNode = builder(data);
        final loadedNodes = runZoned(() => _mountNode(loadedNode, inner),
            zoneValues: {_errorBoundaryZoneKey: boundary});
        replace(loadedNodes);
      } catch (err, stack) {
        handleSuspenseError(err, stack);
      }
    }, onError: (Object err, StackTrace stack) {
      handleSuspenseError(err, stack);
    });
  } catch (err, stack) {
    handleSuspenseError(err, stack);
  }

  ownerRegion.add(inner.disposeAll);
}
