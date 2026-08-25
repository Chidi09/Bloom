# Bloom Full-Stack Todo Backend Example (`bloom_fullstack_todo`)

A real, working backend reference application wiring together **all 15 packages** of the Bloom framework against a **real PostgreSQL database**.

---

## 📦 Packages Integrated & Exercised

| Package | Role & Route / Code Path in Application |
|---|---|
| `bloom_framework` | Core DI container (`globalContainer`), `BloomEnv`, `BloomApiRouter`, `BloomRequest`, `BloomResponse`. |
| `bloom_db` | ORM queries (`User.objects()`, `TodoList.objects()`, `TodoTask.objects()`), `Q()` filters, `QuerySet.insertRaw()`, and `PostgresDbExecutor` connection. |
| `bloom_db_generator` | Declarative `@BloomModel` & `@BloomField` annotations on models (`User`, `TodoList`, `TodoTask`) matching generated `ModelMeta` and `fromRow`. |
| `bloom_validate` | Declarative request DTO schemas (`SignupRequestSchema`, `LoginRequestSchema`, `CreateTodoListSchema`, `CreateTodoTaskSchema`) validating bodies before execution. |
| `bloom_auth_server` | BCrypt password hashing (`hashPassword`), user verification (`verifyPassword`, `dummyVerifyPassword`), JWT session tokens (`issueSessionToken`), rate limiting (`AuthRateLimiter`), and `BloomAuthMiddleware`. |
| `bloom_mail` | Transactional welcome email message (`BloomMailMessage`) delivered via `BloomConsoleBackend` during signup. |
| `bloom_jobs` | Background task queue (`BloomTaskQueue`), registry (`BloomTaskRegistry`), and worker (`BloomJobWorker`) processing `send_welcome_email` jobs asynchronously. |
| `bloom_security` | Global IP sliding-window rate limiting (`BloomRateLimitMiddleware`), security headers (`BloomSecurityHeadersMiddleware`), `BloomAdvancedCorsMiddleware.permissive()`, and WebSocket upgrade (`serveWithWebSockets`). |
| `bloom_storage` | Local file uploads and presigned URL generation via `LocalDiskBackend` and `BloomStorage` static accessor at `/api/uploads/avatar`. |
| `bloom_realtime` | Real-time WebSocket pub/sub (`BloomChannelHub`) broadcasting list mutations and task updates on `/ws/realtime`. |
| `bloom_cache` | In-memory LRU cache (`InMemoryCache`) caching list and task index GET responses with stampede deduplication (`getOrSet`). |
| `bloom_i18n` | Multi-locale catalog (`BloomLocales`), `Accept-Language` middleware (`BloomLocaleMiddleware`), ICU plural formatting, and `req.t()` resolution. |
| `bloom_admin` | Server-side rendered HTML admin panel (`BloomAdminSite`) mounted at `/admin` for `User`, `TodoList`, and `TodoTask`. |
| `bloom_migrate` | DDL schema generation and automatic startup migration runner (`MigrationRunner`) executing `migrations/todo/0001_initial.sql`. |
| `bloom_rest` | DRF-style ViewSets (`BloomViewSet<TodoList>`, `BloomViewSet<TodoTask>`), serializers (`BloomModelSerializer`), permissions (`IsAuthenticated`), and pagination. |
| `bloom_errors` | Outermost error middleware (`BloomErrorMiddleware`) catching and rendering typed exceptions (`BloomNotFoundException`, `BloomUnauthorizedException`, `BloomValidationFailedException`). |

---

## 🚀 Getting Started

### 1. Requirements
- Dart SDK `3.3.0` or higher
- PostgreSQL running locally at `127.0.0.1:5432` with database `bloom_integration_test` (user `postgres`, password `postgres`).

### 2. Configure Environment
Copy `.env.example` to `.env` (defaults are pre-configured for the local test DB):
```bash
cp .env.example .env
```

### 3. Apply Migrations & Run the Server
```bash
dart pub get
dart run bin/server.dart
```

When started, the backend will:
1. Connect to PostgreSQL.
2. Automatically run pending migrations via `bloom_migrate`.
3. Boot the `bloom_jobs` background worker.
4. Mount all API endpoints, admin routes at `/admin/`, and WebSocket at `/ws/realtime`.

---

## 📡 API Endpoints & `curl` Examples

### 1. Health Check (Demonstrates `bloom_i18n`)
```bash
# Default English locale
curl -s http://127.0.0.1:8080/api/health

# Spanish locale via Accept-Language header
curl -s -H "Accept-Language: es-ES" http://127.0.0.1:8080/api/health
```

### 2. User Signup (Demonstrates `bloom_validate`, `bloom_auth_server`, `bloom_jobs`, `bloom_mail`)
```bash
curl -s -X POST http://127.0.0.1:8080/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Alice Developer",
    "email": "alice@example.com",
    "password": "super-secure-password"
  }'
```
*Note: Check the server console to see the `bloom_jobs` worker process the `send_welcome_email` job and `bloom_mail`'s `BloomConsoleBackend` log the email.*

### 3. User Login (Demonstrates `bloom_auth_server` BCrypt & Lockout)
```bash
curl -s -X POST http://127.0.0.1:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice@example.com",
    "password": "super-secure-password"
  }'
```
*Export the returned JWT token to an environment variable for subsequent authenticated calls:*
```bash
export TOKEN="<PASTE_TOKEN_FROM_LOGIN_HERE>"
```

### 4. Create a Todo List (Demonstrates `bloom_rest`, `bloom_db`, `bloom_realtime`)
```bash
curl -s -X POST http://127.0.0.1:8080/api/lists \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sprint 1 Objectives"
  }'
```

### 5. Create a Task in the List
```bash
curl -s -X POST http://127.0.0.1:8080/api/tasks \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "listId": 1,
    "title": "Wire all 15 Bloom framework packages",
    "done": false
  }'
```

### 6. List Tasks with Caching (Demonstrates `bloom_cache`)
```bash
# First call executes DB query and caches result
curl -s -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:8080/api/tasks?listId=1"

# Subsequent repeat calls within 30s return instantly from bloom_cache
curl -s -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:8080/api/tasks?listId=1"
```

### 7. Upload a File Attachment (Demonstrates `bloom_storage`)
```bash
curl -s -X POST http://127.0.0.1:8080/api/uploads/avatar \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: image/png" \
  --data-binary "PNG_MOCK_IMAGE_DATA_BYTES_HERE"
```

### 8. Access the Server-Side HTML Admin Panel (Demonstrates `bloom_admin`)
Open in your browser:
```
http://127.0.0.1:8080/admin/
```
Or via curl:
```bash
curl -s http://127.0.0.1:8080/admin/
curl -s http://127.0.0.1:8080/admin/todo/todolist/
curl -s http://127.0.0.1:8080/admin/todo/todotask/
```

### 9. Connect to Realtime WebSockets (Demonstrates `bloom_realtime` & `bloom_security`)
Connect using a WebSocket client (e.g. `wscat` or Dart client):
```bash
wscat -c ws://127.0.0.1:8080/ws/realtime
```
Subscribe to list changes:
```json
{"type":"subscribe","channel":"lists:1"}
```
Whenever a task is created, updated, or deleted, a real-time event will be broadcast to all connected WebSocket subscribers.

---

## 🧪 Automated Hermetic Integration Testing

The example app includes a comprehensive, hermetic end-to-end integration test suite located at [`test/integration_test.dart`](file:///root/dev/Bloom/examples/bloom_fullstack_todo/test/integration_test.dart) that boots the application in-process against an isolated in-memory SQLite database without requiring a running PostgreSQL server.

### Running the Test Suite
```bash
cd examples/bloom_fullstack_todo
dart test
```

### What the Suite Proves
- **Full-Stack Router & Middleware Pipeline**: Real HTTP requests dispatched over ephemeral sockets through `BloomErrorMiddleware`, `BloomRateLimitMiddleware`, `BloomSecurityHeadersMiddleware`, `BloomAdvancedCorsMiddleware`, and `BloomLocaleMiddleware`.
- **Authentication & Security**: User signup with BCrypt password hashing, session JWT issuance (`issueSessionToken`), token cryptographic verification, and brute-force/protected route defense via `BloomAuthMiddleware`.
- **Asynchronous Jobs & Mail**: Automatic enqueueing of `send_welcome_email` background tasks via `bloom_jobs` on user registration and transactional email delivery verification via `bloom_mail`.
- **Database & REST CRUD Round-Trip**: Full lifecycle operations (create, list, retrieve, update, delete, cascade delete) using `bloom_rest` ViewSets and `bloom_db` QuerySet ORM queries.
- **Multi-Tenant Ownership Isolation**: Strict cross-user data isolation ensuring users cannot view, modify, inject tasks into, or delete another user's lists or tasks (producing HTTP 404 responses).
- **Storage & Presigned URLs**: Binary file uploads to `bloom_storage`, raw bytes downloading, and signed URL generation.
- **Admin Interface**: Server-rendered HTML dashboard and model changelist tables (`bloom_admin`) for `User`, `TodoList`, and `TodoTask`.

