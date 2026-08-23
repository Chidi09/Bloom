import 'dart:async';
import 'dart:js_interop';

import 'package:signals_core/signals_core.dart';
import 'package:web/web.dart' as web;

import 'dev_error_overlay.dart';
import 'devtools.dart';
import 'events.dart';
import 'framework.dart';

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
  if (bloomDevErrorOverlayEnabled) {
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

    inner.disposeAll();
    sentinel.clear();

    try {
      final fallbackNode = fallback(error, stackTrace);
      final fallbackNodes = runZoned(
        () => _mountNode(fallbackNode, inner),
        zoneValues: {_errorBoundaryZoneKey: parentBoundary},
      );
      sentinel.appendAll(fallbackNodes);
    } catch (fallbackErr, fallbackStack) {
      inner.disposeAll();
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
    return BloomMountHandle(root, region.disposers.toList());
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
    if (bloomDevErrorOverlayEnabled) {
      root.textContent = '';
      final overlayHost = web.document.createElement('div');
      overlayHost.innerHTML = renderDevErrorOverlay(error, stackTrace).toJS;
      root.appendChild(overlayHost);
      return BloomMountHandle(root, []);
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
        inner.disposeAll();
        try {
          final fallbackNode = fallback(err, stack);
          initial = runZoned(
            () => _mountNode(fallbackNode, inner),
            zoneValues: {_errorBoundaryZoneKey: parentBoundary},
          );
        } catch (fallbackErr, fallbackStack) {
          inner.disposeAll();
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
        inner.disposeAll();
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
            inner.disposeAll();
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
              inner.disposeAll();
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
  final Map<String, _KeyedEntry> activeEntries = {};
  var isFirstRun = true;
  final initialNodes = <web.Node>[];
  final boundary = Zone.current[_errorBoundaryZoneKey] as _ErrorBoundaryHandler?;

  void reconcile() {
    try {
      final items = itemsFn();
      final newKeys = <String>{};
      final newOrder = <_KeyedEntry>[];

      // On the effect's synchronous initial run, the sentinel comments are not
      // attached to the document yet (mounting is still building the node tree
      // bottom-up), so sentinel.end.parentNode is null and any insertBefore
      // would silently no-op. Collect nodes to hand back to the caller instead.
      if (isFirstRun) {
        for (final item in items) {
          final key = keyFn(item);
          newKeys.add(key);
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
          initialNodes.addAll(domNodes);
        }
        return;
      }

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
    reconcile();
    isFirstRun = false;
  });

  parentRegion.add(() {
    stop();
    for (final entry in activeEntries.values) {
      entry.region.disposeAll();
    }
    activeEntries.clear();
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

      inner.disposeAll();
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
      inner.disposeAll();
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

      inner.disposeAll();
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
      inner.disposeAll();
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
