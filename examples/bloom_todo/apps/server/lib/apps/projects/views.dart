import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_todo_core/core.dart';
import '../../db.dart';

class ProjectViews {
  static Future<BloomResponse> list(BloomRequest req) async {
    final workspaceId = req.queryParams['workspaceId'];
    final results = ServerDb.instance.listProjects(workspaceId: workspaceId);
    return BloomResponse.json(results.map((p) => p.toJson()).toList());
  }

  static Future<BloomResponse> getById(BloomRequest req, String id) async {
    final project = ServerDb.instance.projects.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('Project not found'),
    );
    return BloomResponse.json(project.toJson());
  }

  static Future<BloomResponse> create(BloomRequest req) async {
    final body = await req.json();
    final project = Project(
      id: 'prj_${DateTime.now().millisecondsSinceEpoch}',
      workspaceId: body['workspaceId'] as String? ?? 'ws_1',
      parentId: body['parentId'] as String?,
      name: body['name'] as String,
      colorHex: body['colorHex'] as String? ?? '#6366F1',
      icon: body['icon'] as String? ?? 'folder_outlined',
      isFavorite: body['isFavorite'] as bool? ?? false,
      position: ServerDb.instance.projects.length,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    ServerDb.instance.projects.add(project);
    return BloomResponse.json(project.toJson(), statusCode: 201);
  }

  static Future<BloomResponse> archive(BloomRequest req, String id) async {
    final idx = ServerDb.instance.projects.indexWhere((p) => p.id == id);
    if (idx == -1) {
      return BloomResponse.json({'error': 'Project not found'}, statusCode: 404);
    }

    final updated = ServerDb.instance.projects[idx].copyWith(
      isArchived: true,
      updatedAt: DateTime.now().toUtc(),
    );
    ServerDb.instance.projects[idx] = updated;
    return BloomResponse.json(updated.toJson());
  }
}
