// lib/src/web_components.dart
//
// Browser-only Web Components & Custom Elements interoperability module for Bloom JS Native.
// Requires package:web and dart:js_interop (exported via browser.dart).

import 'dart:async';
import 'dart:js_interop';

import 'package:signals_core/signals_core.dart';
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

/// Converts a Dart value into its corresponding JavaScript interop representation ([JSAny]).
///
/// Handles recursive conversion of nested Dart data structures into native JavaScript
/// types for setting rich DOM element properties on Custom Elements and Web Components:
/// - Primitives (`String`, `bool`, `int`, `double`) are converted via `.toJS`.
/// - [List] is recursively converted to a JavaScript `JSArray`.
/// - [Map] is recursively converted to a JavaScript `JSObject` with string keys.
/// - Closures (`void Function()`, `Object? Function()`, `void Function(Object?)`,
///   `Object? Function(Object?)`) are converted to `JSFunction` callbacks with automatic
///   bidirectional argument and return value conversion via [jsToDartValue] and [dartToJsValue].
/// - Existing [JSAny] instances pass through untouched.
/// - Other unhandled Dart types fall back to calling `toString().toJS`.
///
/// Used internally by [customElement] when setting [properties] on live DOM elements.
///
/// ```dart
/// final jsObj = dartToJsValue({
///   'title': 'Release v1.0',
///   'tags': ['web', 'bloom', 'dart'],
///   'config': {'active': true, 'retries': 3},
/// });
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

/// Converts a JavaScript interop value ([JSAny]) into its corresponding idiomatic Dart representation.
///
/// Recursively converts JavaScript types into native Dart data structures:
/// - `JSString` is converted to a Dart [String].
/// - `JSBoolean` is converted to a Dart [bool].
/// - `JSNumber` is converted to a Dart [int] if it represents a whole integer, or [double] otherwise.
/// - `JSArray` is recursively converted to a Dart `List<Object?>`.
/// - `JSObject` is recursively converted to a Dart `Map<String, Object?>` by enumerating keys via `Object.keys`.
///   If an object's keys cannot be extracted, the original [jsVal] is returned.
///
/// Used internally by [CustomElementEvent] to unwrap `event.detail` payloads into typed Dart values.
///
/// ```dart
/// final dartData = jsToDartValue(customEventDetail);
/// if (dartData is Map<String, Object?>) {
///   print('Item name: ${dartData['name']}');
/// }
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

/// A strongly-typed event wrapper for custom element DOM events carrying a deserialized [detail] payload.
///
/// When browser Custom Elements and Web Components (e.g. Shoelace, Lit, Vaadin, FAST) dispatch
/// custom DOM events (such as `sl-change`, `ionChange`, or `tab-select`), their event data payload
/// is carried in the `event.detail` property. [CustomElementEvent] automatically unwraps `detail`
/// into idiomatic Dart values ([Map], [List], primitives) of type [T] via [jsToDartValue].
///
/// ### Backend Execution Note
/// Custom element events are dispatched exclusively in the browser during client-side DOM mounting
/// via [mount]. Event listeners are never triggered during Server-Side Rendering ([renderToHtml]).
///
/// ```dart
/// customElement(
///   'sl-select',
///   events: {
///     'sl-change': (CustomElementEvent<dynamic> event) {
///       event.preventDefault();
///       print('Selected value: ${event.detail}');
///     },
///   },
/// )
/// ```
class CustomElementEvent<T> {
  /// The underlying native DOM [web.Event] instance.
  final web.Event rawEvent;

  /// The custom event type name string (e.g. `'sl-change'`, `'custom-select'`).
  final String type;

  /// The deserialized `event.detail` payload converted to Dart type [T].
  ///
  /// Primitives, objects (as `Map<String, Object?>`), and arrays (as `List<Object?>`)
  /// are automatically deserialized by [jsToDartValue].
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
  ///
  /// Forwards directly to [web.Event.preventDefault] on [rawEvent].
  ///
  /// ```dart
  /// event.preventDefault();
  /// ```
  void preventDefault() => rawEvent.preventDefault();

  /// Stops propagation of this event through the DOM hierarchy.
  ///
  /// Forwards directly to [web.Event.stopPropagation] on [rawEvent].
  ///
  /// ```dart
  /// event.stopPropagation();
  /// ```
  void stopPropagation() => rawEvent.stopPropagation();

  /// Whether [preventDefault] has been called on the underlying DOM event.
  ///
  /// Forwards directly to [web.Event.defaultPrevented] on [rawEvent].
  bool get defaultPrevented => rawEvent.defaultPrevented;
}

/// Handler callback signature for custom element events carrying a deserialized [detail] payload.
///
/// Used in the `events` map of [customElement] to listen to custom DOM events emitted by Web Components.
///
/// ```dart
/// final CustomElementEventHandler<dynamic> onSelection = (event) {
///   print('Selected: ${event.detail}');
/// };
/// ```
typedef CustomElementEventHandler<T> = void Function(
    CustomElementEvent<T> event);

// ─── Upgrade Guard ────────────────────────────────────────────────────────────

/// Asynchronously waits for a custom element tag to be registered and upgraded in the browser's `CustomElementRegistry`.
///
/// Calls `window.customElements.whenDefined(tag)` to ensure that the custom element's
/// class definition has been loaded and registered before interacting with its DOM properties.
///
/// ### Graceful Timeout Handling
/// If the custom element is already registered, the returned [Future] completes immediately.
/// If the definition has not yet loaded (e.g. while an external script is fetching asynchronously),
/// it waits up to [timeout] (defaulting to 3 seconds). If the timeout expires before registration
/// occurs, it completes gracefully rather than throwing or hanging indefinitely.
///
/// ```dart
/// await whenCustomElementDefined('sl-button', timeout: const Duration(seconds: 2));
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

/// Creates a [BloomNode] representing a browser Custom Element / Web Component with reactive property bindings, custom event listeners, and SSR attribute support.
///
/// Seamlessly integrates third-party Web Component libraries (such as Shoelace, Lit, Fast,
/// Material Web, Vaadin) and custom-authored elements into Bloom applications.
///
/// ### Properties vs Attributes Distinction
/// Understanding the difference between HTML attributes and JavaScript properties is essential:
/// - **Attributes** ([attrs]): Plain string key-value pairs serialized directly into the HTML tag
///   (e.g. `<sl-button variant="primary" size="medium">`). Attributes configure simple string or
///   boolean states and are emitted during Server-Side Rendering ([renderToHtml]).
/// - **Properties** ([properties]): Rich JavaScript values (objects, arrays, dates, numbers, functions)
///   assigned directly to the live DOM element instance via JS interop after mounting. Plain HTML
///   attributes cannot express nested structures or dynamic closures without awkward JSON stringification.
///
/// ### Reactive Property Updates via Signals
/// When a [Signal], [ReadonlySignal], or a getter closure `() => signal.value` is passed in [properties],
/// a fine-grained `effect` automatically tracks the signal dependency. Whenever the signal updates,
/// the property on the live DOM element instance is updated immediately in place without re-rendering,
/// replacing, or re-mounting the DOM node.
///
/// ### Custom Event Interop
/// The [events] map registers listeners for custom events emitted by the element (e.g. `'sl-change'`,
/// `'ionInput'`, `'date-selected'`). The `event.detail` payload is automatically deserialized into
/// native Dart types ([Map], [List], primitives) and wrapped in a [CustomElementEvent].
/// Listeners maintain stable JS function references and are cleanly removed on unmount.
/// Standard DOM events (`click`, `input`, `keydown`) can also be registered via [on].
///
/// ### Why [waitForUpgrade] Exists
/// Assigning a JavaScript property to an un-upgraded custom element before its class definition is
/// registered via `customElements.define` creates an "own property" directly on the `HTMLElement`
/// instance. When the custom element definition subsequently loads and upgrades, the element class's
/// prototype getter/setter is shadowed by the instance own-property, causing broken component state
/// or lost reactivity.
///
/// When [waitForUpgrade] is `true` (the default), Bloom awaits `customElements.whenDefined(tag)`
/// (up to [upgradeTimeout]) before applying properties, ensuring prototype setters execute correctly.
/// If the definition never arrives within [upgradeTimeout], the guard times out gracefully and assigns
/// properties to prevent indefinite blocking.
///
/// ### Server-Side Rendering (SSR) Behavior
/// During SSR (`renderToHtml`), [customElement] emits the custom element HTML tag (`<${tag} ...>`)
/// with its [attrs], [className], [style], [children], and [text] as static HTML for instant first paint
/// and SEO indexing.
///
/// [properties], [events], [on], [ref], and upgrade guards are completely browser-only and run during
/// client-side hydration and mounting ([mount]).
///
/// ### Cleanup on Unmount
/// All event listeners registered through [events] and all reactive property signal effects are
/// automatically unregistered and disposed when the custom element is unmounted from the DOM.
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
///
/// ```dart
/// defineCustomElement(
///   'user-card',
///   (CustomElementContext context) {
///     final name = context.attributeSignal('user-name');
///     return Live(() => Div(
///       children: [
///         H1(text: name.value ?? 'Anonymous'),
///         Button(
///           text: 'Select',
///           onClick: (e) => context.dispatchCustomEvent('user-select', detail: {'name': name.value}),
///         ),
///       ],
///     ));
///   },
///   observedAttributes: ['user-name'],
/// );
/// ```
class CustomElementContext {
  /// The host [web.HTMLElement] instance.
  final web.HTMLElement host;

  /// The attached [web.ShadowRoot], or `null` if Shadow DOM was disabled (`useShadowDom: false`).
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
  /// Reading this signal inside a [Live] or [effect] creates a reactive dependency on the DOM attribute.
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

  /// Synchronously reads the current string value of attribute [name] on [host].
  ///
  /// Returns `null` if the attribute is not set.
  ///
  /// ```dart
  /// final id = context.getAttribute('data-id');
  /// ```
  String? getAttribute(String name) => host.getAttribute(name);

  /// Dispatches a custom DOM event from the [host] element with [type] and [detail].
  ///
  /// The [detail] payload is converted to JavaScript via [dartToJsValue].
  /// By default, `bubbles: true` and `composed: true` are enabled so the event traverses
  /// both normal DOM boundaries and Shadow DOM boundaries.
  ///
  /// ```dart
  /// context.dispatchCustomEvent('change', detail: {'value': 42, 'valid': true});
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
/// Enables authoring reusable Web Components in pure Dart and Bloom JS Native, which can then
/// be consumed by any web application, static HTML page, or non-Bloom framework (React, Vue,
/// Angular, Svelte, vanilla JS).
///
/// ### Lifecycle Integration
/// - **Connected Callback (`connectedCallback`)**: When the custom element connects to the DOM,
///   it mounts the descriptor tree returned by [builder] via [mountToElement] into the host element
///   (or a wrapper within the Shadow DOM).
/// - **Disconnected Callback (`disconnectedCallback`)**: When removed from the DOM, it unmounts
///   the Bloom tree and disposes all reactive signals and effects.
/// - **Attribute Changed Callback (`attributeChangedCallback`)**: Attributes listed in [observedAttributes]
///   are observed; when modified on the DOM element, changes are automatically pushed to the reactive
///   signals created via [CustomElementContext.attributeSignal].
///
/// ### Shadow DOM Encapsulation
/// By default, creates an open Shadow DOM (`useShadowDom: true`, `shadowMode: 'open'`) and mounts the
/// Bloom subtree into an internal wrapper `<div style="display: contents;">` to maintain full style
/// and DOM encapsulation. Set `useShadowDom: false` to mount directly into the light DOM of the host element.
///
/// ### Browser-Only Execution
/// [defineCustomElement] requires the browser's `customElements` registry, `window`, and JavaScript
/// evaluation. It does not execute during Server-Side Rendering (`renderToHtml`).
///
/// ```dart
/// void main() {
///   defineCustomElement(
///     'bloom-user-badge',
///     (CustomElementContext context) {
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
