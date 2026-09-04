library;

import 'package:signals_core/signals_core.dart' as s;
import '_signals_stub.dart'
    if (dart.library.js_interop) '_signals_browser.dart';

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

/// Creates a reactive [Signal] container initialized to [initialValue].
///
/// When hot-reload tracking is active and a non-null [key] is supplied,
/// the signal's value survives in-page module re-executions across hot remounts.
///
/// If the stored value type does not match [T], the signal cleanly resets to [initialValue].
///
/// The browser-side registry backing keyed signals is bounded at
/// [kMaxSignalRegistryEntries] entries with least-recently-used eviction, so a
/// long dev session cannot grow it without limit; an evicted key simply resets
/// to [initialValue] on its next remount. Zero overhead when no key is given or
/// tracking is inactive.
s.Signal<T> signal<T>(T initialValue, {String? key}) {
  if (key == null || !isBrowserHotReloadActive()) {
    return s.signal<T>(initialValue);
  }

  try {
    final registry = getBrowserSignalRegistry();
    if (registry == null) {
      return s.signal<T>(initialValue);
    }

    final sig = s.signal<T>(initialValue);

    if (registry.containsKey(key)) {
      final stored = registry[key];
      if (stored is T) {
        sig.value = stored;
      }
    }

    sig.subscribe((val) {
      storeBrowserSignalValue(registry, key, val);
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
