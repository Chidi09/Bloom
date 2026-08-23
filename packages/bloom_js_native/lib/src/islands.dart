// lib/src/islands.dart
//
// Island registry and partial hydration orchestrator for Bloom JS Native.
// Discovers server-rendered island placeholders in the browser DOM and hydrates
// them according to configurable hydration strategies with prop deserialization
// and isolated error handling.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dev_error_overlay.dart';
import 'devtools.dart';
import 'framework.dart';
import 'hydrate.dart';
import 'island_node.dart';
import 'mount.dart';

export 'island_node.dart';

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

@JS('Reflect.apply')
external JSAny? _reflectApply(
  JSFunction target,
  JSAny thisArg,
  JSArray<JSAny?> arguments,
);

/// Lifecycle status of an island instance managed by [BloomIslandOrchestrator].
///
/// ```dart
/// if (instance.status == IslandStatus.hydrated) {
///   print('Island is interactive');
/// }
/// ```
enum IslandStatus {
  /// The island placeholder has been discovered but its hydration strategy trigger has not fired yet.
  pending,

  /// The island has been successfully hydrated and is actively interactive.
  hydrated,

  /// An error occurred during props extraction, builder execution, or DOM hydration.
  failed,

  /// The island instance has been unmounted and its resources have been released.
  disposed,
}

/// Builder function that instantiates a [BloomNode] tree for an island, given its decoded [props].
///
/// Invoked by [BloomIslandOrchestrator] when an island's [HydrationStrategy] triggers.
///
/// ```dart
/// BloomNode counterBuilder(Map<String, dynamic> props) {
///   final count = signal(props['initialCount'] as int? ?? 0);
///   return Button(
///     text: 'Count: ${count.value}',
///     on: {'click': (_) => count.value++},
///   );
/// }
/// ```
typedef BloomIslandBuilder = BloomNode Function(Map<String, dynamic> props);

/// Specification of a registered island component definition.
///
/// Associates an island [name] with its descriptor [builder] callback and an optional
/// fallback [defaultStrategy].
///
/// ```dart
/// final def = BloomIslandDefinition(
///   name: 'user-cart',
///   builder: (props) => CartWidget(userId: props['userId']),
///   defaultStrategy: HydrationStrategy.visible,
/// );
/// ```
class BloomIslandDefinition {
  /// The unique string identifier for this island (e.g. `'shopping-cart'`).
  final String name;

  /// The factory callback creating the island's [BloomNode] descriptor tree.
  final BloomIslandBuilder builder;

  /// The default hydration strategy applied when the placeholder element does not specify one.
  final HydrationStrategy defaultStrategy;

  /// Creates a new island definition.
  const BloomIslandDefinition({
    required this.name,
    required this.builder,
    this.defaultStrategy = HydrationStrategy.immediate,
  });
}

// ─── Island Registry ────────────────────────────────────────────────────────

/// Registry storing client-side island builders keyed by name.
///
/// Allows registering interactive island components prior to DOM readiness or hydration orchestration.
/// Applications typically register islands at entry point boot time before calling [orchestrateIslands].
///
/// ```dart
/// final registry = BloomIslandRegistry();
/// registry.register('like-button', (props) {
///   return Button(text: 'Like');
/// });
/// ```
class BloomIslandRegistry {
  final Map<String, BloomIslandDefinition> _definitions = {};

  /// The default singleton registry instance used by top-level [registerIsland] and [orchestrateIslands].
  static final BloomIslandRegistry instance = BloomIslandRegistry();

  /// Creates an empty island registry.
  BloomIslandRegistry();

  /// Registers an island builder under [name] with an optional fallback [defaultStrategy].
  ///
  /// Overwrites any previously registered definition with the same [name].
  ///
  /// ```dart
  /// registry.register('search-box', (props) {
  ///   return Input(attrs: {'placeholder': props['placeholder'] ?? 'Search'});
  /// }, defaultStrategy: HydrationStrategy.interaction);
  /// ```
  void register(
    String name,
    BloomIslandBuilder builder, {
    HydrationStrategy defaultStrategy = HydrationStrategy.immediate,
  }) {
    _definitions[name] = BloomIslandDefinition(
      name: name,
      builder: builder,
      defaultStrategy: defaultStrategy,
    );
  }

  /// Removes the definition for [name] from the registry.
  ///
  /// Returns `true` if a definition was found and removed, `false` otherwise.
  bool unregister(String name) => _definitions.remove(name) != null;

  /// Looks up the [BloomIslandDefinition] registered under [name], or returns `null` if not found.
  BloomIslandDefinition? get(String name) => _definitions[name];

  /// Returns `true` if an island builder is registered under [name].
  bool has(String name) => _definitions.containsKey(name);

  /// Clears all registered island definitions from this registry.
  void clear() => _definitions.clear();

  /// An unmodifiable view of all registered island definitions.
  Map<String, BloomIslandDefinition> get definitions =>
      Map.unmodifiable(_definitions);
}

/// Registers an island builder in the default global [BloomIslandRegistry.instance].
///
/// Allows defining interactive island components before the DOM is loaded or scanned.
///
/// ```dart
/// registerIsland('cart-badge', (props) {
///   final items = signal(props['count'] as int? ?? 0);
///   return Span(className: 'badge', text: '${items.value}');
/// });
/// ```
void registerIsland(
  String name,
  BloomIslandBuilder builder, {
  HydrationStrategy defaultStrategy = HydrationStrategy.immediate,
}) {
  BloomIslandRegistry.instance.register(
    name,
    builder,
    defaultStrategy: defaultStrategy,
  );
}

/// Removes an island definition by [name] from the global [BloomIslandRegistry.instance].
///
/// Returns `true` if the island was registered and removed.
///
/// ```dart
/// unregisterIsland('cart-badge');
/// ```
bool unregisterIsland(String name) =>
    BloomIslandRegistry.instance.unregister(name);

// ─── Props Deserializer ─────────────────────────────────────────────────────

/// Extracts decoded props from an island placeholder [element].
///
/// Reads the [bloomPropsAttribute] (`data-bloom-props`) attribute on [element].
/// If absent or unparseable, looks for a child `<script type="application/json">`
/// element inside [element].
///
/// Handles raw JSON strings, URI-encoded JSON strings, and malformed syntax without throwing.
/// Returns an empty map if no props payload is present or if decoding fails.
///
/// ```dart
/// final props = extractIslandProps(element);
/// print('Product ID: ${props["productId"]}');
/// ```
Map<String, dynamic> extractIslandProps(web.Element element) {
  final attr = element.getAttribute(bloomPropsAttribute);
  if (attr != null && attr.trim().isNotEmpty) {
    final trimmed = attr.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      try {
        final uriDecoded = Uri.decodeComponent(trimmed);
        final decoded = jsonDecode(uriDecoded);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {}
    }
  }

  try {
    final script = element.querySelector('script[type="application/json"]');
    if (script != null) {
      final content = script.textContent?.trim();
      if (content != null && content.isNotEmpty) {
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      }
    }
  } catch (_) {}

  return const <String, dynamic>{};
}

// ─── Island Instance & Orchestration ────────────────────────────────────────

/// Represents an individual island placeholder element discovered in the browser DOM.
///
/// Tracks the island's name, host element, parsed props, assigned [HydrationStrategy],
/// and active lifecycle [status]. Owns the [BloomMountHandle] once hydrated.
///
/// ```dart
/// final orchestrator = orchestrateIslands();
/// for (final island in orchestrator.islands) {
///   print('Discovered island: ${island.name} [${island.status}]');
/// }
/// ```
class BloomIslandInstance {
  /// The registered name of this island (e.g. `'shopping-cart'`).
  final String name;

  /// The host DOM element carrying the `data-bloom-island` placeholder attribute.
  final web.Element element;

  /// The hydration strategy governing when this island activates.
  final HydrationStrategy strategy;

  /// The decoded props payload passed to the island builder.
  final Map<String, dynamic> props;

  final BloomIslandOrchestrator _orchestrator;
  IslandStatus _status = IslandStatus.pending;
  BloomMountHandle? _mountHandle;
  Object? _error;
  StackTrace? _stackTrace;
  bool _isHydrating = false;

  final List<void Function()> _cleanupCallbacks = [];

  /// Creates a new island instance record.
  BloomIslandInstance._({
    required this.name,
    required this.element,
    required this.strategy,
    required this.props,
    required BloomIslandOrchestrator orchestrator,
  }) : _orchestrator = orchestrator;

  /// The current lifecycle status of this island instance.
  IslandStatus get status => _status;

  /// Whether this island has successfully hydrated.
  bool get isHydrated => _status == IslandStatus.hydrated;

  /// Whether this island is still awaiting its strategy trigger.
  bool get isPending => _status == IslandStatus.pending;

  /// Whether hydration failed due to a builder or DOM exception.
  bool get isFailed => _status == IslandStatus.failed;

  /// Whether this island has been disposed.
  bool get isDisposed => _status == IslandStatus.disposed;

  /// The active [BloomMountHandle] managing this island's reactive scope, or `null` if not hydrated.
  BloomMountHandle? get mountHandle => _mountHandle;

  /// The error object thrown if hydration failed, or `null`.
  Object? get error => _error;

  /// The stack trace captured if hydration failed, or `null`.
  StackTrace? get stackTrace => _stackTrace;

  void _addCleanup(void Function() cleanup) {
    _cleanupCallbacks.add(cleanup);
  }

  void _runCleanups() {
    for (final cleanup in _cleanupCallbacks) {
      try {
        cleanup();
      } catch (_) {}
    }
    _cleanupCallbacks.clear();
  }

  /// Triggers immediate hydration of this island instance.
  ///
  /// Guaranteed to execute hydration at most once. If already hydrated, failed, or disposed,
  /// returns the existing [mountHandle] (or `null`).
  ///
  /// ```dart
  /// await islandInstance.hydrate();
  /// ```
  Future<BloomMountHandle?> hydrate() async {
    if (_status != IslandStatus.pending || _isHydrating) {
      return _mountHandle;
    }
    _isHydrating = true;
    _runCleanups();

    try {
      final definition = _orchestrator.registry.get(name);
      if (definition == null) {
        throw StateError(
          'Bloom island: no builder registered for island "$name".',
        );
      }

      final node = definition.builder(props);
      final handle = hydrateElement(node, element);
      _mountHandle = handle;
      _status = IslandStatus.hydrated;
      _isHydrating = false;

      try {
        element.setAttribute(bloomHydratedAttribute, 'true');
      } catch (_) {}

      BloomJsDevTools.notify('island-hydrated', {
        'name': name,
        'strategy': strategy.value,
      });

      return handle;
    } catch (err, stack) {
      _status = IslandStatus.failed;
      _error = err;
      _stackTrace = stack;
      _isHydrating = false;

      BloomJsDevTools.notify('mount-error', {
        'error': err.toString(),
        'stackTrace': stack.toString(),
        'island': name,
      });

      if (bloomDevErrorOverlayEnabled) {
        element.textContent = '';
        final overlayHost = web.document.createElement('div');
        overlayHost.innerHTML = renderDevErrorOverlay(
          err,
          stack,
          componentName: 'Island: $name',
        ).toJS;
        element.appendChild(overlayHost);
      }

      return null;
    }
  }

  /// Disposes this island instance, releasing reactive effects and unmounting DOM listeners.
  ///
  /// Safe to call multiple times.
  ///
  /// ```dart
  /// islandInstance.dispose();
  /// ```
  void dispose() {
    if (_status == IslandStatus.disposed) return;
    _runCleanups();
    _status = IslandStatus.disposed;
    try {
      _mountHandle?.dispose();
    } catch (_) {}
    _mountHandle = null;
  }
}

/// Orchestrates discovery, hydration strategy evaluation, and lifecycle management for Bloom islands.
///
/// Scans the document for placeholder DOM elements marked with [bloomIslandAttribute]
/// (`data-bloom-island`), matches them against registered island builders in [registry],
/// and evaluates their respective [HydrationStrategy] triggers.
///
/// ### Failure Isolation
/// If an island builder throws an exception or fails to hydrate, the error is captured and
/// reported through [BloomJsDevTools] (and [renderDevErrorOverlay] in development), leaving
/// all other islands on the page completely unaffected and functioning normally.
///
/// ### Lifecycle and Teardown
/// When tearing down or navigating away, call [dispose] to disconnect all intersection observers,
/// remove attached interaction event listeners, cancel idle timers, and dispose mounted islands.
///
/// ```dart
/// registerIsland('cart', (props) => Cart(count: props['count']));
///
/// final orchestrator = BloomIslandOrchestrator();
/// orchestrator.scan();
///
/// // Later on teardown:
/// orchestrator.dispose();
/// ```
class BloomIslandOrchestrator {
  /// The island registry providing component builders for discovered placeholders.
  final BloomIslandRegistry registry;

  /// The root DOM element scanned for island placeholders. Defaults to `document.body`.
  final web.Element? rootElement;

  /// Default root margin applied to [HydrationStrategy.visible] intersection observers.
  final String defaultRootMargin;

  final List<BloomIslandInstance> _islands = [];
  final Map<String, web.IntersectionObserver> _intersectionObservers = {};
  final List<void Function()> _globalDisposers = [];
  bool _disposed = false;

  /// Creates a new island orchestrator.
  ///
  /// If [autoScan] is `true` (the default), automatically executes [scan] on initialization.
  BloomIslandOrchestrator({
    BloomIslandRegistry? registry,
    this.rootElement,
    this.defaultRootMargin = '200px',
    bool autoScan = true,
  }) : registry = registry ?? BloomIslandRegistry.instance {
    if (autoScan) {
      scan();
    }
  }

  /// Whether this orchestrator has been disposed.
  bool get isDisposed => _disposed;

  /// An unmodifiable list of all island instances currently tracked by this orchestrator.
  List<BloomIslandInstance> get islands => List.unmodifiable(_islands);

  /// All island instances currently awaiting hydration triggers.
  List<BloomIslandInstance> get pendingIslands =>
      _islands.where((i) => i.isPending).toList();

  /// All island instances that have successfully hydrated into interactive subtrees.
  List<BloomIslandInstance> get hydratedIslands =>
      _islands.where((i) => i.isHydrated).toList();

  /// All island instances that failed during hydration.
  List<BloomIslandInstance> get failedIslands =>
      _islands.where((i) => i.isFailed).toList();

  /// Scans [root] (or [rootElement], or `document`) for unhydrated island placeholders.
  ///
  /// Creates a [BloomIslandInstance] for each discovered element and initializes its
  /// hydration strategy listener. Returns the list of newly discovered island instances.
  ///
  /// ```dart
  /// final newIslands = orchestrator.scan();
  /// print('Found ${newIslands.length} new islands');
  /// ```
  List<BloomIslandInstance> scan([web.Element? root]) {
    if (_disposed) return const [];

    final container = root ?? rootElement ?? web.document.body ?? web.document.documentElement;
    if (container == null) return const [];

    final selector = '[$bloomIslandAttribute]:not([$bloomHydratedAttribute="true"])';
    final nodes = container.querySelectorAll(selector);
    final newlyDiscovered = <BloomIslandInstance>[];

    for (var i = 0; i < nodes.length; i++) {
      final item = nodes.item(i);
      if (item == null || !item.isA<web.Element>()) continue;
      final el = item as web.Element;

      // Skip elements already tracked
      if (_islands.any((inst) => inst.element == el)) continue;

      final name = el.getAttribute(bloomIslandAttribute);
      if (name == null || name.trim().isEmpty) continue;

      final def = registry.get(name.trim());
      final rawStrategy = el.getAttribute(bloomStrategyAttribute);
      final strategy = rawStrategy != null && rawStrategy.isNotEmpty
          ? HydrationStrategy.parse(rawStrategy, defaultStrategy: def?.defaultStrategy ?? HydrationStrategy.immediate)
          : (def?.defaultStrategy ?? HydrationStrategy.immediate);

      final props = extractIslandProps(el);
      final instance = BloomIslandInstance._(
        name: name.trim(),
        element: el,
        strategy: strategy,
        props: props,
        orchestrator: this,
      );

      _islands.add(instance);
      newlyDiscovered.add(instance);
      _setupStrategyTrigger(instance);
    }

    return newlyDiscovered;
  }

  void _setupStrategyTrigger(BloomIslandInstance instance) {
    if (_disposed || instance.status != IslandStatus.pending) return;

    switch (instance.strategy) {
      case HydrationStrategy.immediate:
        scheduleMicrotask(() {
          if (!_disposed && instance.isPending) {
            instance.hydrate();
          }
        });

      case HydrationStrategy.visible:
        _setupVisibleTrigger(instance);

      case HydrationStrategy.idle:
        _setupIdleTrigger(instance);

      case HydrationStrategy.interaction:
        _setupInteractionTrigger(instance);

      case HydrationStrategy.media:
        _setupMediaTrigger(instance);

      case HydrationStrategy.never:
        // Stays static.
        break;
    }
  }

  void _setupVisibleTrigger(BloomIslandInstance instance) {
    final margin = instance.element.getAttribute(bloomRootMarginAttribute) ?? defaultRootMargin;
    final observer = _getOrCreateObserver(margin);
    observer.observe(instance.element);

    instance._addCleanup(() {
      try {
        observer.unobserve(instance.element);
      } catch (_) {}
    });
  }

  web.IntersectionObserver _getOrCreateObserver(String rootMargin) {
    if (_intersectionObservers.containsKey(rootMargin)) {
      return _intersectionObservers[rootMargin]!;
    }

    final observer = web.IntersectionObserver(
      ((JSArray<web.IntersectionObserverEntry> entries, web.IntersectionObserver obs) {
        for (final entry in entries.toDart) {
          if (entry.isIntersecting) {
            final target = entry.target;
            obs.unobserve(target);
            final match = _islands.firstWhere(
              (inst) => inst.element == target,
              orElse: () => _BloomDummyIslandInstance(),
            );
            if (match is! _BloomDummyIslandInstance && match.isPending) {
              match.hydrate();
            }
          }
        }
      }).toJS,
      web.IntersectionObserverInit(rootMargin: rootMargin),
    );

    _intersectionObservers[rootMargin] = observer;
    return observer;
  }

  void _setupIdleTrigger(BloomIslandInstance instance) {
    var cancelled = false;
    Timer? fallbackTimer;
    int? idleHandle;

    try {
      final ric = _reflectGet(web.window, 'requestIdleCallback');
      if (ric != null && ric.isA<JSFunction>()) {
        final jsCb = ((JSAny? _) {
          if (!cancelled && !_disposed && instance.isPending) {
            instance.hydrate();
          }
        }).toJS;
        final res = _reflectApply(ric as JSFunction, web.window, [jsCb].toJS);
        if (res != null && res.isA<JSNumber>()) {
          idleHandle = (res as JSNumber).toDartInt;
        }
      } else {
        fallbackTimer = Timer(const Duration(milliseconds: 50), () {
          if (!cancelled && !_disposed && instance.isPending) {
            instance.hydrate();
          }
        });
      }
    } catch (_) {
      fallbackTimer = Timer(const Duration(milliseconds: 50), () {
        if (!cancelled && !_disposed && instance.isPending) {
          instance.hydrate();
        }
      });
    }

    instance._addCleanup(() {
      cancelled = true;
      fallbackTimer?.cancel();
      if (idleHandle != null) {
        try {
          final cic = _reflectGet(web.window, 'cancelIdleCallback');
          if (cic != null && cic.isA<JSFunction>()) {
            _reflectApply(cic as JSFunction, web.window, [idleHandle.toJS].toJS);
          }
        } catch (_) {}
      }
    });
  }

  void _setupInteractionTrigger(BloomIslandInstance instance) {
    final events = const ['pointerenter', 'pointerdown', 'focusin', 'keydown', 'touchstart'];
    late web.EventListener listener;
    var removed = false;

    void removeListeners() {
      if (removed) return;
      removed = true;
      for (final ev in events) {
        try {
          instance.element.removeEventListener(ev, listener);
        } catch (_) {}
      }
    }

    listener = ((web.Event e) {
      removeListeners();
      if (!_disposed && instance.isPending) {
        instance.hydrate();
      }
    }).toJS;

    for (final ev in events) {
      instance.element.addEventListener(ev, listener);
    }

    instance._addCleanup(removeListeners);
  }

  void _setupMediaTrigger(BloomIslandInstance instance) {
    final mediaQuery = instance.element.getAttribute(bloomMediaAttribute);
    if (mediaQuery == null || mediaQuery.trim().isEmpty) {
      instance.hydrate();
      return;
    }

    try {
      final mql = web.window.matchMedia(mediaQuery.trim());
      if (mql.matches) {
        instance.hydrate();
        return;
      }

      late web.EventListener listener;
      var removed = false;

      void removeListener() {
        if (removed) return;
        removed = true;
        try {
          mql.removeEventListener('change', listener);
        } catch (_) {}
      }

      listener = ((web.Event e) {
        if (mql.matches) {
          removeListener();
          if (!_disposed && instance.isPending) {
            instance.hydrate();
          }
        }
      }).toJS;

      mql.addEventListener('change', listener);
      instance._addCleanup(removeListener);
    } catch (_) {
      instance.hydrate();
    }
  }

  /// Manually triggers hydration of the island hosted at [element].
  ///
  /// Returns the resulting [BloomMountHandle], or `null` if hydration failed.
  ///
  /// ```dart
  /// final element = web.document.querySelector('#special-island')!;
  /// await orchestrator.hydrateIsland(element);
  /// ```
  Future<BloomMountHandle?> hydrateIsland(web.Element element) async {
    if (_disposed) return null;
    var instance = _islands.cast<BloomIslandInstance?>().firstWhere(
          (inst) => inst?.element == element,
          orElse: () => null,
        );
    if (instance == null) {
      final newOnes = scan(element);
      if (newOnes.isNotEmpty) {
        instance = newOnes.first;
      }
    }
    return instance?.hydrate();
  }

  /// Forces all currently pending islands to hydrate immediately.
  ///
  /// ```dart
  /// await orchestrator.hydrateAll();
  /// ```
  Future<void> hydrateAll() async {
    if (_disposed) return;
    final pending = pendingIslands;
    await Future.wait([for (final inst in pending) inst.hydrate()]);
  }

  /// Tears down the orchestrator, releasing observers, removing event listeners,
  /// and disposing all hydrated island subtrees.
  ///
  /// ```dart
  /// orchestrator.dispose();
  /// ```
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    for (final observer in _intersectionObservers.values) {
      try {
        observer.disconnect();
      } catch (_) {}
    }
    _intersectionObservers.clear();

    for (final island in _islands) {
      island.dispose();
    }
    _islands.clear();

    for (final disposer in _globalDisposers) {
      try {
        disposer();
      } catch (_) {}
    }
    _globalDisposers.clear();
  }
}

class _BloomDummyIslandInstance extends BloomIslandInstance {
  _BloomDummyIslandInstance()
      : super._(
          name: '',
          element: web.document.createElement('div'),
          strategy: HydrationStrategy.never,
          props: const {},
          orchestrator: BloomIslandOrchestrator(autoScan: false),
        );
}

/// Boots and starts an island orchestrator managing client-side island hydration.
///
/// Scans the document for placeholder DOM elements marked with [bloomIslandAttribute],
/// attaches hydration listeners according to their [HydrationStrategy], and returns
/// the active [BloomIslandOrchestrator] handle.
///
/// ```dart
/// void main() {
///   registerIsland('nav-menu', (props) => NavigationMenu());
///   registerIsland('cart', (props) => ShoppingCart(items: props['items']));
///
///   final orchestrator = orchestrateIslands();
/// }
/// ```
BloomIslandOrchestrator orchestrateIslands({
  BloomIslandRegistry? registry,
  web.Element? rootElement,
  String defaultRootMargin = '200px',
}) {
  return BloomIslandOrchestrator(
    registry: registry,
    rootElement: rootElement,
    defaultRootMargin: defaultRootMargin,
    autoScan: true,
  );
}

