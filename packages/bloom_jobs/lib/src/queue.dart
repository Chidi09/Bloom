import 'dart:async';
import 'task.dart';

/// In-memory background job queue.
///
/// Provides thread-safe / asynchronous-safe enqueueing and atomic task claiming.
/// Uses an internal re-entrant FIFO execution queue ([_synchronized]) to ensure
/// concurrent `claimNext()` callers never interleave across asynchronous suspension
/// points and cannot claim the same task.
class BloomTaskQueue {
  final List<BloomQueuedTask> _tasks = [];
  int _idCounter = 0;
  Future<void> _lastLock = Future.value();

  /// Enqueues a task for immediate execution.
  Future<BloomQueuedTask> enqueue(
    String taskName,
    Map<String, dynamic> payload, {
    int maxAttempts = 3,
  }) {
    return enqueueScheduled(
      taskName,
      payload,
      DateTime.now(),
      maxAttempts: maxAttempts,
    );
  }

  /// Enqueues a task scheduled for execution at or after [runAt].
  Future<BloomQueuedTask> enqueueScheduled(
    String taskName,
    Map<String, dynamic> payload,
    DateTime runAt, {
    int maxAttempts = 3,
  }) {
    return _synchronized(() {
      _idCounter++;
      final task = BloomQueuedTask(
        id: _idCounter.toString(),
        taskName: taskName,
        payload: Map<String, dynamic>.from(payload),
        status: BloomTaskStatus.pending,
        createdAt: DateTime.now(),
        scheduledAt: runAt,
        attempts: 0,
        maxAttempts: maxAttempts,
      );
      _tasks.add(task);
      return task;
    });
  }

  /// Atomically claims the next pending, due task.
  ///
  /// Safe against concurrent invocations across asynchronous yields.
  /// If a pending and due task exists, transitions its status to [BloomTaskStatus.running],
  /// increments [BloomQueuedTask.attempts], and returns the task.
  /// Returns `null` if no tasks are pending and due.
  Future<BloomQueuedTask?> claimNext([DateTime? now]) {
    return _synchronized(() {
      final referenceTime = now ?? DateTime.now();

      // Find candidate tasks that are pending and due
      final dueTasks = _tasks.where((t) => t.isDue(referenceTime)).toList();
      if (dueTasks.isEmpty) {
        return null;
      }

      // Sort by scheduledAt ascending, then id ascending to ensure deterministic FIFO ordering
      dueTasks.sort((a, b) {
        final cmp = a.scheduledAt.compareTo(b.scheduledAt);
        if (cmp != 0) return cmp;
        return int.parse(a.id).compareTo(int.parse(b.id));
      });

      final task = dueTasks.first;
      task.status = BloomTaskStatus.running;
      task.attempts += 1;
      task.startedAt = DateTime.now();
      return task;
    });
  }

  /// Marks a task as succeeded.
  ///
  /// Throws [StateError] if no task with [taskId] is found in the queue.
  Future<void> markCompleted(String taskId) {
    return _synchronized(() {
      final task = _tasks.firstWhere(
        (t) => t.id == taskId,
        orElse: () => throw StateError('Task with id "$taskId" not found in queue.'),
      );
      task.status = BloomTaskStatus.succeeded;
      task.lastError = null;
      task.lastStackTrace = null;
      task.finishedAt = DateTime.now();
    });
  }

  /// Marks a task as failed. If attempts < maxAttempts, it is requeued as pending.
  ///
  /// Throws [StateError] if no task with [taskId] is found in the queue.
  Future<void> markFailed(
    String taskId, {
    required String errorMessage,
    String? stackTrace,
    DateTime? retryAfter,
  }) {
    return _synchronized(() {
      final task = _tasks.firstWhere(
        (t) => t.id == taskId,
        orElse: () => throw StateError('Task with id "$taskId" not found in queue.'),
      );
      task.lastError = errorMessage;
      task.lastStackTrace = stackTrace;
      task.finishedAt = DateTime.now();

      if (task.attempts < task.maxAttempts) {
        task.status = BloomTaskStatus.pending;
        // Back off before the next retry attempt: use the caller-supplied time if given,
        // otherwise a default exponential backoff (2^attempts seconds, capped at 60s) so a
        // failing task doesn't get re-claimed immediately on the worker's next poll.
        final effectiveRetryAfter = retryAfter ??
            DateTime.now().add(
              Duration(seconds: (1 << task.attempts).clamp(1, 60)),
            );
        _tasks.remove(task);
        final rescheduled = BloomQueuedTask(
          id: task.id,
          taskName: task.taskName,
          payload: task.payload,
          status: BloomTaskStatus.pending,
          createdAt: task.createdAt,
          scheduledAt: effectiveRetryAfter,
          attempts: task.attempts,
          maxAttempts: task.maxAttempts,
          lastError: task.lastError,
          lastStackTrace: task.lastStackTrace,
        );
        _tasks.add(rescheduled);
      } else {
        task.status = BloomTaskStatus.failed;
      }
    });
  }

  /// Returns an unmodifiable snapshot of all tasks currently in the queue.
  Future<List<BloomQueuedTask>> allTasks() {
    return _synchronized(() => List<BloomQueuedTask>.unmodifiable(_tasks));
  }

  /// Returns task by [id], or null if not found.
  Future<BloomQueuedTask?> getTask(String id) {
    return _synchronized(() {
      final matches = _tasks.where((t) => t.id == id);
      return matches.isEmpty ? null : matches.first;
    });
  }

  /// Clears all tasks from the queue.
  Future<void> clear() {
    return _synchronized(() {
      _tasks.clear();
      _idCounter = 0;
    });
  }

  /// Internal synchronization primitive ensuring mutual exclusion for critical sections
  /// without requiring third-party locking packages.
  Future<T> _synchronized<T>(FutureOr<T> Function() criticalSection) {
    final completer = Completer<T>();
    final prev = _lastLock;
    _lastLock = completer.future.then((_) {}, onError: (_) {});

    prev.whenComplete(() {
      try {
        final result = criticalSection();
        if (result is Future<T>) {
          result.then(completer.complete, onError: completer.completeError);
        } else {
          completer.complete(result);
        }
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }
}
