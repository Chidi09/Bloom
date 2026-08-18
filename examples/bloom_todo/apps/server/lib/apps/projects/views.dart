import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_todo_core/core.dart';
import '../../db.dart';

class ProjectViews {
  static Future<BloomResponse> list(BloomRequest req) async {
    final workspaceId = req.queryParams['workspaceId'];
    final results = ServerDb.instance.listProjects(workspaceId: workspaceId);
    return BloomResponse.json(results.map((p) => p.toJson()).toList());
  }

  static Future<BloomResponse> getById(BloomRequest req, String id) async {
    final project = ServerDb.instance.projects.where((p) => p.id == id).firstOrNull;
    if (project == null) {
      throw BloomNotFoundException('Project with ID "$id" was not found', {'project_id': id});
    }
    return BloomResponse.json(project.toJson());
  }

  static Future<BloomResponse> create(BloomRequest req) async {
    final body = await req.json();
    final name = body['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      throw const BloomBadRequestException('Project name is required', {'field': 'name'});
    }

    final project = Project(
      id: 'prj_${DateTime.now().millisecondsSinceEpoch}',
      workspaceId: body['workspaceId'] as String? ?? 'ws_1',
      parentId: body['parentId'] as String?,
      name: name.trim(),
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
      throw BloomNotFoundException('Project with ID "$id" was not found', {'project_id': id});
    }

    final updated = ServerDb.instance.projects[idx].copyWith(
      isArchived: true,
      updatedAt: DateTime.now().toUtc(),
    );
    ServerDb.instance.projects[idx] = updated;
    return BloomResponse.json(updated.toJson());
  }
}
