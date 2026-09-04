import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'mount.dart';

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

@JS('Reflect.set')
external bool _reflectSet(JSAny target, String key, JSAny? value);

const String _bloomSignalRegistryProp = '__bloom_signal_registry__';

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
    registry.remove(registry.keys.first);
  }
}
