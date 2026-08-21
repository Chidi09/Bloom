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

/// Create a read-only view of a signal.
s.ReadonlySignal<T> readonly<T>(s.Signal<T> signal) {
  return signal.readonly();
}
