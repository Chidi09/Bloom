import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../../../../app/boot.dart';

class ProjectDetailPage extends StatefulWidget {
  final String projectId;

  const ProjectDetailPage({super.key, required this.projectId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  @override
  void initState() {
    super.initState();
    BloomBoot.taskController.loadForProject(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = BloomBoot.taskController.tasks.watch(context);
    final loading = BloomBoot.taskController.isLoading.watch(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Project Tasks', style: TodoTypography.h3),
      ),
      body: loading && tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: tasks.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 44),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return TaskTile(
                  task: task,
                  onToggleComplete: () => BloomBoot.taskController.toggleComplete(task.id),
                );
              },
            ),
    );
  }
}
