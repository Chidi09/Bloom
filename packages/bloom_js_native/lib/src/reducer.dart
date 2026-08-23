// lib/src/reducer.dart
//
// Reducer-style state management, analogous to React's `useReducer`.
// Pure Dart, backed by the same `signals` package as the rest of the
// framework's reactivity — dispatching an action updates a signal, so
// existing `effect()`/component-rebuild machinery picks up the change
// exactly like any other signal write.
import 'package:signals_core/signals_core.dart';

/// A pure state-transition function that computes the next state from the current [state] and an [action].
///
/// Must be deterministic and free of side effects. Given the current state of type [S]
/// and an incoming action of type [A], it returns a new state of type [S].
///
/// Used by [BloomReducer] and [useReducer] to coordinate complex state machines.
///
/// ```dart
/// sealed class CounterAction {}
/// class Increment extends CounterAction { final int amount; Increment(this.amount); }
/// class Reset extends CounterAction {}
///
/// int counterReducer(int state, CounterAction action) => switch (action) {
///   Increment(:final amount) => state + amount,
///   Reset() => 0,
/// };
/// ```
typedef BloomReducerFn<S, A> = S Function(S state, A action);

/// A signal-backed state container managing complex state transitions via a pure reducer function.
///
/// [BloomReducer] provides Redux/React `useReducer`-style state management integrated
/// directly into the Bloom JS Native `signals` reactivity system. When an action is dispatched
/// via [dispatch], [reducerFn] calculates the next state and updates the underlying [Signal].
/// Any reactive consumer—such as a `Live` widget descriptor, `computed`, or `effect`—will
/// automatically re-render or re-evaluate in response.
///
/// ### Backend Behavior
/// - **Browser (`mount`)**: Fully reactive. State updates propagate to all subscribed DOM nodes
///   and effect scopes. Dispatched actions are recorded in [history].
/// - **SSR (`renderToHtml`)**: Safe to initialize and read on the server. During SSR, [state]
///   holds [BloomReducer]'s initial state (or any state reached before rendering), which is
///   read synchronously during HTML tree generation.
///
/// ### Example
/// ```dart
/// // 1. Define State & Actions
/// class TodoItem {
///   final String id;
///   final String title;
///   final bool done;
///   const TodoItem({required this.id, required this.title, this.done = false});
/// }
///
/// sealed class TodoAction {}
/// class AddTodo extends TodoAction { final String title; AddTodo(this.title); }
/// class ToggleTodo extends TodoAction { final String id; ToggleTodo(this.id); }
///
/// // 2. Define Pure Reducer
/// List<TodoItem> todoReducer(List<TodoItem> state, TodoAction action) => switch (action) {
///   AddTodo(:final title) => [
///       ...state,
///       TodoItem(id: '${state.length + 1}', title: title),
///     ],
///   ToggleTodo(:final id) => [
///       for (final item in state)
///         if (item.id == id)
///           TodoItem(id: item.id, title: item.title, done: !item.done)
///         else
///           item,
///     ],
/// };
///
/// // 3. Instantiate & Use in Component Tree
/// final todos = useReducer(todoReducer, const <TodoItem>[]);
///
/// BloomNode buildTodoList() {
///   return Div(
///     children: [
///       Button(
///         text: 'Add Task',
///         on: {'click': (e) => todos.dispatch(AddTodo('New Task'))},
///       ),
///       Live(() => Ul(
///         children: [
///           for (final item in todos.state.value)
///             Li(
///               text: item.title,
///               style: item.done ? 'text-decoration: line-through' : null,
///               on: {'click': (e) => todos.dispatch(ToggleTodo(item.id))},
///             ),
///         ],
///       )),
///     ],
///   );
/// }
/// ```
///
/// See also:
/// - [useReducer], a convenience function to create a [BloomReducer].
/// - [BloomReducerFn], the type signature for reducer transition functions.
class BloomReducer<S, A> {
  /// The pure state-transition function that derives the next state on each [dispatch].
  final BloomReducerFn<S, A> reducerFn;

  late final Signal<S> _state;

  /// A log of dispatched actions, oldest first. Primarily useful for
  /// debugging/dev-tools; not required for normal use.
  final List<A> _history = [];

  /// Creates a [BloomReducer] instance initialized with [reducerFn] and [initialState].
  ///
  /// Initializes an internal [Signal] with [initialState] and assigns a debug label
  /// for devtools inspection.
  ///
  /// ```dart
  /// final reducer = BloomReducer<int, CounterAction>(counterReducer, 0);
  /// ```
  BloomReducer(this.reducerFn, S initialState) {
    _state = signal<S>(initialState, debugLabel: '$runtimeType.state');
  }

  /// Reactive signal holding the current state.
  ///
  /// Reading `.value` inside a reactive context (such as `Live`, `computed`, or `effect`)
  /// tracks this signal as a dependency, triggering re-evaluation whenever an action
  /// is dispatched via [dispatch].
  ///
  /// ```dart
  /// Live(() => Div(text: 'Current: ${reducer.state.value}'))
  /// ```
  ReadonlySignal<S> get state => _state.readonly();

  /// An unmodifiable, chronological history of all actions dispatched to this reducer.
  ///
  /// The first element is the oldest dispatched action, and the last element is the most recent.
  /// Intended for diagnostic logging, testing, and devtools integration.
  List<A> get history => List.unmodifiable(_history);

  /// Dispatches [action], synchronously computing and applying the next state via [reducerFn].
  ///
  /// The action is appended to [history], and the returned state from [reducerFn] is
  /// assigned to [state]. All reactive listeners and `Live` boundaries observing [state]
  /// are notified synchronously.
  ///
  /// ```dart
  /// reducer.dispatch(Increment(5));
  /// ```
  void dispatch(A action) {
    _history.add(action);
    _state.value = reducerFn(_state.value, action);
  }
}

/// Creates a [BloomReducer] with the given [reducerFn] and [initialState].
///
/// Convenience factory named to mirror React's `useReducer(reducer, initialState)` convention.
/// Returns a state container wrapping a reactive [Signal] driven by [reducerFn].
///
/// ### Example
/// ```dart
/// final counter = useReducer<int, String>(
///   (count, action) => action == 'inc' ? count + 1 : count - 1,
///   0,
/// );
///
/// counter.dispatch('inc');
/// print(counter.state.value); // 1
/// ```
BloomReducer<S, A> useReducer<S, A>(
  BloomReducerFn<S, A> reducerFn,
  S initialState,
) {
  return BloomReducer<S, A>(reducerFn, initialState);
}
