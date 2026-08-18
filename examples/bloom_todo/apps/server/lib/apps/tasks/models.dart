import 'package:bloom_todo_core/core.dart';

class TaskQuerySet {
  final List<Task> _tasks;

  const TaskQuerySet([this._tasks = const []]);

  TaskQuerySet forWorkspace(String workspaceId) =>
      TaskQuerySet(_tasks.where((t) => t.workspaceId == workspaceId).toList());

  TaskQuerySet forProject(String projectId) =>
      TaskQuerySet(_tasks.where((t) => t.projectId == projectId).toList());

  TaskQuerySet dueToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return TaskQuerySet(
      _tasks.where((t) {
        if (t.dueAt == null) return false;
        final d = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
        return d.isAtSameMomentAs(today) || (d.isBefore(today) && !t.isCompleted);
      }).toList(),
    );
  }

  TaskQuerySet upcoming() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));
    return TaskQuerySet(
      _tasks.where((t) {
        if (t.dueAt == null) return false;
        return t.dueAt!.isAfter(today) && t.dueAt!.isBefore(nextWeek);
      }).toList(),
    );
  }

  TaskQuerySet incomplete() =>
      TaskQuerySet(_tasks.where((t) => !t.isCompleted).toList());

  TaskQuerySet completed() =>
      TaskQuerySet(_tasks.where((t) => t.isCompleted).toList());

  List<Task> toList() => List.unmodifiable(_tasks);
}
