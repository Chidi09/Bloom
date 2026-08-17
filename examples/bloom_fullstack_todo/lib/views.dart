import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_cache/bloom_cache.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_jobs/bloom_jobs.dart';
import 'package:bloom_realtime/bloom_realtime.dart';
import 'package:bloom_rest/bloom_rest.dart';
import 'package:bloom_storage/bloom_storage.dart';
import 'package:bloom_validate/bloom_validate.dart';
import 'models/todo_list.dart';
import 'models/todo_task.dart';
import 'models/user.dart';
import 'permissions.dart';
import 'serializers.dart';

/// Handlers for authentication routes.
class AuthApiHandlers {
  final DbExecutor db;
  final BloomTaskQueue jobQueue;

  AuthApiHandlers({
    required this.db,
    required this.jobQueue,
  });

  /// POST /api/auth/signup
  Future<BloomResponse> handleSignup(BloomRequest req) async {
    // 1. Validate request payload using bloom_validate
    final SignupRequestSchema schema;
    try {
      schema = BloomRequestSchema.validateSchema(SignupRequestSchema.fromRequest(req));
    } on BloomValidationException catch (e) {
      // Throw typed exception from bloom_errors
      throw BloomValidationFailedException(message: e.message, errors: e.errors);
    }

    final email = schema.email.trim().toLowerCase();
    final name = schema.name.trim();
    final password = schema.password;

    // 2. Check if user already exists using bloom_db
    final existing = await User.objects().filter(Q('email', email)).first(db);
    if (existing != null) {
      throw BloomConflictException('An account with email "$email" already exists.');
    }

    // 3. Hash password using bloom_auth_server (BCrypt cost 12)
    final passwordHash = hashPassword(password, cost: 12);

    // 4. Save user record to Postgres via bloom_db
    final user = User(
      email: email,
      passwordHash: passwordHash,
      name: name,
      createdAt: DateTime.now().toUtc(),
    );

    final insertedId = await QuerySet.insertRaw(db, User.meta, {
      'email': user.email,
      'password_hash': user.passwordHash,
      'name': user.name,
      'created_at': user.createdAt,
    });

    final savedUser = User(
      id: insertedId,
      email: user.email,
      passwordHash: user.passwordHash,
      name: user.name,
      createdAt: user.createdAt,
    );

    // 5. Enqueue background welcome email job via bloom_jobs
    await jobQueue.enqueue('send_welcome_email', {
      'userId': savedUser.id,
      'email': savedUser.email,
      'name': savedUser.name,
    });

    // 6. Issue cryptographically signed session JWT token via bloom_auth_server
    final token = issueSessionToken(
      userId: savedUser.id.toString(),
      email: savedUser.email,
      roles: const ['user'],
      ttl: const Duration(days: 7),
    );

    return BloomResponse.json({
      'token': token,
      'user': savedUser.toJson(),
      'message': 'Signup successful. Welcome email queued.',
    }, statusCode: 201);
  }

  /// POST /api/auth/login
  Future<BloomResponse> handleLogin(BloomRequest req) async {
    // 1. Validate payload
    final LoginRequestSchema schema;
    try {
      schema = BloomRequestSchema.validateSchema(LoginRequestSchema.fromRequest(req));
    } on BloomValidationException catch (e) {
      throw BloomValidationFailedException(message: e.message, errors: e.errors);
    }

    final email = schema.email.trim().toLowerCase();
    final password = schema.password;

    // 2. Check brute-force & lockout protection via bloom_auth_server
    try {
      authLimiter.verifyAllowed(email);
    } on AccountLockedException catch (e) {
      throw BloomForbiddenException(
        'Account is temporarily locked due to consecutive failed attempts.',
        {'retryAfterSeconds': e.retryAfterSeconds},
      );
    } on RateLimitException catch (e) {
      throw BloomTooManyRequestsException(
        'Too many login attempts. Please try again later.',
        Duration(seconds: e.retryAfterSeconds),
      );
    }

    // 3. Query user from Postgres
    final user = await User.objects().filter(Q('email', email)).first(db);

    if (user == null) {
      // Run dummy BCrypt verification to prevent timing-based user enumeration
      dummyVerifyPassword(password);
      authLimiter.recordFailure(email);
      throw BloomUnauthorizedException('Invalid email or password');
    }

    // 4. Verify BCrypt password hash
    final isValid = verifyPassword(password, user.passwordHash);
    if (!isValid) {
      authLimiter.recordFailure(email);
      throw BloomUnauthorizedException('Invalid email or password');
    }

    // 5. Clear rate limit failure streaks
    authLimiter.recordSuccess(email);

    // 6. Issue JWT session token
    final token = issueSessionToken(
      userId: user.id.toString(),
      email: user.email,
      roles: const ['user'],
      ttl: const Duration(days: 7),
    );

    return BloomResponse.json({
      'token': token,
      'user': user.toJson(),
      'message': 'Login successful.',
    });
  }

  /// GET /api/auth/me (Protected route)
  Future<BloomResponse> handleMe(BloomRequest req) async {
    final userIdStr = req.authUserId;
    if (userIdStr == null) {
      throw BloomUnauthorizedException('Authentication required.');
    }

    final userId = int.tryParse(userIdStr) ?? 0;
    final user = await User.objects().filter(Q('id', userId)).first(db);
    if (user == null) {
      throw BloomNotFoundException('User account not found.');
    }

    return BloomResponse.json({
      'user': user.toJson(),
      'claims': req.auth?.toMap(),
    });
  }
}

/// Handlers for file uploads and downloads using bloom_storage.
class UploadApiHandlers {
  final BloomStorageBackend storage;

  UploadApiHandlers({required this.storage});

  /// POST /api/uploads/avatar
  /// Uploads raw avatar bytes or base64 data to storage.
  Future<BloomResponse> handleUploadAvatar(BloomRequest req) async {
    final userId = req.authUserId;
    if (userId == null) {
      throw BloomUnauthorizedException('Authentication required to upload attachments');
    }

    final bytes = req.rawBody;
    if (bytes.isEmpty) {
      throw BloomBadRequestException('No file data provided in request body');
    }

    final filename = 'avatars/user_${userId}_${DateTime.now().millisecondsSinceEpoch}.png';
    final fileUrl = await storage.upload(
      filename,
      bytes,
      contentType: 'image/png',
    );

    final signedUrl = await storage.getSignedUrl(
      filename,
      expiry: const Duration(hours: 1),
    );

    return BloomResponse.json({
      'filename': filename,
      'publicUrl': fileUrl,
      'signedDownloadUrl': signedUrl,
      'sizeBytes': bytes.length,
      'message': 'File uploaded successfully via bloom_storage',
    }, statusCode: 201);
  }

  /// GET /api/uploads/signed-url
  /// Generates a signed download URL for an existing file.
  Future<BloomResponse> handleGetSignedUrl(BloomRequest req) async {
    final filename = req.queryParams['file'];
    if (filename == null || filename.isEmpty) {
      throw BloomBadRequestException('Missing "file" query parameter');
    }

    final exists = await storage.exists(filename);
    if (!exists) {
      throw BloomNotFoundException('File "$filename" does not exist in storage');
    }

    final signedUrl = await storage.getSignedUrl(
      filename,
      expiry: const Duration(minutes: 30),
    );

    return BloomResponse.json({
      'file': filename,
      'signedUrl': signedUrl,
      'expiresInMinutes': 30,
    });
  }
}

/// Custom ViewSet for TodoList entities with caching, realtime notifications, and ownership isolation.
class TodoListViewSet extends BloomViewSet<TodoList> {
  final BloomCache cache;
  final BloomChannelHub realtimeHub;

  TodoListViewSet({
    required DbExecutor Function(BloomRequest req) getDb,
    required this.cache,
    required this.realtimeHub,
  }) : super(
          meta: TodoList.meta,
          fromRow: TodoList.fromRow,
          getDb: getDb,
          options: BloomViewSetOptions<TodoList>(
            serializer: BloomModelSerializer<TodoList>(
              meta: TodoList.meta,
              fields: BloomFieldSet.all().withReadOnly(['id', 'ownerId', 'createdAt']),
            ),
            pagination: const PageNumberPagination(defaultPageSize: 20),
            permission: const IsAuthenticated(),
            config: const BloomViewSetConfig(
              filterableFields: ['name'],
              orderableFields: ['created_at', 'id', 'name'],
              defaultPageSize: 20,
            ),
          ),
        );

  /// Helper to resolve authenticated user ID from session.
  int _resolveUserId(BloomRequest req) {
    final uidStr = req.authUserId;
    if (uidStr == null || uidStr.isEmpty) {
      throw BloomUnauthorizedException('Authentication required');
    }
    final uid = int.tryParse(uidStr);
    if (uid == null) {
      throw BloomUnauthorizedException('Invalid session token identity');
    }
    return uid;
  }

  @override
  Future<BloomResponse> list(BloomRequest req) async {
    final userId = _resolveUserId(req);
    final cacheKey = 'todo_lists:user:$userId:page_${req.queryParams['page'] ?? 1}';

    // Demonstrate bloom_cache getOrSet: caches response for 60 seconds
    final cachedResult = await cache.getOrSet<Map<String, dynamic>>(
      cacheKey,
      () async {
        final db = getDb(req);
        final lists = await TodoList.objects()
            .filter(Q('ownerId', userId))
            .orderBy('-createdAt')
            .all(db);

        return {
          'count': lists.length,
          'results': lists.map((l) => l.toJson()).toList(),
          'cached_at': DateTime.now().toUtc().toIso8601String(),
        };
      },
      ttl: const Duration(seconds: 60),
    );

    return BloomResponse.json({
      ...cachedResult,
      'source': 'bloom_cache',
    });
  }

  @override
  Future<BloomResponse> create(BloomRequest req) async {
    final userId = _resolveUserId(req);

    // Validate using bloom_validate
    final CreateTodoListSchema schema;
    try {
      schema = BloomRequestSchema.validateSchema(CreateTodoListSchema.fromRequest(req));
    } on BloomValidationException catch (e) {
      throw BloomValidationFailedException(message: e.message, errors: e.errors);
    }

    final db = getDb(req);
    final list = TodoList(
      name: schema.name,
      ownerId: userId,
      createdAt: DateTime.now().toUtc(),
    );

    final insertedId = await QuerySet.insertRaw(db, TodoList.meta, {
      'name': list.name,
      'owner_id': list.ownerId,
      'created_at': list.createdAt,
    });

    final savedList = TodoList(
      id: insertedId,
      name: list.name,
      ownerId: list.ownerId,
      createdAt: list.createdAt,
    );

    // Invalidate list caches for this user
    await cache.delete('todo_lists:user:$userId:page_1');

    // Broadcast mutation via bloom_realtime pub/sub hub
    realtimeHub.broadcast('user:$userId:lists', {
      'event': 'list_created',
      'list': savedList.toJson(),
    });

    return BloomResponse.json(savedList.toJson(), statusCode: 201);
  }

  @override
  Future<BloomResponse> retrieve(BloomRequest req) async {
    final userId = _resolveUserId(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    final pk = int.tryParse(pkStr ?? '');
    if (pk == null) {
      throw BloomBadRequestException('Invalid list ID');
    }

    final db = getDb(req);
    final item = await TodoList.objects()
        .filter(Q('id', pk) & Q('ownerId', userId))
        .first(db);

    if (item == null) {
      throw BloomNotFoundException('Todo list not found');
    }

    return BloomResponse.json(item.toJson());
  }

  @override
  Future<BloomResponse> update(BloomRequest req) async {
    final userId = _resolveUserId(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    final pk = int.tryParse(pkStr ?? '');
    if (pk == null) {
      throw BloomBadRequestException('Invalid list ID');
    }

    final schema = BloomRequestSchema.validateSchema(CreateTodoListSchema.fromRequest(req));
    final db = getDb(req);

    final qs = TodoList.objects().filter(Q('id', pk) & Q('ownerId', userId));
    final updated = await qs.update(db, {'name': schema.name});
    if (updated == 0) {
      throw BloomNotFoundException('Todo list not found or unauthorized');
    }

    final updatedItem = await qs.get(db);

    // Invalidate caches & broadcast
    await cache.delete('todo_lists:user:$userId:page_1');
    realtimeHub.broadcast('lists:$pk', {
      'event': 'list_updated',
      'list': updatedItem.toJson(),
    });

    return BloomResponse.json(updatedItem.toJson());
  }

  @override
  Future<BloomResponse> destroy(BloomRequest req) async {
    final userId = _resolveUserId(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    final pk = int.tryParse(pkStr ?? '');
    if (pk == null) {
      throw BloomBadRequestException('Invalid list ID');
    }

    final db = getDb(req);
    final qs = TodoList.objects().filter(Q('id', pk) & Q('ownerId', userId));
    final deleted = await qs.delete(db);
    if (deleted == 0) {
      throw BloomNotFoundException('Todo list not found or unauthorized');
    }

    await cache.delete('todo_lists:user:$userId:page_1');
    realtimeHub.broadcast('user:$userId:lists', {
      'event': 'list_deleted',
      'listId': pk,
    });

    return BloomResponse.noContent();
  }
}

/// Custom ViewSet for TodoTask entities.
class TodoTaskViewSet extends BloomViewSet<TodoTask> {
  final BloomCache cache;
  final BloomChannelHub realtimeHub;

  TodoTaskViewSet({
    required DbExecutor Function(BloomRequest req) getDb,
    required this.cache,
    required this.realtimeHub,
  }) : super(
          meta: TodoTask.meta,
          fromRow: TodoTask.fromRow,
          getDb: getDb,
          options: BloomViewSetOptions<TodoTask>(
            serializer: BloomModelSerializer<TodoTask>(
              meta: TodoTask.meta,
              fields: BloomFieldSet.all().withReadOnly(['id', 'createdAt']),
            ),
            pagination: const PageNumberPagination(defaultPageSize: 50),
            permission: const IsAuthenticated(),
            config: const BloomViewSetConfig(
              filterableFields: ['list_id', 'done'],
              orderableFields: ['created_at', 'id'],
              defaultPageSize: 50,
            ),
          ),
        );

  int _resolveUserId(BloomRequest req) {
    final uidStr = req.authUserId;
    if (uidStr == null || uidStr.isEmpty) {
      throw BloomUnauthorizedException('Authentication required');
    }
    final uid = int.tryParse(uidStr);
    if (uid == null) {
      throw BloomUnauthorizedException('Invalid session token');
    }
    return uid;
  }

  @override
  Future<BloomResponse> list(BloomRequest req) async {
    final userId = _resolveUserId(req);
    final listIdStr = req.queryParams['listId'] ?? req.queryParams['list_id'];
    if (listIdStr == null) {
      throw BloomBadRequestException('listId query parameter is required');
    }
    final listId = int.tryParse(listIdStr);
    if (listId == null) {
      throw BloomBadRequestException('Invalid listId query parameter');
    }

    final db = getDb(req);

    // Verify ownership of the list
    final listObj = await TodoList.objects()
        .filter(Q('id', listId) & Q('ownerId', userId))
        .first(db);
    if (listObj == null) {
      throw BloomNotFoundException('Todo list not found or unauthorized');
    }

    final cacheKey = 'todo_tasks:list:$listId';

    // Demonstrate bloom_cache getOrSet
    final result = await cache.getOrSet<Map<String, dynamic>>(
      cacheKey,
      () async {
        final tasks = await TodoTask.objects()
            .filter(Q('listId', listId))
            .orderBy('id')
            .all(db);

        return {
          'count': tasks.length,
          'listId': listId,
          'results': tasks.map((t) => t.toJson()).toList(),
          'cached_at': DateTime.now().toUtc().toIso8601String(),
        };
      },
      ttl: const Duration(seconds: 30),
    );

    return BloomResponse.json(result);
  }

  @override
  Future<BloomResponse> create(BloomRequest req) async {
    final userId = _resolveUserId(req);

    final CreateTodoTaskSchema schema;
    try {
      schema = BloomRequestSchema.validateSchema(CreateTodoTaskSchema.fromRequest(req));
    } on BloomValidationException catch (e) {
      throw BloomValidationFailedException(message: e.message, errors: e.errors);
    }

    final db = getDb(req);

    // Verify user owns the target list
    final listObj = await TodoList.objects()
        .filter(Q('id', schema.listId) & Q('ownerId', userId))
        .first(db);
    if (listObj == null) {
      throw BloomNotFoundException('Target Todo list not found or unauthorized');
    }

    final task = TodoTask(
      listId: schema.listId,
      title: schema.title,
      done: schema.done,
      createdAt: DateTime.now().toUtc(),
    );

    final insertedId = await QuerySet.insertRaw(db, TodoTask.meta, {
      'list_id': task.listId,
      'title': task.title,
      'done': task.done,
      'created_at': task.createdAt,
    });

    final savedTask = TodoTask(
      id: insertedId,
      listId: task.listId,
      title: task.title,
      done: task.done,
      createdAt: task.createdAt,
    );

    // Invalidate list tasks cache
    await cache.delete('todo_tasks:list:${schema.listId}');

    // Broadcast mutation to list channel
    realtimeHub.broadcast('lists:${schema.listId}', {
      'event': 'task_created',
      'task': savedTask.toJson(),
    });

    return BloomResponse.json(savedTask.toJson(), statusCode: 201);
  }

  @override
  Future<BloomResponse> retrieve(BloomRequest req) async {
    final userId = _resolveUserId(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    final pk = int.tryParse(pkStr ?? '');
    if (pk == null) {
      throw BloomBadRequestException('Invalid task ID');
    }

    final db = getDb(req);
    final task = await TodoTask.objects().filter(Q('id', pk)).first(db);
    if (task == null) {
      throw BloomNotFoundException('Task not found');
    }

    // Verify owner
    final listObj = await TodoList.objects()
        .filter(Q('id', task.listId) & Q('ownerId', userId))
        .first(db);
    if (listObj == null) {
      throw BloomNotFoundException('Task not found');
    }

    return BloomResponse.json(task.toJson());
  }

  @override
  Future<BloomResponse> update(BloomRequest req) async {
    final userId = _resolveUserId(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    final pk = int.tryParse(pkStr ?? '');
    if (pk == null) {
      throw BloomBadRequestException('Invalid task ID');
    }

    final db = getDb(req);
    final task = await TodoTask.objects().filter(Q('id', pk)).first(db);
    if (task == null) {
      throw BloomNotFoundException('Task not found');
    }

    // Verify list ownership
    final listObj = await TodoList.objects()
        .filter(Q('id', task.listId) & Q('ownerId', userId))
        .first(db);
    if (listObj == null) {
      throw BloomNotFoundException('Task not found');
    }

    final schema = BloomRequestSchema.validateSchema(UpdateTodoTaskSchema.fromRequest(req));
    final updates = <String, dynamic>{};
    if (schema.title != null) updates['title'] = schema.title!;
    if (schema.done != null) updates['done'] = schema.done!;

    if (updates.isNotEmpty) {
      await TodoTask.objects().filter(Q('id', pk)).update(db, updates);
    }

    final updatedTask = await TodoTask.objects().filter(Q('id', pk)).get(db);

    // Invalidate caches & broadcast
    await cache.delete('todo_tasks:list:${task.listId}');
    realtimeHub.broadcast('lists:${task.listId}', {
      'event': 'task_updated',
      'task': updatedTask.toJson(),
    });

    return BloomResponse.json(updatedTask.toJson());
  }

  @override
  Future<BloomResponse> destroy(BloomRequest req) async {
    final userId = _resolveUserId(req);
    final pkStr = req.params['pk'] ?? req.params['id'];
    final pk = int.tryParse(pkStr ?? '');
    if (pk == null) {
      throw BloomBadRequestException('Invalid task ID');
    }

    final db = getDb(req);
    final task = await TodoTask.objects().filter(Q('id', pk)).first(db);
    if (task == null) {
      throw BloomNotFoundException('Task not found');
    }

    final listObj = await TodoList.objects()
        .filter(Q('id', task.listId) & Q('ownerId', userId))
        .first(db);
    if (listObj == null) {
      throw BloomNotFoundException('Task not found');
    }

    await TodoTask.objects().filter(Q('id', pk)).delete(db);

    // Invalidate caches & broadcast
    await cache.delete('todo_tasks:list:${task.listId}');
    realtimeHub.broadcast('lists:${task.listId}', {
      'event': 'task_deleted',
      'taskId': pk,
      'listId': task.listId,
    });

    return BloomResponse.noContent();
  }
}
