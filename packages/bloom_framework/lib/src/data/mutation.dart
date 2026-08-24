// lib/src/data/mutation.dart
import 'dart:async';
import '../core/logger.dart';
import '../state/signals.dart';
import 'cache.dart';

/// Lifecycle execution status of a [BloomMutation].
///
/// Example:
/// ```dart
/// if (postMutation.status.value == MutationStatus.pending) {
///   // show spinner
/// }
/// ```
enum MutationStatus {
  /// Mutation has not been executed yet or has been reset.
  idle,

  /// Mutation execution is currently in progress.
  pending,

  /// Mutation executed successfully.
  success,

  /// Mutation execution encountered an error.
  error,
}

/// The asynchronous execution function that performs the mutation operation.
typedef MutationFn<T, P> = Future<T> Function(P params);

/// Hook called immediately prior to executing the mutation, returning an optional context object.
typedef OnMutateCallback<P> = FutureOr<dynamic> Function(P params);

/// Hook called upon successful mutation completion.
typedef OnSuccessCallback<T, P> = FutureOr<void> Function(T data, P params, dynamic context);

/// Hook called when a mutation throws an error.
typedef OnErrorCallback<P> = FutureOr<void> Function(Object error, P params, dynamic context);

/// Hook called after mutation settled (either succeeded or failed).
typedef OnSettledCallback<T, P> = FutureOr<void> Function(T? data, Object? error, P params, dynamic context);

/// Optimistic update transformation function updating cached data prior to network response.
typedef OptimisticUpdater<T, P> = T? Function(P params, T? oldData);

/// Asynchronous mutation manager with automated optimistic updates, automatic rollback, and cache invalidation.
///
/// Encapsulates execution state signals ([data], [status], [error]), executes optimistic updates
/// against [BloomData] query cache, rolls back automatically on error, and invalidates target query keys.
///
/// Example:
/// ```dart
/// final createPost = BloomMutation<Post, Map<String, dynamic>>(
///   mutateFn: (params) => api.createPost(params),
///   optimisticKey: ['posts'],
///   optimisticData: (params, oldPosts) => [Post.fromMap(params), ...?oldPosts],
///   invalidateKeys: [['posts']],
/// );
///
/// await createPost.mutate({'title': 'New Article'});
/// ```
class BloomMutation<T, P> {
  /// The underlying mutation execution function.
  final MutationFn<T, P> mutateFn;

  /// Optional query cache key targeted for optimistic updates.
  final List<dynamic>? optimisticKey;

  /// Optimistic data transformation callback applied before network resolution.
  final OptimisticUpdater<T, P>? optimisticData;

  /// List of query cache keys to invalidate upon successful completion.
  final List<List<dynamic>> invalidateKeys;

  /// Optional hook invoked before mutation execution.
  final OnMutateCallback<P>? onMutate;

  /// Optional hook invoked on successful mutation.
  final OnSuccessCallback<T, P>? onSuccess;

  /// Optional hook invoked on mutation error.
  final OnErrorCallback<P>? onError;

  /// Optional hook invoked when mutation settles.
  final OnSettledCallback<T, P>? onSettled;

  late final Signal<T?> _data;
  late final Signal<MutationStatus> _status;
  late final Signal<Object?> _error;

  /// Creates a [BloomMutation] instance.
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
    _status = signal<MutationStatus>(MutationStatus.idle, debugLabel: 'mutation.status');
    _error = signal<Object?>(null, debugLabel: 'mutation.error');
  }

  /// Reactive signal holding the latest successful result data, or `null`.
  ReadonlySignal<T?> get data => _data.readonly();

  /// Reactive signal indicating the current mutation lifecycle status.
  ReadonlySignal<MutationStatus> get status => _status.readonly();

  /// Reactive signal holding any error thrown during execution, or `null`.
  ReadonlySignal<Object?> get error => _error.readonly();

  /// Whether the mutation is in [MutationStatus.idle] status.
  bool get isIdle => _status.value == MutationStatus.idle;

  /// Whether the mutation is actively executing in background.
  bool get isPending => _status.value == MutationStatus.pending;

  /// Whether the mutation succeeded.
  bool get isSuccess => _status.value == MutationStatus.success;

  /// Whether the mutation failed with an error.
  bool get isError => _status.value == MutationStatus.error;

  /// Safely executes mutation with parameters [params].
  ///
  /// Catches errors and returns `null` on failure (state signals are updated with the error).
  ///
  /// Example:
  /// ```dart
  /// final result = await createPost.mutate({'title': 'Hello'});
  /// ```
  Future<T?> mutate(P params) async {
    try {
      return await mutateAsync(params);
    } catch (_) {
      return null;
    }
  }

  /// Executes mutation returning the resolved data [T] or rethrowing the caught error.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final post = await createPost.mutateAsync({'title': 'Hello'});
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
          (old) => optimisticData!(params, old),
        );
      }
    }

    // 2. Custom onMutate hook
    if (onMutate != null) {
      try {
        context = await onMutate!(params);
      } catch (err) {
        logger.warn('Error inside onMutate hook: $err');
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
    } catch (err, st) {
      logger.error('Mutation execution failed: $err', err, st);
      _error.value = err;
      _status.value = MutationStatus.error;

      // 4. Automated Optimistic Rollback
      if (optimisticKey != null) {
        logger.info('BloomMutation: Automatically rolling back optimistic update for [${BloomData.normalizeKey(optimisticKey!)}]');
        BloomData.setQueryData<T>(optimisticKey!, (_) => autoPreviousSnapshot);
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

  /// Resets mutation state signals to [MutationStatus.idle] and clears data and error.
  ///
  /// Example:
  /// ```dart
  /// createPost.reset();
  /// ```
  void reset() {
    _data.value = null;
    _status.value = MutationStatus.idle;
    _error.value = null;
  }
}

/// Creates a declarative mutation with optional automated optimistic rollback and cache invalidation.
///
/// Example:
/// ```dart
/// final deleteItem = mutation<bool, int>(
///   mutate: (id) => api.deleteItem(id),
///   invalidateKeys: [['items']],
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
