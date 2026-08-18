import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../../../app/boot.dart';

class UpcomingPage extends StatefulWidget {
  const UpcomingPage({super.key});

  @override
  State<UpcomingPage> createState() => _UpcomingPageState();
}

class _UpcomingPageState extends State<UpcomingPage> {
  @override
  void initState() {
    super.initState();
    BloomBoot.taskController.loadUpcoming();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = BloomBoot.taskController.tasks.watch(context);
    final loading = BloomBoot.taskController.isLoading.watch(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Upcoming (Next 7 Days)', style: TodoTypography.h3),
      ),
      body: loading && tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? Center(
                  child: Text('No upcoming tasks scheduled', style: TodoTypography.body),
                )
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
