/// Core reactivity module re-exporting reactive primitives from `package:signals`.
///
/// Re-exports Bloom's primary state primitives so developers can access reactivity
/// directly from the Bloom JS Native package without an explicit secondary dependency:
/// - `signal`: Creates mutable reactive state containers.
/// - `computed`: Derives readonly state from one or more signals with automatic dependency tracking.
/// - `effect`: Runs a side effect that automatically subscribes to signals read within its callback.
/// - `batch`: Batches multiple signal updates into a single notification pass.
/// - `untracked`: Reads a signal's value without subscribing the enclosing effect or computed callback.
/// - Types: `Signal`, `Computed`, `ReadonlySignal`, and `Effect`.
///
/// ```dart
/// final count = signal(0);
/// final isEven = computed(() => count.value.isEven);
///
/// BloomNode counter() => Live(() => Div(
///   children: [
///     Text('Count: ${count.value} (Even: ${isEven.value})'),
///     Button(onClick: (_) => count.value++, text: '+1'),
///   ],
/// ));
/// ```
library;

import 'package:signals/signals.dart' as s;

// Re-export core signal types & utilities matching Bloom framework conventions
export 'package:signals/signals.dart'
    show
        Signal,
        Computed,
        ReadonlySignal,
        Effect,
        signal,
        computed,
        effect,
        batch,
        untracked;

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
