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
      final uniquePrefix = 'test_jobs_${DateTime.now().microsecondsSinceEpoch}';
      queue = RedisTaskQueue(prefix: uniquePrefix);
    });

    tearDown(() async {
      if (!redisAvailable) return;
      await queue.clear();
      await queue.close();
    });

    test('enqueue, claimNext, and markCompleted with token', () async {
      if (!redisAvailable) {
        // Gracefully skip when Redis server is not running locally
        return;
      }

      final task =
          await queue.enqueue('send_email', {'to': 'user@example.com'});
      expect(task.id, isNotEmpty);
      expect(task.taskName, 'send_email');

      final beforeClaim = DateTime.now().toUtc();
      final claimed = await queue.claimNext();
      expect(claimed, isNotNull);
      expect(claimed!.id, task.id);
      expect(claimed.status, BloomTaskStatus.running);
      expect(claimed.attempts, 1);
      expect(claimed.startedAt, isNotNull);
      expect(claimed.token, isNotNull);
      expect(claimed.token, isNotEmpty);
      expect(claimed.leaseExpiresAt, isNotNull);
      expect(
        claimed.leaseExpiresAt!
            .isAfter(beforeClaim.add(const Duration(minutes: 4))),
        isTrue,
      );

      await queue.markCompleted(task.id, token: claimed.token);
      final finished = await queue.getTask(task.id);
      expect(finished, isNotNull);
      expect(finished!.status, BloomTaskStatus.succeeded);
      expect(finished.finishedAt, isNotNull);
      expect(finished.token, isNull);
      expect(finished.leaseExpiresAt, isNull);
    });

    test('token enforcement on markCompleted and markFailed in Redis',
        () async {
      if (!redisAvailable) return;

      final task = await queue.enqueue('token_redis_job', {});
      final claimed = await queue.claimNext();

      // Missing token
      expect(() => queue.markCompleted(task.id), throwsStateError);
      expect(
        () => queue.markFailed(task.id, errorMessage: 'err'),
        throwsStateError,
      );

      // Wrong token
      expect(
        () => queue.markCompleted(task.id, token: 'wrong_tok'),
        throwsStateError,
      );
      expect(
        () =>
            queue.markFailed(task.id, token: 'wrong_tok', errorMessage: 'err'),
        throwsStateError,
      );

      // Complete with correct token
      await queue.markCompleted(task.id, token: claimed!.token);
      final finished = await queue.getTask(task.id);
      expect(finished!.status, BloomTaskStatus.succeeded);
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
      await queue.markFailed(
        task.id,
        token: claimed1!.token,
        errorMessage: 'transient failure',
      );

      final retry1 = await queue.getTask(task.id);
      expect(retry1, isNotNull);
      expect(retry1!.status, BloomTaskStatus.pending);
      expect(retry1.attempts, 1);
      expect(retry1.lastError, 'transient failure');
      expect(retry1.token, isNull);
      expect(retry1.scheduledAt.isAfter(beforeFail), isTrue);

      // Claim with future time
      final claimed2 =
          await queue.claimNext(DateTime.now().add(const Duration(minutes: 5)));
      expect(claimed2, isNotNull);
      expect(claimed2!.attempts, 2);

      await queue.markFailed(
        task.id,
        token: claimed2.token,
        errorMessage: 'permanent failure',
      );
      final finalTask = await queue.getTask(task.id);
      expect(finalTask!.status, BloomTaskStatus.failed);
      expect(finalTask.lastError, 'permanent failure');
      expect(finalTask.token, isNull);
    });

    test('markCompleted and markFailed throw StateError for missing task',
        () async {
      if (!redisAvailable) return;

      expect(
        () => queue.markCompleted('non-existent', token: 'tok'),
        throwsStateError,
      );
      expect(
        () =>
            queue.markFailed('non-existent', token: 'tok', errorMessage: 'err'),
        throwsStateError,
      );
    });

    test(
        'recovery after expiry in Redis: expired running task is reclaimed before pending work',
        () async {
      if (!redisAvailable) return;

      final t0 = DateTime.now().toUtc();
      final task = await queue.enqueueScheduled('redis_lease_job', {}, t0,
          maxAttempts: 3);

      final claimed1 = await queue.claimNext(t0, const Duration(seconds: 5));
      expect(claimed1, isNotNull);
      expect(claimed1!.attempts, 1);
      final token1 = claimed1.token;

      // Before expiry: no due task
      final t3 = t0.add(const Duration(seconds: 3));
      expect(await queue.claimNext(t3), isNull);

      // After expiry: reclaimed and claimed with new token
      final t6 = t0.add(const Duration(seconds: 6));
      final claimed2 = await queue.claimNext(t6, const Duration(seconds: 5));
      expect(claimed2, isNotNull);
      expect(claimed2!.id, task.id);
      expect(claimed2.attempts, 2);
      expect(claimed2.token, isNot(equals(token1)));
    });

    test(
        'stale completion rejection in Redis: stale token cannot update a reclaimed task',
        () async {
      if (!redisAvailable) return;

      final t0 = DateTime.now().toUtc();
      final task = await queue.enqueueScheduled('stale_redis_job', {}, t0,
          maxAttempts: 3);

      final worker1 = await queue.claimNext(t0, const Duration(seconds: 5));
      expect(worker1, isNotNull);
      final staleToken = worker1!.token;

      final t6 = t0.add(const Duration(seconds: 6));
      final worker2 = await queue.claimNext(t6, const Duration(seconds: 5));
      expect(worker2, isNotNull);
      final activeToken = worker2!.token;

      // Worker 1 stale attempts -> REJECTED
      expect(
        () => queue.markCompleted(task.id, token: staleToken),
        throwsStateError,
      );
      expect(
        () => queue.markFailed(task.id, token: staleToken, errorMessage: 'err'),
        throwsStateError,
      );

      // Worker 2 completes successfully
      await queue.markCompleted(task.id, token: activeToken);
      final finished = await queue.getTask(task.id);
      expect(finished!.status, BloomTaskStatus.succeeded);
    });

    test(
        'expired task that reached maxAttempts in Redis is marked failed upon lease expiration',
        () async {
      if (!redisAvailable) return;

      final t0 = DateTime.now().toUtc();
      final task = await queue.enqueueScheduled('redis_one_shot', {}, t0,
          maxAttempts: 1);

      final claimed = await queue.claimNext(t0, const Duration(seconds: 5));
      expect(claimed, isNotNull);
      expect(claimed!.attempts, 1);

      final t6 = t0.add(const Duration(seconds: 6));
      final nextClaim = await queue.claimNext(t6);
      expect(nextClaim, isNull);

      final finalTask = await queue.getTask(task.id);
      expect(finalTask!.status, BloomTaskStatus.failed);
      expect(finalTask.lastError, contains('lease expired'));
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
