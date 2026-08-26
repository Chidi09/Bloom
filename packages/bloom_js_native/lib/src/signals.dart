library;

import 'dart:js_interop';
import 'package:signals_core/signals_core.dart' as s;
import 'package:web/web.dart' as web;

import 'mount.dart';

// signals_core, not signals: `package:signals` depends on the Flutter SDK and
// on signals_flutter, which would make this package -- and everything built on
// it, including server-side rendering in bloom_server -- require Flutter.
// signals_core is the same reactivity engine with zero dependencies, and none
// of the Flutter-only bindings are used here.

// Re-export core signal types & utilities matching Bloom framework conventions
export 'package:signals_core/signals_core.dart'
    show
        Signal,
        Computed,
        ReadonlySignal,
        Effect,
        computed,
        effect,
        batch,
        untracked;

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

@JS('Reflect.set')
external bool _reflectSet(JSAny target, String key, JSAny? value);

const String _bloomSignalRegistryProp = '__bloom_signal_registry__';

Map<String, Object?> _getOrCreateSignalRegistry(JSAny win) {
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
}

/// Creates a reactive [Signal] container initialized to [initialValue].
///
/// When hot-reload tracking is active ([isHotReloadTrackingActive]) and a non-null
/// [key] is supplied (either explicitly or injected at compile-time by Bloom's DDC dev loop),
/// the signal's value survives in-page module re-executions across hot remounts.
///
/// If the stored value type does not match [T], the signal cleanly resets to [initialValue].
s.Signal<T> signal<T>(T initialValue, {String? key}) {
  if (key == null || !isHotReloadTrackingActive()) {
    return s.signal<T>(initialValue);
  }

  try {
    final win = web.window as JSAny;
    final registry = _getOrCreateSignalRegistry(win);
    final sig = s.signal<T>(initialValue);

    if (registry.containsKey(key)) {
      final stored = registry[key];
      if (stored is T) {
        sig.value = stored;
      }
    }

    sig.subscribe((val) {
      registry[key] = val;
    });

    return sig;
  } catch (_) {
    return s.signal<T>(initialValue);
  }
}

/// Creates a read-only view of [signal] to prevent external mutation.
///
/// Returns a [s.ReadonlySignal] wrapping [signal].
///
/// ```dart
/// final _count = signal(0);
/// final count = readonly(_count);
/// ```
s.ReadonlySignal<T> readonly<T>(s.Signal<T> signal) {
  return signal.readonly();
}
