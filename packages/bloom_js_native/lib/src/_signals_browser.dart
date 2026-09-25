import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'mount.dart';
import '_signal_scope.dart';

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

@JS('Reflect.set')
external bool _reflectSet(JSAny target, String key, JSAny? value);

const String _bloomSignalRegistryProp = '__bloom_signal_registry__';
const String _bloomHotEffectRegistryProp = '__bloom_hot_effect_registry__';
const String _bloomDisposeHotEffectsProp = '__bloomDisposeHotEffects';
const String _bloomPrepareHotEffectsProp = '__bloomPrepareHotEffects';
const String _bloomDisposePreviousHotEffectsProp =
    '__bloomDisposePreviousHotEffects';
List<void Function()> _previousHotEffects = [];

/// Maximum number of entries kept in the browser hot-reload signal registry.
///
/// Keyed signals (see `signal(initialValue, key: ...)`) persist their latest
/// value on `window` so it survives an in-page hot remount. Without a bound, a
/// long dev session that repeatedly renames or removes keyed call sites would
/// accumulate stale entries forever. Once this cap is exceeded, the
/// least-recently-used entry is evicted; an evicted key simply falls back to
/// the documented clean-reset behavior (fresh `initialValue`) on its next
/// remount. Every write refreshes the key's recency, so actively updated
/// signals are evicted last.
const int kMaxSignalRegistryEntries = 512;

bool isBrowserHotReloadActive() => isHotReloadTrackingActive();

Set<void Function()>? getBrowserHotEffectRegistry() {
  try {
    final win = web.window as JSAny;
    final boxed = _reflectGet(win, _bloomHotEffectRegistryProp);
    if (boxed != null && boxed.isA<JSBoxedDartObject>()) {
      final dartObj = (boxed as JSBoxedDartObject).toDart;
      if (dartObj is Set<void Function()>) {
        return dartObj;
      }
    }
    final registry = <void Function()>{};
    _reflectSet(win, _bloomHotEffectRegistryProp, registry.toJSBox);
    _reflectSet(
      win,
      _bloomDisposeHotEffectsProp,
      (() => disposeBrowserHotEffects()).toJS,
    );
    _reflectSet(
      win,
      _bloomPrepareHotEffectsProp,
      (() => prepareBrowserHotReloadEffects()).toJS,
    );
    _reflectSet(
      win,
      _bloomDisposePreviousHotEffectsProp,
      (() => disposePreviousBrowserHotEffects()).toJS,
    );
    return registry;
  } catch (_) {
    return null;
  }
}

/// Disposes every user-created effect currently registered in this DDC session.
///
/// Normal HMR uses [prepareBrowserHotReloadEffects] and
/// [disposePreviousBrowserHotEffects] to defer old cleanup until after the new
/// app has attempted its patch or remount. This immediate form remains useful
/// for explicit teardown and tests.
void disposeBrowserHotEffects() {
  final registry = getBrowserHotEffectRegistry();
  if (registry == null || registry.isEmpty) return;

  final pending = registry.toList(growable: false);
  registry.clear();
  for (final cleanup in pending) {
    try {
      cleanup();
    } catch (_) {}
  }
}

/// Moves effects from the old module aside so updated code can patch first.
void prepareBrowserHotReloadEffects() {
  beginBloomSignalScopeTransition();
  final registry = getBrowserHotEffectRegistry();
  if (registry == null) return;
  _previousHotEffects.addAll(registry);
  registry.clear();
}

/// Disposes old module effects after updated code has mounted or patched.
void disposePreviousBrowserHotEffects() {
  final pending = _previousHotEffects.toList(growable: false);
  _previousHotEffects.clear();
  for (final cleanup in pending) {
    try {
      cleanup();
    } catch (_) {}
  }
  finishBloomSignalScopeTransition();
}

Map<String, Object?>? getBrowserSignalRegistry() {
  try {
    final win = web.window as JSAny;
    final boxed = _reflectGet(win, _bloomSignalRegistryProp);
    if (boxed != null && boxed.isA<JSBoxedDartObject>()) {
      final dartObj = (boxed as JSBoxedDartObject).toDart;
      if (dartObj is Map<String, Object?>) {
        return dartObj;
      }
    }
    final map = <String, Object?>{};
    _reflectSet(win, _bloomSignalRegistryProp, map.toJSBox);
    return map;
  } catch (_) {
    return null;
  }
}

/// Stores [value] under [key] in the hot-reload signal [registry].
///
/// The write refreshes [key]'s recency and keeps the registry bounded at
/// [kMaxSignalRegistryEntries] entries: when a brand-new key overflows the
/// cap, the least-recently-used entry is evicted (FIFO over Dart's insertion
/// order, with re-written keys moved to the back — i.e. LRU).
void storeBrowserSignalValue(
  Map<String, Object?> registry,
  String key,
  Object? value,
) {
  // `remove` before insert so re-writing an existing key moves it to the end
  // of the map's insertion order; the first remaining key is then always the
  // least-recently-used one.
  registry.remove(key);
  registry[key] = value;
  while (registry.length > kMaxSignalRegistryEntries) {
    final evictedKey = registry.keys.first;
    registry.remove(evictedKey);
    forgetBloomScopedSignal(evictedKey);
  }
}
