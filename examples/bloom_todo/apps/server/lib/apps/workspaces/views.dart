import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_todo_core/core.dart';
import '../../db.dart';

class WorkspaceViews {
  static Future<BloomResponse> list(BloomRequest req) async {
    return BloomResponse.json(ServerDb.instance.listWorkspaces().map((w) => w.toJson()).toList());
  }

  static Future<BloomResponse> getById(BloomRequest req, String id) async {
    final ws = ServerDb.instance.workspaces.where((w) => w.id == id).firstOrNull;
    if (ws == null) {
      throw BloomNotFoundException('Workspace with ID "$id" was not found', {'workspace_id': id});
    }
    return BloomResponse.json(ws.toJson());
  }

  static Future<BloomResponse> create(BloomRequest req) async {
    final body = await req.json();
    final name = body['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      throw const BloomBadRequestException('Workspace name is required', {'field': 'name'});
    }

    final slug = name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');

    final ws = Workspace(
      id: 'ws_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      slug: slug,
      ownerId: req.headers['x-user-id'] ?? 'usr_demo_123',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    ServerDb.instance.workspaces.add(ws);
    return BloomResponse.json(ws.toJson(), statusCode: 201);
  }

  static Future<BloomResponse> members(BloomRequest req, String id) async {
    final ws = ServerDb.instance.workspaces.where((w) => w.id == id).firstOrNull;
    if (ws == null) {
      throw BloomNotFoundException('Workspace with ID "$id" was not found', {'workspace_id': id});
    }

    final members = [
      WorkspaceMember(
        id: 'mem_1',
        workspaceId: id,
        userId: 'usr_demo_123',
        role: MemberRole.owner,
        invitedAt: DateTime.now().subtract(const Duration(days: 60)),
        joinedAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ];
    return BloomResponse.json(members.map((m) => m.toJson()).toList());
  }
}
