import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_todo_core/core.dart';
import '../../db.dart';
import 'serializers.dart';

class TaskViews {
  static Future<BloomResponse> list(BloomRequest req) async {
    final workspaceId = req.queryParams['workspaceId'];
    final projectId = req.queryParams['projectId'];

    final results = ServerDb.instance.listTasks(
      workspaceId: workspaceId,
      projectId: projectId,
    );

    return BloomResponse.json(results.map((t) => t.toJson()).toList());
  }

  static Future<BloomResponse> getById(BloomRequest req, String id) async {
    final task = ServerDb.instance.getTask(id);
    if (task == null) {
      return BloomResponse.json({'error': 'Task not found'}, statusCode: 404);
    }
    return BloomResponse.json(task.toJson());
  }

  static Future<BloomResponse> create(BloomRequest req) async {
    final body = await req.json();
    final dto = TaskCreateDto.fromJson(body);

    final validation = TaskValidator.validateTitle(dto.title);
    if (!validation.isValid) {
      return BloomResponse.json({'error': validation.error}, statusCode: 400);
    }

    final task = ServerDb.instance.createTask(
      title: dto.title,
      description: dto.description,
      projectId: dto.projectId,
      workspaceId: dto.workspaceId,
      priority: dto.priority,
      dueAt: dto.dueAt,
      labels: dto.labels,
    );

    return BloomResponse.json(task.toJson(), statusCode: 201);
  }

  static Future<BloomResponse> update(BloomRequest req, String id) async {
    final body = await req.json();
    final dto = TaskUpdateDto.fromJson(body);

    final existing = ServerDb.instance.getTask(id);
    if (existing == null) {
      return BloomResponse.json({'error': 'Task not found'}, statusCode: 404);
    }

    final index = ServerDb.instance.tasks.indexOf(existing);
    final updated = existing.copyWith(
      title: dto.title,
      description: dto.description,
      projectId: dto.projectId,
      sectionId: dto.sectionId,
      priority: dto.priority,
      dueAt: dto.dueAt,
      recurrenceRule: dto.recurrenceRule,
      isCompleted: dto.isCompleted,
      position: dto.position,
      labels: dto.labels,
      updatedAt: DateTime.now().toUtc(),
    );

    ServerDb.instance.tasks[index] = updated;
    return BloomResponse.json(updated.toJson());
  }

  static Future<BloomResponse> complete(BloomRequest req, String id) async {
    final updated = ServerDb.instance.toggleTaskComplete(id);
    if (updated == null) {
      return BloomResponse.json({'error': 'Task not found'}, statusCode: 404);
    }
    return BloomResponse.json(updated.toJson());
  }

  static Future<BloomResponse> bulkComplete(BloomRequest req) async {
    final body = await req.json();
    final ids = (body['ids'] as List<dynamic>?)?.cast<String>() ?? [];

    for (final id in ids) {
      final idx = ServerDb.instance.tasks.indexWhere((t) => t.id == id);
      if (idx != -1 && !ServerDb.instance.tasks[idx].isCompleted) {
        ServerDb.instance.tasks[idx] = ServerDb.instance.tasks[idx].copyWith(
          isCompleted: true,
          completedAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
      }
    }

    return BloomResponse.json({'status': 'completed', 'count': ids.length});
  }

  static Future<BloomResponse> move(BloomRequest req, String id) async {
    final body = await req.json();
    final projectId = body['projectId'] as String;
    final sectionId = body['sectionId'] as String?;
    final position = body['position'] as int? ?? 0;

    final existing = ServerDb.instance.getTask(id);
    if (existing == null) {
      return BloomResponse.json({'error': 'Task not found'}, statusCode: 404);
    }

    final idx = ServerDb.instance.tasks.indexOf(existing);
    final updated = existing.copyWith(
      projectId: projectId,
      sectionId: sectionId,
      position: position,
      updatedAt: DateTime.now().toUtc(),
    );
    ServerDb.instance.tasks[idx] = updated;

    return BloomResponse.json(updated.toJson());
  }

  static Future<BloomResponse> today(BloomRequest req) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final results = ServerDb.instance.tasks.where((t) {
      if (t.dueAt == null) return false;
      final d = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
      return d.isAtSameMomentAs(today) || (d.isBefore(today) && !t.isCompleted);
    }).toList();

    return BloomResponse.json(results.map((t) => t.toJson()).toList());
  }

  static Future<BloomResponse> upcoming(BloomRequest req) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));

    final results = ServerDb.instance.tasks.where((t) {
      if (t.dueAt == null) return false;
      return t.dueAt!.isAfter(today) && t.dueAt!.isBefore(nextWeek);
    }).toList();

    return BloomResponse.json(results.map((t) => t.toJson()).toList());
  }
}
