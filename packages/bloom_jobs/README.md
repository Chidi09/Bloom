# bloom_jobs

Background job queue and worker system for Bloom server applications, modeled on the `djangors-tasks` architecture with pluggable storage backends (In-Memory, Database, and Redis).

## Overview

`bloom_jobs` provides:
- **`BloomTaskRegistry`**: Central inventory for registering named task handlers (`BloomTaskHandler`).
- **`BloomTaskQueue`**: Abstract job queue interface with atomic, race-free `claimNext()` task claiming.
- **Queue Backends**:
  - **`InMemoryTaskQueue`**: In-process FIFO queue with async re-entrant lock synchronization (ideal for testing and single-instance local dev).
  - **`DatabaseTaskQueue`**: Persistent SQL queue (`SqliteDbExecutor` and `PostgresDbExecutor`) supporting crash resilience and atomic row-level claiming via `FOR UPDATE SKIP LOCKED` / atomic subquery updates.
  - **`RedisTaskQueue`**: Distributed high-throughput Redis queue with atomic Lua script claiming for multi-worker / multi-isolate deployments.
- **`BloomJobWorker`**: Worker execution loop supporting configurable polling intervals, recurring task ticks, and automatic retry backoff.
- **`BloomRecurringRegistry`**: Recurring scheduled tasks evaluated on periodic intervals.

---

## Storage Backends & Choosing a Backend

### 1. In-Memory Backend (`InMemoryTaskQueue`)

Best for development, unit tests, and single-instance applications where persistence across server restarts is not required.

```dart
import 'package:bloom_jobs/bloom_jobs.dart';

// Default constructor or factory
final BloomTaskQueue queue = InMemoryTaskQueue();
// or: final BloomTaskQueue queue = BloomTaskQueue();
```

### 2. Database Backend (`DatabaseTaskQueue`)

Best for single-node or multi-node production applications where tasks must survive server restarts and database crashes without requiring external Redis infrastructure.

Supports both PostgreSQL and SQLite via `package:bloom_db`.

```dart
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_jobs/bloom_jobs.dart';

// SQLite (in-memory for tests, or file-backed)
final db = SqliteDbExecutor.openFile('/var/data/app.db');
// Or PostgreSQL:
// final db = await PostgresDbExecutor.connectUrl('postgres://user:pass@localhost:5432/app');

final queue = DatabaseTaskQueue(db);
await queue.ensureSchema(); // Idempotently creates table and performance indices
```

### 3. Redis Backend (`RedisTaskQueue`)

Best for high-throughput, distributed multi-worker architectures across separate machines or isolates. Uses Redis Lua scripts (`EVAL`) with sorted sets (`ZSET`) to ensure atomic, non-blocking task claiming.

```dart
import 'package:bloom_jobs/bloom_jobs.dart';

// Connect via standard Redis URL
final queue = RedisTaskQueue.fromUrl(
  'redis://:secretpassword@127.0.0.1:6379/0',
  prefix: 'production_jobs',
);
```

---

## Complete Example

```dart
import 'package:bloom_jobs/bloom_jobs.dart';

void main() async {
  // 1. Initialize Registry and Queue backend
  final registry = BloomTaskRegistry();
  final queue = InMemoryTaskQueue(); // or DatabaseTaskQueue(db) or RedisTaskQueue(...)
  final recurring = BloomRecurringRegistry();

  // 2. Register a task handler
  registry.register('send_welcome_email', (Map<String, dynamic> payload) async {
    final email = payload['email'] as String;
    final name = payload['name'] as String;
    print('Sending welcome email to $name <$email>...');
  });

  // 3. Register a recurring periodic task (runs every 30 minutes)
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

  // Process a single task (ideal for tests or batch ticks)
  final didRun = await worker.runOnce();
  print('Task processed: $didRun');

  // Or start the background worker loop
  // await worker.run();
}
```

---

## Concurrency & Atomicity Guarantees

- **In-Memory**: Uses a chained FIFO `Completer` synchronization queue (`_synchronized`) ensuring concurrent asynchronous calls within the Dart event loop never interleave across suspension points.
- **Database (Postgres)**: Executes `UPDATE ... WHERE id = (SELECT id ... FOR UPDATE SKIP LOCKED) RETURNING ...`, allowing hundreds of concurrent worker processes to claim due tasks with zero lock contention.
- **Database (SQLite)**: Executes an atomic `UPDATE ... WHERE id = (SELECT id ... LIMIT 1) AND status = 'pending' RETURNING ...` ensuring safe single-writer compare-and-swap semantics.
- **Redis**: Executes an atomic Lua script (`EVAL`) that reads the earliest due task via `ZRANGEBYSCORE`, atomically pops it from the ZSET via `ZREM`, updates status to `running`, and writes back to Redis in one non-interruptible step.
