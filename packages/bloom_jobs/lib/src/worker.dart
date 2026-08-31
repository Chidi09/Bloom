import 'dart:async';
import 'queue.dart';
import 'registry.dart';
import 'recurring.dart';

/// Worker that claims and executes background tasks from the queue.
///
/// Mirrors `Worker` in `djangors-tasks` with builder style configuration:
/// `withPollInterval` and `withRecurringTickInterval`.
class BloomJobWorker {
  /// Queue from which tasks are claimed and updated.
  final BloomTaskQueue queue;

  /// Registry containing task handlers.
  final BloomTaskRegistry registry;

  /// Optional recurring registry for scheduled recurring jobs.
  final BloomRecurringRegistry? recurringRegistry;

  /// Polling interval when the queue is empty.
  final Duration pollInterval;

  /// Optional interval for ticking recurring tasks.
  final Duration? recurringTickInterval;

  /// Internal control flag to stop [run] loop.
  bool _isRunning = false;

  /// Creates a [BloomJobWorker] with [queue], [registry], and optional [recurringRegistry].
  BloomJobWorker({
    required this.queue,
    required this.registry,
    this.recurringRegistry,
    this.pollInterval = const Duration(seconds: 1),
    this.recurringTickInterval,
  });

  /// Configures the polling interval for checking due tasks when idle.
  BloomJobWorker withPollInterval(Duration interval) {
    return BloomJobWorker(
      queue: queue,
      registry: registry,
      recurringRegistry: recurringRegistry,
      pollInterval: interval,
      recurringTickInterval: recurringTickInterval,
    );
  }

  /// Configures how often due recurring tasks are checked and enqueued.
  BloomJobWorker withRecurringTickInterval(Duration interval) {
    return BloomJobWorker(
      queue: queue,
      registry: registry,
      recurringRegistry: recurringRegistry,
      pollInterval: pollInterval,
      recurringTickInterval: interval,
    );
  }

  /// Claims and executes a single task from the queue if available.
  ///
  /// Returns `true` if a task was claimed and processed (whether successful or failed),
  /// and `false` if no due task was available.
  /// Any exception thrown during handler execution or payload parsing is caught,
  /// recorded on the task, and does NOT propagate out.
  Future<bool> runOnce([DateTime? now, Duration? leaseDuration]) async {
    final task = await queue.claimNext(now, leaseDuration);
    if (task == null) {
      return false;
    }

    final handler = registry.get(task.taskName);
    if (handler == null) {
      final err = 'Task handler "${task.taskName}" not found in registry.';
      await queue.markFailed(
        task.id,
        token: task.token,
        errorMessage: err,
      );
      return true;
    }

    try {
      final result = handler(task.payload);
      if (result is Future) {
        await result;
      }
      await queue.markCompleted(task.id, token: task.token);
    } catch (e, st) {
      await queue.markFailed(
        task.id,
        token: task.token,
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      );
    }

    return true;
  }

  /// Runs the worker loop indefinitely (or until [stop] is called).
  ///
  /// Periodically checks for due tasks and evaluates recurring task schedules.
  Future<void> run() async {
    _isRunning = true;
    var lastRecurringTick = DateTime.now();

    while (_isRunning) {
      if (recurringRegistry != null && recurringTickInterval != null) {
        final now = DateTime.now();
        if (now.difference(lastRecurringTick) >= recurringTickInterval!) {
          try {
            await recurringRegistry!.tick(queue, now);
          } catch (_) {
            // Error in recurring tick should not crash worker loop
          }
          lastRecurringTick = now;
        }
      }

      try {
        final processed = await runOnce();
        if (!processed) {
          await Future.delayed(pollInterval);
        }
      } catch (_) {
        // Unexpected worker-level errors back off and resume loop
        await Future.delayed(pollInterval);
      }
    }
  }

  /// Stops the worker execution loop if running.
  void stop() {
    _isRunning = false;
  }

  /// Whether the worker loop is currently active.
  bool get isRunning => _isRunning;
}
