# bloom_jobs

Background job queue and worker system for Bloom server applications, modeled on the `djangors-tasks` Rust crate architecture.

## Overview

`bloom_jobs` provides:
- **`BloomTaskRegistry`**: Central registry for registering named task handlers (`BloomTaskHandler`).
- **`BloomTaskQueue`**: In-memory job queue with asynchronous FIFO safety and atomic `claimNext()` task claiming.
- **`BloomJobWorker`**: Worker loop supporting configurable poll intervals, recurring task ticks, and atomic claims.
- **`BloomRecurringRegistry`**: Recurring scheduled tasks running on periodic intervals (Phase 1 simplification).
- Seamless integration with the Bloom Dependency Injection container (`BloomContainer`).

> **Note on Persistence Scope**: Phase 1 provides an in-process, in-memory queue. DB-backed persistence (mirroring the `djangors_task_queue` table), distributed multi-process queues, and full 5-field cron parsing are deferred to subsequent phases.

## Usage

```dart
import 'package:bloom_framework/bloom.dart';
import 'package:bloom_jobs/bloom_jobs.dart';

void main() async {
  // 1. Configure DI container
  final registry = BloomTaskRegistry();
  final queue = BloomTaskQueue();
  final recurring = BloomRecurringRegistry();

  globalContainer.provideValue<BloomTaskRegistry>(registry);
  globalContainer.provideValue<BloomTaskQueue>(queue);
  globalContainer.provideValue<BloomRecurringRegistry>(recurring);

  // 2. Register a task handler
  registry.register('send_welcome_email', (Map<String, dynamic> payload) async {
    final email = payload['email'] as String;
    final name = payload['name'] as String;
    print('Sending welcome email to $name <$email>...');
  });

  // 3. Register a recurring task (runs every 30 minutes)
  recurring.register(
    taskName: 'send_welcome_email',
    interval: const Duration(minutes: 30),
    payload: {'email': 'admin@example.com', 'name': 'Admin'},
  );

  // 4. Enqueue tasks for immediate or scheduled execution
  await queue.enqueue('send_welcome_email', {
    'email': 'user@example.com',
    'name': 'Alice',
  });

  await queue.enqueueScheduled(
    'send_welcome_email',
    {'email': 'later@example.com', 'name': 'Bob'},
    DateTime.now().add(const Duration(minutes: 5)),
  );

  // 5. Create and run a Worker
  final worker = BloomJobWorker(
    queue: queue,
    registry: registry,
    recurringRegistry: recurring,
  )
      .withPollInterval(const Duration(seconds: 1))
      .withRecurringTickInterval(const Duration(seconds: 10));

  // Process a single task (ideal for tests or triggered passes)
  final didRun = await worker.runOnce();
  print('Task processed: $didRun');

  // Or start the background worker loop
  // worker.run();
}
```

## Atomic Concurrency Guarantee

Even in single-isolate Dart, concurrent async operations can yield across `await` suspension points. `BloomTaskQueue.claimNext()` guarantees atomicity through an internal chained FIFO synchronization lock (`_synchronized`), ensuring that two concurrent callers cannot claim the same task or observe intermediate states.
