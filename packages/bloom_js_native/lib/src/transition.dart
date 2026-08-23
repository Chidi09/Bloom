import 'dart:async';

import 'package:signals/signals.dart';

final Signal<bool> _isTransitionPending = signal(false);

/// Reactive read-only signal indicating whether a non-urgent transition update is pending.
///
/// Observes whether a background state transition initiated by [startTransition] is currently
/// executing. When [startTransition] is invoked, [isTransitionPending] becomes `true`
/// immediately and resets to `false` once the deferred microtask completes.
///
/// Reading this signal inside a [Live] region allows UI elements to render busy indicators,
/// spinners, or dimmed opacities without blocking immediate user interactions.
///
/// ```dart
/// Div(
///   children: [
///     Live(() => isTransitionPending.value
///         ? const Span(className: 'spinner', text: 'Updating list...')
///         : const Span(text: 'Up to date')),
///   ],
/// )
/// ```
ReadonlySignal<bool> get isTransitionPending => _isTransitionPending.readonly();

/// Defers a non-urgent state update to a microtask while tracking transition status via [isTransitionPending].
///
/// Immediately sets [isTransitionPending] to `true`, schedules [update] inside a
/// [scheduleMicrotask] block, and resets [isTransitionPending] to `false` when finished.
///
/// Use [startTransition] to keep high-frequency user interactions (like typing in a search box
/// or toggling a tab) responsive by deferring expensive derived computations or large state updates.
///
/// ```dart
/// Input(
///   attrs: {'placeholder': 'Filter items...'},
///   on: {
///     'input': (e) {
///       // Urgent: reflect keystroke in input signal immediately
///       searchQuery.value = e.value ?? '';
///
///       // Non-urgent: defer expensive list filtering to microtask
///       startTransition(() {
///         filteredItems.value = performExpensiveFilter(searchQuery.value);
///       });
///     },
///   },
/// )
/// ```
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

