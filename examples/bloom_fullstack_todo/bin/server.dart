import 'dart:async';
import 'dart:io';
import 'package:bloom_framework/bloom_server.dart';

// Database & Codegen
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_migrate/bloom_migrate.dart';

// Errors & Security
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_security/bloom_security.dart';

// Jobs, Mail, Storage, Realtime, Cache, i18n, Admin
import 'package:bloom_mail/bloom_mail.dart';
import 'package:bloom_jobs/bloom_jobs.dart';
import 'package:bloom_storage/bloom_storage.dart';
import 'package:bloom_realtime/bloom_realtime.dart';
import 'package:bloom_cache/bloom_cache.dart';
import 'package:bloom_i18n/bloom_i18n.dart';
import 'package:bloom_admin/bloom_admin.dart';

// Domain Models & URL Routing
import '../lib/models/user.dart';
import '../lib/models/todo_list.dart';
import '../lib/models/todo_task.dart';
import '../lib/urls.dart';

Future<void> main(List<String> args) async {
  // ---------------------------------------------------------------------------
  // 1. Environment Configuration via BloomEnv
  // ---------------------------------------------------------------------------
  final envFile = File('.env');
  if (envFile.existsSync()) {
    BloomEnv.loadContent(envFile.readAsStringSync());
  }

  // Load defaults for local Postgres instance
  BloomEnv.loadMap({
    'DB_HOST': BloomEnv.getOrNull('DB_HOST') ?? '127.0.0.1',
    'DB_PORT': BloomEnv.getOrNull('DB_PORT') ?? '5432',
    'DB_USER': BloomEnv.getOrNull('DB_USER') ?? 'postgres',
    'DB_PASSWORD': BloomEnv.getOrNull('DB_PASSWORD') ?? 'postgres',
    'DB_NAME': BloomEnv.getOrNull('DB_NAME') ?? 'bloom_integration_test',
    'BLOOM_AUTH_SECRET': BloomEnv.getOrNull('BLOOM_AUTH_SECRET') ??
        'bloom-super-secure-jwt-signing-secret-key-32chars',
    'APP_ENV': BloomEnv.getOrNull('APP_ENV') ?? 'local',
    'PORT': BloomEnv.getOrNull('PORT') ?? '8080',
    'STORAGE_PATH': BloomEnv.getOrNull('STORAGE_PATH') ?? './storage/uploads',
  }, overwrite: false);

  final dbHost = BloomEnv.get('DB_HOST');
  final dbPort = BloomEnv.getInt('DB_PORT', defaultValue: 5432);
  final dbUser = BloomEnv.get('DB_USER');
  final dbPass = BloomEnv.get('DB_PASSWORD');
  final dbName = BloomEnv.get('DB_NAME');
  final serverPort = BloomEnv.getInt('PORT', defaultValue: 8080);
  final storagePath = BloomEnv.get('STORAGE_PATH', defaultValue: './storage/uploads');

  stdout.writeln('Connecting to Postgres at $dbHost:$dbPort/$dbName as $dbUser...');

  // ---------------------------------------------------------------------------
  // 2. Real Postgres Connection via bloom_db
  // ---------------------------------------------------------------------------
  final db = await PostgresDbExecutor.connect(
    host: dbHost,
    port: dbPort,
    username: dbUser,
    password: dbPass,
    database: dbName,
  );
  globalContainer.provideValue<DbExecutor>(db);

  // ---------------------------------------------------------------------------
  // 3. Database Migrations via bloom_migrate
  // ---------------------------------------------------------------------------
  stdout.writeln('Running database migrations via bloom_migrate...');
  final migrationRunner = MigrationRunner(
    db: db,
    migrationsDirectory: 'migrations',
  );
  try {
    final applied = await migrationRunner.migrate();
    stdout.writeln('Applied ${applied.length} pending migration(s).');
  } catch (e) {
    stdout.writeln('Note on migrations: $e');
  }

  // ---------------------------------------------------------------------------
  // 4. Cache Subsystem via bloom_cache (In-Memory LRU Backend)
  // ---------------------------------------------------------------------------
  final cache = InMemoryCache(maxCapacity: 5000);
  globalContainer.provideValue<BloomCache>(cache);
  globalContainer.provideValue<InMemoryCache>(cache);

  // ---------------------------------------------------------------------------
  // 5. Transactional Mail Subsystem via bloom_mail (ConsoleBackend for dev)
  // ---------------------------------------------------------------------------
  const mailBackend = BloomConsoleBackend();
  globalContainer.provideSingleton<BloomMailBackend>(() => mailBackend);

  // ---------------------------------------------------------------------------
  // 6. Background Job Queue & Worker via bloom_jobs
  // ---------------------------------------------------------------------------
  final taskRegistry = BloomTaskRegistry();
  final taskQueue = BloomTaskQueue();
  final recurringRegistry = BloomRecurringRegistry();

  globalContainer.provideValue<BloomTaskRegistry>(taskRegistry);
  globalContainer.provideValue<BloomTaskQueue>(taskQueue);
  globalContainer.provideValue<BloomRecurringRegistry>(recurringRegistry);

  // Register the "send_welcome_email" task handler
  taskRegistry.register('send_welcome_email', (payload) async {
    final email = payload['email'] as String? ?? 'user@example.com';
    final name = payload['name'] as String? ?? 'User';

    final message = BloomMailMessage.single(
      to: email,
      from: 'welcome@bloomtodo.local',
      subject: 'Welcome to Bloom Todo!',
      body: 'Hello $name, welcome to the fullstack Bloom Todo application!',
      htmlBody: '<h1>Welcome, $name!</h1><p>Welcome to Bloom Todo powered by Bloom framework.</p>',
    );

    await mailBackend.send(message);
    stdout.writeln('Processed welcome email background job for $name <$email>');
  });

  // Start background worker
  final jobWorker = BloomJobWorker(
    queue: taskQueue,
    registry: taskRegistry,
    recurringRegistry: recurringRegistry,
  ).withPollInterval(const Duration(milliseconds: 500));

  // Run worker loop in background
  unawaited(jobWorker.run());

  // ---------------------------------------------------------------------------
  // 7. File Storage Subsystem via bloom_storage (LocalDiskBackend)
  // ---------------------------------------------------------------------------
  final storageBackend = LocalDiskBackend(
    baseDirectory: storagePath,
    publicUrlPrefix: 'http://127.0.0.1:$serverPort/api/files',
  );
  BloomStorage.register(storageBackend);
  globalContainer.provideValue<BloomStorageBackend>(storageBackend);

  // ---------------------------------------------------------------------------
  // 8. Real-time Pub/Sub & Presence Hub via bloom_realtime
  // ---------------------------------------------------------------------------
  final realtimeHub = BloomChannelHub();
  globalContainer.provideValue<BloomChannelHub>(realtimeHub);

  // ---------------------------------------------------------------------------
  // 9. Internationalization (i18n / l10n) via bloom_i18n
  // ---------------------------------------------------------------------------
  final locales = BloomLocales(defaultLocale: 'en-US');
  locales.addLocale('en-US', {
    'welcome': 'Welcome to Bloom Todo backend!',
    'task_count': '{count, plural, =0 {No tasks remaining} =1 {1 task remaining} other {# tasks remaining}}',
    'list_created': 'Todo list "{name}" was successfully created.',
  });
  locales.addLocale('es-ES', {
    'welcome': '¡Bienvenido al backend de Bloom Todo!',
    'task_count': '{count, plural, =0 {No quedan tareas} =1 {1 tarea restante} other {# tareas restantes}}',
    'list_created': 'La lista de tareas "{name}" fue creada exitosamente.',
  });
  globalContainer.provideValue<BloomLocales>(locales);

  // ---------------------------------------------------------------------------
  // 10. API Router & Outermost Middlewares Pipeline
  // ---------------------------------------------------------------------------
  final router = BloomApiRouter();

  // MIDDLEWARE ORDER (OUTERMOST FIRST):
  // 1. bloom_errors: Catches and normalizes all unhandled exceptions
  router.use(const BloomErrorMiddleware());

  // 2. bloom_security: Rate limiting (IP sliding window: 120 req / min)
  router.use(BloomRateLimitMiddleware(
    maxRequests: 120,
    window: const Duration(minutes: 1),
    whitelist: {'127.0.0.1'},
  ));

  // 3. bloom_security: Security headers (nosniff, DENY frame, etc.)
  router.use(const BloomSecurityHeadersMiddleware());

  // 4. bloom_security: CORS handling (permissive for dev clients)
  router.use(BloomAdvancedCorsMiddleware.permissive());

  // 5. bloom_i18n: Accept-Language and ?locale= resolver
  router.use(BloomLocaleMiddleware(
    defaultLocale: 'en-US',
    supportedLocales: const ['en-US', 'es-ES'],
    locales: locales,
  ));

  // ---------------------------------------------------------------------------
  // 11. Admin Panel via bloom_admin (Mounted at /admin)
  // ---------------------------------------------------------------------------
  final adminSite = BloomAdminSite()
      .withSiteHeader('Bloom Todo Administration')
      .withSiteTitle('Bloom Control Center');

  adminSite.register<User>(
    meta: User.meta,
    fromRow: User.fromRow,
    config: const BloomModelAdminConfig(
      listDisplay: ['id', 'email', 'name', 'createdAt'],
      searchFields: ['email', 'name'],
    ),
  );

  adminSite.register<TodoList>(
    meta: TodoList.meta,
    fromRow: TodoList.fromRow,
    config: const BloomModelAdminConfig(
      listDisplay: ['id', 'name', 'ownerId', 'createdAt'],
      searchFields: ['name'],
    ),
  );

  adminSite.register<TodoTask>(
    meta: TodoTask.meta,
    fromRow: TodoTask.fromRow,
    config: const BloomModelAdminConfig(
      listDisplay: ['id', 'listId', 'title', 'done', 'createdAt'],
      listFilter: ['done'],
      listEditable: ['title', 'done'],
    ),
  );

  adminSite.mount(router, db: db, basePath: '/admin');

  // ---------------------------------------------------------------------------
  // 12. Register All API Routes via urls.dart (Django-style central routing)
  // ---------------------------------------------------------------------------
  registerUrls(
    router,
    db: db,
    jobQueue: taskQueue,
    storageBackend: storageBackend,
    cache: cache,
    realtimeHub: realtimeHub,
    serverPort: serverPort,
  );

  // ---------------------------------------------------------------------------
  // 13. Start Server with Native WebSocket Upgrade Routing
  // ---------------------------------------------------------------------------
  final server = await router.serveWithWebSockets(
    port: serverPort,
    webSocketRoutes: {
      '/ws/realtime': (socket, request) {
        realtimeHub.registerConnection(socket);
      },
    },
  );

  stdout.writeln('===============================================================');
  stdout.writeln('  Bloom Todo Full-Stack Backend listening on port ${server.port}');
  stdout.writeln('  Admin Interface:  http://127.0.0.1:${server.port}/admin/');
  stdout.writeln('  Health Check:     http://127.0.0.1:${server.port}/api/health');
  stdout.writeln('  Realtime WS:      ws://127.0.0.1:${server.port}/ws/realtime');
  stdout.writeln('===============================================================');
}
