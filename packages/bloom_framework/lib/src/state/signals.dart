/// Fine-grained reactive state primitives for Bloom applications.
///
/// Built on top of `package:signals_flutter`, providing signals, computed values,
/// reactive side effects, batching, and Flutter widget integrations.
library;

import 'package:signals_flutter/signals_flutter.dart' as sf;

// Re-export core signal types & valid extensions
export 'package:signals_flutter/signals_flutter.dart'
    show
        Signal,
        Computed,
        ReadonlySignal,
        Effect,
        Watch,
        SignalsMixin;

/// Creates a fine-grained reactive state signal with an [initialValue].
///
/// Signals hold a value and notify dependent widgets, effects, and computed values
/// synchronously when their value changes.
///
/// Example:
/// ```dart
/// final counter = signal(0);
/// counter.value++;
/// ```
sf.Signal<T> signal<T>(T initialValue, {String? debugLabel}) {
  return sf.signal<T>(initialValue, debugLabel: debugLabel);
}

/// Creates a computed (derived) reactive value.
///
/// Re-evaluates automatically whenever any signals read inside [compute] change.
/// The result is cached until an upstream signal dependency updates.
///
/// Example:
/// ```dart
/// final firstName = signal('Ada');
/// final lastName = signal('Lovelace');
/// final fullName = computed(() => '${firstName.value} ${lastName.value}');
/// ```
sf.Computed<T> computed<T>(T Function() compute, {String? debugLabel}) {
  return sf.computed<T>(compute, debugLabel: debugLabel);
}

/// Runs a reactive side-effect callback [cb] whenever any accessed signal changes.
///
/// Returns a disposer function that cancels future executions of the effect.
///
/// Example:
/// ```dart
/// final count = signal(0);
/// final dispose = effect(() {
///   print('Count is now: ${count.value}');
/// });
/// count.value = 1; // prints "Count is now: 1"
/// dispose(); // Stops the effect
/// ```
void Function() effect(void Function() cb, {String? debugLabel}) {
  return sf.effect(cb, debugLabel: debugLabel);
}

/// Batches multiple signal updates into a single synchronous notification cycle.
///
/// Prevents intermediate states from triggering redundant recomputations or UI rebuilds.
///
/// Example:
/// ```dart
/// batch(() {
///   firstName.value = 'Grace';
///   lastName.value = 'Hopper';
/// });
/// ```
T batch<T>(T Function() cb) {
  return sf.batch<T>(cb);
}

/// Creates a read-only view of a [signal].
///
/// Prevents consumers from directly modifying the underlying value.
///
/// Example:
/// ```dart
/// final _internalCount = signal(0);
/// ReadonlySignal<int> get count => readonly(_internalCount);
/// ```
sf.ReadonlySignal<T> readonly<T>(sf.Signal<T> signal) {
  return signal.readonly();
}

