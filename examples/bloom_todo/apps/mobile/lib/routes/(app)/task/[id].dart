import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_ui/ui.dart';

class TaskDetailPage extends StatelessWidget {
  final String taskId;

  const TaskDetailPage({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Details', style: TodoTypography.h3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review Bloom architecture blueprint', style: TodoTypography.h2),
            const SizedBox(height: 12),
            Text(
              'Check melos pipeline, Shorebird OTA and multi-isolate cluster',
              style: TodoTypography.body.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const DueDateChip(dueAt: null),
                const SizedBox(width: 8),
                PrioritySelector(
                  selected: Priority.p1,
                  onChanged: (p) {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text('Activity & Comments', style: TodoTypography.h3),
            const SizedBox(height: 12),
            Text(
              'No comments yet. Start the conversation below.',
              style: TodoTypography.caption.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
