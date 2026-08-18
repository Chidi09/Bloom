import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_ui/ui.dart';

class KanbanBoard extends StatelessWidget {
  final List<Section> sections;
  final List<Task> tasks;
  final Function(String taskId, String? newSectionId)? onTaskMoved;

  const KanbanBoard({
    super.key,
    required this.sections,
    required this.tasks,
    this.onTaskMoved,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections.map((section) {
          final sectionTasks = tasks.where((t) => t.sectionId == section.id).toList();

          return Container(
            width: 300,
            margin: const EdgeInsets.only(right: 16),
            child: BloomCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(section.name, style: TodoTypography.bodySemiBold),
                        BloomBadge(
                          variant: BloomBadgeVariant.secondary,
                          size: BloomBadgeSize.sm,
                          child: Text('${sectionTasks.length}'),
                        ),
                      ],
                    ),
                  ),
                  const BloomSeparator(),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    itemCount: sectionTasks.length,
                    itemBuilder: (context, index) {
                      final task = sectionTasks[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: BloomCard(
                          size: BloomCardSize.sm,
                          child: Text(task.title, style: TodoTypography.bodyMedium),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
