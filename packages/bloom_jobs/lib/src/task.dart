import 'dart:async';

/// Signature for background task handlers.
typedef BloomTaskHandler = FutureOr<void> Function(
    Map<String, dynamic> payload);

/// Execution status of a queued task.
enum BloomTaskStatus {
  /// The task is queued and waiting for worker execution.
  pending,

  /// The task has been claimed by a worker and is actively executing.
  running,

  /// The task execution completed successfully.
  succeeded,

  /// The task failed and exhausted all retry attempts.
  failed,
}

/// Represents an individual task instance queued for execution.
class BloomQueuedTask {
  /// Unique identifier of this queued task.
  final String id;

  /// Identifier name of the registered task handler.
  final String taskName;

  /// Input payload parameters passed to the task handler.
  final Map<String, dynamic> payload;

  /// Current execution lifecycle status.
  BloomTaskStatus status;

  /// Timestamp when this task record was created.
  final DateTime createdAt;

  /// Earliest scheduled execution timestamp.
  DateTime scheduledAt;

  /// Number of execution attempts made so far.
  int attempts;

  /// Maximum allowed execution attempts before being marked failed permanently.
  final int maxAttempts;

  /// Ownership token verifying active lease ownership.
  String? token;

  /// Timestamp when the current execution lease expires.
  DateTime? leaseExpiresAt;

  /// Last error or exception message if execution failed.
  String? lastError;

  /// Last stack trace string if execution failed.
  String? lastStackTrace;

  /// Timestamp when execution started.
  DateTime? startedAt;

  /// Timestamp when execution finished.
  DateTime? finishedAt;

  /// Creates a [BloomQueuedTask] record.
  BloomQueuedTask({
    required this.id,
    required this.taskName,
    required this.payload,
    this.status = BloomTaskStatus.pending,
    DateTime? createdAt,
    DateTime? scheduledAt,
    this.attempts = 0,
    this.maxAttempts = 3,
    this.token,
    this.leaseExpiresAt,
    this.lastError,
    this.lastStackTrace,
    this.startedAt,
    this.finishedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        scheduledAt = scheduledAt ?? DateTime.now();

  /// Whether this task has exceeded its allowed retry attempts.
  bool get hasExceededMaxAttempts => attempts >= maxAttempts;

  /// Whether this task is currently due for execution relative to [now].
  bool isDue([DateTime? now]) {
    final reference = now ?? DateTime.now();
    return status == BloomTaskStatus.pending &&
        (scheduledAt.isBefore(reference) ||
            scheduledAt.isAtSameMomentAs(reference));
  }

  /// Converts this task into a JSON-serializable Map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'taskName': taskName,
        'payload': payload,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'scheduledAt': scheduledAt.toIso8601String(),
        'attempts': attempts,
        'maxAttempts': maxAttempts,
        'token': token,
        'leaseExpiresAt': leaseExpiresAt?.toIso8601String(),
        'lastError': lastError,
        'lastStackTrace': lastStackTrace,
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
      };

  @override
  String toString() =>
      'BloomQueuedTask(id: $id, taskName: $taskName, status: ${status.name}, attempts: $attempts/$maxAttempts, scheduledAt: $scheduledAt, token: $token, leaseExpiresAt: $leaseExpiresAt)';
}
