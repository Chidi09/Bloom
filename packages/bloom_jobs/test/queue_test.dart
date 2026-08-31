import 'package:bloom_jobs/bloom_jobs.dart';
import 'package:test/test.dart';

void main() {
  group('BloomTaskQueue enqueue/claim', () {
    test(
        'claimNext returns an immediately-due task and marks it running with token and lease',
        () async {
      final queue = BloomTaskQueue();
      final enqueued = await queue.enqueue('send_email', {'to': 'a@b.com'});
      final beforeClaim = DateTime.now();
      final claimed = await queue.claimNext();

      expect(claimed, isNotNull);
      expect(claimed!.id, enqueued.id);
      expect(claimed.status, BloomTaskStatus.running);
      expect(claimed.attempts, 1);
      expect(claimed.token, isNotNull);
      expect(claimed.token, isNotEmpty);
      expect(claimed.leaseExpiresAt, isNotNull);
      expect(
        claimed.leaseExpiresAt!
            .isAfter(beforeClaim.add(const Duration(minutes: 4))),
        isTrue,
      );
    });

    test(
        'claimNext uses custom defaultLeaseDuration and parameter leaseDuration',
        () async {
      final queue =
          InMemoryTaskQueue(defaultLeaseDuration: const Duration(minutes: 10));
      final now = DateTime.now();
      await queue.enqueueScheduled('job_default', {}, now);
      final claimed1 = await queue.claimNext(now);
      expect(
        claimed1!.leaseExpiresAt!.difference(now).inMinutes,
        10,
      );

      final now2 = DateTime.now();
      await queue.enqueueScheduled('job_override', {}, now2);
      final claimed2 = await queue.claimNext(now2, const Duration(minutes: 20));
      expect(
        claimed2!.leaseExpiresAt!.difference(now2).inMinutes,
        20,
      );
    });

    test('claimNext returns null when nothing is due', () async {
      final queue = BloomTaskQueue();
      await queue.enqueueScheduled(
          'later', {}, DateTime.now().add(const Duration(hours: 1)));
      expect(await queue.claimNext(), isNull);
    });

    test('claimNext respects FIFO ordering by scheduledAt', () async {
      final queue = BloomTaskQueue();
      final now = DateTime.now();
      await queue.enqueueScheduled(
          'second', {}, now.add(const Duration(seconds: 2)));
      await queue.enqueueScheduled('first', {}, now);

      final claimed =
          await queue.claimNext(now.add(const Duration(seconds: 5)));
      expect(claimed!.taskName, 'first');
    });
  });

  group('markCompleted and token enforcement', () {
    test('transitions a claimed task to succeeded with matching token',
        () async {
      final queue = BloomTaskQueue();
      final task = await queue.enqueue('job', {});
      final claimed = await queue.claimNext();
      await queue.markCompleted(task.id, token: claimed!.token);

      final fetched = await queue.getTask(task.id);
      expect(fetched!.status, BloomTaskStatus.succeeded);
      expect(fetched.token, isNull);
      expect(fetched.leaseExpiresAt, isNull);
    });

    test('throws StateError when token is missing, null, or invalid', () async {
      final queue = BloomTaskQueue();
      final task = await queue.enqueue('job', {});
      final claimed = await queue.claimNext();

      // Null / missing token
      expect(() => queue.markCompleted(task.id), throwsStateError);
      // Mismatched token
      expect(
        () => queue.markCompleted(task.id, token: 'wrong-token'),
        throwsStateError,
      );

      // Task remains running
      final fetched = await queue.getTask(task.id);
      expect(fetched!.status, BloomTaskStatus.running);

      // Successfully complete with correct token
      await queue.markCompleted(task.id, token: claimed!.token);
      final finished = await queue.getTask(task.id);
      expect(finished!.status, BloomTaskStatus.succeeded);
    });

    test('throws StateError for an unknown task id', () async {
      final queue = BloomTaskQueue();
      expect(
        () => queue.markCompleted('does-not-exist', token: 'any-token'),
        throwsStateError,
      );
    });
  });

  group('markFailed retry/backoff and token enforcement', () {
    test('requeues as pending with exponential backoff when attempts remain',
        () async {
      final queue = BloomTaskQueue();
      final task = await queue.enqueue('flaky_job', {}, maxAttempts: 3);
      final claimed = await queue.claimNext(); // attempts -> 1
      final beforeFail = DateTime.now();

      await queue.markFailed(claimed!.id,
          token: claimed.token, errorMessage: 'boom');

      final rescheduled = await queue.getTask(task.id);
      expect(rescheduled, isNotNull);
      expect(rescheduled!.status, BloomTaskStatus.pending);
      expect(rescheduled.lastError, 'boom');
      expect(rescheduled.token, isNull);
      expect(rescheduled.leaseExpiresAt, isNull);
      expect(rescheduled.scheduledAt.isAfter(beforeFail), isTrue);
      expect(await queue.claimNext(beforeFail), isNull,
          reason: 'should not be claimable again before its backoff elapses');
    });

    test('honors an explicit retryAfter override', () async {
      final queue = BloomTaskQueue();
      await queue.enqueue('job', {}, maxAttempts: 3);
      final claimed = await queue.claimNext();
      final explicitRetry = DateTime.now().add(const Duration(minutes: 5));

      await queue.markFailed(
        claimed!.id,
        token: claimed.token,
        errorMessage: 'boom',
        retryAfter: explicitRetry,
      );

      final rescheduled = await queue.getTask(claimed.id);
      expect(rescheduled!.scheduledAt, explicitRetry);
    });

    test('marks the task failed (not requeued) once maxAttempts is exhausted',
        () async {
      final queue = BloomTaskQueue();
      final task = await queue.enqueue('doomed_job', {}, maxAttempts: 1);
      final claimed = await queue.claimNext(); // attempts -> 1 (== maxAttempts)

      await queue.markFailed(
        claimed!.id,
        token: claimed.token,
        errorMessage: 'final failure',
      );

      final finalTask = await queue.getTask(task.id);
      expect(finalTask!.status, BloomTaskStatus.failed);
      expect(finalTask.token, isNull);
    });

    test('throws StateError on markFailed without valid token', () async {
      final queue = BloomTaskQueue();
      final task = await queue.enqueue('job', {});
      await queue.claimNext();

      expect(
        () => queue.markFailed(task.id, errorMessage: 'err'),
        throwsStateError,
      );
      expect(
        () =>
            queue.markFailed(task.id, token: 'bad-token', errorMessage: 'err'),
        throwsStateError,
      );
    });

    test('throws StateError for an unknown task id', () async {
      final queue = BloomTaskQueue();
      expect(
        () =>
            queue.markFailed('does-not-exist', token: 'tok', errorMessage: 'x'),
        throwsStateError,
      );
    });
  });

  group('Durability: Lease expiry, recovery, and stale token rejection', () {
    test(
        'recovery after expiry: expired running task is reclaimed before pending work',
        () async {
      final queue = BloomTaskQueue();
      final t0 = DateTime.now();
      final task =
          await queue.enqueueScheduled('long_job', {}, t0, maxAttempts: 3);

      // Claim at t0 with 5s lease
      final claimed1 = await queue.claimNext(t0, const Duration(seconds: 5));
      expect(claimed1, isNotNull);
      expect(claimed1!.attempts, 1);
      final token1 = claimed1.token;

      // At t0 + 3s: not yet expired, no other pending task -> claimNext is null
      final t3 = t0.add(const Duration(seconds: 3));
      expect(await queue.claimNext(t3), isNull);

      // At t0 + 6s: lease expired -> claimNext reclaims and claims it
      final t6 = t0.add(const Duration(seconds: 6));
      final claimed2 = await queue.claimNext(t6, const Duration(seconds: 5));
      expect(claimed2, isNotNull);
      expect(claimed2!.id, task.id);
      expect(claimed2.attempts, 2);
      expect(claimed2.token, isNot(equals(token1)));
      expect(claimed2.status, BloomTaskStatus.running);
    });

    test(
        'stale completion rejection: stale token cannot update a reclaimed task',
        () async {
      final queue = BloomTaskQueue();
      final t0 = DateTime.now();
      final task =
          await queue.enqueueScheduled('reclaimed_job', {}, t0, maxAttempts: 3);

      // Worker 1 claims task
      final worker1Claim =
          await queue.claimNext(t0, const Duration(seconds: 5));
      expect(worker1Claim, isNotNull);
      final staleToken = worker1Claim!.token;

      // Lease expires and Worker 2 claims it
      final t6 = t0.add(const Duration(seconds: 6));
      final worker2Claim =
          await queue.claimNext(t6, const Duration(seconds: 5));
      expect(worker2Claim, isNotNull);
      final activeToken = worker2Claim!.token;

      // Worker 1 attempts to complete task with staleToken -> REJECTED
      expect(
        () => queue.markCompleted(task.id, token: staleToken),
        throwsStateError,
      );

      // Worker 1 attempts to fail task with staleToken -> REJECTED
      expect(
        () => queue.markFailed(task.id, token: staleToken, errorMessage: 'err'),
        throwsStateError,
      );

      // Task remains running under Worker 2
      final current = await queue.getTask(task.id);
      expect(current!.status, BloomTaskStatus.running);
      expect(current.token, activeToken);

      // Worker 2 completes successfully with activeToken
      await queue.markCompleted(task.id, token: activeToken);
      final finished = await queue.getTask(task.id);
      expect(finished!.status, BloomTaskStatus.succeeded);
    });

    test(
        'expired task that reached maxAttempts is marked failed upon lease expiration',
        () async {
      final queue = BloomTaskQueue();
      final t0 = DateTime.now();
      final task =
          await queue.enqueueScheduled('one_shot', {}, t0, maxAttempts: 1);

      final claimed = await queue.claimNext(t0, const Duration(seconds: 5));
      expect(claimed, isNotNull);
      expect(claimed!.attempts, 1);

      // At t0 + 6s: expired running task with attempts >= maxAttempts
      final t6 = t0.add(const Duration(seconds: 6));
      final nextClaim = await queue.claimNext(t6);
      expect(nextClaim, isNull);

      final finalTask = await queue.getTask(task.id);
      expect(finalTask!.status, BloomTaskStatus.failed);
      expect(finalTask.lastError, contains('lease expired'));
    });
  });

  group('Recurring tasks interval validation', () {
    test('rejects zero or negative interval with ArgumentError', () {
      final registry = BloomRecurringRegistry();

      expect(
        () => registry.register(taskName: 'bad_zero', interval: Duration.zero),
        throwsArgumentError,
      );
      expect(
        () => registry.register(
          taskName: 'bad_negative',
          interval: const Duration(seconds: -10),
        ),
        throwsArgumentError,
      );
      expect(
        () => BloomRecurringTask(
          id: '1',
          taskName: 'bad_task',
          interval: Duration.zero,
        ),
        throwsArgumentError,
      );
    });

    test('accepts strictly positive interval and ticks due tasks', () async {
      final registry = BloomRecurringRegistry();
      final recurring = registry.register(
        taskName: 'valid_job',
        interval: const Duration(minutes: 1),
        payload: {'v': 1},
      );
      expect(recurring.interval, const Duration(minutes: 1));

      final queue = BloomTaskQueue();
      final tickTime = DateTime.now().add(const Duration(minutes: 2));
      final count = await registry.tick(queue, tickTime);
      expect(count, 1);

      final claimed = await queue.claimNext(tickTime);
      expect(claimed, isNotNull);
      expect(claimed!.taskName, 'valid_job');
    });
  });

  group('clear/allTasks', () {
    test('allTasks reflects enqueued tasks', () async {
      final queue = BloomTaskQueue();
      await queue.enqueue('a', {});
      await queue.enqueue('b', {});
      expect((await queue.allTasks()).length, 2);
    });

    test('clear empties the queue', () async {
      final queue = BloomTaskQueue();
      await queue.enqueue('a', {});
      await queue.clear();
      expect(await queue.allTasks(), isEmpty);
    });
  });
}
