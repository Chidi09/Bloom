library;

import 'package:signals_core/signals_core.dart' as s;
import 'package:meta/meta.dart' show internal;
import '_signal_scope.dart';
import '_signals_stub.dart'
    if (dart.library.js_interop) '_signals_browser.dart';

// signals_core, not signals: `package:signals` depends on the Flutter SDK and
// on signals_flutter, which would make this package -- and everything built on
// it, including server-side rendering in bloom_server -- require Flutter.
// signals_core is the same reactivity engine with zero dependencies, and none
// of the Flutter-only bindings are used here.

// Re-export core signal types & utilities matching Bloom framework conventions
export 'package:signals_core/signals_core.dart'
    show Signal, Computed, ReadonlySignal, Effect, computed, batch, untracked;

/// Callback type accepted by [effect]. The result is ignored by the effect
/// engine, so callbacks may return any value.
typedef BloomEffectCallback = dynamic Function();

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

  final scope = currentBloomSignalScope;
  final scopedKey = scope == null ? key : '$scope|$key';

  try {
    final registry = getBrowserSignalRegistry();
    if (registry == null) {
      return s.signal<T>(initialValue);
    }

    final sig = s.signal<T>(initialValue);

    if (scope != null) {
      registerBloomScopedSignal(scope, scopedKey);
    }

    if (registry.containsKey(scopedKey)) {
      final stored = registry[scopedKey];
      if (stored is T) {
        sig.value = stored;
      }
    }

    sig.subscribe((val) {
      storeBrowserSignalValue(registry, scopedKey, val);
    });

    return sig;
  } catch (_) {
    return s.signal<T>(initialValue);
  }
}

/// Runs [callback] in a stable nested signal scope during DDC hot reload.
///
/// This is an implementation hook used by Bloom's development compiler to
/// isolate signals owned by stateful objects created at a stable call site.
/// It has no Zone overhead outside an active browser hot-reload session.
T bloomHmrScope<T>(String scopeId, T Function() callback) {
  if (!isBrowserHotReloadActive()) return callback();
  return runWithBloomSignalScope(scopeId, callback);
}

/// Runs [compute] reactively and returns a function that stops the effect.
///
/// While Bloom DDC hot-reload tracking is active, the returned cleanup is also
/// registered so the dev runtime can stop old module effects after updated
/// code attempts its in-place patch or remount. Outside that dev mode this
/// delegates directly to `signals_core`.
void Function() effect(
  BloomEffectCallback compute, {
  String? debugLabel,
  BloomEffectCallback? onDispose,
  @internal String? hotReloadScopeId,
}) {
  final parentScope = currentBloomSignalScope;
  final signalScope = hotReloadScopeId == null
      ? parentScope
      : composeBloomSignalScope(hotReloadScopeId);
  final scopedCompute = signalScope == null
      ? compute
      : () => runWithBloomSignalScopeValue(signalScope, compute);
  final cleanup = s.effect(
    scopedCompute,
    debugLabel: debugLabel,
    onDispose: onDispose,
  );
  if (!isBrowserHotReloadActive()) return cleanup;

  final registry = getBrowserHotEffectRegistry();
  if (registry == null) return cleanup;

  var disposed = false;
  late final void Function() trackedCleanup;
  trackedCleanup = () {
    if (disposed) return;
    disposed = true;
    registry.remove(trackedCleanup);
    cleanup();
  };
  registry.add(trackedCleanup);
  return trackedCleanup;
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
