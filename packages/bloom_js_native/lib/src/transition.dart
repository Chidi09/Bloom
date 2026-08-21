import 'dart:async';

import 'package:signals/signals.dart';

final Signal<bool> _isTransitionPending = signal(false);

/// Reactive readonly signal indicating whether a non-urgent transition update is running.
ReadonlySignal<bool> get isTransitionPending => _isTransitionPending.readonly();

/// Executes non-urgent state updates inside a deferred transition frame.
void startTransition(void Function() update) {
  _isTransitionPending.value = true;
  scheduleMicrotask(() {
    try {
      update();
    } finally {
      _isTransitionPending.value = false;
    }
  });
}
