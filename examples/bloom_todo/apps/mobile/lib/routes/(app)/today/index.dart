import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../../../app/boot.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  @override
  void initState() {
    super.initState();
    BloomBoot.taskController.loadToday();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = BloomBoot.taskController.tasks.watch(context);
    final loading = BloomBoot.taskController.isLoading.watch(context);

    final completedCount = tasks.where((t) => t.isCompleted).length;
    final totalCount = tasks.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: TodoTypography.h3),
            Text(
              '${DateTime.now().day}/${DateTime.now().month} • $completedCount of $totalCount completed',
              style: TodoTypography.caption.copyWith(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => BloomBoot.taskController.loadToday(),
          ),
        ],
      ),
      body: loading && tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 64, color: TodoColors.success),
                      const SizedBox(height: 16),
                      Text('All done for today!', style: TodoTypography.h3),
                      const SizedBox(height: 8),
                      Text(
                        'Enjoy your evening or plan upcoming tasks',
                        style: TodoTypography.caption.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
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
