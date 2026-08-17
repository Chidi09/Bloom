// lib/bloom_jobs.dart
/// Background job queue and worker library for Bloom applications.
///
/// Provides in-memory asynchronous task queuing with atomic claiming guarantees,
/// named handler registration via [BloomTaskRegistry], scheduled and recurring tasks
/// via [BloomRecurringRegistry], and background worker execution via [BloomJobWorker].
///
/// Example usage:
/// ```dart
/// final registry = BloomTaskRegistry();
/// final queue = BloomTaskQueue();
///
/// // Register handler
/// registry.register('send_email', (payload) async {
///   print('Sending email to ${payload['email']}');
/// });
///
/// // Enqueue task
/// await queue.enqueue('send_email', {'email': 'user@example.com'});
///
/// // Process task with worker
/// final worker = BloomJobWorker(queue: queue, registry: registry);
/// await worker.runOnce();
/// ```
library bloom_jobs;

export 'src/task.dart';
export 'src/registry.dart';
export 'src/queue.dart';
export 'src/recurring.dart';
export 'src/worker.dart';

