import 'package:bloom_jobs/bloom_jobs.dart';

void registerTaskJobs(BloomTaskRegistry registry, BloomRecurringRegistry recurring) {
  // 1. Task Reminders Handler
  registry.register('send_task_reminder', (payload) async {
    // Dispatch push notification or email to payload['userId']
  });

  // 2. Register Handler for recurring generator
  registry.register('generate_recurring_tasks', (payload) async {
    // 1. Query completed recurring tasks with overdue next occurrences
    // 2. Compute next date via RecurrenceParser
    // 3. Clone task to next occurrence
  });

  // 3. Schedule Hourly Recurring Task Generator
  recurring.register(
    taskName: 'generate_recurring_tasks',
    interval: const Duration(hours: 1),
  );
}
