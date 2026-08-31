// test/rpc_mount_test.dart
import 'dart:convert';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:test/test.dart';

class TaskItem {
  final String id;
  final String title;
  final bool completed;

  TaskItem({required this.id, required this.title, this.completed = false});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
      };

  factory TaskItem.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return TaskItem(
      id: map['id'] as String,
      title: map['title'] as String,
      completed: map['completed'] as bool? ?? false,
    );
  }
}

class CreateTaskInput {
  final String title;
  final bool completed;

  CreateTaskInput({required this.title, this.completed = false});

  Map<String, dynamic> toJson() => {'title': title, 'completed': completed};

  factory CreateTaskInput.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return CreateTaskInput(
      title: map['title'] as String? ?? '',
      completed: map['completed'] as bool? ?? false,
    );
  }
}

final getTaskContract = BloomRpcContract<void, TaskItem>.get(
  '/tasks/:id',
  decodeOutput: TaskItem.fromJson,
);

final createTaskContract = BloomRpcContract<CreateTaskInput, TaskItem>.post(
  '/tasks',
  encodeInput: (input) => input.toJson(),
  decodeInput: CreateTaskInput.fromJson,
  encodeOutput: (task) => task.toJson(),
  decodeOutput: TaskItem.fromJson,
);

void main() {
  group('BloomRpcRouter Mount on BloomApiRouter', () {
    late BloomRpcRouter rpcRouter;
    late BloomApiRouter apiRouter;
    final inMemoryDb = <String, TaskItem>{
      'task-1': TaskItem(id: 'task-1', title: 'First Task', completed: false),
    };

    setUp(() {
      rpcRouter = BloomRpcRouter();

      // Bind GET /tasks/:id
      rpcRouter.bind(getTaskContract, (ctx, _) async {
        final id = ctx.pathParams['id'];
        final task = inMemoryDb[id];
        if (task == null) {
          throw BloomRpcHttpException(
            statusCode: 404,
            message: 'Task "$id" not found',
            contract: getTaskContract,
          );
        }
        return task;
      });

      // Bind POST /tasks
      rpcRouter.bind(createTaskContract, (ctx, input) async {
        if (input.title.trim().isEmpty) {
          throw const BloomRpcValidationErrors(
            fieldErrors: {
              'title': ['Title is required and cannot be blank.'],
            },
          );
        }

        final newTask = TaskItem(
          id: 'task-${inMemoryDb.length + 1}',
          title: input.title,
          completed: input.completed,
        );
        inMemoryDb[newTask.id] = newTask;
        return newTask;
      });

      apiRouter = BloomApiRouter();
      apiRouter.mountRpc(rpcRouter, basePath: '/api/rpc');
    });

    test('successful typed round-trip: GET /api/rpc/tasks/:id', () async {
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/rpc/tasks/task-1'),
      );

      final res = await apiRouter.handle(req);
      expect(res.statusCode, 200);

      final json = res.bodyJson as Map<String, dynamic>;
      expect(json['id'], 'task-1');
      expect(json['title'], 'First Task');
      expect(json['completed'], false);
    });

    test('successful typed round-trip: POST /api/rpc/tasks', () async {
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/api/rpc/tasks'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode({'title': 'New Architecture Task', 'completed': true}),
      );

      final res = await apiRouter.handle(req);
      expect(res.statusCode, 200);

      final json = res.bodyJson as Map<String, dynamic>;
      expect(json['id'], 'task-2');
      expect(json['title'], 'New Architecture Task');
      expect(json['completed'], true);
    });

    test('validation failure returning 422 with structured field errors',
        () async {
      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost:8080/api/rpc/tasks'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode({'title': '   ', 'completed': false}),
      );

      final res = await apiRouter.handle(req);
      expect(res.statusCode, 422);

      final json = res.bodyJson as Map<String, dynamic>;
      expect(json['errors'], isNotNull);
      final errors = json['errors'] as Map<String, dynamic>;
      expect(errors['title'], isList);
      expect(
          errors['title'], contains('Title is required and cannot be blank.'));
    });

    test('unknown route returning 404 without leaking stack trace', () async {
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/rpc/unknown/route'),
      );

      final res = await apiRouter.handle(req);
      expect(res.statusCode, 404);

      final json = res.bodyJson as Map<String, dynamic>;
      expect(json['error'], contains('No RPC handler found'));
      expect(json['statusCode'], 404);
      expect(res.bodyText, isNot(contains('dart:')));
      expect(res.bodyText, isNot(contains('#0')));
    });

    test('BloomRpcHttpException 404 on not-found item', () async {
      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost:8080/api/rpc/tasks/non-existent'),
      );

      final res = await apiRouter.handle(req);
      expect(res.statusCode, 404);
    });
  });
}
