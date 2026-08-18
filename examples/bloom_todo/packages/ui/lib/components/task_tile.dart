import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';
import 'package:bloom_todo_core/core.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import 'due_date_chip.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onToggleComplete;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggleComplete,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: TodoColors.success.withValues(alpha: 0.2),
        child: const Icon(Icons.check_circle, color: TodoColors.success),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: TodoColors.danger.withValues(alpha: 0.2),
        child: const Icon(Icons.delete, color: TodoColors.danger),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          onToggleComplete();
        } else {
          onDelete?.call();
        }
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Native BloomCheckbox
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: BloomCheckbox(
                  checked: task.isCompleted,
                  onChanged: (checked) => onToggleComplete(),
                ),
              ),

              // Title, Description & Native BloomBadges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TodoTypography.bodyMedium.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? Colors.grey
                            : null,
                      ),
                    ),
                    if (task.description != null && task.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          task.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TodoTypography.caption.copyWith(color: Colors.grey),
                        ),
                      ),
                    if (task.dueAt != null || task.labels.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (task.dueAt != null)
                              DueDateChip(
                                dueAt: task.dueAt,
                                recurrenceRule: task.recurrenceRule,
                              ),
                            ...task.labels.map(
                              (label) => BloomBadge(
                                variant: BloomBadgeVariant.outline,
                                size: BloomBadgeSize.sm,
                                child: Text('@$label'),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
