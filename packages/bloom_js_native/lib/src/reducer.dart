// lib/src/reducer.dart
//
// Reducer-style state management, analogous to React's `useReducer`.
// Pure Dart, backed by the same `signals` package as the rest of the
// framework's reactivity — dispatching an action updates a signal, so
// existing `effect()`/component-rebuild machinery picks up the change
// exactly like any other signal write.
import 'package:signals/signals.dart';

/// A pure state-transition function: given the current [state] and an
/// [action], returns the next state. Must not perform side effects.
typedef BloomReducerFn<S, A> = S Function(S state, A action);

/// Signal-backed reducer state container, analogous to React's
/// `useReducer`. Dispatch actions to transition [state] through
/// [reducerFn]; reactive consumers observe [state] like any other signal.
class BloomReducer<S, A> {
  /// The pure reducer function driving state transitions.
  final BloomReducerFn<S, A> reducerFn;

  late final Signal<S> _state;

  /// A log of dispatched actions, oldest first. Primarily useful for
  /// debugging/dev-tools; not required for normal use.
  final List<A> _history = [];

  BloomReducer(this.reducerFn, S initialState) {
    _state = signal<S>(initialState, debugLabel: '$runtimeType.state');
  }

  /// Reactive signal holding the current state.
  ReadonlySignal<S> get state => _state.readonly();

  /// Read-only view of dispatched actions, oldest first.
  List<A> get history => List.unmodifiable(_history);

  /// Dispatches [action], synchronously computing and applying the next
  /// state via [reducerFn].
  void dispatch(A action) {
    _history.add(action);
    _state.value = reducerFn(_state.value, action);
  }
}

/// Creates a [BloomReducer] with the given [reducerFn] and [initialState].
/// Named to mirror React's `useReducer(reducer, initialState)` call shape.
BloomReducer<S, A> useReducer<S, A>(
  BloomReducerFn<S, A> reducerFn,
  S initialState,
) {
  return BloomReducer<S, A>(reducerFn, initialState);
}
