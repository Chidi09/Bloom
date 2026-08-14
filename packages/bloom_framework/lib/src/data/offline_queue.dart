// lib/src/data/offline_queue.dart
import 'dart:async';
import '../core/logger.dart';

enum ConflictPolicy {
  serverWins,
  clientWins,
  custom,
}

/// A queued mutation awaiting network connectivity for synchronization.
class QueuedMutation {
  final String id;
  final String tag;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;
  int retryCount;

  QueuedMutation({
    required this.id,
    required this.tag,
    required this.payload,
    required this.queuedAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tag,
        'payload': payload,
        'queuedAt': queuedAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory QueuedMutation.fromJson(Map<String, dynamic> json) => QueuedMutation(
        id: json['id'] as String,
        tag: json['tag'] as String,
        payload: json['payload'] as Map<String, dynamic>,
        queuedAt: DateTime.parse(json['queuedAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
      );
}

typedef MutationExecutor = Future<bool> Function(QueuedMutation mutation);

/// Manages offline-first mutation queuing and automated replay synchronization.
class OfflineMutationQueue {
  final List<QueuedMutation> _queue = [];
  bool _isProcessing = false;
  ConflictPolicy conflictPolicy;

  OfflineMutationQueue({this.conflictPolicy = ConflictPolicy.clientWins});

  int get length => _queue.length;
  bool get isEmpty => _queue.isEmpty;
  bool get isProcessing => _isProcessing;
  List<QueuedMutation> get items => List.unmodifiable(_queue);

  /// Add a failed/offline mutation to the persistent replay queue.
  void enqueue({
    required String tag,
    required Map<String, dynamic> payload,
    String? id,
  }) {
    final mutation = QueuedMutation(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      tag: tag,
      payload: payload,
      queuedAt: DateTime.now(),
    );
    _queue.add(mutation);
    logger.info('OfflineMutationQueue: Queued mutation [$tag] (id: ${mutation.id}). Queue depth: ${_queue.length}');
  }

  /// Process all pending mutations in FIFO sequence.
  Future<int> processQueue(MutationExecutor executor) async {
    if (_isProcessing || _queue.isEmpty) return 0;
    _isProcessing = true;
    int successCount = 0;

    logger.info('OfflineMutationQueue: Replaying ${_queue.length} pending mutations...');

    final remaining = <QueuedMutation>[];
    for (final mutation in _queue) {
      try {
        final success = await executor(mutation);
        if (success) {
          successCount++;
          logger.debug('OfflineMutationQueue: Mutation [${mutation.id}] successfully replayed.');
        } else {
          mutation.retryCount++;
          remaining.add(mutation);
        }
      } catch (err) {
        mutation.retryCount++;
        logger.warn('OfflineMutationQueue: Replay failed for [${mutation.id}]: $err');
        remaining.add(mutation);
      }
    }

    _queue.clear();
    _queue.addAll(remaining);
    _isProcessing = false;

    logger.info('OfflineMutationQueue: Replay finished. Successfully synced: $successCount, Remaining: ${_queue.length}');
    return successCount;
  }

  /// Clear all queued mutations.
  void clear() => _queue.clear();
}
