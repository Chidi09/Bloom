// lib/src/web/ssr_engine.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';

class DiscoveredApiRoute {
  final String path;
  final String relativeFilePath;
  final bool hasGet;
  final bool hasPost;
  final bool hasPut;
  final bool hasDelete;
  final bool hasPatch;

  DiscoveredApiRoute({
    required this.path,
    required this.relativeFilePath,
    this.hasGet = true,
    this.hasPost = false,
    this.hasPut = false,
    this.hasDelete = false,
    this.hasPatch = false,
  });
}

class DiscoveredPageRoute {
  final String path;
  final String relativeFilePath;
  final String? declaredTitle;
  final String? declaredDescription;

  DiscoveredPageRoute({
    required this.path,
    required this.relativeFilePath,
    this.declaredTitle,
    this.declaredDescription,
  });
}

/// Server-Side Rendering (SSR) & API Router Bundle Engine for Bloom.
///
/// Emits executable Dart server (`build/server.dart`) handling API endpoints and dynamic SSR HTML.
class BloomSsrEngine {
  final BloomProject project;
  final Directory outputDir;

  BloomSsrEngine({
    required this.project,
    Directory? outputDir,
  }) : outputDir = outputDir ?? Directory(p.join(project.rootDir.path, 'build'));

  /// Discovers all API routes in `lib/routes/api/`.
  List<DiscoveredApiRoute> discoverApiRoutes() {
    final apiDir = Directory(p.join(project.rootDir.path, 'lib', 'routes', 'api'));
    if (!apiDir.existsSync()) return [];

    final routes = <DiscoveredApiRoute>[];
    final files = apiDir.listSync(recursive: true).whereType<File>();

    final methodRegex = RegExp(r'(FutureOr<BloomResponse>|Future<BloomResponse>|BloomResponse)\s+(get|post|put|delete|patch)\s*\(');

    for (final file in files) {
      if (!file.path.endsWith('.dart')) continue;
      final relPath = p.relative(file.path, from: apiDir.path);
      if (p.basename(relPath).startsWith('_')) continue; // Skip middleware files

      var routePath = relPath.replaceAll('.dart', '');
      if (routePath == 'index' || routePath.endsWith('/index')) {
        routePath = routePath.replaceAll(RegExp(r'/?index$'), '');
      }

      // Convert [param] to :param for router matching
      routePath = routePath.replaceAllMapped(RegExp(r'\[(.*?)\]'), (m) => ':${m.group(1)}');
      if (!routePath.startsWith('/')) {
        routePath = '/$routePath';
      }

      final fullApiPath = '/api$routePath';
      final content = file.readAsStringSync();
      final matches = methodRegex.allMatches(content).map((m) => m.group(2)!.toLowerCase()).toSet();

      // Fallback detection for simpler definitions like `get(BloomRequest req)`
      final hasGet = matches.contains('get') || content.contains('get(BloomRequest') || content.contains('get(request');
      final hasPost = matches.contains('post') || content.contains('post(BloomRequest') || content.contains('post(request');
      final hasPut = matches.contains('put') || content.contains('put(BloomRequest') || content.contains('put(request');
      final hasDelete = matches.contains('delete') || content.contains('delete(BloomRequest') || content.contains('delete(request');
      final hasPatch = matches.contains('patch') || content.contains('patch(BloomRequest') || content.contains('patch(request');

      routes.add(DiscoveredApiRoute(
        path: fullApiPath,
        relativeFilePath: relPath,
        hasGet: hasGet || (!hasPost && !hasPut && !hasDelete && !hasPatch),
        hasPost: hasPost,
        hasPut: hasPut,
        hasDelete: hasDelete,
        hasPatch: hasPatch,
      ));
    }

    routes.sort((a, b) => a.path.compareTo(b.path));
    return routes;
  }

  /// Discovers client page routes for SSR rendering.
  List<DiscoveredPageRoute> discoverPageRoutes() {
    final routesDir = Directory(p.join(project.rootDir.path, 'lib', 'routes'));
    if (!routesDir.existsSync()) return [];

    final pageRoutes = <DiscoveredPageRoute>[];
    final files = routesDir.listSync(recursive: true).whereType<File>();

    for (final file in files) {
      if (!file.path.endsWith('.dart')) continue;
      final relPath = p.relative(file.path, from: routesDir.path);
      if (relPath.startsWith('api') || relPath.endsWith('.g.dart') || p.basename(relPath).startsWith('_')) {
        continue;
      }

      var routePath = relPath.replaceAll('.dart', '');
      if (routePath == 'index' || routePath.endsWith('/index')) {
        routePath = routePath.replaceAll(RegExp(r'/?index$'), '');
      }
      routePath = routePath.replaceAllMapped(RegExp(r'\[(.*?)\]'), (m) => ':${m.group(1)}');
      if (!routePath.startsWith('/')) {
        routePath = '/$routePath';
      }

      final content = file.readAsStringSync();
      final titleMatch = RegExp(r'''title\s*[:=]\s*['"](.*?)['"]''').firstMatch(content);
      final descMatch = RegExp(r'''description\s*[:=]\s*['"](.*?)['"]''').firstMatch(content);

      pageRoutes.add(DiscoveredPageRoute(
        path: routePath.isEmpty ? '/' : routePath,
        relativeFilePath: relPath,
        declaredTitle: titleMatch?.group(1),
        declaredDescription: descMatch?.group(1),
      ));
    }

    return pageRoutes;
  }

  /// Generates the standalone SSR and API server file (`build/server.dart`).
  Future<File> generate() async {
    print(Ansi.boldText('\n🖥️  Building Bloom Full-Stack SSR & API Server...'));

    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final apiRoutes = discoverApiRoutes();
    final pageRoutes = discoverPageRoutes();
    print('› Discovered ${apiRoutes.length} backend API endpoint(s) and ${pageRoutes.length} SSR page route(s).');

    final serverFile = File(p.join(outputDir.path, 'server.dart'));
    final code = _generateServerDartCode(apiRoutes, pageRoutes);
    serverFile.writeAsStringSync(code);

    print(Ansi.success('✔ Server bundle generated: ${serverFile.path}\n'));
    return serverFile;
  }

  String _generateServerDartCode(List<DiscoveredApiRoute> apiRoutes, List<DiscoveredPageRoute> pageRoutes) {
    final config = project.loadBloomConfig();
    final appName = config['name']?.toString() ?? 'Bloom App';

    final buffer = StringBuffer();
    buffer.writeln('// AUTO-GENERATED BY BLOOM CLI. DO NOT EDIT.');
    buffer.writeln('// Standalone Server-Side Rendering (SSR) & API Route Runtime Server.');
    buffer.writeln();
    buffer.writeln("import 'dart:convert';");
    buffer.writeln("import 'dart:io';");
    buffer.writeln("import 'dart:typed_data';");
    buffer.writeln("import 'package:path/path.dart' as p;");
    buffer.writeln("import 'package:bloom_framework/bloom_server.dart';");
    buffer.writeln();

    // Import API route files
    for (var i = 0; i < apiRoutes.length; i++) {
      final r = apiRoutes[i];
      final importPath = '../lib/routes/api/${r.relativeFilePath.replaceAll(r'\', '/')}';
      buffer.writeln("import '$importPath' as api_route_$i;");
    }
    buffer.writeln();

    buffer.writeln('Future<void> main(List<String> args) async {');
    buffer.writeln("  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;");
    buffer.writeln('  final router = BloomApiRouter();');
    buffer.writeln('  router.use(BloomCorsMiddleware());');
    buffer.writeln();

    // Register API endpoints
    buffer.writeln('  // Registered API Routes');
    for (var i = 0; i < apiRoutes.length; i++) {
      final r = apiRoutes[i];
      if (r.hasGet) {
        buffer.writeln("  router.get('${r.path}', (req) => api_route_$i.get(req));");
      }
      if (r.hasPost) {
        buffer.writeln("  router.post('${r.path}', (req) => api_route_$i.post(req));");
      }
      if (r.hasPut) {
        buffer.writeln("  router.put('${r.path}', (req) => api_route_$i.put(req));");
      }
      if (r.hasDelete) {
        buffer.writeln("  router.delete('${r.path}', (req) => api_route_$i.delete(req));");
      }
      if (r.hasPatch) {
        buffer.writeln("  router.patch('${r.path}', (req) => api_route_$i.patch(req));");
      }
    }
    buffer.writeln();

    // Register Dynamic SSR Page Renderers
    buffer.writeln('  // Server-Side Rendered (SSR) Dynamic Page Handlers');
    for (final page in pageRoutes) {
      final defaultTitle = page.declaredTitle ?? '$appName - ${page.path == "/" ? "Home" : page.path}';
      final defaultDesc = page.declaredDescription ?? 'Dynamic server rendered content for ${page.path}';
      buffer.writeln("  router.get('${page.path}', (req) async {");
      buffer.writeln("    return BloomResponse.html(_renderDynamicSsrHtml(");
      buffer.writeln("      appTitle: '$appName',");
      buffer.writeln("      pageTitle: '$defaultTitle',");
      buffer.writeln("      description: '$defaultDesc',");
      buffer.writeln("      routePath: req.path,");
      buffer.writeln("      params: req.params,");
      buffer.writeln("    ));");
      buffer.writeln("  });");
    }
    buffer.writeln();

    // Catch-all Static File Server & Fallback Handler with Path Traversal Guard
    buffer.writeln('''
  // Catch-all Static Asset Handler & Fallback
  router.all('*', (req) async {
    final webDir = Directory('build/web');
    if (webDir.existsSync()) {
      final requestedPath = req.path.startsWith('/') ? req.path.substring(1) : req.path;
      final targetPath = p.canonicalize(p.join(webDir.path, requestedPath));

      // Path-traversal security guard
      if (p.isWithin(webDir.path, targetPath) || targetPath == p.canonicalize(webDir.path)) {
        final staticFile = File(targetPath);
        if (staticFile.existsSync() && !FileSystemEntity.isDirectorySync(staticFile.path)) {
          final bytes = staticFile.readAsBytesSync();
          final ext = staticFile.path.split('.').last.toLowerCase();
          final contentType = _getContentType(ext);
          return BloomResponse(
            statusCode: 200,
            headers: {'content-type': contentType},
            body: Uint8List.fromList(bytes),
          );
        }

        final indexFile = File(p.join(webDir.path, 'index.html'));
        if (indexFile.existsSync()) {
          return BloomResponse.html(indexFile.readAsStringSync());
        }
      }
    }

    return BloomResponse.html(_renderDynamicSsrHtml(
      appTitle: '$appName',
      pageTitle: '$appName',
      description: 'Bloom Full-Stack Server',
      routePath: req.path,
      params: req.params,
    ));
  });

  final server = await router.serve(port: port);
  print('🚀 Bloom Full-Stack Server listening on http://localhost:\$port');
}

String _renderDynamicSsrHtml({
  required String appTitle,
  required String pageTitle,
  required String description,
  required String routePath,
  required Map<String, String> params,
}) {
  final segments = routePath.split('/').where((s) => s.isNotEmpty).toList();
  final headerDisplay = segments.isEmpty ? 'Home' : segments.map((s) => s[0].toUpperCase() + s.substring(1)).join(' / ');
  final safeTitle = pageTitle.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  final safeDesc = description.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  return """
<!DOCTYPE html>
<html lang="en">
<head>
  <base href="/" />
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>\$safeTitle</title>
  <meta name="description" content="\$safeDesc" />
  <meta property="og:title" content="\$safeTitle" />
  <meta property="og:description" content="\$safeDesc" />
  <meta property="og:type" content="website" />
  <meta name="twitter:card" content="summary_large_image" />
  <link rel="manifest" href="/manifest.json" />
  <link rel="apple-touch-icon" href="/icons/Icon-192.png" />
  <meta name="theme-color" content="#10B981" />
  <style>
    body { margin: 0; padding: 0; background-color: #FAFAFA; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; color: #1F2937; }
    #bloom-app-root { min-height: 100vh; display: flex; flex-direction: column; }
    .bloom-ssr-header { padding: 1.5rem 2rem; background: #FFFFFF; border-bottom: 1px solid #E5E7EB; display: flex; align-items: center; justify-content: space-between; }
    .bloom-brand { font-size: 1.25rem; font-weight: 700; color: #111827; }
    .bloom-ssr-main { flex: 1; max-width: 960px; margin: 2rem auto; padding: 0 1.5rem; width: 100%; box-sizing: border-box; }
    .bloom-page-title { font-size: 2rem; font-weight: 800; margin-bottom: 0.5rem; }
    .bloom-page-desc { font-size: 1.125rem; color: #4B5563; line-height: 1.6; }
    .bloom-badge { margin-top: 1.5rem; display: inline-block; padding: 0.5rem 1rem; background: #ECFDF5; border: 1px solid #A7F3D0; border-radius: 9999px; color: #065F46; font-weight: 600; font-size: 0.875rem; }
  </style>
</head>
<body>
  <div id="bloom-app-root">
    <header class="bloom-ssr-header">
      <div class="bloom-brand">\$appTitle</div>
    </header>
    <main class="bloom-ssr-main">
      <h1 class="bloom-page-title">\$headerDisplay</h1>
      <p class="bloom-page-desc">\$safeDesc</p>
      <div class="bloom-badge">🖥️ Dynamic SSR Hydration Active</div>
    </main>
  </div>
  <script>
    window.__BLOOM_SSR_ROUTE__ = "\$routePath";
    window.__BLOOM_SSR_PARAMS__ = \${jsonEncode(params)};
  </script>
  <script src="flutter.js" defer></script>
</body>
</html>
""".trim();
}

String _getContentType(String extension) {
  switch (extension) {
    case 'html': return 'text/html; charset=utf-8';
    case 'js': return 'application/javascript; charset=utf-8';
    case 'css': return 'text/css; charset=utf-8';
    case 'json': return 'application/json; charset=utf-8';
    case 'png': return 'image/png';
    case 'jpg':
    case 'jpeg': return 'image/jpeg';
    case 'svg': return 'image/svg+xml';
    default: return 'application/octet-stream';
  }
}
''');

    return buffer.toString();
  }
}
