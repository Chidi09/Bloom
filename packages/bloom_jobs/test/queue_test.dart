import 'package:bloom_jobs/bloom_jobs.dart';
import 'package:test/test.dart';

void main() {
  group('BloomTaskQueue enqueue/claim', () {
    test('claimNext returns an immediately-due task and marks it running', () async {
      final queue = BloomTaskQueue();
      final enqueued = await queue.enqueue('send_email', {'to': 'a@b.com'});
      final claimed = await queue.claimNext();

      expect(claimed, isNotNull);
      expect(claimed!.id, enqueued.id);
      expect(claimed.status, BloomTaskStatus.running);
      expect(claimed.attempts, 1);
    });

    test('claimNext returns null when nothing is due', () async {
      final queue = BloomTaskQueue();
      await queue.enqueueScheduled('later', {}, DateTime.now().add(const Duration(hours: 1)));
      expect(await queue.claimNext(), isNull);
    });

    test('claimNext respects FIFO ordering by scheduledAt', () async {
      final queue = BloomTaskQueue();
      final now = DateTime.now();
      await queue.enqueueScheduled('second', {}, now.add(const Duration(seconds: 2)));
      await queue.enqueueScheduled('first', {}, now);

      final claimed = await queue.claimNext(now.add(const Duration(seconds: 5)));
      expect(claimed!.taskName, 'first');
    });
  });

  group('markCompleted', () {
    test('transitions a claimed task to succeeded', () async {
      final queue = BloomTaskQueue();
      final task = await queue.enqueue('job', {});
      await queue.claimNext();
      await queue.markCompleted(task.id);

      final fetched = await queue.getTask(task.id);
      expect(fetched!.status, BloomTaskStatus.succeeded);
    });

    test('throws StateError for an unknown task id', () async {
      final queue = BloomTaskQueue();
      expect(() => queue.markCompleted('does-not-exist'), throwsStateError);
    });
  });

  group('markFailed retry/backoff', () {
    test('requeues as pending with exponential backoff when attempts remain', () async {
      final queue = BloomTaskQueue();
      final task = await queue.enqueue('flaky_job', {}, maxAttempts: 3);
      final claimed = await queue.claimNext(); // attempts -> 1
      final beforeFail = DateTime.now();

      await queue.markFailed(claimed!.id, errorMessage: 'boom');

      final rescheduled = await queue.getTask(task.id);
      expect(rescheduled, isNotNull);
      expect(rescheduled!.status, BloomTaskStatus.pending);
      expect(rescheduled.lastError, 'boom');
      // Regression: a failed task with retries remaining must NOT be
      // immediately re-claimable — it needs a real backoff delay applied
      // when the caller doesn't supply an explicit retryAfter.
      expect(rescheduled.scheduledAt.isAfter(beforeFail), isTrue);
      expect(await queue.claimNext(beforeFail), isNull,
          reason: 'should not be claimable again before its backoff elapses');
    });

    test('honors an explicit retryAfter override', () async {
      final queue = BloomTaskQueue();
      await queue.enqueue('job', {}, maxAttempts: 3);
      final claimed = await queue.claimNext();
      final explicitRetry = DateTime.now().add(const Duration(minutes: 5));

      await queue.markFailed(claimed!.id, errorMessage: 'boom', retryAfter: explicitRetry);

      final rescheduled = await queue.getTask(claimed.id);
      expect(rescheduled!.scheduledAt, explicitRetry);
    });

    test('marks the task failed (not requeued) once maxAttempts is exhausted', () async {
      final queue = BloomTaskQueue();
      final task = await queue.enqueue('doomed_job', {}, maxAttempts: 1);
      final claimed = await queue.claimNext(); // attempts -> 1 (== maxAttempts)

      await queue.markFailed(claimed!.id, errorMessage: 'final failure');

      final finalTask = await queue.getTask(task.id);
      expect(finalTask!.status, BloomTaskStatus.failed);
    });

    test('throws StateError for an unknown task id', () async {
      final queue = BloomTaskQueue();
      expect(
        () => queue.markFailed('does-not-exist', errorMessage: 'x'),
        throwsStateError,
      );
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
