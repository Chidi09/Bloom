import 'dart:js_interop';

import 'package:signals/signals.dart';
import 'package:web/web.dart' as web;

import 'events.dart';
import 'framework.dart';

// ── Public API ──────────────────────────────────────────────────────────

/// Handle returned by [mount]. Call [unmount] / [dispose] to detach the
/// tree and dispose all reactive effects created during mount.
class BloomMountHandle {
  final web.Element _root;
  final List<void Function()> _disposers;
  bool _disposed = false;

  BloomMountHandle(this._root, this._disposers);

  /// Remove all children from the root and dispose effects.
  void unmount() => dispose();

  /// Alias for [unmount].
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

  bool get isDisposed => _disposed;
}

/// Mount a descriptor tree into the DOM element matching [selector].
///
/// ```dart
/// final handle = mount(app, '#app');
/// // later
/// handle.unmount();
/// ```
BloomMountHandle mount(BloomNode node, String selector) {
  final root = web.document.querySelector(selector);
  if (root == null) {
    throw StateError('Bloom mount: selector "$selector" matched no element.');
  }
  return mountToElement(node, root);
}

/// Mount into a specific [Element] (useful for tests / manual roots).
BloomMountHandle mountToElement(BloomNode node, web.Element root) {
  final region = _Region();
  final domNodes = _mountNode(node, region);
  for (final n in domNodes) {
    root.appendChild(n);
  }
  return BloomMountHandle(root, region.disposers.toList());
}

// ── Internal mount helpers ────────────────────────────────────────────

/// A scoped set of disposers owned by one reactive boundary.
///
/// When a Live/Show/ForEach region re-renders, its previous child subtree's
/// effects are disposed first — otherwise nested reactive boundaries would
/// accumulate zombie signal subscriptions on every update (leak).
class _Region {
  final Set<void Function()> disposers = {};

  void add(void Function() d) => disposers.add(d);

  void disposeAll() {
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
      final container = web.document.createElement('span');
      container.setAttribute('data-bloom-live', '');
      _bindReactiveRegion(container, region, builder);
      return [container];

    case ShowNode(:final child, :final fallback):
      final container = web.document.createElement('span');
      container.setAttribute('data-bloom-show', '');
      _bindReactiveRegion(container, region,
          () => node.when() ? child : (fallback ?? FragmentNode(const [])));
      return [container];

    case ForEachNode():
      final container = web.document.createElement('span');
      container.setAttribute('data-bloom-foreach', '');
      _bindReactiveRegion<List<BloomNode>>(
        container,
        region,
        () => node.buildChildren(),
        wrap: (children) => FragmentNode(children),
      );
      return [container];

    case StyleNode(:final css):
      final el = web.document.createElement('style');
      el.textContent = css;
      return [el];
  }
}

/// Shared reactive-region binding: re-renders the container's contents
/// whenever signals read inside [build] change, disposing the previous
/// subtree's effects before each rebuild.
void _bindReactiveRegion<T>(
  web.Element container,
  _Region parentRegion,
  T Function() build, {
  BloomNode Function(T value)? wrap,
}) {
  final inner = _Region();

  void renderRegion() {
    inner.disposeAll();
    final value = build();
    final node = wrap == null ? value as BloomNode : wrap(value);
    final nodes = _mountNode(node, inner);
    container.textContent = '';
    for (final n in nodes) {
      container.appendChild(n);
    }
  }

  // effect() runs immediately, giving the initial render exactly once.
  final stop = effect(() {
    renderRegion();
  });

  parentRegion.add(() {
    stop();
    inner.disposeAll();
  });
}

void _attachListener(
  web.Element el,
  String type,
  BloomEventHandler handler,
) {
  void listener(web.Event e) {
    final bloomEvent = _wrapEvent(type, e);
    handler(bloomEvent);
    if (bloomEvent.defaultPrevented) e.preventDefault();
    if (bloomEvent.propagationStopped) e.stopPropagation();
  }

  el.addEventListener(type, listener.toJS);
}

BloomEvent _wrapEvent(String type, web.Event e) {
  String? value;
  bool? checked;

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

  return BloomEvent(
    type: type,
    value: value,
    checked: checked,
    rawTarget: e.target as JSAny?,
    preventDefaultFn: () => e.preventDefault(),
    stopPropagationFn: () => e.stopPropagation(),
  );
}

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

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
