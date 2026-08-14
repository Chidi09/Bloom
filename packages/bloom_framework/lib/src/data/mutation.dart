// lib/src/data/mutation.dart
import 'dart:async';
import '../core/logger.dart';
import '../state/signals.dart';
import 'cache.dart';

enum MutationStatus { idle, pending, success, error }

typedef MutationFn<T, P> = Future<T> Function(P params);
typedef OnMutateCallback<P> = FutureOr<dynamic> Function(P params);
typedef OnSuccessCallback<T, P> = FutureOr<void> Function(T data, P params, dynamic context);
typedef OnErrorCallback<P> = FutureOr<void> Function(Object error, P params, dynamic context);
typedef OnSettledCallback<T, P> = FutureOr<void> Function(T? data, Object? error, P params, dynamic context);
typedef OptimisticUpdater<T, P> = T? Function(P params, T? oldData);

/// Asynchronous mutation manager with automated optimistic updates, automatic rollback, and cache invalidation.
class BloomMutation<T, P> {
  final MutationFn<T, P> mutateFn;
  final List<dynamic>? optimisticKey;
  final OptimisticUpdater<T, P>? optimisticData;
  final List<List<dynamic>> invalidateKeys;
  final OnMutateCallback<P>? onMutate;
  final OnSuccessCallback<T, P>? onSuccess;
  final OnErrorCallback<P>? onError;
  final OnSettledCallback<T, P>? onSettled;

  late final Signal<T?> _data;
  late final Signal<MutationStatus> _status;
  late final Signal<Object?> _error;

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

  ReadonlySignal<T?> get data => _data.readonly();
  ReadonlySignal<MutationStatus> get status => _status.readonly();
  ReadonlySignal<Object?> get error => _error.readonly();

  bool get isIdle => _status.value == MutationStatus.idle;
  bool get isPending => _status.value == MutationStatus.pending;
  bool get isSuccess => _status.value == MutationStatus.success;
  bool get isError => _status.value == MutationStatus.error;

  /// Safely execute mutation with parameters [params].
  /// Catches errors and returns `null` on failure (state flags are updated).
  Future<T?> mutate(P params) async {
    try {
      return await mutateAsync(params);
    } catch (_) {
      return null;
    }
  }

  /// Execute mutation returning the resolved data or rethrowing the error.
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

  /// Reset mutation state to idle.
  void reset() {
    _data.value = null;
    _status.value = MutationStatus.idle;
    _error.value = null;
  }
}

/// Create a declarative mutation with optional automated optimistic rollback and cache invalidation.
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
