// lib/src/mutation.dart
import 'dart:async';

import 'package:signals_core/signals_core.dart';

import 'data.dart';

/// Lifecycle execution status of a [BloomMutation].
enum MutationStatus {
  /// Mutation has not been executed yet or was reset via [BloomMutation.reset].
  idle,

  /// Mutation execution is actively in-flight.
  pending,

  /// Mutation completed successfully and result data is accessible in [BloomMutation.data].
  success,

  /// Mutation execution failed with an exception, accessible in [BloomMutation.error].
  error,
}

/// The asynchronous execution function that performs a mutation operation.
///
/// Accepts parameters of type [P] and resolves to a result of type [T].
///
/// ```dart
/// MutationFn<Task, CreateTaskParams> createTask = (params) => client.post('/tasks', body: params.toJson());
/// ```
typedef MutationFn<T, P> = Future<T> Function(P params);

/// Lifecycle hook called immediately prior to executing a mutation.
///
/// May return an arbitrary context object (such as a rollback snapshot or telemetry token)
/// which is subsequently passed to [OnSuccessCallback], [OnErrorCallback], and [OnSettledCallback].
/// Any exception thrown inside [onMutate] is swallowed to ensure the mutation proceeds.
///
/// ```dart
/// OnMutateCallback<String> onMutate = (id) {
///   print('Deleting task $id');
///   return {'startTime': DateTime.now()};
/// };
/// ```
typedef OnMutateCallback<P> = FutureOr<dynamic> Function(P params);

/// Lifecycle hook invoked upon successful completion of a mutation.
///
/// Receives the resolved [data] of type [T], the original [params] of type [P],
/// and the optional [context] returned by [OnMutateCallback].
///
/// ```dart
/// OnSuccessCallback<Task, CreateTaskParams> onSuccess = (task, params, context) {
///   print('Created task with ID: ${task.id}');
/// };
/// ```
typedef OnSuccessCallback<T, P> = FutureOr<void> Function(
    T data, P params, dynamic context);

/// Lifecycle hook invoked when a mutation throws an error.
///
/// Receives the thrown [error], the original [params] of type [P],
/// and the optional [context] returned by [OnMutateCallback].
///
/// ```dart
/// OnErrorCallback<CreateTaskParams> onError = (err, params, context) {
///   showToast('Failed to create task: $err');
/// };
/// ```
typedef OnErrorCallback<P> = FutureOr<void> Function(
    Object error, P params, dynamic context);

/// Lifecycle hook invoked when a mutation settles (either resolved successfully or failed with an error).
///
/// Always executes after [OnSuccessCallback] or [OnErrorCallback]. Receives nullable [data] and [error],
/// the original [params], and the [context].
///
/// ```dart
/// OnSettledCallback<Task, CreateTaskParams> onSettled = (data, error, params, context) {
///   stopLoadingSpinner();
/// };
/// ```
typedef OnSettledCallback<T, P> = FutureOr<void> Function(
    T? data, Object? error, P params, dynamic context);

/// Optimistic update transformation function updating cached data in [BloomData] prior to network response.
///
/// Given the mutation [params] and existing cached data [oldData] for [BloomMutation.optimisticKey],
/// returns the projected new data of type `T?`. If the mutation subsequently fails, [BloomMutation]
/// automatically rolls back the cache to its pre-mutation snapshot.
///
/// ```dart
/// OptimisticUpdater<List<Task>, Task> addOptimisticTask = (newTask, currentTasks) {
///   return [...?currentTasks, newTask];
/// };
/// ```
typedef OptimisticUpdater<T, P> = T? Function(P params, T? oldData);

/// Asynchronous mutation manager with automated optimistic updates, automatic rollback,
/// and cache invalidation.
///
/// [BloomMutation] orchestrates side-effecting operations (such as HTTP `POST`, `PUT`, `DELETE`):
/// - **Optimistic Updates**: Immediately writes anticipated state changes into the [BloomData] cache
///   via [optimisticData] before the network response completes.
/// - **Automated Rollback**: If the network call fails or throws, [BloomMutation] automatically reverts
///   the cache entry at [optimisticKey] to its exact pre-mutation snapshot.
/// - **Cache Invalidation**: Automatically calls [BloomData.invalidateQueries] for all keys in [invalidateKeys]
///   upon successful completion, triggering background refetches in active [BloomQuery] instances.
/// - **Reactive Signals**: Exposes [data], [status], and [error] as [ReadonlySignal] instances,
///   allowing UI components to track loading and error states reactively.
///
/// ### Execution Flow
/// 1. [status] changes to [MutationStatus.pending] and [error] is cleared to `null`.
/// 2. If [optimisticKey] and [optimisticData] are set, snapshot current cache data and apply optimistic update.
/// 3. [onMutate] hook is executed; its returned value becomes the `context`.
/// 4. [mutateFn] is executed with the supplied parameters.
/// 5. **On Success**:
///    - [data] is set to the resolved result, [status] becomes [MutationStatus.success].
///    - Cache queries in [invalidateKeys] are invalidated.
///    - [onSuccess] and [onSettled] hooks are awaited.
/// 6. **On Error**:
///    - [error] is set to the thrown exception, [status] becomes [MutationStatus.error].
///    - If [optimisticKey] was modified, the cache is automatically rolled back to the pre-mutation snapshot.
///    - [onError] and [onSettled] hooks are awaited.
///    - [mutateAsync] rethrows the error, while [mutate] catches it and returns `null`.
///
/// ### Backend Behavior
/// - **Browser (`mount`)**: Subscribed `Live` descriptors update reactively across pending, success, and error states.
/// - **SSR (`renderToHtml`)**: Safe to instantiate. Initial state is [MutationStatus.idle].
///
/// ### Example
/// ```dart
/// final createTodo = mutation<Todo, String>(
///   mutate: (title) => httpClient.post<Todo>('/todos', body: {'title': title}),
///   optimisticKey: ['todos'],
///   optimisticData: (title, oldTodos) => [
///     ...?oldTodos as List<Todo>?,
///     Todo(id: 'temp-id', title: title, done: false),
///   ],
///   invalidateKeys: [['todos']],
///   onError: (err, title, context) => print('Failed to add todo: $err'),
/// );
///
/// BloomNode buildAddTodoForm() {
///   return Div(
///     children: [
///       Button(
///         text: 'Create',
///         on: {'click': (e) => createTodo.mutate('Buy groceries')},
///       ),
///       Live(() => createTodo.isPending ? Span(text: ' Saving...') : Span(text: '')),
///     ],
///   );
/// }
/// ```
///
/// See also:
/// - [mutation], the convenience factory function for creating mutations.
/// - [BloomQuery], for managing cached queries that this mutation invalidates.
/// - [BloomData], the underlying cache manager.
class BloomMutation<T, P> {
  /// The underlying asynchronous execution function performing the mutation.
  final MutationFn<T, P> mutateFn;

  /// Optional query cache key targeted for automated optimistic updates and rollback.
  final List<dynamic>? optimisticKey;

  /// Optimistic data transformation callback applied to the cache before network resolution.
  final OptimisticUpdater<T, P>? optimisticData;

  /// List of query cache key prefixes invalidated upon successful mutation completion.
  final List<List<dynamic>> invalidateKeys;

  /// Optional hook invoked immediately prior to executing the mutation.
  final OnMutateCallback<P>? onMutate;

  /// Optional hook invoked upon successful mutation resolution.
  final OnSuccessCallback<T, P>? onSuccess;

  /// Optional hook invoked when the mutation fails with an error.
  final OnErrorCallback<P>? onError;

  /// Optional hook invoked when the mutation settles (either success or error).
  final OnSettledCallback<T, P>? onSettled;

  late final Signal<T?> _data;
  late final Signal<MutationStatus> _status;
  late final Signal<Object?> _error;

  /// Creates a [BloomMutation] instance with execution hooks and cache invalidation targets.
  BloomMutation({
    required this.mutateFn,
    this.optimisticKey,
    this.optimisticData,
    this.invalidateKeys = const [],
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
  }) {
    _data = signal<T?>(null, debugLabel: 'mutation.data');
    _status = signal<MutationStatus>(MutationStatus.idle,
        debugLabel: 'mutation.status');
    _error = signal<Object?>(null, debugLabel: 'mutation.error');
  }

  /// Reactive signal holding the latest successful result data, or `null` if unexecuted or failed.
  ReadonlySignal<T?> get data => _data.readonly();

  /// Reactive signal indicating the current lifecycle [MutationStatus] (`idle`, `pending`, `success`, `error`).
  ReadonlySignal<MutationStatus> get status => _status.readonly();

  /// Reactive signal holding the unhandled exception thrown during execution, or `null` if idle/successful.
  ReadonlySignal<Object?> get error => _error.readonly();

  /// Whether the mutation is in [MutationStatus.idle] status (unexecuted or reset).
  bool get isIdle => _status.value == MutationStatus.idle;

  /// Whether the mutation is actively in-flight ([MutationStatus.pending]).
  bool get isPending => _status.value == MutationStatus.pending;

  /// Whether the mutation completed successfully ([MutationStatus.success]).
  bool get isSuccess => _status.value == MutationStatus.success;

  /// Whether the mutation failed with an error ([MutationStatus.error]).
  bool get isError => _status.value == MutationStatus.error;

  /// Safely executes the mutation with [params].
  ///
  /// Catches any thrown exceptions and returns `null` on failure (updating [status] and [error] signals).
  ///
  /// ```dart
  /// final result = await createTodo.mutate('New Task');
  /// if (result != null) {
  ///   print('Success');
  /// }
  /// ```
  Future<T?> mutate(P params) async {
    try {
      return await mutateAsync(params);
    } catch (_) {
      return null;
    }
  }

  /// Executes the mutation with [params], returning the resolved data or rethrowing the caught error.
  ///
  /// Useful when callers want standard `try`/`catch` error handling at the call site.
  ///
  /// ```dart
  /// try {
  ///   final task = await createTodo.mutateAsync('New Task');
  ///   print('Created: ${task.id}');
  /// } catch (e) {
  ///   print('Failed: $e');
  /// }
  /// ```
  Future<T> mutateAsync(P params) async {
    _status.value = MutationStatus.pending;
    _error.value = null;

    dynamic context;
    T? autoPreviousSnapshot;

    // 1. Automated Optimistic Update Snapshot & Application
    if (optimisticKey != null) {
      autoPreviousSnapshot = BloomData.getQueryData<T>(optimisticKey!);
      if (optimisticData != null) {
        BloomData.setQueryData<T>(
          optimisticKey!,
          (old) => optimisticData!(params, old) as T,
        );
      }
    }

    // 2. Custom onMutate hook
    if (onMutate != null) {
      try {
        context = await onMutate!(params);
      } catch (_) {
        // Swallow onMutate errors — don't block the mutation
      }
    }

    try {
      final result = await mutateFn(params);
      _data.value = result;
      _status.value = MutationStatus.success;
      _error.value = null;

      // 3. Automated Cache Invalidation
      for (final key in invalidateKeys) {
        BloomData.invalidateQueries(key);
      }

      if (onSuccess != null) {
        await onSuccess!(result, params, context);
      }
      if (onSettled != null) {
        await onSettled!(result, null, params, context);
      }

      return result;
    } catch (err) {
      _error.value = err;
      _status.value = MutationStatus.error;

      // 4. Automated Optimistic Rollback
      if (optimisticKey != null) {
        BloomData.setQueryData<T>(
            optimisticKey!, (_) => autoPreviousSnapshot as T);
      }

      if (onError != null) {
        await onError!(err, params, context);
      }
      if (onSettled != null) {
        await onSettled!(null, err, params, context);
      }

      rethrow;
    }
  }

  /// Resets the mutation state back to [MutationStatus.idle], clearing [data] and [error] to `null`.
  ///
  /// ```dart
  /// createTodo.reset();
  /// ```
  void reset() {
    _data.value = null;
    _status.value = MutationStatus.idle;
    _error.value = null;
  }
}

/// Creates a declarative [BloomMutation] with optional optimistic rollback and automatic cache invalidation.
///
/// Convenience factory function for [BloomMutation].
///
/// ```dart
/// final deleteTask = mutation<void, int>(
///   mutate: (id) => api.deleteTask(id),
///   invalidateKeys: [['tasks']],
/// );
/// ```
BloomMutation<T, P> mutation<T, P>({
  required MutationFn<T, P> mutate,
  List<dynamic>? optimisticKey,
  OptimisticUpdater<T, P>? optimisticData,
  List<List<dynamic>> invalidateKeys = const [],
  OnMutateCallback<P>? onMutate,
  OnSuccessCallback<T, P>? onSuccess,
  OnErrorCallback<P>? onError,
  OnSettledCallback<T, P>? onSettled,
}) {
  return BloomMutation<T, P>(
    mutateFn: mutate,
    optimisticKey: optimisticKey,
    optimisticData: optimisticData,
    invalidateKeys: invalidateKeys,
    onMutate: onMutate,
    onSuccess: onSuccess,
    onError: onError,
    onSettled: onSettled,
  );
}
