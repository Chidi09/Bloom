import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';
import 'task_detail_sheet.dart';

class UpcomingView extends StatelessWidget {
  const UpcomingView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    final todayTasks = store.tasks.where((t) => t.dueAt != null && t.dueAt!.isAfter(today.subtract(const Duration(seconds: 1))) && t.dueAt!.isBefore(tomorrow)).toList();
    final tomorrowTasks = store.tasks.where((t) => t.dueAt != null && t.dueAt!.isAfter(tomorrow.subtract(const Duration(seconds: 1))) && t.dueAt!.isBefore(tomorrow.add(const Duration(days: 1)))).toList();
    final upcoming7Days = store.tasks.where((t) => t.dueAt != null && t.dueAt!.isAfter(tomorrow.add(const Duration(days: 1))) && t.dueAt!.isBefore(nextWeek)).toList();
    final laterTasks = store.tasks.where((t) => t.dueAt == null || t.dueAt!.isAfter(nextWeek)).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildTimelineGroup(context, store, 'Today', todayTasks),
        const SizedBox(height: 24),
        _buildTimelineGroup(context, store, 'Tomorrow', tomorrowTasks),
        const SizedBox(height: 24),
        _buildTimelineGroup(context, store, 'Next 7 Days', upcoming7Days),
        const SizedBox(height: 24),
        _buildTimelineGroup(context, store, 'Later & Backlog', laterTasks),
      ],
    );
  }

  Widget _buildTimelineGroup(BuildContext context, TaskStore store, String label, List<Task> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No tasks scheduled for $label', style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
          )
        else
          ...tasks.map((t) => _buildTaskTile(context, store, t)),
      ],
    );
  }

  Widget _buildTaskTile(BuildContext context, TaskStore store, Task task) {
    final project = store.getProject(task.projectId);
    final color = _parseColor(project.colorHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => TaskDetailSheet.show(context, task),
        borderRadius: BorderRadius.circular(10),
        child: BloomCard(
          size: BloomCardSize.sm,
          backgroundColor: task.isCompleted ? const Color(0xFF0F0F13).withValues(alpha: 0.6) : const Color(0xFF14141A),
          borderColor: task.isCompleted ? const Color(0xFF1A1A20) : const Color(0xFF22222A),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted ? const Color(0xFF71717A) : Colors.white,
                  ),
                ),
              ),
              BloomBadge(
                variant: BloomBadgeVariant.outline,
                size: BloomBadgeSize.sm,
                leading: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                child: Text(project.name),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _parseColor(String? hex) {
    if (hex == null) return const Color(0xFF6366F1);
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('0xFF$clean'));
    }
    return const Color(0xFF6366F1);
  }
}
