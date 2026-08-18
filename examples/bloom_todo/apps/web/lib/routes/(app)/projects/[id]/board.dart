import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../../../../widgets/kanban_board.dart';

class ProjectBoardPage extends StatelessWidget {
  final String projectId;

  const ProjectBoardPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final sections = [
      Section(id: 'sec_1', projectId: projectId, name: 'To Do', createdAt: DateTime.now()),
      Section(id: 'sec_2', projectId: projectId, name: 'In Progress', createdAt: DateTime.now()),
      Section(id: 'sec_3', projectId: projectId, name: 'Done', createdAt: DateTime.now()),
    ];

    final tasks = [
      Task(
        id: 'tsk_1',
        projectId: projectId,
        sectionId: 'sec_1',
        workspaceId: 'ws_1',
        creatorId: 'usr_1',
        title: 'Review Bloom architecture blueprint',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Task(
        id: 'tsk_2',
        projectId: projectId,
        sectionId: 'sec_2',
        workspaceId: 'ws_1',
        creatorId: 'usr_1',
        title: 'Implement offline sync queue',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Project Board (Kanban)', style: TodoTypography.h3),
      ),
      body: KanbanBoard(
        sections: sections,
        tasks: tasks,
        onTaskMoved: (taskId, newSectionId) {
          // Handle task relocation
        },
      ),
    );
  }
}
