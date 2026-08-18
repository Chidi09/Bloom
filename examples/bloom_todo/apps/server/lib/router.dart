import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_security/bloom_security.dart';

import 'ssr_landing.dart';
import 'apps/auth/urls.dart' as auth_urls;
import 'apps/comments/urls.dart' as comments_urls;
import 'apps/notifications/urls.dart' as notifications_urls;
import 'apps/projects/urls.dart' as projects_urls;
import 'apps/search/urls.dart' as search_urls;
import 'apps/sections/urls.dart' as sections_urls;
import 'apps/tasks/urls.dart' as tasks_urls;
import 'apps/workspaces/urls.dart' as workspaces_urls;
import 'apps/labels/urls.dart' as labels_urls;

/// Wire up the top-level [BloomApiRouter] with every sub-application's routes,
/// pure SSR landing page, auto-generated Swagger & Scalar docs, and web client assets.
void registerUrls(BloomApiRouter router) {
  // ── Global middleware ─────────────────────────────────────────────────────
  router.use(BloomAdvancedCorsMiddleware.permissive());
  router.use(
    const BloomSecurityHeadersMiddleware(
      contentSecurityPolicy:
          "default-src 'self'; "
          "img-src 'self' data: https:; "
          "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://unpkg.com https://cdn.jsdelivr.net; "
          "style-src 'self' 'unsafe-inline' https://unpkg.com https://cdn.jsdelivr.net https://fonts.googleapis.com; "
          "font-src 'self' data: https://fonts.gstatic.com; "
          "object-src 'none'; "
          "base-uri 'self'; "
          "connect-src 'self' https: http:;",
    ),
  );
  router.use(
    BloomRateLimitMiddleware(
      maxRequests: 300,
      window: const Duration(minutes: 1),
    ),
  );

  // ── Native Pure SSR Landing Page (0ms, 0kB JS baseline) ───────────────────
  router.get('/', (BloomRequest req) async {
    return BloomResponse.html(renderLandingHtml());
  });

  // ── Auto-Generated Swagger UI & OpenAPI 3.1 Documentation ─────────────────
  router.enableOpenApi(
    title: 'Bloom Todo API',
    version: '1.0.0',
    description: 'Production REST API for Bloom Todoist-grade full-stack task manager.',
  );

  // ── Health check ──────────────────────────────────────────────────────────
  router.get('/api/health', (BloomRequest req) async {
    return BloomResponse.json({
      'status': 'healthy',
      'engine': 'bloom_realtime_aot',
      'version': '1.0.0',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  });

  // ── Sub-application API routes ────────────────────────────────────────────
  auth_urls.registerUrls(router, prefix: '/api/auth');
  workspaces_urls.registerUrls(router, prefix: '/api/workspaces');
  projects_urls.registerUrls(router, prefix: '/api/projects');
  sections_urls.registerUrls(router, prefix: '/api/sections');
  tasks_urls.registerUrls(router, prefix: '/api/tasks');
  labels_urls.registerUrls(router, prefix: '/api/labels');
  comments_urls.registerUrls(router, prefix: '/api/comments');
  notifications_urls.registerUrls(router, prefix: '/api/notifications');
  search_urls.registerUrls(router, prefix: '/api/search');

  // ── Interactive Web App Client Route & Static Asset Fallbacks ─────────────
  final webBuildDir = Directory(p.join(Directory.current.path, 'apps', 'web', 'build', 'web'));

  router.get('/app', (BloomRequest req) async {
    final indexFile = File(p.join(webBuildDir.path, 'index.html'));
    if (indexFile.existsSync()) {
      return BloomResponse.html(indexFile.readAsStringSync());
    }
    return BloomResponse.html(renderLandingHtml());
  });

  // Static Assets (flutter.js, main.dart.js, canvaskit, icons, etc.)
  for (final filename in ['flutter.js', 'main.dart.js', 'flutter_service_worker.js', 'manifest.json', 'version.json']) {
    router.get('/$filename', (BloomRequest req) async {
      final file = File(p.join(webBuildDir.path, filename));
      if (file.existsSync()) {
        final ext = p.extension(filename).replaceAll('.', '');
        final contentType = switch (ext) {
          'js' => 'application/javascript; charset=utf-8',
          'json' => 'application/json; charset=utf-8',
          _ => 'text/plain',
        };
        return BloomResponse(
          statusCode: 200,
          headers: {'content-type': contentType},
          body: file.readAsBytesSync(),
        );
      }
      return BloomResponse(statusCode: 404);
    });
  }
}
