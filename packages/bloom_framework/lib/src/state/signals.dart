// lib/src/state/signals.dart
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

/// Create a fine-grained reactive state signal.
sf.Signal<T> signal<T>(T initialValue, {String? debugLabel}) {
  return sf.signal<T>(initialValue, debugLabel: debugLabel);
}

/// Create a computed (derived) reactive value.
sf.Computed<T> computed<T>(T Function() compute, {String? debugLabel}) {
  return sf.computed<T>(compute, debugLabel: debugLabel);
}

/// Run a reactive side-effect whenever any accessed signal changes.
/// Returns a disposer function.
void Function() effect(void Function() cb, {String? debugLabel}) {
  return sf.effect(cb, debugLabel: debugLabel);
}

/// Batch multiple signal updates into a single synchronous notification cycle.
T batch<T>(T Function() cb) {
  return sf.batch<T>(cb);
}

/// Create a read-only view of a signal.
sf.ReadonlySignal<T> readonly<T>(sf.Signal<T> signal) {
  return signal.readonly();
}
