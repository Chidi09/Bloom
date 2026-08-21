import 'dart:async';
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
      final sentinel = _Sentinel('live');
      _bindSentinelRegion(sentinel, region, builder);
      return [sentinel.start, sentinel.end];

    case ShowNode(:final child, :final fallback):
      final sentinel = _Sentinel('show');
      _bindSentinelRegion(
        sentinel,
        region,
        () => node.when() ? child : (fallback ?? FragmentNode(const [])),
      );
      return [sentinel.start, sentinel.end];

    case ForEachNode():
      final sentinel = _Sentinel('foreach');
      if (node.keyFn != null) {
        _bindKeyedForEachSentinel(sentinel, region, node);
      } else {
        _bindSentinelRegion<List<BloomNode>>(
          sentinel,
          region,
          () => node.buildChildren(),
          wrap: (children) => FragmentNode(children),
        );
      }
      return [sentinel.start, sentinel.end];

    case StyleNode(:final css):
      final el = web.document.createElement('style');
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

    case ContextProviderNode(:final context, :final value, :final child):
      return runZoned(
        () => _mountNode(child, region),
        zoneValues: {context.zoneKey: value},
      );

    case ErrorBoundaryNode(:final builder, :final fallback):
      final sentinel = _Sentinel('error-boundary');
      final inner = _Region();
      try {
        final node = builder();
        final nodes = _mountNode(node, inner);
        sentinel.appendAll(nodes);
      } catch (err, stack) {
        inner.disposeAll();
        sentinel.clear();
        final fallbackNode = fallback(err, stack);
        final nodes = _mountNode(fallbackNode, inner);
        sentinel.appendAll(nodes);
      }
      region.add(inner.disposeAll);
      return [sentinel.start, sentinel.end];

    case PortalNode(:final child, :final targetSelector):
      final targetEl = web.document.querySelector(targetSelector) ?? web.document.body!;
      final childNodes = _mountNode(child, region);
      for (final n in childNodes) {
        targetEl.appendChild(n);
        region.add(() => n.parentNode?.removeChild(n));
      }
      final comment = web.document.createComment(' portal:$targetSelector ');
      return [comment];

    case SuspenseNode(:final resource, :final builder, :final fallback):
      final sentinel = _Sentinel('suspense');
      final inner = _Region();
      final fallbackNodes = _mountNode(fallback, inner);
      sentinel.appendAll(fallbackNodes);

      resource().then((data) {
        if (region.disposers.isNotEmpty) {
          inner.disposeAll();
          sentinel.clear();
          final loadedNode = builder(data);
          final loadedNodes = _mountNode(loadedNode, inner);
          sentinel.appendAll(loadedNodes);
        }
      });

      region.add(inner.disposeAll);
      return [sentinel.start, sentinel.end];
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

class _KeyedEntry {
  final String key;
  final List<web.Node> domNodes;
  final _Region region;

  _KeyedEntry({
    required this.key,
    required this.domNodes,
    required this.region,
  });
}

void _bindKeyedForEachSentinel<T>(
  _Sentinel sentinel,
  _Region parentRegion,
  ForEachNode<T> forEachNode,
) {
  final keyFn = forEachNode.keyFn!;
  final Map<String, _KeyedEntry> activeEntries = {};

  void reconcile() {
    final items = forEachNode.items();
    final newKeys = <String>{};
    final newOrder = <_KeyedEntry>[];

    for (final item in items) {
      final key = keyFn(item);
      newKeys.add(key);

      if (activeEntries.containsKey(key)) {
        final existing = activeEntries[key]!;
        existing.region.disposeAll();
        final descriptor = forEachNode.builder(item);
        final newDomNodes = _mountNode(descriptor, existing.region);

        final parent = sentinel.end.parentNode;
        if (parent != null) {
          for (final n in existing.domNodes) {
            if (n.parentNode == parent) parent.removeChild(n);
          }
          for (final n in newDomNodes) {
            parent.insertBefore(n, sentinel.end);
          }
        }

        final updated = _KeyedEntry(key: key, domNodes: newDomNodes, region: existing.region);
        activeEntries[key] = updated;
        newOrder.add(updated);
      } else {
        final itemRegion = _Region();
        final descriptor = forEachNode.builder(item);
        final domNodes = _mountNode(descriptor, itemRegion);
        final entry = _KeyedEntry(key: key, domNodes: domNodes, region: itemRegion);
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
  }

  final stop = effect(() {
    reconcile();
  });

  parentRegion.add(() {
    stop();
    for (final entry in activeEntries.values) {
      entry.region.disposeAll();
    }
    activeEntries.clear();
  });
}

/// Shared sentinel reactive-region binding: re-renders between comments
/// whenever signals read inside [build] change.
void _bindSentinelRegion<T>(
  _Sentinel sentinel,
  _Region parentRegion,
  T Function() build, {
  BloomNode Function(T value)? wrap,
}) {
  final inner = _Region();

  void renderRegion() {
    inner.disposeAll();
    sentinel.clear();
    final value = build();
    final node = wrap == null ? value as BloomNode : wrap(value);
    final nodes = _mountNode(node, inner);
    sentinel.appendAll(nodes);
  }

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
