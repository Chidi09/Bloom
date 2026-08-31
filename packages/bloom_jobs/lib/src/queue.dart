import 'dart:async';
import 'task.dart';

/// Abstract background job queue interface for Bloom applications.
///
/// Defines the core contract for enqueueing, scheduling, claiming, and updating
/// background tasks across in-memory, database-backed, and distributed Redis backends.
abstract class BloomTaskQueue {
  /// Default duration before a running task's lease expires. Defaults to 5 minutes.
  static const Duration standardLeaseDuration = Duration(minutes: 5);

  /// The configured default lease duration for tasks claimed from this queue.
  Duration get defaultLeaseDuration;

  /// Creates the default in-memory task queue.
  factory BloomTaskQueue({Duration defaultLeaseDuration}) = InMemoryTaskQueue;

  /// Creates an in-memory task queue.
  factory BloomTaskQueue.inMemory({Duration defaultLeaseDuration}) =
      InMemoryTaskQueue;

  /// Const constructor for subclassing.
  const BloomTaskQueue.base();

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
  });

  /// Atomically claims the next pending, due task.
  ///
  /// Safe against concurrent invocations across asynchronous yields and processes.
  /// If a pending and due task exists, transitions its status to [BloomTaskStatus.running],
  /// increments [BloomQueuedTask.attempts], generates an ownership token [BloomQueuedTask.token],
  /// and sets [BloomQueuedTask.leaseExpiresAt] based on [leaseDuration] (or [defaultLeaseDuration]).
  ///
  /// Before claiming pending work, any expired running leases (where `leaseExpiresAt <= now`)
  /// are atomically reclaimed: tasks with attempts < maxAttempts are returned to pending,
  /// while tasks that exhausted maxAttempts are marked failed.
  ///
  /// Returns `null` if no tasks are pending and due.
  Future<BloomQueuedTask?> claimNext([DateTime? now, Duration? leaseDuration]);

  /// Marks a task as succeeded.
  ///
  /// Requires that [taskId] matches an actively [BloomTaskStatus.running] task and that
  /// [token] matches the task's current ownership token.
  ///
  /// Throws [StateError] if no matching running task with the provided [token] is found.
  Future<void> markCompleted(String taskId, {String? token});

  /// Marks a task as failed. If attempts < maxAttempts, it is requeued as pending.
  ///
  /// Requires that [taskId] matches an actively [BloomTaskStatus.running] task and that
  /// [token] matches the task's current ownership token.
  ///
  /// Throws [StateError] if no matching running task with the provided [token] is found.
  Future<void> markFailed(
    String taskId, {
    String? token,
    required String errorMessage,
    String? stackTrace,
    DateTime? retryAfter,
  });

  /// Returns an unmodifiable snapshot of all tasks currently in the queue.
  Future<List<BloomQueuedTask>> allTasks();

  /// Returns task by [id], or null if not found.
  Future<BloomQueuedTask?> getTask(String id);

  /// Clears all tasks from the queue.
  Future<void> clear();
}

/// In-memory background job queue.
///
/// Provides thread-safe / asynchronous-safe enqueueing and atomic task claiming.
/// Uses an internal re-entrant FIFO execution queue ([_synchronized]) to ensure
/// concurrent `claimNext()` callers never interleave across asynchronous suspension
/// points and cannot claim the same task.
class InMemoryTaskQueue extends BloomTaskQueue {
  @override
  final Duration defaultLeaseDuration;

  final List<BloomQueuedTask> _tasks = [];
  int _idCounter = 0;
  int _tokenSeq = 0;
  Future<void> _lastLock = Future.value();

  /// Creates a new in-memory task queue.
  InMemoryTaskQueue({
    this.defaultLeaseDuration = BloomTaskQueue.standardLeaseDuration,
  }) : super.base();

  @override
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

  @override
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

  @override
  Future<BloomQueuedTask?> claimNext([DateTime? now, Duration? leaseDuration]) {
    return _synchronized(() {
      final referenceTime = now ?? DateTime.now();
      final effectiveLease = leaseDuration ?? defaultLeaseDuration;

      // 1. Atomically reclaim expired running leases before pending work
      for (final t in _tasks) {
        if (t.status == BloomTaskStatus.running &&
            t.leaseExpiresAt != null &&
            (t.leaseExpiresAt!.isBefore(referenceTime) ||
                t.leaseExpiresAt!.isAtSameMomentAs(referenceTime))) {
          t.token = null;
          t.leaseExpiresAt = null;
          if (t.attempts >= t.maxAttempts) {
            t.status = BloomTaskStatus.failed;
            t.finishedAt = referenceTime;
            t.lastError ??= 'Task lease expired';
          } else {
            t.status = BloomTaskStatus.pending;
            if (t.scheduledAt.isAfter(referenceTime)) {
              t.scheduledAt = referenceTime;
            }
          }
        }
      }

      // 2. Find candidate tasks that are pending and due
      final dueTasks = _tasks.where((t) => t.isDue(referenceTime)).toList();
      if (dueTasks.isEmpty) {
        return null;
      }

      // Sort by scheduledAt ascending, then id ascending to ensure deterministic FIFO ordering
      dueTasks.sort((a, b) {
        final cmp = a.scheduledAt.compareTo(b.scheduledAt);
        if (cmp != 0) return cmp;
        final aNum = int.tryParse(a.id);
        final bNum = int.tryParse(b.id);
        if (aNum != null && bNum != null) {
          return aNum.compareTo(bNum);
        }
        return a.id.compareTo(b.id);
      });

      final task = dueTasks.first;
      task.status = BloomTaskStatus.running;
      task.attempts += 1;
      task.startedAt = referenceTime;
      _tokenSeq++;
      task.token = 'tok_${referenceTime.microsecondsSinceEpoch}_$_tokenSeq';
      task.leaseExpiresAt = referenceTime.add(effectiveLease);
      return task;
    });
  }

  @override
  Future<void> markCompleted(String taskId, {String? token}) {
    return _synchronized(() {
      final matches = _tasks.where((t) => t.id == taskId);
      if (matches.isEmpty) {
        throw StateError('Task with id "$taskId" not found in queue.');
      }
      final task = matches.first;
      if (task.status != BloomTaskStatus.running) {
        throw StateError(
          'Task with id "$taskId" is not in running state (status: ${task.status.name}).',
        );
      }
      if (token == null || token.isEmpty || task.token != token) {
        throw StateError(
          'Invalid or stale ownership token for task with id "$taskId".',
        );
      }
      task.status = BloomTaskStatus.succeeded;
      task.lastError = null;
      task.lastStackTrace = null;
      task.finishedAt = DateTime.now();
      task.token = null;
      task.leaseExpiresAt = null;
    });
  }

  @override
  Future<void> markFailed(
    String taskId, {
    String? token,
    required String errorMessage,
    String? stackTrace,
    DateTime? retryAfter,
  }) {
    return _synchronized(() {
      final matches = _tasks.where((t) => t.id == taskId);
      if (matches.isEmpty) {
        throw StateError('Task with id "$taskId" not found in queue.');
      }
      final task = matches.first;
      if (task.status != BloomTaskStatus.running) {
        throw StateError(
          'Task with id "$taskId" is not in running state (status: ${task.status.name}).',
        );
      }
      if (token == null || token.isEmpty || task.token != token) {
        throw StateError(
          'Invalid or stale ownership token for task with id "$taskId".',
        );
      }
      task.lastError = errorMessage;
      task.lastStackTrace = stackTrace;
      task.finishedAt = DateTime.now();
      task.token = null;
      task.leaseExpiresAt = null;

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

  @override
  Future<List<BloomQueuedTask>> allTasks() {
    return _synchronized(() => List<BloomQueuedTask>.unmodifiable(_tasks));
  }

  @override
  Future<BloomQueuedTask?> getTask(String id) {
    return _synchronized(() {
      final matches = _tasks.where((t) => t.id == id);
      return matches.isEmpty ? null : matches.first;
    });
  }

  @override
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
