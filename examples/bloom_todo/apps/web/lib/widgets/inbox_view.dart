import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';
import 'task_detail_sheet.dart';

class InboxView extends StatelessWidget {
  const InboxView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;
    final inboxTasks = store.tasks.where((t) => t.projectId == 'prj_1' && !t.isCompleted).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        BloomCard(
          backgroundColor: const Color(0xFF111116),
          borderColor: const Color(0xFF22222A),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF59E0B), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Inbox Triage: Quickly capture and categorize tasks before organizing them into active projects.',
                    style: TextStyle(fontSize: 13, color: Color(0xFFA1A1AA)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...inboxTasks.map((t) => _buildTaskTile(context, store, t)),
      ],
    );
  }

  Widget _buildTaskTile(BuildContext context, TaskStore store, Task task) {
    final project = store.getProject(task.projectId);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => TaskDetailSheet.show(context, task),
        borderRadius: BorderRadius.circular(10),
        child: BloomCard(
          size: BloomCardSize.sm,
          backgroundColor: const Color(0xFF14141A),
          borderColor: const Color(0xFF22222A),
          child: Row(
            children: [
              BloomCheckbox(
                checked: task.isCompleted,
                onChanged: (_) => store.toggleTaskComplete(task.id),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ),
              BloomBadge(
                variant: BloomBadgeVariant.outline,
                size: BloomBadgeSize.sm,
                child: Text(project.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
