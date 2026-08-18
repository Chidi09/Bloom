// lib/src/data/offline_queue.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import '../core/logger.dart';
import 'cache.dart';
import 'storage.dart';

/// Conflict resolution strategy when replaying offline mutations against the server.
enum ConflictPolicy {
  /// Keep the client mutation and override conflicting server state.
  clientWins,
  /// Discard the client mutation and keep existing server state.
  serverWins,
  /// Invoke a custom [CustomConflictResolver] to merge or handle conflicts.
  custom,
}

/// Execution function that sends an offline mutation payload to the server.
typedef MutationExecutor = Future<dynamic> Function(Map<String, dynamic> payload);

/// Custom conflict resolution handler resolving differences between client payload and server error.
typedef CustomConflictResolver = FutureOr<Map<String, dynamic>?> Function(
  Map<String, dynamic> clientPayload,
  Object serverError,
);

/// A persisted mutation entry stored in the offline queue waiting to be synced.
class QueuedMutation {
  /// Unique mutation ID.
  final String id;

  /// Identifier representing the type/action of mutation (e.g. `'create_post'`).
  final String mutationType;

  /// Serialized payload data for this mutation.
  Map<String, dynamic> payload;

  /// Timestamp when this mutation was enqueued.
  final DateTime createdAt;

  /// Conflict resolution policy applied if replaying fails.
  final ConflictPolicy conflictPolicy;

  /// Number of replay attempts already made.
  int retryCount;

  /// Creates a [QueuedMutation] entry.
  QueuedMutation({
    required this.id,
    required this.mutationType,
    required this.payload,
    required this.createdAt,
    this.conflictPolicy = ConflictPolicy.clientWins,
    this.retryCount = 0,
  });

  /// Serializes this mutation entry to a JSON-compatible map.
  Map<String, dynamic> toMap() => {
        'id': id,
        'mutationType': mutationType,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'conflictPolicy': conflictPolicy.name,
        'retryCount': retryCount,
      };

  /// Deserializes a [QueuedMutation] from a map.
  factory QueuedMutation.fromMap(Map<String, dynamic> map) {
    return QueuedMutation(
      id: map['id']?.toString() ?? '',
      mutationType: map['mutationType']?.toString() ?? '',
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      conflictPolicy: ConflictPolicy.values.firstWhere(
        (e) => e.name == map['conflictPolicy'],
        orElse: () => ConflictPolicy.clientWins,
      ),
      retryCount: map['retryCount'] is int ? map['retryCount'] as int : 0,
    );
  }
}

/// Persistent offline mutation buffer and replay engine.
class OfflineMutationQueue {
  /// Storage adapter used to persist queued mutations across restarts.
  final BloomStorageAdapter? storage;
  static const String _storageKey = 'bloom_offline_mutation_queue';

  final List<QueuedMutation> _queue = [];
  final Map<String, MutationExecutor> _executors = HashMap<String, MutationExecutor>();
  final Map<String, CustomConflictResolver> _resolvers = HashMap<String, CustomConflictResolver>();
  bool _isProcessing = false;

  /// Default singleton instance for global application use.
  static final OfflineMutationQueue instance = OfflineMutationQueue();

  /// Total count of pending mutations in the default queue instance.
  static int get pendingCount => instance.queueDepth;

  /// Creates an [OfflineMutationQueue] with an optional [storage] adapter.
  OfflineMutationQueue({this.storage});

  /// Total number of pending mutations currently waiting in queue.
  int get queueDepth => _queue.length;

  /// Number of mutations currently in queue (alias for [queueDepth]).
  int get length => _queue.length;

  /// Whether the queue is currently empty.
  bool get isEmpty => _queue.isEmpty;

  /// Whether the queue is currently in the middle of replaying mutations.
  bool get isProcessing => _isProcessing;

  /// Unmodifiable list of pending mutations waiting in queue.
  List<QueuedMutation> get pendingMutations => List.unmodifiable(_queue);

  /// Register a mutation executor for a given type name.
  void registerExecutor(
    String mutationType,
    MutationExecutor executor, {
    CustomConflictResolver? conflictResolver,
  }) {
    _executors[mutationType] = executor;
    if (conflictResolver != null) {
      _resolvers[mutationType] = conflictResolver;
    }
  }

  /// Restore persisted mutations from disk.
  Future<void> restore() async {
    if (storage == null) return;
    try {
      final raw = await storage!.read(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _queue.clear();
        for (final item in list) {
          _queue.add(QueuedMutation.fromMap(Map<String, dynamic>.from(item as Map)));
        }
        logger.info('OfflineMutationQueue: Restored ${_queue.length} mutations from persistent storage.');
      }
    } catch (e) {
      logger.error('OfflineMutationQueue: Failed to restore mutations from storage: $e');
    }
  }

  /// Persist current queue to storage.
  Future<void> persist() async {
    if (storage == null) return;
    try {
      final list = _queue.map((m) => m.toMap()).toList();
      await storage!.write(_storageKey, jsonEncode(list));
    } catch (e) {
      logger.error('OfflineMutationQueue: Failed to persist mutations to storage: $e');
    }
  }

  /// Enqueue an optimistic mutation when disconnected.
  Future<String> enqueue({
    String? mutationType,
    String? tag,
    required Map<String, dynamic> payload,
    ConflictPolicy conflictPolicy = ConflictPolicy.clientWins,
  }) async {
    final type = mutationType ?? tag ?? 'unknown';
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final mutation = QueuedMutation(
      id: id,
      mutationType: type,
      payload: payload,
      createdAt: DateTime.now(),
      conflictPolicy: conflictPolicy,
    );

    _queue.add(mutation);
    logger.info('OfflineMutationQueue: Queued mutation [$type] (id: $id). Queue depth: ${_queue.length}');
    await persist();
    return id;
  }

  /// Replay pending mutations sequentially FIFO with conflict policy handling.
  Future<int> processQueue([FutureOr<dynamic> Function(QueuedMutation)? customHandler]) async {
    if (_isProcessing || _queue.isEmpty) return 0;
    _isProcessing = true;

    int syncedCount = 0;
    final toRemove = <QueuedMutation>[];

    logger.info('OfflineMutationQueue: Replaying ${_queue.length} pending mutations...');

    for (final mutation in _queue) {
      final executor = customHandler != null
          ? ((_) => customHandler(mutation))
          : _executors[mutation.mutationType];

      if (executor == null) {
        logger.warn('OfflineMutationQueue: No executor registered for [${mutation.mutationType}]. Skipping.');
        continue;
      }

      try {
        await executor(mutation.payload);
        toRemove.add(mutation);
        syncedCount++;
        logger.debug('OfflineMutationQueue: Mutation [${mutation.id}] successfully replayed.');
      } catch (err) {
        logger.warn('OfflineMutationQueue: Mutation [${mutation.id}] failed during replay: $err');
        mutation.retryCount++;

        // Apply Conflict Policy
        switch (mutation.conflictPolicy) {
          case ConflictPolicy.clientWins:
            break;

          case ConflictPolicy.serverWins:
            logger.info('OfflineMutationQueue: ConflictPolicy.serverWins -> Discarding client mutation [${mutation.id}]');
            toRemove.add(mutation);
            BloomData.invalidateQueries([mutation.mutationType]);
            break;

          case ConflictPolicy.custom:
            final resolver = _resolvers[mutation.mutationType];
            if (resolver != null) {
              final resolvedPayload = await resolver(mutation.payload, err);
              if (resolvedPayload != null) {
                mutation.payload = resolvedPayload;
                try {
                  await executor(mutation.payload);
                  toRemove.add(mutation);
                  syncedCount++;
                } catch (_) {}
              } else {
                toRemove.add(mutation);
              }
            }
            break;
        }
      }
    }

    _queue.removeWhere((item) => toRemove.contains(item));
    await persist();

    _isProcessing = false;
    logger.info('OfflineMutationQueue: Replay finished. Successfully synced: $syncedCount, Remaining: ${_queue.length}');
    return syncedCount;
  }

  /// Clear all queued mutations.
  Future<void> clear() async {
    _queue.clear();
    await persist();
  }
}
