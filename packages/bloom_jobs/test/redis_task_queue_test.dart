import 'dart:io';
import 'package:bloom_jobs/bloom_jobs.dart';
import 'package:test/test.dart';

void main() {
  group('RedisTaskQueue URL parsing', () {
    test('parses standard redis:// URLs with auth, port, and db', () {
      final queue = RedisTaskQueue.fromUrl(
        'redis://:mypassword@127.0.0.1:6380/3',
        prefix: 'custom_jobs',
      );

      expect(queue.host, '127.0.0.1');
      expect(queue.port, 6380);
      expect(queue.password, 'mypassword');
      expect(queue.db, 3);
      expect(queue.secure, isFalse);
      expect(queue.prefix, 'custom_jobs');
    });

    test('parses rediss:// TLS connection URLs', () {
      final queue = RedisTaskQueue.fromUrl('rediss://secure.redis.host:6379/0');
      expect(queue.host, 'secure.redis.host');
      expect(queue.port, 6379);
      expect(queue.secure, isTrue);
      expect(queue.prefix, 'bloom_jobs');
    });
  });

  group('RedisTaskQueue integration (live Redis)', () {
    late RedisTaskQueue queue;
    bool redisAvailable = false;

    setUpAll(() async {
      try {
        final socket = await Socket.connect(
          'localhost',
          6379,
          timeout: const Duration(milliseconds: 400),
        );
        await socket.close();
        redisAvailable = true;
      } catch (_) {
        redisAvailable = false;
      }
    });

    setUp(() {
      if (!redisAvailable) return;
      final uniquePrefix =
          'test_jobs_${DateTime.now().microsecondsSinceEpoch}';
      queue = RedisTaskQueue(prefix: uniquePrefix);
    });

    tearDown(() async {
      if (!redisAvailable) return;
      await queue.clear();
      await queue.close();
    });

    test('enqueue, claimNext, and markCompleted', () async {
      if (!redisAvailable) {
        // Gracefully skip when Redis server is not running locally
        return;
      }

      final task =
          await queue.enqueue('send_email', {'to': 'user@example.com'});
      expect(task.id, isNotEmpty);
      expect(task.taskName, 'send_email');

      final claimed = await queue.claimNext();
      expect(claimed, isNotNull);
      expect(claimed!.id, task.id);
      expect(claimed.status, BloomTaskStatus.running);
      expect(claimed.attempts, 1);
      expect(claimed.startedAt, isNotNull);

      await queue.markCompleted(task.id);
      final finished = await queue.getTask(task.id);
      expect(finished, isNotNull);
      expect(finished!.status, BloomTaskStatus.succeeded);
      expect(finished.finishedAt, isNotNull);
    });

    test('scheduled tasks are not claimed before due time', () async {
      if (!redisAvailable) return;

      final futureTime = DateTime.now().add(const Duration(hours: 1));
      await queue.enqueueScheduled('future_job', {'id': 1}, futureTime);

      final claimed = await queue.claimNext();
      expect(claimed, isNull);
    });

    test('markFailed retries with backoff and marks failed on maxAttempts',
        () async {
      if (!redisAvailable) return;

      final task = await queue.enqueue('flaky', {}, maxAttempts: 2);
      final claimed1 = await queue.claimNext();
      expect(claimed1, isNotNull);

      final beforeFail = DateTime.now();
      await queue.markFailed(task.id, errorMessage: 'transient failure');

      final retry1 = await queue.getTask(task.id);
      expect(retry1, isNotNull);
      expect(retry1!.status, BloomTaskStatus.pending);
      expect(retry1.attempts, 1);
      expect(retry1.lastError, 'transient failure');
      expect(retry1.scheduledAt.isAfter(beforeFail), isTrue);

      // Claim with future time
      final claimed2 =
          await queue.claimNext(DateTime.now().add(const Duration(minutes: 5)));
      expect(claimed2, isNotNull);
      expect(claimed2!.attempts, 2);

      await queue.markFailed(task.id, errorMessage: 'permanent failure');
      final finalTask = await queue.getTask(task.id);
      expect(finalTask!.status, BloomTaskStatus.failed);
      expect(finalTask.lastError, 'permanent failure');
    });

    test('markCompleted and markFailed throw StateError for missing task',
        () async {
      if (!redisAvailable) return;

      expect(
        () => queue.markCompleted('non-existent'),
        throwsStateError,
      );
      expect(
        () => queue.markFailed('non-existent', errorMessage: 'err'),
        throwsStateError,
      );
    });

    test('allTasks and clear work as expected', () async {
      if (!redisAvailable) return;

      await queue.enqueue('task_a', {});
      await queue.enqueue('task_b', {});

      final all = await queue.allTasks();
      expect(all.length, 2);

      await queue.clear();
      expect(await queue.allTasks(), isEmpty);
    });

    test('BloomJobWorker runs end-to-end against RedisTaskQueue', () async {
      if (!redisAvailable) return;

      final registry = BloomTaskRegistry();
      var processed = false;
      registry.register('redis_worker_job', (payload) async {
        processed = true;
      });

      await queue.enqueue('redis_worker_job', {'key': 'val'});

      final worker = BloomJobWorker(queue: queue, registry: registry);
      final didRun = await worker.runOnce();

      expect(didRun, isTrue);
      expect(processed, isTrue);

      final tasks = await queue.allTasks();
      expect(tasks.first.status, BloomTaskStatus.succeeded);
    });
  });
}
