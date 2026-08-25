import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_mail/bloom_mail.dart';
import 'package:bloom_jobs/bloom_jobs.dart';
import 'package:bloom_storage/bloom_storage.dart';
import 'package:bloom_realtime/bloom_realtime.dart';
import 'package:bloom_cache/bloom_cache.dart';
import 'package:bloom_i18n/bloom_i18n.dart';
import 'package:bloom_admin/bloom_admin.dart';

import '../bin/server.dart';
import '../lib/models/user.dart';
import '../lib/models/todo_list.dart';
import '../lib/models/todo_task.dart';

/// Lightweight HTTP response wrapper for test assertions.
class TestHttpResponse {
  final int statusCode;
  final HttpHeaders headers;
  final String bodyText;
  final dynamic bodyJson;

  TestHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyText,
    required this.bodyJson,
  });

  Map<String, dynamic> get asJsonMap =>
      bodyJson is Map<String, dynamic> ? bodyJson as Map<String, dynamic> : <String, dynamic>{};

  List<dynamic> get asJsonList =>
      bodyJson is List<dynamic> ? bodyJson as List<dynamic> : const [];
}

/// HTTP client helper targeting the running test server on an ephemeral port.
class TestClient {
  final int port;
  final HttpClient _client = HttpClient();

  TestClient(this.port);

  Future<TestHttpResponse> request(
    String method,
    String path, {
    Map<String, dynamic>? jsonBody,
    List<int>? rawBody,
    String? token,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: port,
      path: path,
      queryParameters: queryParams,
    );
    final req = await _client.openUrl(method, uri);
    if (token != null) {
      req.headers.set('authorization', 'Bearer $token');
    }
    if (headers != null) {
      headers.forEach((k, v) => req.headers.set(k, v));
    }
    if (jsonBody != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(jsonBody));
    } else if (rawBody != null) {
      req.add(rawBody);
    }
    final resp = await req.close();
    final bodyString = await resp.transform(utf8.decoder).join();
    dynamic parsedJson;
    try {
      parsedJson = jsonDecode(bodyString);
    } catch (_) {
      parsedJson = null;
    }
    return TestHttpResponse(
      statusCode: resp.statusCode,
      headers: resp.headers,
      bodyText: bodyString,
      bodyJson: parsedJson,
    );
  }

  Future<TestHttpResponse> get(
    String path, {
    String? token,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) =>
      request('GET', path, token: token, headers: headers, queryParams: queryParams);

  Future<TestHttpResponse> post(
    String path, {
    Map<String, dynamic>? json,
    List<int>? raw,
    String? token,
    Map<String, String>? headers,
    String? contentType,
  }) {
    final h = <String, String>{...?headers};
    if (contentType != null) h['content-type'] = contentType;
    return request('POST', path, jsonBody: json, rawBody: raw, token: token, headers: h);
  }

  Future<TestHttpResponse> put(
    String path, {
    Map<String, dynamic>? json,
    String? token,
    Map<String, String>? headers,
  }) =>
      request('PUT', path, jsonBody: json, token: token, headers: headers);

  Future<TestHttpResponse> patch(
    String path, {
    Map<String, dynamic>? json,
    String? token,
    Map<String, String>? headers,
  }) =>
      request('PATCH', path, jsonBody: json, token: token, headers: headers);

  Future<TestHttpResponse> delete(
    String path, {
    String? token,
    Map<String, String>? headers,
  }) =>
      request('DELETE', path, token: token, headers: headers);

  void close() => _client.close(force: true);
}

/// Applies SQLite DDL schema directly to an in-memory test database.
Future<void> createSqliteSchema(DbExecutor db) async {
  await db.execute('PRAGMA foreign_keys = ON;');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS todo_users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS todo_lists (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      owner_id INTEGER NOT NULL REFERENCES todo_users(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS todo_tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      list_id INTEGER NOT NULL REFERENCES todo_lists(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      done INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS todo_lists_owner_id_idx ON todo_lists(owner_id);');
  await db.execute('CREATE INDEX IF NOT EXISTS todo_tasks_list_id_idx ON todo_tasks(list_id);');
}

void main() {
  group('Bloom Full-Stack Todo End-to-End Integration Suite', () {
    late DbExecutor db;
    late InMemoryCache cache;
    late BloomInMemoryBackend mailBackend;
    late BloomTaskRegistry taskRegistry;
    late BloomTaskQueue taskQueue;
    late BloomRecurringRegistry recurringRegistry;
    late BloomJobWorker jobWorker;
    late Directory tempStorageDir;
    late BloomStorageBackend storageBackend;
    late BloomChannelHub realtimeHub;
    late BloomLocales locales;
    late BloomApiRouter router;
    late HttpServer server;
    late TestClient client;

    const testSecret = 'bloom-test-secret-key-32-chars-long-abc';

    setUpAll(() async {
      // 1. Configure environment and signing secret
      BloomEnv.loadMap({
        'BLOOM_AUTH_SECRET': testSecret,
        'APP_ENV': 'test',
      }, overwrite: true);

      // 2. In-memory SQLite Database & Schema
      db = SqliteDbExecutor.inMemory();
      await createSqliteSchema(db);
      globalContainer.provideValue<DbExecutor>(db);

      // 3. In-memory Cache
      cache = InMemoryCache(maxCapacity: 1000);
      globalContainer.provideValue<BloomCache>(cache);
      globalContainer.provideValue<InMemoryCache>(cache);

      // 4. In-memory Transactional Mail Backend
      mailBackend = BloomInMemoryBackend();
      globalContainer.provideSingleton<BloomMailBackend>(() => mailBackend);

      // 5. Background Jobs Subsystem
      taskRegistry = BloomTaskRegistry();
      taskQueue = BloomTaskQueue.inMemory();
      recurringRegistry = BloomRecurringRegistry();

      globalContainer.provideValue<BloomTaskRegistry>(taskRegistry);
      globalContainer.provideValue<BloomTaskQueue>(taskQueue);
      globalContainer.provideValue<BloomRecurringRegistry>(recurringRegistry);

      registerTaskHandlers(taskRegistry, mailBackend);

      jobWorker = BloomJobWorker(
        queue: taskQueue,
        registry: taskRegistry,
        recurringRegistry: recurringRegistry,
      );

      // 6. Temporary Storage Backend
      tempStorageDir = Directory.systemTemp.createTempSync('bloom_fullstack_test_storage_');
      storageBackend = LocalDiskBackend(
        baseDirectory: tempStorageDir.path,
        publicUrlPrefix: 'http://127.0.0.1:0/api/files',
      );
      BloomStorage.register(storageBackend);
      globalContainer.provideValue<BloomStorageBackend>(storageBackend);

      // 7. Realtime Hub
      realtimeHub = BloomChannelHub();
      globalContainer.provideValue<BloomChannelHub>(realtimeHub);

      // 8. Internationalization Locales
      locales = createDefaultLocales();
      globalContainer.provideValue<BloomLocales>(locales);

      // 9. Build App Router
      router = buildAppRouter(
        db: db,
        jobQueue: taskQueue,
        storageBackend: storageBackend,
        cache: cache,
        realtimeHub: realtimeHub,
        locales: locales,
        serverPort: 0,
      );

      // 10. Start Real Ephemeral HTTP Server
      server = await router.serve(port: 0);
      client = TestClient(server.port);
    });

    tearDownAll(() async {
      client.close();
      await server.close(force: true);
      await db.close();
      if (tempStorageDir.existsSync()) {
        tempStorageDir.deleteSync(recursive: true);
      }
    });

    // =========================================================================
    // 1. Health Check & Internationalization (bloom_i18n)
    // =========================================================================
    group('Health Check & Internationalization (/api/health)', () {
      test('GET /api/health returns 200 with default en-US locale greeting', () async {
        final res = await client.get('/api/health');
        expect(res.statusCode, 200);

        final data = res.asJsonMap;
        expect(data['status'], 'healthy');
        expect(data['framework'], contains('Bloom'));
        expect(data['locale'], 'en-US');
        expect(data['greeting'], 'Welcome to Bloom Todo backend!');
        expect(data['timestamp'], isNotNull);
      });

      test('GET /api/health with Accept-Language: es-ES resolves Spanish greeting', () async {
        final res = await client.get('/api/health', headers: {'accept-language': 'es-ES'});
        expect(res.statusCode, 200);

        final data = res.asJsonMap;
        expect(data['locale'], 'es-ES');
        expect(data['greeting'], '¡Bienvenido al backend de Bloom Todo!');
      });
    });

    // =========================================================================
    // 2. Authentication, JWT, Background Jobs & Mail (bloom_auth_server, bloom_jobs, bloom_mail)
    // =========================================================================
    group('User Authentication & Lifecycle (/api/auth/*)', () {
      late String aliceToken;
      late int aliceId;

      test('POST /api/auth/signup creates user, issues JWT, and queues welcome email job', () async {
        final signupPayload = {
          'name': 'Alice Integration',
          'email': 'alice@example.com',
          'password': 'password1234',
        };

        final res = await client.post('/api/auth/signup', json: signupPayload);
        expect(res.statusCode, 201);

        final data = res.asJsonMap;
        expect(data['token'], isNotNull);
        expect(data['message'], contains('Signup successful'));

        final userMap = data['user'] as Map<String, dynamic>;
        expect(userMap['id'], isA<int>());
        expect(userMap['email'], 'alice@example.com');
        expect(userMap['name'], 'Alice Integration');
        expect(userMap['createdAt'], isNotNull);
        expect(userMap.containsKey('password_hash'), isFalse);
        expect(userMap.containsKey('passwordHash'), isFalse);

        aliceToken = data['token'] as String;
        aliceId = userMap['id'] as int;

        // Verify cryptographic JWT signature
        final claims = verifySessionToken(aliceToken, secret: testSecret);
        expect(claims.userId, aliceId.toString());
        expect(claims.email, 'alice@example.com');
        expect(claims.roles, contains('user'));

        // Verify background job was enqueued on jobQueue
        final allTasks = await taskQueue.allTasks();
        expect(allTasks, isNotEmpty);
        final welcomeTask = allTasks.firstWhere((t) => t.taskName == 'send_welcome_email');
        expect(welcomeTask.payload['email'], 'alice@example.com');
        expect(welcomeTask.payload['name'], 'Alice Integration');

        // Process job queue with worker and assert transactional email delivery
        final initialSentCount = mailBackend.sentMessages.length;
        final claimed = await jobWorker.runOnce();
        expect(claimed, isTrue);
        expect(mailBackend.sentMessages.length, initialSentCount + 1);

        final sentMail = mailBackend.sentMessages.last;
        expect(sentMail.to, contains('alice@example.com'));
        expect(sentMail.subject, 'Welcome to Bloom Todo!');
        expect(sentMail.body, contains('Alice Integration'));
      });

      test('POST /api/auth/signup with duplicate email returns 409 Conflict', () async {
        final res = await client.post('/api/auth/signup', json: {
          'name': 'Alice Clone',
          'email': 'alice@example.com',
          'password': 'differentpassword',
        });
        expect(res.statusCode, 409);
        expect(res.asJsonMap['error']['message'], contains('already exists'));
      });

      test('POST /api/auth/signup with validation failure returns 422 Unprocessable Entity', () async {
        final res = await client.post('/api/auth/signup', json: {
          'name': 'A', // too short (< 2 chars)
          'email': 'not-an-email',
          'password': 'short', // too short (< 8 chars)
        });
        expect(res.statusCode, 422);
      });

      test('POST /api/auth/login with valid credentials returns 200 with JWT token', () async {
        final res = await client.post('/api/auth/login', json: {
          'email': 'alice@example.com',
          'password': 'password1234',
        });
        expect(res.statusCode, 200);

        final data = res.asJsonMap;
        expect(data['token'], isNotNull);
        expect(data['user']['email'], 'alice@example.com');

        final claims = verifySessionToken(data['token'] as String, secret: testSecret);
        expect(claims.userId, aliceId.toString());
      });

      test('POST /api/auth/login with invalid password returns 401 Unauthorized', () async {
        final res = await client.post('/api/auth/login', json: {
          'email': 'alice@example.com',
          'password': 'wrongpassword',
        });
        expect(res.statusCode, 401);
        expect(res.asJsonMap['error']['message'], contains('Invalid email or password'));
      });

      test('POST /api/auth/login with non-existent user returns 401 Unauthorized', () async {
        final res = await client.post('/api/auth/login', json: {
          'email': 'nobody@example.com',
          'password': 'somepassword',
        });
        expect(res.statusCode, 401);
        expect(res.asJsonMap['error']['message'], contains('Invalid email or password'));
      });

      test('GET /api/auth/me returns authenticated user identity with valid token', () async {
        final res = await client.get('/api/auth/me', token: aliceToken);
        expect(res.statusCode, 200);

        final data = res.asJsonMap;
        expect(data['user']['id'], aliceId);
        expect(data['user']['email'], 'alice@example.com');
        expect(data['user']['name'], 'Alice Integration');
        expect(data['claims']['userId'], aliceId.toString());
      });

      test('GET /api/auth/me without token returns 401 Unauthorized', () async {
        final res = await client.get('/api/auth/me');
        expect(res.statusCode, 401);
      });

      test('GET /api/auth/me with tampered / invalid token returns 401 Unauthorized', () async {
        final res = await client.get('/api/auth/me', token: 'forged.malformed.jwt.token');
        expect(res.statusCode, 401);
      });
    });

    // =========================================================================
    // 3. Bearer Token Authentication Middleware (BloomAuthMiddleware)
    // =========================================================================
    group('Authentication Middleware Security on REST Routes', () {
      test('GET /api/lists requires valid Bearer token (401 without auth header)', () async {
        final res = await client.get('/api/lists');
        expect(res.statusCode, 401);
      });

      test('POST /api/lists requires valid Bearer token (401 on garbage token)', () async {
        final res = await client.post(
          '/api/lists',
          json: {'name': 'Unauthorized List'},
          token: 'invalid_token_xyz',
        );
        expect(res.statusCode, 401);
      });

      test('GET /api/tasks requires valid Bearer token (401 without token)', () async {
        final res = await client.get('/api/tasks', queryParams: {'listId': '1'});
        expect(res.statusCode, 401);
      });
    });

    // =========================================================================
    // 4. Todo List & Task CRUD Round-Trip (bloom_rest, bloom_db, bloom_cache, bloom_realtime)
    // =========================================================================
    group('Todo List & Task REST CRUD Lifecycle', () {
      late String token;
      late int listId;
      late int task1Id;
      late int task2Id;

      setUpAll(() async {
        // Sign up dedicated user for CRUD lifecycle tests
        final res = await client.post('/api/auth/signup', json: {
          'name': 'Bob Tester',
          'email': 'bob.crud@example.com',
          'password': 'password1234',
        });
        expect(res.statusCode, 201);
        token = res.asJsonMap['token'] as String;
      });

      test('POST /api/lists creates a new TodoList', () async {
        final res = await client.post(
          '/api/lists',
          json: {'name': 'Work Sprint 42'},
          token: token,
        );
        expect(res.statusCode, 201);

        final data = res.asJsonMap;
        expect(data['id'], isA<int>());
        expect(data['name'], 'Work Sprint 42');
        expect(data['ownerId'], isA<int>());
        expect(data['createdAt'], isNotNull);

        listId = data['id'] as int;
      });

      test('GET /api/lists retrieves lists list with cache integration', () async {
        final res = await client.get('/api/lists', token: token);
        expect(res.statusCode, 200);

        final data = res.asJsonMap;
        expect(data['count'], 1);
        final results = data['results'] as List<dynamic>;
        expect(results.length, 1);
        expect(results[0]['id'], listId);
        expect(results[0]['name'], 'Work Sprint 42');
        expect(data['source'], 'bloom_cache');
      });

      test('GET /api/lists/:pk retrieves a single TodoList by id', () async {
        final res = await client.get('/api/lists/$listId', token: token);
        expect(res.statusCode, 200);

        final data = res.asJsonMap;
        expect(data['id'], listId);
        expect(data['name'], 'Work Sprint 42');
      });

      test('PATCH /api/lists/:pk updates TodoList name', () async {
        final res = await client.patch(
          '/api/lists/$listId',
          json: {'name': 'Work Sprint 42 - Renamed'},
          token: token,
        );
        expect(res.statusCode, 200);

        final data = res.asJsonMap;
        expect(data['id'], listId);
        expect(data['name'], 'Work Sprint 42 - Renamed');

        // Confirm database reflected update
        final getRes = await client.get('/api/lists/$listId', token: token);
        expect(getRes.asJsonMap['name'], 'Work Sprint 42 - Renamed');
      });

      test('POST /api/tasks creates tasks attached to the TodoList', () async {
        // Create Task 1
        final res1 = await client.post(
          '/api/tasks',
          json: {
            'listId': listId,
            'title': 'Implement Bloom Database ORM',
            'done': false,
          },
          token: token,
        );
        expect(res1.statusCode, 201);
        task1Id = res1.asJsonMap['id'] as int;
        expect(res1.asJsonMap['title'], 'Implement Bloom Database ORM');
        expect(res1.asJsonMap['done'], false);
        expect(res1.asJsonMap['listId'], listId);

        // Create Task 2
        final res2 = await client.post(
          '/api/tasks',
          json: {
            'listId': listId,
            'title': 'Ship Hermetic Integration Tests',
            'done': false,
          },
          token: token,
        );
        expect(res2.statusCode, 201);
        task2Id = res2.asJsonMap['id'] as int;
        expect(res2.asJsonMap['title'], 'Ship Hermetic Integration Tests');
      });

      test('GET /api/tasks?listId=:listId returns all tasks for the list', () async {
        final res = await client.get('/api/tasks', queryParams: {'listId': listId.toString()}, token: token);
        expect(res.statusCode, 200);

        final data = res.asJsonMap;
        expect(data['count'], 2);
        final results = data['results'] as List<dynamic>;
        expect(results.length, 2);
        expect(results.map((t) => t['id']), containsAll([task1Id, task2Id]));
      });

      test('GET /api/tasks/:pk retrieves individual task details', () async {
        final res = await client.get('/api/tasks/$task1Id', token: token);
        expect(res.statusCode, 200);
        expect(res.asJsonMap['id'], task1Id);
        expect(res.asJsonMap['title'], 'Implement Bloom Database ORM');
        expect(res.asJsonMap['done'], false);
      });

      test('PATCH /api/tasks/:pk toggles task done state and title', () async {
        final res = await client.patch(
          '/api/tasks/$task1Id',
          json: {'done': true, 'title': 'Implement Bloom Database ORM (Done)'},
          token: token,
        );
        expect(res.statusCode, 200);

        final data = res.asJsonMap;
        expect(data['id'], task1Id);
        expect(data['done'], true);
        expect(data['title'], 'Implement Bloom Database ORM (Done)');
      });

      test('DELETE /api/tasks/:pk removes a task (204 No Content)', () async {
        final res = await client.delete('/api/tasks/$task2Id', token: token);
        expect(res.statusCode, 204);

        // Verify task no longer exists
        final getRes = await client.get('/api/tasks/$task2Id', token: token);
        expect(getRes.statusCode, 404);

        // Verify list task count decremented
        final listTasksRes = await client.get('/api/tasks', queryParams: {'listId': listId.toString()}, token: token);
        expect(listTasksRes.asJsonMap['count'], 1);
      });

      test('DELETE /api/lists/:pk deletes list and cascade deletes remaining tasks', () async {
        final res = await client.delete('/api/lists/$listId', token: token);
        expect(res.statusCode, 204);

        // Verify list is gone
        final getListRes = await client.get('/api/lists/$listId', token: token);
        expect(getListRes.statusCode, 404);

        // Verify cascade-deleted task is also gone
        final getTaskRes = await client.get('/api/tasks/$task1Id', token: token);
        expect(getTaskRes.statusCode, 404);
      });
    });

    // =========================================================================
    // 5. Multi-User Ownership Isolation & Cross-Tenant Access Control
    // =========================================================================
    group('Multi-User Ownership Isolation & Access Control', () {
      late String user1Token;
      late int user1Id;
      late int user1ListId;
      late int user1TaskId;

      late String user2Token;
      late int user2Id;
      late int user2ListId;

      setUpAll(() async {
        // Register User 1 (Tenant A)
        final res1 = await client.post('/api/auth/signup', json: {
          'name': 'User One',
          'email': 'tenant.a@example.com',
          'password': 'password1234',
        });
        user1Token = res1.asJsonMap['token'] as String;
        user1Id = res1.asJsonMap['user']['id'] as int;

        // Register User 2 (Tenant B)
        final res2 = await client.post('/api/auth/signup', json: {
          'name': 'User Two',
          'email': 'tenant.b@example.com',
          'password': 'password1234',
        });
        user2Token = res2.asJsonMap['token'] as String;
        user2Id = res2.asJsonMap['user']['id'] as int;

        // User 1 creates private list and task
        final listRes = await client.post(
          '/api/lists',
          json: {'name': 'Tenant A Private Project'},
          token: user1Token,
        );
        user1ListId = listRes.asJsonMap['id'] as int;

        final taskRes = await client.post(
          '/api/tasks',
          json: {
            'listId': user1ListId,
            'title': 'Tenant A Secret Strategy',
            'done': false,
          },
          token: user1Token,
        );
        user1TaskId = taskRes.asJsonMap['id'] as int;

        // User 2 creates their own list
        final list2Res = await client.post(
          '/api/lists',
          json: {'name': 'Tenant B General Notes'},
          token: user2Token,
        );
        user2ListId = list2Res.asJsonMap['id'] as int;
      });

      test('User 2 listing /api/lists only sees their own lists, never User 1 lists', () async {
        final res = await client.get('/api/lists', token: user2Token);
        expect(res.statusCode, 200);

        final data = res.asJsonMap;
        expect(data['count'], 1);
        final results = data['results'] as List<dynamic>;
        expect(results.length, 1);
        expect(results[0]['id'], user2ListId);
        expect(results[0]['name'], 'Tenant B General Notes');
        expect(results[0]['ownerId'], user2Id);
      });

      test('User 2 cannot retrieve User 1 list by ID (404 Not Found)', () async {
        final res = await client.get('/api/lists/$user1ListId', token: user2Token);
        expect(res.statusCode, 404);
      });

      test('User 2 cannot modify User 1 list (404 Not Found)', () async {
        final res = await client.patch(
          '/api/lists/$user1ListId',
          json: {'name': 'Hacked by Tenant B'},
          token: user2Token,
        );
        expect(res.statusCode, 404);
      });

      test('User 2 cannot delete User 1 list (404 Not Found)', () async {
        final res = await client.delete('/api/lists/$user1ListId', token: user2Token);
        expect(res.statusCode, 404);
      });

      test('User 2 cannot add a task into User 1 list (404 Not Found)', () async {
        final res = await client.post(
          '/api/tasks',
          json: {
            'listId': user1ListId,
            'title': 'Unauthorized Injected Task',
            'done': false,
          },
          token: user2Token,
        );
        expect(res.statusCode, 404);
        expect(res.asJsonMap['error']['message'], contains('not found or unauthorized'));
      });

      test('User 2 cannot list tasks from User 1 list (404 Not Found)', () async {
        final res = await client.get(
          '/api/tasks',
          queryParams: {'listId': user1ListId.toString()},
          token: user2Token,
        );
        expect(res.statusCode, 404);
      });

      test('User 2 cannot retrieve User 1 task directly (404 Not Found)', () async {
        final res = await client.get('/api/tasks/$user1TaskId', token: user2Token);
        expect(res.statusCode, 404);
      });

      test('User 2 cannot update User 1 task (404 Not Found)', () async {
        final res = await client.patch(
          '/api/tasks/$user1TaskId',
          json: {'done': true},
          token: user2Token,
        );
        expect(res.statusCode, 404);
      });

      test('User 2 cannot delete User 1 task (404 Not Found)', () async {
        final res = await client.delete('/api/tasks/$user1TaskId', token: user2Token);
        expect(res.statusCode, 404);
      });

      test('User 1 retains full uninterrupted access to their own list and tasks', () async {
        final listRes = await client.get('/api/lists/$user1ListId', token: user1Token);
        expect(listRes.statusCode, 200);
        expect(listRes.asJsonMap['name'], 'Tenant A Private Project');

        final taskRes = await client.get('/api/tasks/$user1TaskId', token: user1Token);
        expect(taskRes.statusCode, 200);
        expect(taskRes.asJsonMap['title'], 'Tenant A Secret Strategy');
      });
    });

    // =========================================================================
    // 6. File Storage Subsystem (bloom_storage)
    // =========================================================================
    group('File Storage & Uploads (/api/uploads/* and /api/files/*)', () {
      late String userToken;
      late String uploadedFilename;
      final mockAvatarBytes = utf8.encode('mock-avatar-png-binary-stream-data-xyz');

      setUpAll(() async {
        final res = await client.post('/api/auth/signup', json: {
          'name': 'Storage Tester',
          'email': 'storage.user@example.com',
          'password': 'password1234',
        });
        userToken = res.asJsonMap['token'] as String;
      });

      test('POST /api/uploads/avatar uploads file to storage backend', () async {
        final res = await client.post(
          '/api/uploads/avatar',
          raw: mockAvatarBytes,
          contentType: 'image/png',
          token: userToken,
        );
        expect(res.statusCode, 201);

        final data = res.asJsonMap;
        expect(data['filename'], isNotNull);
        expect(data['sizeBytes'], mockAvatarBytes.length);
        expect(data['publicUrl'], isNotNull);
        expect(data['signedDownloadUrl'], isNotNull);

        uploadedFilename = data['filename'] as String;
      });

      test('GET /api/files/:path serves uploaded file bytes', () async {
        final res = await client.get('/api/files/$uploadedFilename');
        expect(res.statusCode, 200);
        expect(res.bodyText, utf8.decode(mockAvatarBytes));
      });

      test('GET /api/uploads/signed-url returns presigned download URL for existing file', () async {
        final res = await client.get(
          '/api/uploads/signed-url',
          queryParams: {'file': uploadedFilename},
          token: userToken,
        );
        expect(res.statusCode, 200);
        expect(res.asJsonMap['signedUrl'], isNotNull);
        expect(res.asJsonMap['expiresInMinutes'], 30);
      });

      test('GET /api/uploads/signed-url returns 404 for non-existent file', () async {
        final res = await client.get(
          '/api/uploads/signed-url',
          queryParams: {'file': 'avatars/does_not_exist.png'},
          token: userToken,
        );
        expect(res.statusCode, 404);
      });
    });

    // =========================================================================
    // 7. Server-Side Rendered HTML Admin Panel (bloom_admin)
    // =========================================================================
    group('Server-Side Rendered Admin Panel (/admin/*)', () {
      test('GET /admin/ renders admin index dashboard HTML with registered models', () async {
        final res = await client.get('/admin/');
        expect(res.statusCode, 200);
        expect(res.headers.value('content-type'), contains('text/html'));
        expect(res.bodyText, contains('Bloom Todo Administration'));
        expect(res.bodyText, contains('todo.User'));
        expect(res.bodyText, contains('todo.TodoList'));
        expect(res.bodyText, contains('todo.TodoTask'));
      });

      test('GET /admin/todo/user/ renders User changelist table', () async {
        final res = await client.get('/admin/todo/user/');
        expect(res.statusCode, 200);
        expect(res.headers.value('content-type'), contains('text/html'));
        expect(res.bodyText, contains('User'));
      });

      test('GET /admin/todo/todolist/ renders TodoList changelist table', () async {
        final res = await client.get('/admin/todo/todolist/');
        expect(res.statusCode, 200);
        expect(res.headers.value('content-type'), contains('text/html'));
        expect(res.bodyText, contains('TodoList'));
      });

      test('GET /admin/todo/todotask/ renders TodoTask changelist table', () async {
        final res = await client.get('/admin/todo/todotask/');
        expect(res.statusCode, 200);
        expect(res.headers.value('content-type'), contains('text/html'));
        expect(res.bodyText, contains('TodoTask'));
      });
    });
  });
}
