import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_cache/bloom_cache.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_i18n/bloom_i18n.dart';
import 'package:bloom_jobs/bloom_jobs.dart';
import 'package:bloom_realtime/bloom_realtime.dart';
import 'package:bloom_storage/bloom_storage.dart';
import 'views.dart';

/// Central route registration for the Bloom Todo backend, mirroring
/// Django's `urls.py`. Each route maps a path to a handler/ViewSet method
/// defined in `views.dart`, with auth middleware applied per-route.
void registerUrls(
  BloomApiRouter router, {
  required DbExecutor db,
  required BloomTaskQueue jobQueue,
  required BloomStorageBackend storageBackend,
  required BloomCache cache,
  required BloomChannelHub realtimeHub,
  required int serverPort,
}) {
  // ---------------------------------------------------------------------
  // System routes
  // ---------------------------------------------------------------------
  router.get('/api/health', (req) async {
    return BloomResponse.json({
      'status': 'healthy',
      'framework': 'Bloom 0.2.1',
      'locale': req.locale,
      'greeting': req.t('welcome'),
      'database': 'PostgreSQL connected',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  });

  // ---------------------------------------------------------------------
  // Auth routes
  // ---------------------------------------------------------------------
  final authHandlers = AuthApiHandlers(db: db, jobQueue: jobQueue);
  router.post('/api/auth/signup', authHandlers.handleSignup);
  router.post('/api/auth/login', authHandlers.handleLogin);
  router.get(
    '/api/auth/me',
    authHandlers.handleMe,
    middlewares: [const BloomAuthMiddleware()],
  );

  // ---------------------------------------------------------------------
  // File upload routes
  // ---------------------------------------------------------------------
  final uploadHandlers = UploadApiHandlers(storage: storageBackend);
  router.post(
    '/api/uploads/avatar',
    uploadHandlers.handleUploadAvatar,
    middlewares: [const BloomAuthMiddleware()],
  );
  router.get(
    '/api/uploads/signed-url',
    uploadHandlers.handleGetSignedUrl,
    middlewares: [const BloomAuthMiddleware()],
  );

  // Direct file serving for local storage
  router.get('/api/files/:path', (req) async {
    final filePath = req.params['path'];
    if (filePath == null || filePath.isEmpty) {
      throw BloomBadRequestException('Missing file path');
    }
    final bytes = await storageBackend.download(filePath);
    return BloomResponse(
      statusCode: 200,
      headers: {'content-type': 'application/octet-stream'},
      body: bytes as dynamic,
    );
  });

  // ---------------------------------------------------------------------
  // REST CRUD ViewSet routes
  // ---------------------------------------------------------------------
  final todoListViewSet = TodoListViewSet(
    getDb: (_) => db,
    cache: cache,
    realtimeHub: realtimeHub,
  );
  router.get('/api/lists', todoListViewSet.list, middlewares: [const BloomAuthMiddleware()]);
  router.post('/api/lists', todoListViewSet.create, middlewares: [const BloomAuthMiddleware()]);
  router.get('/api/lists/:pk', todoListViewSet.retrieve, middlewares: [const BloomAuthMiddleware()]);
  router.put('/api/lists/:pk', todoListViewSet.update, middlewares: [const BloomAuthMiddleware()]);
  router.patch('/api/lists/:pk', todoListViewSet.update, middlewares: [const BloomAuthMiddleware()]);
  router.delete('/api/lists/:pk', todoListViewSet.destroy, middlewares: [const BloomAuthMiddleware()]);

  final todoTaskViewSet = TodoTaskViewSet(
    getDb: (_) => db,
    cache: cache,
    realtimeHub: realtimeHub,
  );
  router.get('/api/tasks', todoTaskViewSet.list, middlewares: [const BloomAuthMiddleware()]);
  router.post('/api/tasks', todoTaskViewSet.create, middlewares: [const BloomAuthMiddleware()]);
  router.get('/api/tasks/:pk', todoTaskViewSet.retrieve, middlewares: [const BloomAuthMiddleware()]);
  router.put('/api/tasks/:pk', todoTaskViewSet.update, middlewares: [const BloomAuthMiddleware()]);
  router.patch('/api/tasks/:pk', todoTaskViewSet.update, middlewares: [const BloomAuthMiddleware()]);
  router.delete('/api/tasks/:pk', todoTaskViewSet.destroy, middlewares: [const BloomAuthMiddleware()]);
}
