// lib/src/transition.dart
//
// Pure-Dart cooperative priority scheduler and concurrent transitions for Bloom JS Native.
// Safe for both SSR (VM) and browser DOM mounting.

import 'dart:async';
import 'package:signals/signals.dart';

// ─── Priority Levels ──────────────────────────────────────────────────────────

/// Priority levels for tasks scheduled with [BloomScheduler].
///
/// Determines execution order in the cooperative work queue. Tasks with higher
/// priority execute before lower-priority tasks. Within the same priority level,
/// tasks run in FIFO (First-In, First-Out) submission order.
///
/// Both browser DOM environments and SSR (VM) evaluate scheduled workloads using
/// these priority tiers.
///
/// ```dart
/// BloomScheduler.schedule(
///   () => refreshTelemetry(),
///   priority: TaskPriority.idle,
/// );
/// ```
enum TaskPriority {
  /// Executed immediately in the current turn without yielding or deferral.
  immediate(0),

  /// Urgent user-facing interactions that block immediate visual feedback (e.g. typing, clicks).
  userBlocking(1),

  /// Standard application updates and default asynchronous workloads.
  normal(2),

  /// Non-urgent transitions, filtering large lists, or secondary UI updates.
  low(3),

  /// Speculative or deferrable work run only when no higher-priority tasks are waiting.
  idle(4);

  /// Numeric priority level, where lower numeric values represent higher priority.
  final int indexValue;

  const TaskPriority(this.indexValue);
}

// ─── Scheduler Task ───────────────────────────────────────────────────────────

/// Represents a unit of work scheduled in the [BloomScheduler] queue.
///
/// Provides handles for querying status, awaiting completion via [future],
/// or cancelling the task prior to execution via [cancel].
///
/// ```dart
/// final task = BloomScheduler.schedule(
///   () => fetchSuggestions(query),
///   priority: TaskPriority.low,
/// );
///
/// // Cancel if the user types a new character before execution:
/// if (queryChanged) {
///   task.cancel();
/// }
/// ```
abstract class SchedulerTask<T> {
  /// Unique identifier assigned to this task instance.
  int get id;

  /// The assigned priority level of this task.
  TaskPriority get priority;

  /// Whether this task was cancelled before completion.
  bool get isCancelled;

  /// Whether this task has finished execution (completed successfully, errored, or cancelled).
  bool get isCompleted;

  /// A future resolving when the task execution completes, or completing with an error.
  Future<T> get future;

  /// Cancels this task if it has not yet started or completed.
  ///
  /// If the task is already executing or completed, this is a no-op.
  void cancel();
}

class _TaskImpl<T> implements SchedulerTask<T> {
  @override
  final int id;

  @override
  final TaskPriority priority;

  final FutureOr<T> Function() _callback;
  final Completer<T> _completer = Completer<T>();

  bool _cancelled = false;
  bool _completed = false;

  _TaskImpl(this.id, this.priority, this._callback) {
    // Prevent unhandled zone errors if the task fails or is cancelled without
    // an active listener. `catchError` cannot be used here: its handler must
    // return a value assignable to T, which a generic task cannot produce.
    _completer.future.ignore();
  }

  @override
  bool get isCancelled => _cancelled;

  @override
  bool get isCompleted => _completed;

  @override
  Future<T> get future => _completer.future;

  @override
  void cancel() {
    if (_completed || _cancelled) return;
    _cancelled = true;
    _completed = true;
    if (!_completer.isCompleted) {
      _completer.completeError(
        TimeoutException('Task $id was cancelled before execution.'),
      );
    }
  }

  Future<void> run() async {
    if (_cancelled || _completed) return;
    try {
      final result = await _callback();
      _completed = true;
      if (!_completer.isCompleted) {
        _completer.complete(result);
      }
    } catch (e, st) {
      _completed = true;
      if (!_completer.isCompleted) {
        _completer.completeError(e, st);
      }
    }
  }
}

// ─── Platform Host Hook ───────────────────────────────────────────────────────

/// Platform host interface providing cooperative macrotask yielding and scheduling.
///
/// In pure-Dart VM and SSR environments, [DefaultSchedulerHost] uses zero-duration
/// `Timer` macrotasks to yield execution without depending on browser APIs.
///
/// In browser DOM applications, a custom host (such as one using `window.requestAnimationFrame`,
/// `window.requestIdleCallback`, or `MessageChannel`) can be installed via [BloomScheduler.setHost].
///
/// ```dart
/// class CustomSchedulerHost implements SchedulerHost {
///   @override
///   bool get isSynchronous => false;
///
///   @override
///   void scheduleWork(void Function() runQueue) {
///     Timer.run(runQueue);
///   }
///
///   @override
///   Future<void> yieldToHost() {
///     final completer = Completer<void>();
///     Timer(Duration.zero, completer.complete);
///     return completer.future;
///   }
/// }
/// ```
abstract class SchedulerHost {
  /// Whether this host executes synchronously without deferral or time-slicing (e.g. in fast SSR).
  bool get isSynchronous;

  /// Requests the host environment to invoke [runQueue] in the next event loop turn.
  void scheduleWork(void Function() runQueue);

  /// Yields execution to the host event loop, completing when the platform is ready to resume.
  Future<void> yieldToHost();
}

/// Default pure-Dart implementation of [SchedulerHost] using [Timer] macrotasks.
///
/// Safe for Dart VM, Server-Side Rendering (SSR), unit tests, and browser runtimes.
///
/// ```dart
/// final host = DefaultSchedulerHost();
/// BloomScheduler.setHost(host);
/// ```
class DefaultSchedulerHost implements SchedulerHost {
  /// Creates a default macrotask-based scheduler host.
  const DefaultSchedulerHost();

  @override
  bool get isSynchronous => false;

  @override
  void scheduleWork(void Function() runQueue) {
    Timer.run(runQueue);
  }

  @override
  Future<void> yieldToHost() {
    final completer = Completer<void>();
    Timer(Duration.zero, completer.complete);
    return completer.future;
  }
}

/// Synchronous scheduler host that immediately runs scheduled tasks without time-slicing.
///
/// Designed for deterministic SSR and instantaneous execution environments where
/// waiting on event loop turns is undesirable.
///
/// ```dart
/// BloomScheduler.setHost(const SyncSchedulerHost());
/// ```
class SyncSchedulerHost implements SchedulerHost {
  /// Creates a synchronous scheduler host.
  const SyncSchedulerHost();

  @override
  bool get isSynchronous => true;

  @override
  void scheduleWork(void Function() runQueue) {
    runQueue();
  }

  @override
  Future<void> yieldToHost() => Future.value();
}

// ─── BloomScheduler ───────────────────────────────────────────────────────────

/// Cooperative priority-based time-slicing scheduler for Bloom JS Native.
///
/// Coordinates task execution across [TaskPriority] levels (immediate, userBlocking,
/// normal, low, idle) in bounded slices (defaulting to [frameBudgetMs] milliseconds),
/// yielding to the event loop between slices so the browser can paint and process user input.
///
/// In pure-Dart / VM / SSR environments, yielding uses portable macrotask timers ([DefaultSchedulerHost]).
/// In browser environments, custom hosts hooking into rAF / idle callbacks can be installed
/// via [setHost].
///
/// ```dart
/// final task = BloomScheduler.schedule(() async {
///   for (final item in largeDataset) {
///     processItem(item);
///     if (BloomScheduler.shouldYield()) {
///       await BloomScheduler.yieldNow();
///     }
///   }
/// }, priority: TaskPriority.low);
/// ```
class BloomScheduler {
  BloomScheduler._();

  static int _nextTaskId = 0;
  static SchedulerHost _host = const DefaultSchedulerHost();

  /// Time slice budget in milliseconds (default 5ms) before yielding to the host event loop.
  static int frameBudgetMs = 5;

  static final List<List<_TaskImpl<dynamic>>> _queues =
      List.generate(5, (_) => <_TaskImpl<dynamic>>[]);

  static bool _isFlushing = false;
  static bool _flushScheduled = false;
  static final Stopwatch _sliceStopwatch = Stopwatch();

  /// Current platform scheduler host.
  static SchedulerHost get currentHost => _host;

  /// Replaces the current scheduler host platform hook.
  ///
  /// In browser entry points, pass an adapter backed by `window.requestAnimationFrame`
  /// or `window.requestIdleCallback`.
  static void setHost(SchedulerHost host) {
    _host = host;
  }

  /// Resets the scheduler host back to [DefaultSchedulerHost].
  static void resetHost() {
    _host = const DefaultSchedulerHost();
  }

  /// Total number of active, non-cancelled pending tasks across all priority tiers.
  static int get pendingTaskCount {
    return _queues.fold<int>(
        0, (sum, q) => sum + q.where((t) => !t.isCancelled).length);
  }

  /// Schedules [task] for execution at the specified [priority].
  ///
  /// Returns a [SchedulerTask] handle to track completion or cancel the task.
  ///
  /// ```dart
  /// final handle = BloomScheduler.schedule(
  ///   () => calculateLayout(),
  ///   priority: TaskPriority.userBlocking,
  /// );
  /// ```
  static SchedulerTask<T> schedule<T>(
    FutureOr<T> Function() task, {
    TaskPriority priority = TaskPriority.normal,
  }) {
    final id = ++_nextTaskId;
    final taskImpl = _TaskImpl<T>(id, priority, task);
    _queues[priority.indexValue].add(taskImpl);

    if (_host.isSynchronous || priority == TaskPriority.immediate) {
      _flushQueue();
    } else {
      _requestFlush();
    }

    return taskImpl;
  }

  /// Checks whether the current time slice has exceeded [frameBudgetMs] or a higher-priority task is queued.
  ///
  /// Call this inside long loops to decide whether to invoke [yieldNow].
  ///
  /// ```dart
  /// if (BloomScheduler.shouldYield()) {
  ///   await BloomScheduler.yieldNow();
  /// }
  /// ```
  static bool shouldYield({int? customBudgetMs}) {
    if (_host.isSynchronous) return false;
    final budget = customBudgetMs ?? frameBudgetMs;
    if (_sliceStopwatch.isRunning &&
        _sliceStopwatch.elapsedMilliseconds >= budget) {
      return true;
    }
    // Check if urgent work arrived while running low/idle tasks
    if (_queues[TaskPriority.immediate.indexValue].isNotEmpty ||
        _queues[TaskPriority.userBlocking.indexValue].isNotEmpty) {
      return true;
    }
    return false;
  }

  /// Yields the current time slice to the host event loop, resuming when the host turns.
  ///
  /// Resets the slice stopwatch upon resuming.
  ///
  /// ```dart
  /// await BloomScheduler.yieldNow();
  /// ```
  static Future<void> yieldNow() async {
    _sliceStopwatch.stop();
    await _host.yieldToHost();
    _sliceStopwatch.reset();
    _sliceStopwatch.start();
  }

  /// Flushes all pending tasks in the queue until empty.
  ///
  /// Primarily used in SSR rendering passes and test assertions.
  ///
  /// ```dart
  /// await BloomScheduler.flush();
  /// ```
  static Future<void> flush() async {
    while (pendingTaskCount > 0) {
      _flushQueue();
      await Future<void>.delayed(Duration.zero);
    }
  }

  static void _requestFlush() {
    if (_flushScheduled || _isFlushing) return;
    _flushScheduled = true;
    _host.scheduleWork(() {
      _flushScheduled = false;
      _flushQueue();
    });
  }

  static void _flushQueue() {
    if (_isFlushing) return;
    _isFlushing = true;
    _sliceStopwatch.reset();
    _sliceStopwatch.start();

    void runLoop() {
      while (true) {
        _TaskImpl<dynamic>? nextTask;
        for (int i = 0; i < _queues.length; i++) {
          final q = _queues[i];
          while (q.isNotEmpty) {
            final t = q.removeAt(0);
            if (!t.isCancelled) {
              nextTask = t;
              break;
            }
          }
          if (nextTask != null) break;
        }

        if (nextTask == null) {
          _sliceStopwatch.stop();
          _isFlushing = false;
          return;
        }

        // Check if slice budget is exceeded before starting next task (unless immediate)
        if (!_host.isSynchronous &&
            nextTask.priority != TaskPriority.immediate &&
            _sliceStopwatch.elapsedMilliseconds >= frameBudgetMs) {
          _queues[nextTask.priority.indexValue].insert(0, nextTask);
          _sliceStopwatch.stop();
          _isFlushing = false;
          _requestFlush();
          return;
        }

        final task = nextTask;
        final runFuture = task.run();
        runFuture.whenComplete(() {
          if (!_host.isSynchronous &&
              _sliceStopwatch.elapsedMilliseconds >= frameBudgetMs) {
            _sliceStopwatch.stop();
            _isFlushing = false;
            _requestFlush();
          } else {
            runLoop();
          }
        });
        return;
      }
    }

    runLoop();
  }
}

// ─── Transitions ──────────────────────────────────────────────────────────────

final Signal<int> _pendingTransitionCount = signal(0);
final Signal<bool> _isTransitionPending = signal(false);

/// Reactive read-only signal indicating whether a non-urgent transition update is pending.
///
/// Observes whether a background state transition initiated by [startTransition] is currently
/// queued, time-slicing, or executing. When [startTransition] is invoked, [isTransitionPending]
/// becomes `true` immediately and remains `true` across all yields until all transition work finishes.
///
/// Reading this signal inside a [Live] region allows UI elements to render busy indicators,
/// spinners, or dimmed opacities without blocking immediate user interactions.
///
/// ```dart
/// Div(
///   children: [
///     Live(() => isTransitionPending.value
///         ? const Span(className: 'spinner', text: 'Updating list...')
///         : const Span(text: 'Up to date')),
///   ],
/// )
/// ```
ReadonlySignal<bool> get isTransitionPending => _isTransitionPending.readonly();

/// Defers a non-urgent state update to a low-priority scheduled task while tracking transition status via [isTransitionPending].
///
/// Immediately sets [isTransitionPending] to `true`, schedules [update] inside [BloomScheduler]
/// at [TaskPriority.low], and resets [isTransitionPending] to `false` when all transition work is finished.
///
/// Use [startTransition] to keep high-frequency user interactions (like typing in a search box
/// or toggling tabs) responsive by deferring expensive derived computations or large state updates.
///
/// ```dart
/// Input(
///   attrs: {'placeholder': 'Filter items...'},
///   on: {
///     'input': (e) {
///       // Urgent: reflect keystroke in input signal immediately
///       searchQuery.value = e.value ?? '';
///
///       // Non-urgent: defer expensive list filtering to low-priority scheduler
///       startTransition(() {
///         filteredItems.value = performExpensiveFilter(searchQuery.value);
///       });
///     },
///   },
/// )
/// ```
void startTransition(FutureOr<void> Function() update) {
  _pendingTransitionCount.value++;
  _isTransitionPending.value = true;

  BloomScheduler.schedule<void>(() async {
    try {
      await update();
    } finally {
      final remaining = _pendingTransitionCount.value - 1;
      _pendingTransitionCount.value = remaining < 0 ? 0 : remaining;
      _isTransitionPending.value = _pendingTransitionCount.value > 0;
    }
  }, priority: TaskPriority.low);
}

/// Schedules a non-urgent transition task returning a [SchedulerTask] handle.
///
/// Similar to [startTransition], but provides the [SchedulerTask] token allowing cancellation
/// and awaiting completion.
///
/// ```dart
/// final task = scheduleTransition(() {
///   filteredList.value = computeFilter(query.value);
/// });
/// ```
SchedulerTask<T> scheduleTransition<T>(FutureOr<T> Function() update) {
  _pendingTransitionCount.value++;
  _isTransitionPending.value = true;

  return BloomScheduler.schedule<T>(() async {
    try {
      return await update();
    } finally {
      final remaining = _pendingTransitionCount.value - 1;
      _pendingTransitionCount.value = remaining < 0 ? 0 : remaining;
      _isTransitionPending.value = _pendingTransitionCount.value > 0;
    }
  }, priority: TaskPriority.low);
}


