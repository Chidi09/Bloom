# Bloom for Backend & Full-Stack Dart Developers: The Complete Architectural Guide

Welcome to the definitive guide for engineers building enterprise-grade backend infrastructure, high-throughput REST APIs, real-time WebSocket communication hubs, sub-millisecond Server-Side Rendered (SSR) micro-frontends, and distributed background workers using **Bloom Server** and **Dart**.

---

## 1. Executive Summary: Why Dart on the Server?

For years, backend development has been dominated by Node.js/TypeScript, Go, Python/Django, and Rust. While each has strengths, building modern full-stack web and mobile applications with them introduces severe architectural fragmentation:
* Schema duplication across ORMs, API contracts, and client view models.
* Serialization/deserialization overhead and fragile type-generation pipelines (tRPC, Prisma, GraphQL codegen).
* Context-switching between frontend (Dart/TS) and backend (Python/Go) languages and toolchains.

**Bloom Server provides a unified full-stack runtime with:**
1. **Multi-Isolate Architecture**: Full utilization of multi-core CPU architecture using lightweight Dart isolates without shared-state concurrency bugs.
2. **Sub-Millisecond SSR (`< 0.4ms`)**: Native HTML string interpolation with zero external JavaScript engine (Node.js/V8) dependencies.
3. **Automatic OpenAPI 3.1 & Interactive Docs**: Real-time OpenAPI JSON, Swagger UI, and Scalar explorer generated directly from Dart route metadata.
4. **Sub-80ms Hot Restarts (`bloom server run --watch`)**: Instant isolate re-spawning on file changes while preserving database connection pools.

---

## 2. Server Architecture Overview

```
                      ┌────────────────────────────────────────┐
                      │          bloom server run --watch      │
                      │             Master TCP Socket          │
                      └───────────────────┬────────────────────┘
                                          │ Port Sharing
                  ┌───────────────────────┼───────────────────────┐
                  ▼                       ▼                       ▼
         ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
         │ Worker Isolate  │     │ Worker Isolate  │     │ Worker Isolate  │
         │  (Thread #1)    │     │  (Thread #2)    │     │  (Thread #8)    │
         ├─────────────────┤     ├─────────────────┤     ├─────────────────┤
         │ • HTTP Router   │     │ • HTTP Router   │     │ • HTTP Router   │
         │ • DB Pool Conn  │     │ • DB Pool Conn  │     │ • DB Pool Conn  │
         │ • WebSocket Hub │     │ • WebSocket Hub │     │ • WebSocket Hub │
         │ • SSR Renderer  │     │ • SSR Renderer  │     │ • SSR Renderer  │
         └─────────────────┘     └─────────────────┘     └─────────────────┘
```

The server runtime (`apps/server/bin/server.dart`) spawns worker isolates matching available CPU cores. Each isolate runs an asynchronous event loop handling non-blocking I/O.

---

## 3. Master Conceptual Rosetta Stone

| Backend Concept | Express.js / Fastify | Django / FastAPI | Bloom Server |
| :--- | :--- | :--- | :--- |
| **Server Instance** | `const app = express()` | `app = FastAPI()` | `final router = BloomApiRouter()` |
| **Route Registration**| `app.get('/api/tasks', handler)` | `@app.get('/api/tasks')` | `router.get('/api/tasks', handler)` |
| **Route Grouping** | `app.use('/api/v1', v1Router)` | `include('apps.tasks.urls')` | `router.mount('/api/v1', tasksRouter)` |
| **Middleware** | `app.use(cors())` | `MIDDLEWARE = [...]` | `router.use(const BloomCorsMiddleware())` |
| **Error Handling** | `app.use((err, req, res, next) => ...)` | Custom exception handlers | `router.use(const BloomErrorMiddleware())` + `throw BloomNotFoundException(...)` |
| **OpenAPI Docs** | `@fastify/swagger` / Swagger UI | `/docs` (FastAPI Swagger) | `router.enableOpenApi(...)` ➔ `/api/docs` (Scalar) & `/api/swagger` |
| **WebSockets** | `ws` / `socket.io` | Django Channels / WebSockets | `BloomChannelHub` + `router.serveWithWebSockets(...)` |
| **ORM / Data Access**| Prisma, Drizzle, TypeORM | Django ORM, SQLAlchemy | `BloomDb`, `BloomRepository<T, ID>`, raw typed SQL |
| **Hot Reload** | `nodemon` / `tsx watch` | `uvicorn --reload` | `bloom server run --watch` (sub-isolate re-spawn in `<80ms`) |

---

## 4. Building Production REST APIs with `BloomApiRouter`

### 4.1 Server Entrypoint (`apps/server/bin/server.dart`)

```dart
// apps/server/bin/server.dart
import 'dart:io';
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_security/bloom_security.dart';

import '../lib/router.dart';
import '../lib/db/database.dart';

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final db = await DatabaseService.initialize();

  final router = BloomApiRouter();

  // 1. Global Middleware Pipeline (Order matters!)
  router.use(const BloomErrorMiddleware()); // Intercepts strongly-typed Bloom exceptions
  router.use(BloomAdvancedCorsMiddleware.permissive());
  router.use(BloomRateLimitMiddleware(maxRequests: 300, window: const Duration(minutes: 1)));
  router.use(BloomLoggingMiddleware());

  // 2. Enable Auto-Generated OpenAPI & Interactive Documentation
  router.enableOpenApi(
    title: 'Bloom Enterprise API',
    version: '1.0.0',
    description: 'Unified high-throughput REST and WebSocket server.',
  );

  // 3. Mount Application Domain Routers
  registerAppRoutes(router, db);

  // 4. Start Multi-Isolate Server on Port 8080
  final server = await router.serve(
    port: port,
    shared: true, // Multi-isolate TCP port sharing
  );

  print('🌸 Bloom Multi-Isolate Server active on http://0.0.0.0:$port');
  print('📚 Scalar Documentation : http://localhost:$port/api/docs');
  print('📖 Swagger Interactive UI : http://localhost:$port/api/swagger');
  print('📄 OpenAPI 3.1 JSON Spec  : http://localhost:$port/api/openapi.json');
}
```

---

## 5. Strongly-Typed Error Handling & Error Boundaries

Never return unformatted 500 error strings or expose database stack traces in production. Bloom Server uses strongly typed exception variants intercepted by `BloomErrorMiddleware`.

### 5.1 Exception Hierarchy

```dart
// Available strongly-typed exception classes:
throw BloomBadRequestException('Invalid JSON payload format');
throw BloomUnauthorizedException('JWT token has expired or is invalid');
throw BloomForbiddenException('Insufficient workspace permissions');
throw BloomNotFoundException('Task with ID "$id" does not exist');
throw BloomConflictException('Project slug already in use');
throw BloomValidationException('Validation failed', errors: {
  'title': 'Field cannot be blank',
  'priority': 'Must be one of [p1, p2, p3, p4]',
});
```

### 5.2 Standard JSON Error Response Format
When any `BloomApiException` is thrown, the client automatically receives:
```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Task with ID \"task_999\" does not exist",
    "statusCode": 404,
    "timestamp": "2026-08-21T14:45:00.000Z"
  }
}
```

---

## 6. Authentication, Session Tokens & Middleware

Bloom includes enterprise authentication utilities supporting Bearer JWTs, signed cookies, API keys, and route guards.

### 6.1 JWT Authentication Middleware

```dart
// apps/server/lib/middleware/auth_middleware.dart
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_auth_server/bloom_auth_server.dart';

class BloomAuthMiddleware implements BloomMiddleware {
  final TokenVerifier verifier;
  const BloomAuthMiddleware(this.verifier);

  @override
  Future<BloomResponse?> handle(BloomRequest req, BloomNextFunction next) async {
    final authHeader = req.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      throw BloomUnauthorizedException('Missing or malformed Authorization header');
    }

    final token = authHeader.substring(7);
    final user = await verifier.verifyJwt(token);

    if (user == null) {
      throw BloomUnauthorizedException('Invalid or expired authentication token');
    }

    // Attach verified user context to request
    req.context['user'] = user;
    return next();
  }
}
```

### 6.2 Scoped Route Protection

```dart
final protectedRouter = BloomApiRouter();
protectedRouter.use(BloomAuthMiddleware(jwtVerifier));

protectedRouter.get('/api/me', (BloomRequest req) async {
  final user = req.context['user'] as AuthenticatedUser;
  return BloomResponse.json(user.toJson());
});
```

---

## 7. Real-Time WebSockets with `BloomChannelHub`

Bloom includes a built-in pub/sub WebSocket channel hub for broadcasting delta state updates to connected browsers, desktop apps, and mobile clients:

```dart
// apps/server/lib/realtime/channel_hub.dart
import 'package:bloom_framework/bloom_server.dart';

final realtimeHub = BloomChannelHub();

void registerWebSocketRoutes(BloomApiRouter router) {
  router.webSocket('/ws', (WebSocketSession session, BloomRequest req) {
    final workspaceId = req.query['workspaceId'] ?? 'global';
    realtimeHub.subscribe(session, channel: 'workspace:$workspaceId');

    session.onMessage((msg) {
      print('Received from client: $msg');
    });

    session.onClose(() {
      realtimeHub.unsubscribe(session);
    });
  });
}

// When a task is created or updated in REST API:
void notifyTaskUpdated(Task task) {
  realtimeHub.broadcast(
    channel: 'workspace:${task.projectId}',
    payload: {
      'event': 'task_updated',
      'task': task.toJson(),
    },
  );
}
```

---

## 8. Sub-Millisecond Server-Side Rendering (SSR)

Unlike Node.js SSR frameworks that require heavy V8 runtime contexts and hydration overhead, Bloom executes pure-Dart AST descriptor trees directly on the server in `< 0.4ms`:

```dart
// apps/server/lib/controllers/ssr_landing_controller.dart
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';

Future<BloomResponse> ssrLandingHandler(BloomRequest req) async {
  final head = HeadManager();
  head.update(
    title: 'Bloom — The Full-Stack Dart Framework',
    description: 'Sub-millisecond SSR, fine-grained signals, and multi-isolate server architecture.',
    ogImage: 'https://bloom.dev/assets/og-cover.png',
  );

  // Pure-Dart AST Component
  final landingPage = Div(
    className: 'min-h-screen bg-[#09090B] text-white flex flex-col items-center justify-center p-6',
    children: [
      H1(className: 'text-4xl font-bold font-sans', text: 'Build Faster with Bloom'),
      P(className: 'mt-3 text-zinc-400 text-sm', text: 'Pure Dart across frontend, mobile, and server.'),
    ],
  );

  final html = renderToHtml(
    landingPage,
    title: head.title.value,
    metaTags: head.toMetaTags(),
  );

  return BloomResponse.html(html);
}
```

---

## 9. Background Isolates & Distributed Job Queue

Bloom includes background worker execution for processing scheduled tasks, email notifications, and heavy data computations without blocking the HTTP event loop.

```dart
// apps/server/lib/jobs/queue.dart
import 'dart:isolate';
import 'package:bloom_framework/bloom_server.dart';

class BloomJobWorker {
  final ReceivePort _receivePort = ReceivePort();
  SendPort? _workerSendPort;

  Future<void> start() async {
    await Isolate.spawn(_workerEntrypoint, _receivePort.sendPort);
    _receivePort.listen((message) {
      if (message is SendPort) {
        _workerSendPort = message;
      } else if (message is Map) {
        print('Job completed: ${message["jobId"]}');
      }
    });
  }

  void dispatch(String taskName, Map<String, dynamic> payload) {
    _workerSendPort?.send({
      'task': taskName,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void _workerEntrypoint(SendPort sendPort) {
    final workerReceivePort = ReceivePort();
    sendPort.send(workerReceivePort.sendPort);

    workerReceivePort.listen((message) async {
      if (message is Map) {
        final task = message['task'];
        final payload = message['payload'];
        // Execute background computation
        print('Executing background worker task: $task');
        sendPort.send({'jobId': message['timestamp'], 'status': 'success'});
      }
    });
  }
}
```

---

## 10. Database Repositories & Migrations

```dart
// apps/server/lib/repositories/task_repository.dart
import 'package:bloom_todo_core/core.dart';
import 'package:sqlite3/sqlite3.dart';

class TaskRepository {
  final Database db;
  TaskRepository(this.db);

  List<Task> findAll() {
    final stmt = db.prepare('SELECT id, title, description, project_id, priority, is_completed, created_at FROM tasks ORDER BY created_at DESC');
    final rows = stmt.select([]);
    return rows.map((row) => Task(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      projectId: row['project_id'] as String,
      priority: Priority.values.firstWhere((p) => p.name == row['priority']),
      isCompleted: (row['is_completed'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
    )).toList();
  }

  void insert(Task task) {
    final stmt = db.prepare('INSERT INTO tasks (id, title, description, project_id, priority, is_completed, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)');
    stmt.execute([
      task.id,
      task.title,
      task.description,
      task.projectId,
      task.priority.name,
      task.isCompleted ? 1 : 0,
      task.createdAt.toIso8601String(),
    ]);
  }
}
```

---

## 11. Monorepo Git Remote Operations

Per the Bloom architectural contract in `GEMINI.md`:
* **DO NOT PUSH TO ORIGIN DIRECTLY.**
* Local monorepo contains public framework code and private infrastructure.
* Always execute the automated filter-repo script:
  ```bash
  /root/dev/Bloom/scripts/push-split.sh
  ```
  1. **Public Repository**: `https://github.com/Chidi09/Bloom.git` (`packages/`, `apps/`, `examples/`, `benchmarks/`).
  2. **Private Repository**: `https://github.com/Chidi09/bloom-cloud.git` (`cloud-backend/`, `cloud-dashboard/`, `docs/`).

---

## 12. Developer Commands & Quality Gates

```bash
# 1. Start server with live file-watching hot restart
bloom server run --watch --port 8080

# 2. Scaffold a new server Django-style application app
bloom server startapp billing

# 3. Run database migrations
bloom migrate

# 4. Zero-error analysis gate across all packages
dart analyze
```
