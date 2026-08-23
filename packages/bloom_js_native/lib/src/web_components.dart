// lib/src/web_components.dart
//
// Browser-only Web Components & Custom Elements interoperability module for Bloom JS Native.
// Requires package:web and dart:js_interop (exported via browser.dart).

import 'dart:async';
import 'dart:js_interop';

import 'package:signals/signals.dart';
import 'package:web/web.dart' as web;

import 'events.dart';
import 'framework.dart';
import 'mount.dart';

// ─── JS Interop Declarations ──────────────────────────────────────────────────

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

@JS('Reflect.set')
external bool _reflectSet(JSAny target, String key, JSAny? value);

@JS('Object.keys')
external JSArray<JSString> _jsObjectKeysRaw(JSObject obj);

@JS('Object')
external JSObject _newJsObject();

@JS('eval')
external JSAny? _jsEval(String code);

// ─── Value Conversion Helpers ─────────────────────────────────────────────────

/// Converts a Dart value [value] (primitives, Lists, Maps, Signals, Functions) into its
/// corresponding JavaScript [JSAny] representation for assigning to DOM element properties.
///
/// Handles recursive conversion of nested [Map] and [List] structures. If [value] is
/// already a [JSAny], it is returned directly.
///
/// ```dart
/// final jsData = dartToJsValue({'name': 'Alice', 'roles': ['admin', 'editor']});
/// ```
JSAny? dartToJsValue(Object? value) {
  if (value == null) return null;
  // An already-converted JS value passes through untouched. The analyzer warns
  // that `is JSAny` on a Dart `Object` is not guaranteed platform-consistent,
  // but the alternative here is worse: without this the value would fall
  // through to the `toString()` branch below and be stringified.
  // ignore: invalid_runtime_check_with_js_interop_types
  if (value is JSAny) return value;
  if (value is String) return value.toJS;
  if (value is bool) return value.toJS;
  if (value is int) return value.toJS;
  if (value is double) return value.toJS;
  if (value is List) {
    final list = <JSAny?>[];
    for (final item in value) {
      list.add(dartToJsValue(item));
    }
    return list.toJS;
  }
  if (value is Map) {
    final obj = _newJsObject();
    for (final entry in value.entries) {
      _reflectSet(obj, entry.key.toString(), dartToJsValue(entry.value));
    }
    return obj;
  }
  if (value is Function) {
    if (value is void Function()) {
      return (() => value()).toJS;
    }
    if (value is Object? Function()) {
      return (() => dartToJsValue(value())).toJS;
    }
    if (value is void Function(Object?)) {
      return ((JSAny? a) => value(jsToDartValue(a))).toJS;
    }
    if (value is Object? Function(Object?)) {
      return ((JSAny? a) => dartToJsValue(value(jsToDartValue(a)))).toJS;
    }
  }
  return value.toString().toJS;
}

/// Converts a JavaScript [JSAny] value [jsVal] into its corresponding Dart representation.
///
/// Recursively converts `JSArray` to `List<Object?>` and `JSObject` to `Map<String, Object?>`.
/// Converts `JSNumber` to `int` when representing a whole integer, or `double` otherwise.
///
/// ```dart
/// final dartMap = jsToDartValue(customEventDetail);
/// ```
Object? jsToDartValue(JSAny? jsVal) {
  if (jsVal == null) return null;
  if (jsVal.isA<JSString>()) return (jsVal as JSString).toDart;
  if (jsVal.isA<JSBoolean>()) return (jsVal as JSBoolean).toDart;
  if (jsVal.isA<JSNumber>()) {
    final d = (jsVal as JSNumber).toDartDouble;
    if (d == d.roundToDouble() && !d.isInfinite && !d.isNaN) {
      return d.toInt();
    }
    return d;
  }
  if (jsVal.isA<JSArray<JSAny?>>()) {
    // `toDart` rather than JSArray's index/length operators, which require
    // SDK 3.6.0 while this package declares >=3.4.0.
    final arr = (jsVal as JSArray<JSAny?>).toDart;
    return [for (final item in arr) jsToDartValue(item)];
  }
  if (jsVal.isA<JSObject>()) {
    final obj = jsVal as JSObject;
    try {
      final keys = _jsObjectKeysRaw(obj).toDart;
      final map = <String, Object?>{};
      for (final k in keys) {
        final key = k.toDart;
        map[key] = jsToDartValue(_reflectGet(obj, key));
      }
      return map;
    } catch (_) {
      return jsVal;
    }
  }
  return jsVal;
}

// ─── Custom Event Wrapper ─────────────────────────────────────────────────────

/// Strongly-typed event wrapper for custom elements dispatching custom DOM events
/// with an attached [detail] payload.
///
/// When custom elements emit events (e.g. `sl-change`, `shoelace-tab-show`, `chart-select`),
/// the payload is carried in `event.detail`. [CustomElementEvent] unwraps `detail` into
/// idiomatic Dart values ([Map], [List], primitives) rather than an opaque JS object.
///
/// ```dart
/// customElement(
///   'sl-select',
///   events: {
///     'sl-change': (event) {
///       print('Selected value: ${event.detail}');
///     },
///   },
/// )
/// ```
class CustomElementEvent<T> {
  /// The underlying native DOM [web.Event].
  final web.Event rawEvent;

  /// The custom event type name (e.g. `'sl-change'`, `'custom-select'`).
  final String type;

  /// The unwrapped `event.detail` payload converted to Dart type [T].
  final T? detail;

  /// The DOM element that dispatched this event.
  final web.Element? target;

  /// Creates a [CustomElementEvent] wrapping [rawEvent] with [type] and converted [detail].
  CustomElementEvent({
    required this.rawEvent,
    required this.type,
    this.detail,
    this.target,
  });

  /// Prevents the browser's default action for this event.
  void preventDefault() => rawEvent.preventDefault();

  /// Stops propagation of this event through the DOM hierarchy.
  void stopPropagation() => rawEvent.stopPropagation();

  /// Whether [preventDefault] has been called on the underlying DOM event.
  bool get defaultPrevented => rawEvent.defaultPrevented;
}

/// Handler callback for custom element events carrying a [detail] payload.
typedef CustomElementEventHandler<T> = void Function(
    CustomElementEvent<T> event);

// ─── Upgrade Guard ────────────────────────────────────────────────────────────

/// Awaits custom element registration and upgrade for [tag] via `customElements.whenDefined`.
///
/// If the custom element is already registered, completes immediately. If the definition
/// has not yet loaded, waits up to [timeout] (defaulting to 3 seconds) before completing
/// gracefully, preventing unhandled hangs if an external script fails to load.
///
/// ```dart
/// await whenCustomElementDefined('sl-button');
/// ```
Future<void> whenCustomElementDefined(
  String tag, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    final promise = web.window.customElements.whenDefined(tag);
    await promise.toDart.timeout(timeout);
  } catch (_) {
    // Timeout or whenDefined failure — continue gracefully
  }
}

// ─── Custom Element Descriptor ────────────────────────────────────────────────

/// Renders an HTML custom element / web component with reactive JS properties and custom events.
///
/// Solves the two core challenges when integrating Web Components into declarative frameworks:
///
/// 1. **Properties vs Attributes**:
///    - **Attributes** ([attrs]) are plain string key-value pairs emitted onto the HTML tag.
///    - **Properties** ([properties]) are rich JavaScript values (objects, arrays, dates, functions)
///      assigned directly to the live DOM element instance via JS interop after mounting.
///
/// 2. **Reactive Property Updates**:
///    - When a [Signal] is passed as a property value or read inside a property getter closure,
///      a fine-grained `effect` tracks the dependency and updates the property on the live DOM
///      instance without recreating or re-mounting the element.
///
/// 3. **Custom Event Interop**:
///    - [events] registers listeners for custom events (`sl-change`, `date-select`) and converts
///      the `event.detail` payload into Dart values.
///    - Keeps stable JS function references to ensure proper removal on unmount.
///
/// 4. **Upgrade Guard**:
///    - When [waitForUpgrade] is `true` (default), waits for `customElements.whenDefined(tag)`
///      before setting properties, preventing property shadowing bugs where un-upgraded instances
///      absorb field assignments.
///
/// ### Server-Side Rendering (SSR) Behavior
/// During SSR (`renderToHtml`), [customElement] emits the custom tag with its [attrs], [className],
/// [style], and [children] as static HTML for instant first paint and SEO. [properties] and [events]
/// are browser-only and run during client-side hydration and mounting.
///
/// ```dart
/// final selectedTab = signal('overview');
/// final chartData = signal([10, 25, 45, 80]);
///
/// BloomNode dashboardChart() => customElement(
///   'chart-view',
///   attrs: {
///     'theme': 'dark',
///   },
///   properties: {
///     'activeTab': () => selectedTab.value,
///     'series': () => chartData.value,
///   },
///   events: {
///     'chart-select': (event) {
///       print('Selected point: ${event.detail}');
///     },
///   },
/// );
/// ```
BloomNode customElement(
  String tag, {
  Map<String, Object?>? properties,
  Map<String, String>? attrs,
  String? className,
  String? style,
  Map<String, CustomElementEventHandler<dynamic>>? events,
  Map<String, BloomEventHandler>? on,
  List<BloomNode> children = const [],
  String? text,
  Ref<web.Element>? ref,
  bool waitForUpgrade = true,
  Duration upgradeTimeout = const Duration(seconds: 3),
}) {
  final elementRef = ref ?? Ref<web.Element>();
  final disposers = <void Function()>[];

  final elNode = El(
    tag,
    className: className,
    style: style,
    attrs: attrs,
    on: on,
    children: children,
    text: text,
  );

  return Mount(
    RefNode(elementRef, elNode),
    onMount: () {
      Future<void>(() async {
        if (!elementRef.isMounted) return;
        final el = elementRef.value;

        if (waitForUpgrade) {
          await whenCustomElementDefined(tag, timeout: upgradeTimeout);
          if (!elementRef.isMounted) return;
        }

        // Attach custom event listeners with stable function references
        if (events != null) {
          for (final entry in events.entries) {
            final type = entry.key;
            final handler = entry.value;

            final JSFunction jsListener = ((web.Event e) {
              final rawDetail = _reflectGet(e as JSAny, 'detail');
              final detail = jsToDartValue(rawDetail);
              final customEvent = CustomElementEvent<dynamic>(
                rawEvent: e,
                type: type,
                detail: detail,
                target: e.target as web.Element?,
              );
              handler(customEvent);
            }).toJS;

            el.addEventListener(type, jsListener);
            disposers.add(() {
              try {
                el.removeEventListener(type, jsListener);
              } catch (_) {}
            });
          }
        }

        // Apply reactive properties via effect
        if (properties != null && properties.isNotEmpty) {
          final effectDispose = effect(() {
            if (!elementRef.isMounted) return;
            for (final entry in properties.entries) {
              final propName = entry.key;
              final propValue = entry.value;
              Object? evaluated;
              if (propValue is ReadonlySignal) {
                evaluated = propValue.value;
              } else if (propValue is Object? Function()) {
                evaluated = propValue();
              } else {
                evaluated = propValue;
              }
              _reflectSet(el as JSAny, propName, dartToJsValue(evaluated));
            }
          });
          disposers.add(effectDispose);
        }
      });
    },
    onUnmount: () {
      for (final dispose in disposers) {
        try {
          dispose();
        } catch (_) {}
      }
      disposers.clear();
    },
  );
}

// ─── Custom Element Definition / Exporting ────────────────────────────────────

/// Context provided to the component [builder] inside [defineCustomElement].
///
/// Exposes the custom element's host element, Shadow DOM root (if enabled),
/// reactive signals for observed attributes, and custom event dispatching helpers.
class CustomElementContext {
  /// The host [web.HTMLElement] instance.
  final web.HTMLElement host;

  /// The attached [web.ShadowRoot], or `null` if Shadow DOM was disabled.
  final web.ShadowRoot? shadowRoot;

  final Map<String, Signal<String?>> _attrSignals = {};

  /// Creates a [CustomElementContext] for [host] with optional [shadowRoot].
  CustomElementContext({
    required this.host,
    this.shadowRoot,
  });

  /// Returns a reactive [Signal] tracking the value of attribute [name].
  ///
  /// Automatically updates whenever `attributeChangedCallback` fires on the custom element.
  ///
  /// ```dart
  /// final variant = context.attributeSignal('variant');
  /// ```
  Signal<String?> attributeSignal(String name) {
    return _attrSignals.putIfAbsent(
      name,
      () => signal(host.getAttribute(name)),
    );
  }

  /// Synchronously reads the current value of attribute [name] on [host].
  String? getAttribute(String name) => host.getAttribute(name);

  /// Dispatches a custom DOM event from the [host] element with [type] and [detail].
  ///
  /// Automatically sets `bubbles: true` and `composed: true` by default so the event
  /// can cross Shadow DOM boundaries.
  ///
  /// ```dart
  /// context.dispatchCustomEvent('change', detail: {'value': 42});
  /// ```
  void dispatchCustomEvent(
    String type, {
    Object? detail,
    bool bubbles = true,
    bool composed = true,
    bool cancelable = true,
  }) {
    final detailJs = dartToJsValue(detail);
    final eventInit = _newJsObject();
    _reflectSet(eventInit, 'detail', detailJs);
    _reflectSet(eventInit, 'bubbles', bubbles.toJS);
    _reflectSet(eventInit, 'composed', composed.toJS);
    _reflectSet(eventInit, 'cancelable', cancelable.toJS);

    final event = web.CustomEvent(type, eventInit as web.CustomEventInit);
    host.dispatchEvent(event);
  }

  void _notifyAttrChange(String name, String? newValue) {
    final sig = _attrSignals[name];
    if (sig != null) {
      sig.value = newValue;
    }
  }
}

/// Registers a native browser Custom Element with [tagName] backed by a Bloom descriptor tree.
///
/// Enables exporting Bloom components as standard Web Components consumable by any web application,
/// static HTML page, or non-Bloom framework (React, Vue, Angular, vanilla JS).
///
/// - **Lifecycle Management**: When the custom element connects to the DOM (`connectedCallback`),
///   it mounts the descriptor tree returned by [builder] via [mountToElement]. When disconnected
///   (`disconnectedCallback`), it tears down the mounted tree and disposes all reactive effects.
/// - **Shadow DOM**: By default, mounts into an open Shadow DOM (`useShadowDom: true`) for style
///   and DOM encapsulation.
/// - **Observed Attributes**: Attributes listed in [observedAttributes] trigger `attributeChangedCallback`
///   and update reactive signals accessible via [CustomElementContext.attributeSignal].
///
/// ```dart
/// void main() {
///   defineCustomElement(
///     'bloom-user-badge',
///     (context) {
///       final name = context.attributeSignal('name');
///       return Live(() => Div(
///         className: 'badge',
///         children: [
///           Text('User: ${name.value ?? 'Guest'}'),
///           Button(
///             text: 'Ping',
///             onClick: (e) => context.dispatchCustomEvent('badge-click', detail: {'name': name.value}),
///           ),
///         ],
///       ));
///     },
///     observedAttributes: ['name'],
///   );
/// }
/// ```
void defineCustomElement(
  String tagName,
  BloomNode Function(CustomElementContext context) builder, {
  List<String> observedAttributes = const [],
  bool useShadowDom = true,
  String shadowMode = 'open',
}) {
  final bridgeKey = '__bloom_ce_${tagName.replaceAll('-', '_')}';
  final handlesMap = <web.HTMLElement, BloomMountHandle>{};
  final contextsMap = <web.HTMLElement, CustomElementContext>{};

  void onConnect(web.HTMLElement host) {
    web.ShadowRoot? shadow;
    web.Element mountTarget = host;
    if (useShadowDom) {
      final shadowInit = _newJsObject();
      _reflectSet(shadowInit, 'mode', shadowMode.toJS);
      shadow = host.attachShadow(shadowInit as web.ShadowRootInit);
      // A ShadowRoot is a DocumentFragment, not an Element, so it cannot be
      // passed to mountToElement directly. Mount into a wrapper element inside
      // the shadow root instead; encapsulation is preserved either way.
      final wrapper = web.document.createElement('div') as web.HTMLDivElement;
      wrapper.setAttribute('style', 'display: contents;');
      shadow.appendChild(wrapper);
      mountTarget = wrapper;
    }
    final ctx = CustomElementContext(host: host, shadowRoot: shadow);
    contextsMap[host] = ctx;
    final node = builder(ctx);
    final handle = mountToElement(node, mountTarget);
    handlesMap[host] = handle;
  }

  void onDisconnect(web.HTMLElement host) {
    final handle = handlesMap.remove(host);
    handle?.unmount();
    contextsMap.remove(host);
  }

  void onAttrChange(
      web.HTMLElement host, String name, String? oldValue, String? newValue) {
    final ctx = contextsMap[host];
    ctx?._notifyAttrChange(name, newValue);
  }

  final bridge = _newJsObject();
  _reflectSet(
      bridge, 'onConnect', ((web.HTMLElement host) => onConnect(host)).toJS);
  _reflectSet(bridge, 'onDisconnect',
      ((web.HTMLElement host) => onDisconnect(host)).toJS);
  _reflectSet(
    bridge,
    'onAttrChange',
    ((web.HTMLElement host, JSString name, JSAny? oldVal, JSAny? newVal) {
      onAttrChange(
        host,
        name.toDart,
        oldVal != null && oldVal.isA<JSString>()
            ? (oldVal as JSString).toDart
            : null,
        newVal != null && newVal.isA<JSString>()
            ? (newVal as JSString).toDart
            : null,
      );
    }).toJS,
  );

  final jsWindow = web.window as JSAny;
  _reflectSet(jsWindow, bridgeKey, bridge);

  final attrsJson = observedAttributes.map((a) => '"$a"').join(',');

  final registerJs = '''
(function() {
  if (customElements.get('$tagName')) return;
  const bridge = window['$bridgeKey'];
  class BloomElement extends HTMLElement {
    static get observedAttributes() {
      return [$attrsJson];
    }
    connectedCallback() {
      if (bridge && bridge.onConnect) bridge.onConnect(this);
    }
    disconnectedCallback() {
      if (bridge && bridge.onDisconnect) bridge.onDisconnect(this);
    }
    attributeChangedCallback(name, oldValue, newValue) {
      if (bridge && bridge.onAttrChange) bridge.onAttrChange(this, name, oldValue, newValue);
    }
  }
  customElements.define('$tagName', BloomElement);
})();
''';

  _jsEval(registerJs);
}
