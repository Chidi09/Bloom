import 'dart:async';
import 'queue.dart';

/// Defines a recurring task configuration.
class BloomRecurringTask {
  /// Unique identifier of the recurring configuration.
  final String id;

  /// Identifier name of the registered task handler.
  final String taskName;

  /// Input payload to pass to the task handler upon enqueueing.
  final Map<String, dynamic> payload;

  /// Schedule interval duration for recurring runs (Phase 1 simplification).
  final Duration interval;

  /// Next scheduled timestamp when this task should be enqueued.
  DateTime nextRunAt;

  /// Previous timestamp when this task was enqueued.
  DateTime? lastRunAt;

  /// Whether this recurring schedule is actively enabled.
  bool enabled;

  /// Creates a [BloomRecurringTask] configuration.
  BloomRecurringTask({
    required this.id,
    required this.taskName,
    required this.interval,
    this.payload = const {},
    DateTime? nextRunAt,
    this.lastRunAt,
    this.enabled = true,
  }) : nextRunAt = nextRunAt ?? DateTime.now().add(interval);
}

/// Registry and manager for recurring periodic tasks.
class BloomRecurringRegistry {
  final Map<String, BloomRecurringTask> _tasks = {};
  int _idCounter = 0;

  /// Registers a recurring task running at fixed [interval].
  BloomRecurringTask register({
    required String taskName,
    required Duration interval,
    Map<String, dynamic> payload = const {},
    DateTime? initialRunAt,
  }) {
    _idCounter++;
    final id = _idCounter.toString();
    final recurring = BloomRecurringTask(
      id: id,
      taskName: taskName,
      interval: interval,
      payload: Map<String, dynamic>.from(payload),
      nextRunAt: initialRunAt ?? DateTime.now().add(interval),
    );
    _tasks[id] = recurring;
    return recurring;
  }

  /// Evaluates all enabled recurring tasks and enqueues due ones into [queue].
  ///
  /// Returns the number of recurring tasks enqueued during this tick.
  Future<int> tick(BloomTaskQueue queue, [DateTime? now]) async {
    final referenceTime = now ?? DateTime.now();
    int enqueuedCount = 0;

    for (final recurring in _tasks.values) {
      if (!recurring.enabled) continue;

      if (recurring.nextRunAt.isBefore(referenceTime) ||
          recurring.nextRunAt.isAtSameMomentAs(referenceTime)) {
        // Enqueue due task
        await queue.enqueueScheduled(
          recurring.taskName,
          recurring.payload,
          recurring.nextRunAt,
        );

        recurring.lastRunAt = recurring.nextRunAt;
        recurring.nextRunAt = recurring.nextRunAt.add(recurring.interval);

        // Catch up if falling behind multiple intervals
        while (recurring.nextRunAt.isBefore(referenceTime) ||
            recurring.nextRunAt.isAtSameMomentAs(referenceTime)) {
          recurring.nextRunAt = recurring.nextRunAt.add(recurring.interval);
        }

        enqueuedCount++;
      }
    }

    return enqueuedCount;
  }

  /// List of all registered recurring tasks.
  List<BloomRecurringTask> get tasks => List.unmodifiable(_tasks.values);

  /// Unregister a recurring task by [id].
  void unregister(String id) {
    _tasks.remove(id);
  }

  /// Clear all recurring tasks.
  void clear() {
    _tasks.clear();
    _idCounter = 0;
  }
}
