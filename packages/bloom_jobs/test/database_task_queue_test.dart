import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_jobs/bloom_jobs.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseTaskQueue (SQLite in-memory)', () {
    late SqliteDbExecutor db;
    late DatabaseTaskQueue queue;

    setUp(() {
      db = SqliteDbExecutor.inMemory();
      queue = DatabaseTaskQueue(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('ensureSchema creates the tasks table and index', () async {
      await queue.ensureSchema();

      final tables = await db.fetchAll(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = tables
          .map((r) => r.tryStringByName('name') ?? r.tryString(0))
          .whereType<String>()
          .toSet();

      expect(names, contains(queue.tableName));
    });

    test('enqueue and claimNext immediately-due task', () async {
      final enqueued =
          await queue.enqueue('send_welcome', {'email': 'alice@example.com'});

      expect(enqueued.id, isNotEmpty);
      expect(enqueued.taskName, 'send_welcome');
      expect(enqueued.status, BloomTaskStatus.pending);

      final claimed = await queue.claimNext();
      expect(claimed, isNotNull);
      expect(claimed!.id, enqueued.id);
      expect(claimed.status, BloomTaskStatus.running);
      expect(claimed.attempts, 1);
      expect(claimed.startedAt, isNotNull);
      expect(claimed.payload['email'], 'alice@example.com');
    });

    test('claimNext returns null when nothing is due', () async {
      await queue.enqueueScheduled(
        'future_task',
        {'step': 1},
        DateTime.now().add(const Duration(hours: 2)),
      );

      final claimed = await queue.claimNext();
      expect(claimed, isNull);
    });

    test('claimNext respects FIFO ordering by scheduledAt', () async {
      final now = DateTime.now();
      await queue.enqueueScheduled(
        'job_second',
        {},
        now.add(const Duration(seconds: 10)),
      );
      await queue.enqueueScheduled(
        'job_first',
        {},
        now,
      );

      final claimed =
          await queue.claimNext(now.add(const Duration(seconds: 15)));
      expect(claimed, isNotNull);
      expect(claimed!.taskName, 'job_first');
    });

    test('markCompleted transitions a claimed task to succeeded', () async {
      final task = await queue.enqueue('success_job', {'amount': 100});
      await queue.claimNext();

      await queue.markCompleted(task.id);

      final fetched = await queue.getTask(task.id);
      expect(fetched, isNotNull);
      expect(fetched!.status, BloomTaskStatus.succeeded);
      expect(fetched.finishedAt, isNotNull);
      expect(fetched.lastError, isNull);
    });

    test('markCompleted throws StateError for unknown task id', () async {
      expect(
        () => queue.markCompleted('non-existent-id'),
        throwsStateError,
      );
    });

    test('markFailed requeues with exponential backoff when attempts remain',
        () async {
      final task = await queue.enqueue('retry_job', {}, maxAttempts: 3);
      final claimed = await queue.claimNext(); // attempts -> 1
      final beforeFail = DateTime.now();

      await queue.markFailed(claimed!.id, errorMessage: 'network timeout');

      final retried = await queue.getTask(task.id);
      expect(retried, isNotNull);
      expect(retried!.status, BloomTaskStatus.pending);
      expect(retried.attempts, 1);
      expect(retried.lastError, 'network timeout');
      expect(retried.scheduledAt.isAfter(beforeFail), isTrue);

      // Should not be claimable before backoff time
      expect(await queue.claimNext(beforeFail), isNull);
    });

    test('markFailed honors explicit retryAfter override', () async {
      final task = await queue.enqueue('custom_retry', {}, maxAttempts: 3);
      final claimed = await queue.claimNext();
      final explicitRetry = DateTime.now().add(const Duration(minutes: 15));

      await queue.markFailed(
        claimed!.id,
        errorMessage: 'rate limited',
        retryAfter: explicitRetry,
      );

      final retried = await queue.getTask(task.id);
      expect(retried, isNotNull);
      expect(
        retried!.scheduledAt.millisecondsSinceEpoch,
        closeTo(explicitRetry.millisecondsSinceEpoch, 1000),
      );
    });

    test('markFailed transitions to failed once maxAttempts is reached',
        () async {
      final task = await queue.enqueue('doomed_job', {}, maxAttempts: 1);
      final claimed = await queue.claimNext(); // attempts -> 1 (== maxAttempts)

      await queue.markFailed(claimed!.id, errorMessage: 'fatal crash');

      final finalTask = await queue.getTask(task.id);
      expect(finalTask, isNotNull);
      expect(finalTask!.status, BloomTaskStatus.failed);
      expect(finalTask.lastError, 'fatal crash');
    });

    test('markFailed throws StateError for unknown task id', () async {
      expect(
        () => queue.markFailed('missing-id', errorMessage: 'err'),
        throwsStateError,
      );
    });

    test('allTasks and clear work as expected', () async {
      await queue.enqueue('task1', {'x': 1});
      await queue.enqueue('task2', {'x': 2});

      final all = await queue.allTasks();
      expect(all.length, 2);

      await queue.clear();
      expect(await queue.allTasks(), isEmpty);
    });

    test('BloomJobWorker runs end-to-end against DatabaseTaskQueue', () async {
      final registry = BloomTaskRegistry();
      var executed = false;
      registry.register('db_job', (payload) async {
        expect(payload['data'], 'val');
        executed = true;
      });

      await queue.enqueue('db_job', {'data': 'val'});

      final worker = BloomJobWorker(queue: queue, registry: registry);
      final processed = await worker.runOnce();

      expect(processed, isTrue);
      expect(executed, isTrue);

      final tasks = await queue.allTasks();
      expect(tasks.first.status, BloomTaskStatus.succeeded);
    });
  });
}
