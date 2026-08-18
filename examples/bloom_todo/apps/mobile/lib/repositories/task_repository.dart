import 'package:bloom_todo_core/core.dart';
import '../app/api_client.dart';

class TaskRepository {
  final ApiClient api;

  TaskRepository(this.api);

  Future<List<Task>> list({String? workspaceId, String? projectId}) async {
    final res = await api.get(
      ApiEndpoints.tasks,
      queryParams: {
        if (workspaceId != null) 'workspaceId': workspaceId,
        if (projectId != null) 'projectId': projectId,
      },
    );
    if (res is List) {
      return res.map((j) => Task.fromJson(j as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<Task>> today() async {
    final res = await api.get(ApiEndpoints.tasksToday);
    if (res is List) {
      return res.map((j) => Task.fromJson(j as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<Task>> upcoming() async {
    final res = await api.get(ApiEndpoints.tasksUpcoming);
    if (res is List) {
      return res.map((j) => Task.fromJson(j as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Task> create({
    required String title,
    String? description,
    required String projectId,
    String? sectionId,
    required String workspaceId,
    Priority priority = Priority.p4,
    DateTime? dueAt,
    String? recurrenceRule,
    List<String> labels = const [],
  }) async {
    final res = await api.post(
      ApiEndpoints.tasks,
      body: {
        'title': title,
        'description': description,
        'projectId': projectId,
        'sectionId': sectionId,
        'workspaceId': workspaceId,
        'priority': priority.name,
        'dueAt': dueAt?.toIso8601String(),
        'recurrenceRule': recurrenceRule,
        'labels': labels,
      },
    );
    return Task.fromJson(res as Map<String, dynamic>);
  }

  Future<Task> complete(String id) async {
    final res = await api.post(ApiEndpoints.taskComplete(id));
    return Task.fromJson(res as Map<String, dynamic>);
  }
}
