import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../state/task_store.dart';
import 'task_detail_sheet.dart';
import 'quick_add_dialog.dart';

class KanbanBoardView extends StatelessWidget {
  final String selectedProjectId;

  const KanbanBoardView({super.key, required this.selectedProjectId});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;
    final projectTasks = store.tasks.where((t) => t.projectId == selectedProjectId).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...store.kanbanColumns.map((col) {
            final columnTasks = projectTasks.where((t) => (t.sectionId ?? 'In Progress') == col).toList();

            return DragTarget<Task>(
              onWillAcceptWithDetails: (details) => details.data.sectionId != col,
              onAcceptWithDetails: (details) {
                store.moveTaskSection(details.data.id, col);
              },
              builder: (context, candidateData, rejectedData) {
                final isHovered = candidateData.isNotEmpty;

                return Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: isHovered ? const Color(0xFF6366F1).withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isHovered ? const Color(0xFF6366F1).withValues(alpha: 0.4) : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Column Header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111116),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF22222A)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(col, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            BloomBadge(
                              variant: BloomBadgeVariant.secondary,
                              size: BloomBadgeSize.sm,
                              child: Text('${columnTasks.length}'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Draggable Column Cards
                      ...columnTasks.map((task) {
                        return Draggable<Task>(
                          data: task,
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: 280,
                              child: _buildKanbanCard(context, store, task),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _buildKanbanCard(context, store, task),
                          ),
                          child: _buildKanbanCard(context, store, task),
                        );
                      }),

                      // In-Column + Add Task Button
                      InkWell(
                        onTap: () => QuickAddDialog.show(context, defaultProjectId: selectedProjectId),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF22222A)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, size: 14, color: Color(0xFF71717A)),
                              SizedBox(width: 6),
                              Text('Add task', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),

          // + Add Section Button
          InkWell(
            onTap: () => _promptAddSection(context, store),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111116),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF22222A)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: Color(0xFFA1A1AA)),
                  SizedBox(width: 8),
                  Text('Add Section', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFA1A1AA))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanCard(BuildContext context, TaskStore store, Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => TaskDetailSheet.show(context, task),
        borderRadius: BorderRadius.circular(10),
        child: BloomCard(
          size: BloomCardSize.sm,
          backgroundColor: const Color(0xFF14141A),
          borderColor: const Color(0xFF22222A),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BloomBadge(
                    variant: task.priority == Priority.p1 ? BloomBadgeVariant.destructive : BloomBadgeVariant.outline,
                    size: BloomBadgeSize.sm,
                    child: Text(task.priority.name.toUpperCase()),
                  ),
                  const BloomAvatar(name: 'Alex Rivers', size: BloomAvatarSize.sm),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  color: task.isCompleted ? const Color(0xFF71717A) : Colors.white,
                ),
              ),
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF71717A)),
                  const SizedBox(width: 4),
                  Text(
                    task.dueAt != null ? '${task.dueAt!.month}/${task.dueAt!.day}' : 'No date',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded, size: 14, color: Color(0xFF71717A)),
                    color: const Color(0xFF1E1E24),
                    onSelected: (newCol) => store.moveTaskSection(task.id, newCol),
                    itemBuilder: (context) => store.kanbanColumns
                        .where((c) => c != (task.sectionId ?? 'In Progress'))
                        .map((c) => PopupMenuItem(value: c, child: Text('Move to $c', style: const TextStyle(color: Colors.white, fontSize: 12))))
                        .toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptAddSection(BuildContext context, TaskStore store) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14141A),
        title: const Text('Add Kanban Section', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'e.g. Blocked, QA, Deploying'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          BloomButton(
            size: BloomButtonSize.sm,
            onPressed: () {
              store.addKanbanColumn(ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Add Section'),
          ),
        ],
      ),
    );
  }
}
