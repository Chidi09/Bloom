import 'package:bloom_todo_core/core.dart';
import '../app/api_client.dart';

class ProjectRepository {
  final ApiClient api;

  ProjectRepository(this.api);

  Future<List<Project>> list({String? workspaceId}) async {
    final res = await api.get(
      ApiEndpoints.projects,
      queryParams: {
        if (workspaceId != null) 'workspaceId': workspaceId,
      },
    );
    if (res is List) {
      return res.map((j) => Project.fromJson(j as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Project> create({
    required String name,
    required String workspaceId,
    String? colorHex,
    String? icon,
  }) async {
    final res = await api.post(
      ApiEndpoints.projects,
      body: {
        'name': name,
        'workspaceId': workspaceId,
        'colorHex': colorHex ?? '#6366F1',
        'icon': icon ?? '📁',
      },
    );
    return Project.fromJson(res as Map<String, dynamic>);
  }
}
