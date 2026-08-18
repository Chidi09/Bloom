import 'package:signals/signals.dart';
import 'package:bloom_todo_core/core.dart';
import '../repositories/task_repository.dart';

class TaskController {
  final TaskRepository repository;

  final tasks = signal<List<Task>>([]);
  final isLoading = signal(false);
  final error = signal<String?>(null);

  TaskController(this.repository);

  Future<void> loadToday() async {
    isLoading.value = true;
    error.value = null;
    try {
      tasks.value = await repository.today();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadUpcoming() async {
    isLoading.value = true;
    error.value = null;
    try {
      tasks.value = await repository.upcoming();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadForProject(String projectId) async {
    isLoading.value = true;
    error.value = null;
    try {
      tasks.value = await repository.list(projectId: projectId);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createTask({
    required String title,
    String? description,
    required String projectId,
    required String workspaceId,
    Priority priority = Priority.p4,
    DateTime? dueAt,
    String? recurrenceRule,
    List<String> labels = const [],
  }) async {
    final newTask = await repository.create(
      title: title,
      description: description,
      projectId: projectId,
      workspaceId: workspaceId,
      priority: priority,
      dueAt: dueAt,
      recurrenceRule: recurrenceRule,
      labels: labels,
    );
    tasks.value = [...tasks.value, newTask];
  }

  Future<void> toggleComplete(String id) async {
    // Optimistic local update
    final prev = tasks.value;
    tasks.value = tasks.value.map((t) {
      if (t.id == id) {
        return t.copyWith(
          isCompleted: !t.isCompleted,
          completedAt: !t.isCompleted ? DateTime.now() : null,
        );
      }
      return t;
    }).toList();

    try {
      await repository.complete(id);
    } catch (e) {
      // Rollback on failure
      tasks.value = prev;
    }
  }
}
