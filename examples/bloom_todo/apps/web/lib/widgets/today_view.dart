import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';
import 'task_detail_sheet.dart';

class TodayView extends StatefulWidget {
  final String selectedFilter;
  final String selectedProjectId;

  const TodayView({
    super.key,
    required this.selectedFilter,
    required this.selectedProjectId,
  });

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  final _inlineAddCtrl = TextEditingController();

  void _handleInlineAdd() {
    final text = _inlineAddCtrl.text.trim();
    if (text.isEmpty) return;

    TaskStore.instance.createTask(
      title: text,
      projectId: widget.selectedProjectId,
      priority: Priority.p2,
      dueAt: DateTime.now(),
    );
    _inlineAddCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final filtered = _getFilteredTasks(store);
    final overdue = filtered.where((t) => !t.isCompleted && t.dueAt != null && t.dueAt!.isBefore(todayStart)).toList();
    final dueToday = filtered.where((t) => !t.isCompleted && t.dueAt != null && t.dueAt!.isAfter(todayStart.subtract(const Duration(seconds: 1))) && t.dueAt!.isBefore(tomorrowStart)).toList();
    final completed = filtered.where((t) => t.isCompleted).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inline Quick Add Bar
          BloomCard(
            backgroundColor: const Color(0xFF111116),
            borderColor: const Color(0xFF22222A),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _inlineAddCtrl,
                      onSubmitted: (_) => _handleInlineAdd(),
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Quick add a task for today... (Press Enter)',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF71717A)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  BloomButton(
                    size: BloomButtonSize.xs,
                    onPressed: _handleInlineAdd,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Overdue Section
          if (overdue.isNotEmpty) ...[
            _buildSectionHeader('Overdue', overdue.length, const Color(0xFFEF4444)),
            const SizedBox(height: 8),
            ...overdue.map((t) => _buildTaskTile(context, store, t)),
            const SizedBox(height: 24),
          ],

          // Due Today Section
          _buildSectionHeader('Due Today', dueToday.length, const Color(0xFF6366F1)),
          const SizedBox(height: 8),
          if (dueToday.isEmpty)
            _buildEmptyState('All caught up for today!', 'Press Q or use the box above to schedule a new task.')
          else
            ...dueToday.map((t) => _buildTaskTile(context, store, t)),

          const SizedBox(height: 24),

          // Completed Section
          if (completed.isNotEmpty) ...[
            _buildSectionHeader('Completed', completed.length, const Color(0xFF10B981)),
            const SizedBox(height: 8),
            ...completed.map((t) => _buildTaskTile(context, store, t)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color indicatorColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: indicatorColor),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
        ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        color: task.isCompleted ? const Color(0xFF71717A) : Colors.white,
                      ),
                    ),
                    if (task.description != null && task.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          task.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BloomBadge(
                    variant: BloomBadgeVariant.outline,
                    size: BloomBadgeSize.sm,
                    leading: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                    child: Text(project.name),
                  ),
                  const SizedBox(width: 6),
                  ...task.labels.map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: BloomBadge(
                        variant: BloomBadgeVariant.secondary,
                        size: BloomBadgeSize.sm,
                        child: Text('@$l'),
                      ),
                    ),
                  ),
                  const BloomAvatar(name: 'Alex Rivers', size: BloomAvatarSize.sm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.task_alt_rounded, size: 36, color: Color(0xFF27272A)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFA1A1AA))),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
            ],
          ],
        ),
      ),
    );
  }

  List<Task> _getFilteredTasks(TaskStore store) {
    return store.tasks.where((t) {
      if (widget.selectedFilter == 'p1') return t.priority == Priority.p1;
      if (widget.selectedFilter == 'my_tasks') return t.creatorId == 'usr_demo_123';
      return true;
    }).toList();
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
