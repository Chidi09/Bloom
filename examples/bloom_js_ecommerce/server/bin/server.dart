import 'dart:io';
import 'package:bloom_server/bloom_server.dart';

// Database & Migrations
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_migrate/bloom_migrate.dart';

// Errors & Security
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_security/bloom_security.dart';

// Domain routing
import '../lib/urls.dart';

Future<void> main(List<String> args) async {
  // ---------------------------------------------------------------------------
  // 1. Environment Configuration via BloomEnv
  // ---------------------------------------------------------------------------
  final envFile = File('.env');
  if (envFile.existsSync()) {
    BloomEnv.loadContent(envFile.readAsStringSync());
  }

  BloomEnv.loadMap({
    'DB_HOST': BloomEnv.getOrNull('DB_HOST') ?? '127.0.0.1',
    'DB_PORT': BloomEnv.getOrNull('DB_PORT') ?? '5432',
    'DB_USER': BloomEnv.getOrNull('DB_USER') ?? 'postgres',
    'DB_PASSWORD': BloomEnv.getOrNull('DB_PASSWORD') ?? 'postgres',
    'DB_NAME': BloomEnv.getOrNull('DB_NAME') ?? 'bloom_ecommerce',
    'BLOOM_AUTH_SECRET': BloomEnv.getOrNull('BLOOM_AUTH_SECRET') ??
        'bloom-super-secure-jwt-signing-secret-key-32chars',
    'APP_ENV': BloomEnv.getOrNull('APP_ENV') ?? 'local',
    'PORT': BloomEnv.getOrNull('PORT') ?? '8080',
  }, overwrite: false);

  final dbHost = BloomEnv.get('DB_HOST');
  final dbPort = BloomEnv.getInt('DB_PORT', defaultValue: 5432);
  final dbUser = BloomEnv.get('DB_USER');
  final dbPass = BloomEnv.get('DB_PASSWORD');
  final dbName = BloomEnv.get('DB_NAME');
  final serverPort = BloomEnv.getInt('PORT', defaultValue: 8080);

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
  // 4. API Router & Middleware Pipeline
  // ---------------------------------------------------------------------------
  final router = BloomApiRouter();

  // MIDDLEWARE ORDER (OUTERMOST FIRST):
  // 1. bloom_security: CORS handling (permissive for the bloom_js_native dev client).
  //    Must be outermost: BloomAdvancedCorsMiddleware only decorates the response
  //    it gets back from `next()` — it has no catch of its own. If an inner
  //    middleware/handler throws, that response only exists after
  //    BloomErrorMiddleware converts the exception, so CORS has to sit outside
  //    BloomErrorMiddleware to see (and decorate) that converted response too;
  //    otherwise every error response (4xx/5xx) leaves without CORS headers and
  //    the browser blocks it before the client ever sees the real error body.
  router.use(BloomAdvancedCorsMiddleware.permissive());

  // 2. bloom_errors: Catches and normalizes all unhandled exceptions
  router.use(const BloomErrorMiddleware());

  // 3. bloom_security: Rate limiting (IP sliding window: 120 req / min)
  router.use(BloomRateLimitMiddleware(
    maxRequests: 120,
    window: const Duration(minutes: 1),
    whitelist: {'127.0.0.1'},
  ));

  // 4. bloom_security: Security headers (nosniff, DENY frame, etc.)
  router.use(const BloomSecurityHeadersMiddleware());

  // ---------------------------------------------------------------------------
  // 5. Register All API Routes via urls.dart (Django-style central routing)
  // ---------------------------------------------------------------------------
  registerUrls(router, db: db);

  // ---------------------------------------------------------------------------
  // 6. Start Server — plain HTTP serve(), no WebSocket/realtime feature here.
  // ---------------------------------------------------------------------------
  final server = await router.serve(port: serverPort);

  stdout.writeln('===============================================================');
  stdout.writeln('  Bloom E-Commerce Backend listening on port ${server.port}');
  stdout.writeln('  Health Check: http://127.0.0.1:${server.port}/api/health');
  stdout.writeln('===============================================================');
}
