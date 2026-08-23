// lib/src/web/ssr_engine.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../deployment/proxy_config_loader.dart';
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
  final bool hasLoader;
  final String? loaderFunctionName;
  final Duration? revalidate;
  final bool hasAction;
  final String? actionFunctionName;

  DiscoveredPageRoute({
    required this.path,
    required this.relativeFilePath,
    this.declaredTitle,
    this.declaredDescription,
    this.hasLoader = false,
    this.loaderFunctionName,
    this.revalidate,
    this.hasAction = false,
    this.actionFunctionName,
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

      // Detect @BloomLoader or loader function
      final loaderMatch = RegExp(r'''(@BloomLoader(?:\s*\([\s\S]*?\))?\s+)?(Future<.*?>|FutureOr<.*?>)\s+([a-zA-Z0-9_]+)\s*\(\s*BloomRouteContext''').firstMatch(content);
      final hasLoader = loaderMatch != null;
      final loaderFunctionName = loaderMatch?.group(3);

      Duration? revalidate;
      if (hasLoader) {
        final revalidateMatch = RegExp(
          r'''@BloomLoader\s*\(\s*revalidate\s*:\s*(?:const\s+)?Duration\s*\(\s*(seconds|minutes|hours|days)\s*:\s*(\d+)\s*,?\s*\)\s*,?\s*\)''',
          multiLine: true,
        ).firstMatch(content);
        if (revalidateMatch != null) {
          final unit = revalidateMatch.group(1);
          final value = int.tryParse(revalidateMatch.group(2) ?? '');
          if (value != null && value >= 0) {
            switch (unit) {
              case 'seconds':
                revalidate = Duration(seconds: value);
                break;
              case 'minutes':
                revalidate = Duration(minutes: value);
                break;
              case 'hours':
                revalidate = Duration(hours: value);
                break;
              case 'days':
                revalidate = Duration(days: value);
                break;
            }
          }
        }
      }

      // Detect @BloomAction or action handler
      final actionMatch = RegExp(r'''(@BloomAction\s*\(\s*\)\s+)?(Future<.*?>|FutureOr<.*?>)\s+([a-zA-Z0-9_]+)\s*\(\s*BloomRouteContext.*?,.*?Map''').firstMatch(content);
      final hasAction = actionMatch != null;
      final actionFunctionName = actionMatch?.group(3);

      pageRoutes.add(DiscoveredPageRoute(
        path: routePath.isEmpty ? '/' : routePath,
        relativeFilePath: relPath,
        declaredTitle: titleMatch?.group(1),
        declaredDescription: descMatch?.group(1),
        hasLoader: hasLoader,
        loaderFunctionName: loaderFunctionName,
        revalidate: revalidate,
        hasAction: hasAction,
        actionFunctionName: actionFunctionName,
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
    final proxyRules = loadProxyRules(config);
    final appName = config['name']?.toString() ?? 'Bloom App';
    final pwaConfig = (config['web'] is Map && config['web']['pwa'] is Map)
        ? (config['web']['pwa'] as Map)
        : <dynamic, dynamic>{};
    final themeColor = pwaConfig['theme_color']?.toString() ?? '#10B981';

    final buffer = StringBuffer();
    buffer.writeln('// AUTO-GENERATED BY BLOOM CLI. DO NOT EDIT.');
    buffer.writeln('// Standalone Server-Side Rendering (SSR) & API Route Runtime Server.');
    buffer.writeln();
    buffer.writeln("import 'dart:convert';");
    buffer.writeln("import 'dart:io';");
    buffer.writeln("import 'dart:typed_data';");
    buffer.writeln("import 'package:path/path.dart' as p;");
    buffer.writeln("import 'package:bloom_framework/bloom.dart';");
    buffer.writeln("import 'package:bloom_framework/bloom_server.dart';");
    buffer.writeln("import 'package:bloom_cli/src/web/prerender_engine.dart';");
    buffer.writeln("import 'package:bloom_cli/src/assets/image_transformer.dart' as bloom_img;");
    buffer.writeln("import 'package:bloom_cli/src/assets/image_variant_cache.dart' as bloom_img_cache;");
    buffer.writeln();

    // Import API route files
    for (var i = 0; i < apiRoutes.length; i++) {
      final r = apiRoutes[i];
      final importPath = '../lib/routes/api/${r.relativeFilePath.replaceAll(r'\', '/')}';
      buffer.writeln("import '$importPath' as api_route_$i;");
    }

    // Import page routes with loaders or actions
    for (var i = 0; i < pageRoutes.length; i++) {
      final pRoute = pageRoutes[i];
      if (pRoute.hasLoader || pRoute.hasAction) {
        final importPath = '../lib/routes/${pRoute.relativeFilePath.replaceAll(r'\', '/')}';
        buffer.writeln("import '$importPath' as page_route_$i;");
      }
    }
    buffer.writeln();

    if (proxyRules.isNotEmpty) {
      buffer.writeln('class _BloomServerProxyRule {');
      buffer.writeln('  final String pathPrefix;');
      buffer.writeln('  final String targetUrl;');
      buffer.writeln('  final bool stripPrefix;');
      buffer.writeln();
      buffer.writeln('  const _BloomServerProxyRule({');
      buffer.writeln('    required this.pathPrefix,');
      buffer.writeln('    required this.targetUrl,');
      buffer.writeln('    required this.stripPrefix,');
      buffer.writeln('  });');
      buffer.writeln('}');
      buffer.writeln();
    }

    buffer.writeln('class _IsrCacheEntry {');
    buffer.writeln('  final String html;');
    buffer.writeln('  final DateTime generatedAt;');
    buffer.writeln('  bool _isRevalidating = false;');
    buffer.writeln();
    buffer.writeln('  _IsrCacheEntry(this.html, this.generatedAt);');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('final Map<String, _IsrCacheEntry> _isrCache = {};');
    buffer.writeln();

    buffer.writeln('Future<void> main(List<String> args) async {');
    buffer.writeln("  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;");
    buffer.writeln('  final router = BloomApiRouter();');
    buffer.writeln('  router.use(BloomCorsMiddleware());');
    buffer.writeln();
    buffer.writeln('  // Reuse a single headless Chromium instance across all SSR requests.');
    buffer.writeln('  // Launched once at startup to avoid per-request process spawn overhead.');
    buffer.writeln('  final _prerenderEngine = BloomPrerenderEngine();');
    buffer.writeln("  await _prerenderEngine.startWithExistingServer('http://localhost:\$port');");
    buffer.writeln();

    // Register neutral internal shell endpoint FIRST
    buffer.writeln('  // Neutral internal shell endpoint for headless-browser prerendering');
    buffer.writeln("  router.get('/__bloom_shell', (req) async {");
    buffer.writeln("    final indexFile = File('build/web/index.html');");
    buffer.writeln("    if (!indexFile.existsSync()) {");
    buffer.writeln("      return BloomResponse.html('<!DOCTYPE html><html><head></head><body><div id=\"bloom-app-root\"></div></body></html>');");
    buffer.writeln("    }");
    buffer.writeln("    var html = indexFile.readAsStringSync();");
    buffer.writeln("    final bloomRoute = req.queryParams['__bloom_route'];");
    buffer.writeln("    if (bloomRoute != null && bloomRoute.isNotEmpty) {");
    buffer.writeln("      final scriptTag = '<script>window.__BLOOM_INITIAL_ROUTE__ = ' + jsonEncode(bloomRoute) + ';</script>';");
    buffer.writeln("      if (html.contains('</head>')) {");
    buffer.writeln("        html = html.replaceFirst('</head>', scriptTag + '</head>');");
    buffer.writeln("      } else {");
    buffer.writeln("        html = scriptTag + html;");
    buffer.writeln("      }");
    buffer.writeln("    }");
    buffer.writeln("    return BloomResponse.html(html);");
    buffer.writeln("  });");
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

    // Register Reverse Proxy Endpoints before Dynamic SSR Page Renderers
    if (proxyRules.isNotEmpty) {
      buffer.writeln('  // Registered Reverse Proxy Endpoints');
      for (final rule in proxyRules) {
        final prefix = rule.pathPrefix.endsWith('/') && rule.pathPrefix.length > 1
            ? rule.pathPrefix.substring(0, rule.pathPrefix.length - 1)
            : rule.pathPrefix;
        final cleanPrefix = prefix.startsWith('/') ? prefix : '/$prefix';
        if (cleanPrefix == '/') {
          buffer.writeln(
            "  router.all('/*', (req) => _forwardProxyRequest(req, const _BloomServerProxyRule(pathPrefix: ${jsonEncode(rule.pathPrefix)}, targetUrl: ${jsonEncode(rule.targetUri.toString())}, stripPrefix: ${rule.stripPrefix})));",
          );
        } else {
          buffer.writeln(
            "  router.all('$cleanPrefix', (req) => _forwardProxyRequest(req, const _BloomServerProxyRule(pathPrefix: ${jsonEncode(rule.pathPrefix)}, targetUrl: ${jsonEncode(rule.targetUri.toString())}, stripPrefix: ${rule.stripPrefix})));",
          );
          buffer.writeln(
            "  router.all('$cleanPrefix/*', (req) => _forwardProxyRequest(req, const _BloomServerProxyRule(pathPrefix: ${jsonEncode(rule.pathPrefix)}, targetUrl: ${jsonEncode(rule.targetUri.toString())}, stripPrefix: ${rule.stripPrefix})));",
          );
        }
      }
      buffer.writeln();
    }

    // Register Dynamic SSR Page Renderers
    buffer.writeln('  // Server-Side Rendered (SSR) Dynamic Page Handlers');
    for (var i = 0; i < pageRoutes.length; i++) {
      final page = pageRoutes[i];
      final defaultTitle = page.declaredTitle ?? '$appName - ${page.path == "/" ? "Home" : page.path}';
      final defaultDesc = page.declaredDescription ?? 'Dynamic server rendered content for ${page.path}';

      buffer.writeln("  router.get('${page.path}', (req) async {");
      if (page.hasLoader && page.loaderFunctionName != null) {
        if (page.revalidate != null) {
          final revalidateSeconds = page.revalidate!.inSeconds;
          buffer.writeln("    final cacheKey = req.path;");
          buffer.writeln("    final cached = _isrCache[cacheKey];");
          buffer.writeln("    if (cached != null) {");
          buffer.writeln("      if (DateTime.now().difference(cached.generatedAt) < Duration(seconds: $revalidateSeconds)) {");
          buffer.writeln("        return BloomResponse.html(cached.html);");
          buffer.writeln("      }");
          buffer.writeln("      if (!cached._isRevalidating) {");
          buffer.writeln("        cached._isRevalidating = true;");
          buffer.writeln("        () async {");
          buffer.writeln("          try {");
          buffer.writeln("            final ctx = BloomRouteContext(params: req.params, queryParams: req.queryParams, url: req.uri);");
          buffer.writeln("            final dynamic loaderData = await page_route_$i.${page.loaderFunctionName}(ctx);");
          buffer.writeln("            String? prerendered;");
          buffer.writeln("            try {");
          buffer.writeln("              prerendered = await _prerenderEngine.renderRoute('/__bloom_shell?__bloom_route=' + Uri.encodeComponent(req.path));");
          buffer.writeln("            } catch (_) {}");
          buffer.writeln("            final html = _renderDynamicSsrHtml(");
          buffer.writeln("              appTitle: '$appName',");
          buffer.writeln("              pageTitle: '$defaultTitle',");
          buffer.writeln("              description: '$defaultDesc',");
          buffer.writeln("              routePath: req.path,");
          buffer.writeln("              params: req.params,");
          buffer.writeln("              themeColor: '$themeColor',");
          buffer.writeln("              loaderData: loaderData,");
          buffer.writeln("              prerenderedBodyHtml: prerendered,");
          buffer.writeln("            );");
          buffer.writeln("            _isrCache[cacheKey] = _IsrCacheEntry(html, DateTime.now());");
          buffer.writeln("          } catch (e) {");
          buffer.writeln("            print('ISR background regeneration error for \$cacheKey: \$e');");
          buffer.writeln("          } finally {");
          buffer.writeln("            cached._isRevalidating = false;");
          buffer.writeln("          }");
          buffer.writeln("        }();");
          buffer.writeln("      }");
          buffer.writeln("      return BloomResponse.html(cached.html);");
          buffer.writeln("    }");
          buffer.writeln();
          buffer.writeln("    final ctx = BloomRouteContext(params: req.params, queryParams: req.queryParams, url: req.uri);");
          buffer.writeln("    dynamic loaderData;");
          buffer.writeln("    try {");
          buffer.writeln("      loaderData = await page_route_$i.${page.loaderFunctionName}(ctx);");
          buffer.writeln("    } catch (e) {");
          buffer.writeln("      loaderData = {'error': e.toString()};");
          buffer.writeln("    }");
          buffer.writeln("    String? prerendered;");
          buffer.writeln("    try {");
          buffer.writeln("      prerendered = await _prerenderEngine.renderRoute('/__bloom_shell?__bloom_route=' + Uri.encodeComponent(req.path));");
          buffer.writeln("    } catch (_) {}");
          buffer.writeln("    final html = _renderDynamicSsrHtml(");
          buffer.writeln("      appTitle: '$appName',");
          buffer.writeln("      pageTitle: '$defaultTitle',");
          buffer.writeln("      description: '$defaultDesc',");
          buffer.writeln("      routePath: req.path,");
          buffer.writeln("      params: req.params,");
          buffer.writeln("      themeColor: '$themeColor',");
          buffer.writeln("      loaderData: loaderData,");
          buffer.writeln("      prerenderedBodyHtml: prerendered,");
          buffer.writeln("    );");
          buffer.writeln("    _isrCache[cacheKey] = _IsrCacheEntry(html, DateTime.now());");
          buffer.writeln("    return BloomResponse.html(html);");
        } else {
          buffer.writeln("    final ctx = BloomRouteContext(params: req.params, queryParams: req.queryParams, url: req.uri);");
          buffer.writeln("    dynamic loaderData;");
          buffer.writeln("    try {");
          buffer.writeln("      loaderData = await page_route_$i.${page.loaderFunctionName}(ctx);");
          buffer.writeln("    } catch (e) {");
          buffer.writeln("      loaderData = {'error': e.toString()};");
          buffer.writeln("    }");
          buffer.writeln("    String? prerendered;");
          buffer.writeln("    try {");
          buffer.writeln("      prerendered = await _prerenderEngine.renderRoute('/__bloom_shell?__bloom_route=' + Uri.encodeComponent(req.path));");
          buffer.writeln("    } catch (_) {}");
          buffer.writeln("    return BloomResponse.html(_renderDynamicSsrHtml(");
          buffer.writeln("      appTitle: '$appName',");
          buffer.writeln("      pageTitle: '$defaultTitle',");
          buffer.writeln("      description: '$defaultDesc',");
          buffer.writeln("      routePath: req.path,");
          buffer.writeln("      params: req.params,");
          buffer.writeln("      themeColor: '$themeColor',");
          buffer.writeln("      loaderData: loaderData,");
          buffer.writeln("      prerenderedBodyHtml: prerendered,");
          buffer.writeln("    ));");
        }
      } else {
        buffer.writeln("    String? prerendered;");
        buffer.writeln("    try {");
        buffer.writeln("      prerendered = await _prerenderEngine.renderRoute('/__bloom_shell?__bloom_route=' + Uri.encodeComponent(req.path));");
        buffer.writeln("    } catch (_) {}");
        buffer.writeln("    return BloomResponse.html(_renderDynamicSsrHtml(");
        buffer.writeln("      appTitle: '$appName',");
        buffer.writeln("      pageTitle: '$defaultTitle',");
        buffer.writeln("      description: '$defaultDesc',");
        buffer.writeln("      routePath: req.path,");
        buffer.writeln("      params: req.params,");
        buffer.writeln("      themeColor: '$themeColor',");
        buffer.writeln("      prerenderedBodyHtml: prerendered,");
        buffer.writeln("    ));");
      }
      buffer.writeln("  });");

      // Register Form Action handler if @BloomAction is declared
      if (page.hasAction && page.actionFunctionName != null) {
        buffer.writeln("  router.post('${page.path}', (req) async {");
        buffer.writeln("    final ctx = BloomRouteContext(params: req.params, queryParams: req.queryParams, url: req.uri);");
        buffer.writeln("    final body = req.json();");
        buffer.writeln("    final form = body is Map<String, dynamic> ? body : req.formData();");
        buffer.writeln("    final result = await page_route_$i.${page.actionFunctionName}(ctx, form);");
        buffer.writeln("    return BloomResponse.json({");
        buffer.writeln("      'isSuccess': result.isSuccess,");
        buffer.writeln("      'errorMessage': result.errorMessage,");
        buffer.writeln("      'data': result.data,");
        buffer.writeln("      'fieldErrors': result.fieldErrors,");
        buffer.writeln("    });");
        buffer.writeln("  });");
      }
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
          final ext = staticFile.path.split('.').last.toLowerCase();

          // Responsive image variants. The client half of this already ships:
          // bloomImage()/buildSrcSet emit srcset URLs of the form
          // "/photo.jpg?w=640" via defaultImageUrlBuilder. This is the server
          // half that actually produces those widths, so a srcset stops being
          // a promise of optimisation that nothing keeps.
          //
          // Any failure here falls through to serving the original file
          // untouched: a broken optimiser must degrade to a correct-but-larger
          // image, never to an error page.
          final widthParam = req.queryParams['w'];
          if (widthParam != null && const ['jpg', 'jpeg', 'png'].contains(ext)) {
            final requestedWidth = int.tryParse(widthParam);
            if (requestedWidth != null &&
                bloom_img.BloomImageTransformer.isAllowedWidth(requestedWidth)) {
              try {
                final variantCache = bloom_img_cache.BloomImageVariantCache(
                  projectRoot: Directory.current,
                );
                var variantBytes = variantCache.read(staticFile, requestedWidth);
                var variantFormat = bloom_img.BloomImageFormat.jpeg;

                if (variantBytes == null) {
                  final result = bloom_img.BloomImageTransformer().transform(
                    staticFile.readAsBytesSync(),
                    requestedWidth,
                  );
                  variantBytes = result.bytes;
                  variantFormat = result.format;
                  variantCache.write(
                      staticFile, requestedWidth, result.bytes, result.format);
                } else {
                  // The cache stores only JPEG and PNG, distinguishable by
                  // their signatures. Trust the bytes, not the request's
                  // extension: a .png without alpha is re-encoded to JPEG, so
                  // the source extension is not the output type.
                  final isPng = variantBytes.length >= 8 &&
                      variantBytes[0] == 0x89 &&
                      variantBytes[1] == 0x50;
                  variantFormat = isPng
                      ? bloom_img.BloomImageFormat.png
                      : bloom_img.BloomImageFormat.jpeg;
                }

                // Re-encoding does not always shrink a file. When the source is
                // already at or below the requested width no resize happens, and
                // re-encoding an already-compressed JPEG costs generation loss
                // AND bytes -- a 618KB photo requested at its own width came back
                // as 684KB. Serving that would be a pessimisation dressed up as
                // an optimisation, so keep the variant only when it actually wins.
                if (variantBytes.length < staticFile.lengthSync()) {
                  return BloomResponse(
                    statusCode: 200,
                    headers: {
                      'content-type': variantFormat == bloom_img.BloomImageFormat.png
                          ? 'image/png'
                          : 'image/jpeg',
                      'cache-control': 'public, max-age=31536000, immutable',
                    },
                    body: variantBytes,
                  );
                }
              } catch (_) {
                // Fall through to the original file below.
              }
            }
          }

          final bytes = staticFile.readAsBytesSync();
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

    String? prerendered;
    try {
      prerendered = await _prerenderEngine.renderRoute('/__bloom_shell?__bloom_route=' + Uri.encodeComponent(req.path));
    } catch (_) {}
    return BloomResponse.html(_renderDynamicSsrHtml(
      appTitle: '$appName',
      pageTitle: '$appName',
      description: 'Bloom Full-Stack Server',
      routePath: req.path,
      params: req.params,
      themeColor: '$themeColor',
      prerenderedBodyHtml: prerendered,
    ));
  });

  final server = await router.serve(port: port);
  print('🚀 Bloom Full-Stack Server listening on http://localhost:\$port');
}

String _escapeHtml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _renderDynamicSsrHtml({
  required String appTitle,
  required String pageTitle,
  required String description,
  required String routePath,
  required Map<String, String> params,
  required String themeColor,
  dynamic loaderData,
  String? prerenderedBodyHtml,
}) {
  final segments = routePath.split('/').where((s) => s.isNotEmpty).toList();
  final headerDisplay = segments.isEmpty ? 'Home' : segments.map((s) => s[0].toUpperCase() + s.substring(1)).join(' / ');
  final safeTitle = _escapeHtml(pageTitle);
  final safeDesc = _escapeHtml(description);
  final safeAppTitle = _escapeHtml(appTitle);
  final safeHeader = _escapeHtml(headerDisplay);
  final safeTheme = _escapeHtml(themeColor);

  final bodyContent = prerenderedBodyHtml != null
      ? '<div id="bloom-app-root">\\n    \$prerenderedBodyHtml\\n  </div>'
      : """
  <div id="bloom-app-root">
    <header class="bloom-ssr-header">
      <div class="bloom-brand">
        <span class="bloom-logo-dot"></span>
        <span>\$safeAppTitle</span>
      </div>
      <div class="bloom-ssr-nav">
        <span class="bloom-badge">Bloom SSR Engine Active</span>
      </div>
    </header>
    <main class="bloom-ssr-main">
      <div class="bloom-pill">Full-Stack SSR • 0kB JS Baseline</div>
      <h1 class="bloom-page-title">\$safeHeader</h1>
      <p class="bloom-page-desc">\$safeDesc</p>
      \${loaderData != null ? '<div class="bloom-ssr-loader-data"><pre>' + _escapeHtml(const JsonEncoder.withIndent('  ').convert(loaderData)) + '</pre></div>' : ''}
    </main>
  </div>""";

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
  <meta name="theme-color" content="\$safeTheme" />
  <style>
    body { margin: 0; padding: 0; background-color: #09090B; font-family: -apple-system, BlinkMacSystemFont, "Inter", "Segoe UI", Roboto, sans-serif; color: #F4F4F5; -webkit-font-smoothing: antialiased; }
    #bloom-app-root { min-height: 100vh; display: flex; flex-direction: column; background: radial-gradient(circle at 50% 0%, rgba(99, 102, 241, 0.12) 0%, transparent 60%); }
    .bloom-ssr-header { padding: 1.25rem 2.5rem; background: rgba(14, 14, 18, 0.7); backdrop-filter: blur(16px); border-bottom: 1px solid #1E1E24; display: flex; align-items: center; justify-content: space-between; }
    .bloom-brand { font-size: 1.05rem; font-weight: 700; color: #FFFFFF; display: flex; align-items: center; gap: 0.6rem; letter-spacing: -0.02em; }
    .bloom-logo-dot { width: 10px; height: 10px; border-radius: 50%; background: #6366F1; box-shadow: 0 0 12px #6366F1; }
    .bloom-ssr-main { flex: 1; max-width: 900px; margin: 4rem auto; padding: 0 1.5rem; width: 100%; box-sizing: border-box; text-align: center; }
    .bloom-pill { display: inline-flex; align-items: center; padding: 0.35rem 0.85rem; background: rgba(39, 39, 42, 0.6); border: 1px solid #27272A; border-radius: 9999px; color: #A1A1AA; font-size: 0.8rem; font-weight: 500; margin-bottom: 1.5rem; }
    .bloom-page-title { font-size: 3.25rem; font-weight: 800; letter-spacing: -0.03em; margin: 0 0 1rem 0; color: #FFFFFF; line-height: 1.15; }
    .bloom-page-desc { font-size: 1.15rem; color: #A1A1AA; line-height: 1.6; max-width: 620px; margin: 0 auto; }
    .bloom-badge { display: inline-block; padding: 0.35rem 0.75rem; background: rgba(16, 185, 129, 0.1); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 9999px; color: #10B981; font-weight: 600; font-size: 0.75rem; }
    .bloom-ssr-loader-data { margin-top: 2rem; padding: 1.25rem; background: #111116; border: 1px solid #22222A; border-radius: 12px; font-family: monospace; font-size: 0.85rem; color: #E2E8F0; text-align: left; }
  </style>
</head>
<body>
\$bodyContent
  <script>
    window.__BLOOM_SSR_ROUTE__ = \${jsonEncode(routePath)};
    window.__BLOOM_SSR_PARAMS__ = \${jsonEncode(params)};
    window.__BLOOM_LOADER_DATA__ = \${jsonEncode(loaderData)};
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

    if (proxyRules.isNotEmpty) {
      buffer.writeln('''
const _proxyHopByHopHeaders = {
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'host',
};

final _proxyHttpClient = HttpClient()..autoUncompress = false;

Uri _resolveProxyTargetUri(Uri requestUri, _BloomServerProxyRule rule) {
  final reqPath = requestUri.path;
  final prefix = rule.pathPrefix.endsWith('/') && rule.pathPrefix.length > 1
      ? rule.pathPrefix.substring(0, rule.pathPrefix.length - 1)
      : rule.pathPrefix;

  String effectiveSubPath;
  if (rule.stripPrefix) {
    if (reqPath == prefix) {
      effectiveSubPath = '';
    } else if (reqPath.startsWith('\$prefix/')) {
      effectiveSubPath = reqPath.substring(prefix.length);
    } else {
      effectiveSubPath = reqPath;
    }
  } else {
    effectiveSubPath = reqPath;
  }

  final targetUri = Uri.parse(rule.targetUrl);
  final basePath = targetUri.path.endsWith('/') && targetUri.path.length > 1
      ? targetUri.path.substring(0, targetUri.path.length - 1)
      : (targetUri.path == '/' ? '' : targetUri.path);

  final String finalPath;
  if (effectiveSubPath.startsWith('/')) {
    finalPath = '\$basePath\$effectiveSubPath';
  } else if (effectiveSubPath.isEmpty) {
    finalPath = basePath.isEmpty ? '/' : basePath;
  } else {
    finalPath = '\$basePath/\$effectiveSubPath';
  }

  final query = requestUri.hasQuery
      ? requestUri.query
      : (targetUri.hasQuery ? targetUri.query : null);

  return targetUri.replace(
    path: finalPath.isEmpty ? '/' : finalPath,
    query: query,
  );
}

Future<BloomResponse> _forwardProxyRequest(BloomRequest req, _BloomServerProxyRule rule) async {
  final upstreamUri = _resolveProxyTargetUri(req.uri, rule);
  try {
    final upstreamReq = await _proxyHttpClient.openUrl(req.method, upstreamUri);

    req.headers.forEach((name, value) {
      final lower = name.toLowerCase();
      if (_proxyHopByHopHeaders.contains(lower)) return;
      upstreamReq.headers.add(name, value);
    });

    final clientIp = req.headers['x-forwarded-for'] ?? '127.0.0.1';
    upstreamReq.headers.set('x-forwarded-for', clientIp);
    upstreamReq.headers.set('x-forwarded-proto', req.isSecure ? 'https' : 'http');
    if (req.headers.containsKey('host')) {
      upstreamReq.headers.set('x-forwarded-host', req.headers['host']!);
    }

    if (req.rawBody.isNotEmpty) {
      upstreamReq.add(req.rawBody);
    }
    final upstreamRes = await upstreamReq.close();

    final responseHeaders = <String, String>{};
    upstreamRes.headers.forEach((name, values) {
      final lower = name.toLowerCase();
      if (_proxyHopByHopHeaders.contains(lower)) return;
      responseHeaders[name] = values.join(', ');
    });

    responseHeaders.remove('content-length');

    // Stream the upstream straight through. Buffering here would hold an
    // entire proxied response in memory and delay first byte until the
    // upstream finished.
    return BloomResponse.stream(
      upstreamRes,
      statusCode: upstreamRes.statusCode,
      headers: responseHeaders,
    );
  } catch (e) {
    return BloomResponse(
      statusCode: 502,
      headers: {'content-type': 'text/plain; charset=utf-8'},
      body: Uint8List.fromList(utf8.encode('502 Bad Gateway: Upstream connection failed to \$upstreamUri\\n\\n\$e')),
    );
  }
}
''');
    }

    return buffer.toString();
  }
}
