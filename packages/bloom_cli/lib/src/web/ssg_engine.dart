// lib/src/web/ssg_engine.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'pwa_generator.dart';

class DiscoveredRoute {
  final String path;
  final String relativeFilePath;
  final bool isDynamic;
  final String? declaredTitle;
  final String? declaredDescription;
  final List<String> staticPaths;

  DiscoveredRoute({
    required this.path,
    required this.relativeFilePath,
    required this.isDynamic,
    this.declaredTitle,
    this.declaredDescription,
    this.staticPaths = const [],
  });
}

/// Static Site Generation (SSG) Engine for Bloom.
///
/// Pre-renders static HTML pages, XML sitemaps, robots.txt, and PWA assets.
class BloomSsgEngine {
  final BloomProject project;
  final Directory outputDir;

  BloomSsgEngine({
    required this.project,
    Directory? outputDir,
  }) : outputDir = outputDir ?? Directory(p.join(project.rootDir.path, 'build', 'web'));

  /// Discovers all client page routes from `lib/routes/` excluding API routes.
  List<DiscoveredRoute> discoverRoutes() {
    final routesDir = Directory(p.join(project.rootDir.path, 'lib', 'routes'));
    if (!routesDir.existsSync()) return [];

    final config = project.loadBloomConfig();
    final configuredStaticPaths = _loadConfiguredStaticPaths(config);

    final routes = <DiscoveredRoute>[];
    final files = routesDir.listSync(recursive: true).whereType<File>();

    for (final file in files) {
      if (!file.path.endsWith('.dart')) continue;
      final relPath = p.relative(file.path, from: routesDir.path);

      // Skip API routes, generated files, layouts, and private files
      if (relPath.startsWith('api') ||
          relPath.endsWith('.g.dart') ||
          p.basename(relPath).startsWith('_')) {
        continue;
      }

      var routePath = relPath.replaceAll('.dart', '');
      if (routePath == 'index' || routePath.endsWith('/index')) {
        routePath = routePath.replaceAll(RegExp(r'/?index$'), '');
      }
      if (!routePath.startsWith('/')) {
        routePath = '/$routePath';
      }

      final isDynamic = routePath.contains('[') && routePath.contains(']');
      final fileContent = file.readAsStringSync();

      // Extract declared metadata & title from AST / Regex
      final titleMatch = RegExp(r'''title\s*[:=]\s*['"](.*?)['"]''').firstMatch(fileContent);
      final descMatch = RegExp(r'''description\s*[:=]\s*['"](.*?)['"]''').firstMatch(fileContent);

      // Extract static path enumeration for parameterized routes
      final dynamicPaths = <String>[];
      if (isDynamic) {
        if (configuredStaticPaths.containsKey(routePath)) {
          dynamicPaths.addAll(configuredStaticPaths[routePath]!);
        } else {
          // Check for staticPaths in source file
          final staticPathsMatch = RegExp(r'''staticPaths\s*(=>|=)\s*\[(.*?)\]''').firstMatch(fileContent);
          if (staticPathsMatch != null) {
            final rawList = staticPathsMatch.group(2)!;
            final items = RegExp(r'''['"](.*?)['"]''').allMatches(rawList).map((m) => m.group(1)!).toList();
            dynamicPaths.addAll(items);
          }
        }
      }

      routes.add(DiscoveredRoute(
        path: routePath.isEmpty ? '/' : routePath,
        relativeFilePath: relPath,
        isDynamic: isDynamic,
        declaredTitle: titleMatch?.group(1),
        declaredDescription: descMatch?.group(1),
        staticPaths: dynamicPaths,
      ));
    }

    // Sort routes for deterministic output
    routes.sort((a, b) => a.path.compareTo(b.path));
    return routes;
  }

  Map<String, List<String>> _loadConfiguredStaticPaths(Map<dynamic, dynamic> config) {
    final result = <String, List<String>>{};
    final webConfig = config['web'];
    if (webConfig is Map || webConfig is YamlMap) {
      final staticPaths = webConfig['static_paths'] ?? webConfig['staticPaths'];
      if (staticPaths is Map || staticPaths is YamlMap) {
        staticPaths.forEach((k, v) {
          if (v is List) {
            result[k.toString()] = v.map((item) => item.toString()).toList();
          }
        });
      }
    }
    return result;
  }

  /// Executes the full Static Site Generation pipeline.
  Future<void> generate() async {
    print(Ansi.boldText('\n⚡ Running Bloom Static Site Generator (SSG)...'));

    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final routes = discoverRoutes();
    print('› Discovered ${routes.length} client route(s) for pre-rendering.');

    final config = project.loadBloomConfig();
    final appTitle = config['name']?.toString() ?? 'Bloom App';
    final baseUrl = config['domain']?.toString() ?? 'https://bloom.dev';
    final pwaConfig = (config['web'] is Map && config['web']['pwa'] is Map)
        ? (config['web']['pwa'] as Map)
        : <dynamic, dynamic>{};
    final themeColor = pwaConfig['theme_color']?.toString() ?? '#10B981';

    final renderedRoutes = <String>[];

    // 1. Generate HTML for each static route and enumerated parameterized paths
    for (final route in routes) {
      if (route.isDynamic) {
        if (route.staticPaths.isEmpty) {
          print(Ansi.warn('  ⚠ Notice: Dynamic route "${route.path}" has no static_paths configured. Skipping static pre-rendering.'));
          continue;
        }

        for (final paramVal in route.staticPaths) {
          final instantiatedPath = route.path.replaceAll(RegExp(r'\[.*?\]'), paramVal);
          _generateHtmlPage(
            routePath: instantiatedPath,
            appTitle: appTitle,
            pageTitle: route.declaredTitle ?? '$appTitle - $instantiatedPath',
            description: route.declaredDescription ?? 'Pre-rendered content for $instantiatedPath',
            themeColor: themeColor,
          );
          renderedRoutes.add(instantiatedPath);
        }
      } else {
        _generateHtmlPage(
          routePath: route.path,
          appTitle: appTitle,
          pageTitle: route.declaredTitle ?? (route.path == '/' ? appTitle : '$appTitle - ${route.path.substring(1)}'),
          description: route.declaredDescription ?? 'Pre-rendered content for ${route.path}',
          themeColor: themeColor,
        );
        renderedRoutes.add(route.path);
      }
    }

    // Ensure root index.html exists
    if (!renderedRoutes.contains('/')) {
      _generateHtmlPage(
        routePath: '/',
        appTitle: appTitle,
        pageTitle: appTitle,
        description: 'Welcome to $appTitle',
        themeColor: themeColor,
      );
      renderedRoutes.add('/');
    }

    // 2. Generate XML Sitemap with all concrete rendered routes
    _generateSitemap(renderedRoutes, baseUrl);

    // 3. Generate Robots.txt
    _generateRobots(baseUrl);

    // 4. Generate PWA Assets
    PwaGenerator(project: project, outputDir: outputDir).generate();

    print(Ansi.success('✔ Static site generation complete! Output written to ${outputDir.path}\n'));
  }

  void _generateHtmlPage({
    required String routePath,
    required String appTitle,
    required String pageTitle,
    required String description,
    required String themeColor,
  }) {
    final cleanPath = routePath == '/' ? '' : (routePath.startsWith('/') ? routePath.substring(1) : routePath);
    final targetDir = cleanPath.isEmpty ? outputDir : Directory(p.join(outputDir.path, cleanPath));
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final targetFile = File(p.join(targetDir.path, 'index.html'));
    final html = _buildHtmlTemplate(
      title: pageTitle,
      description: description,
      routePath: routePath,
      themeColor: themeColor,
      appTitle: appTitle,
    );

    targetFile.writeAsStringSync(html);
  }

  String _buildHtmlTemplate({
    required String title,
    required String description,
    required String routePath,
    required String themeColor,
    required String appTitle,
  }) {
    final routeSegments = routePath.split('/').where((s) => s.isNotEmpty).toList();
    final headerDisplay = routeSegments.isEmpty ? 'Home' : routeSegments.map((s) => s[0].toUpperCase() + s.substring(1)).join(' / ');

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <base href="/" />
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${_escapeHtml(title)}</title>
  <meta name="description" content="${_escapeHtml(description)}" />
  <meta property="og:title" content="${_escapeHtml(title)}" />
  <meta property="og:description" content="${_escapeHtml(description)}" />
  <meta property="og:type" content="website" />
  <link rel="manifest" href="/manifest.json" />
  <link rel="apple-touch-icon" href="/icons/Icon-192.png" />
  <meta name="theme-color" content="${_escapeHtml(themeColor)}" />
  <style>
    body { margin: 0; padding: 0; background-color: #FAFAFA; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; color: #1F2937; }
    #bloom-app-root { min-height: 100vh; display: flex; flex-direction: column; }
    .bloom-prerendered-header { padding: 1.5rem 2rem; background: #FFFFFF; border-bottom: 1px solid #E5E7EB; display: flex; align-items: center; justify-content: space-between; }
    .bloom-brand { font-size: 1.25rem; font-weight: 700; color: #111827; }
    .bloom-prerendered-main { flex: 1; max-width: 960px; margin: 2rem auto; padding: 0 1.5rem; width: 100%; box-sizing: border-box; }
    .bloom-page-title { font-size: 2rem; font-weight: 800; margin-bottom: 0.5rem; }
    .bloom-page-desc { font-size: 1.125rem; color: #4B5563; line-height: 1.6; }
    #bloom-hydrating { margin-top: 2rem; padding: 1rem; background: #F3F4F6; border-radius: 8px; font-size: 0.875rem; color: #6B7280; display: inline-block; }
  </style>
</head>
<body>
  <div id="bloom-app-root">
    <header class="bloom-prerendered-header">
      <div class="bloom-brand">${_escapeHtml(appTitle)}</div>
    </header>
    <main class="bloom-prerendered-main">
      <h1 class="bloom-page-title">${_escapeHtml(headerDisplay)}</h1>
      <p class="bloom-page-desc">${_escapeHtml(description)}</p>
      <div id="bloom-hydrating">⚡ Pre-rendered with Bloom SSG. Hydrating Flutter application...</div>
    </main>
  </div>
  <noscript>
    <div style="padding: 2rem; text-align: center; color: #DC2626;">
      JavaScript is required for full interactive features. Content above is pre-rendered for accessibility.
    </div>
  </noscript>
  <script>
    window.__BLOOM_ROUTE__ = ${jsonEncode(routePath)};
    window.__BLOOM_DATA__ = ${jsonEncode({'route': routePath, 'title': title})};
  </script>
  <script src="flutter.js" defer></script>
  <script>
    window.addEventListener('load', function(ev) {
      if (typeof _flutter !== 'undefined') {
        _flutter.loader.loadEntrypoint({
          serviceWorker: { serviceWorkerVersion: 'bloom-v1' },
          onEntrypointLoaded: function(engineInitializer) {
            engineInitializer.initializeEngine().then(function(appRunner) {
              const root = document.getElementById('bloom-app-root');
              if (root) root.remove();
              appRunner.runApp();
            });
          }
        });
      }
    });
  </script>
</body>
</html>
'''.trim();
  }

  void _generateSitemap(List<String> routes, String baseUrl) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');

    final now = DateTime.now().toUtc().toIso8601String().split('T').first;
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

    for (final route in routes) {
      final fullUrl = '$normalizedBase$route';
      buffer.writeln('  <url>');
      buffer.writeln('    <loc>$fullUrl</loc>');
      buffer.writeln('    <lastmod>$now</lastmod>');
      buffer.writeln('    <changefreq>daily</changefreq>');
      buffer.writeln('    <priority>${route == "/" ? "1.0" : "0.8"}</priority>');
      buffer.writeln('  </url>');
    }

    buffer.writeln('</urlset>');
    final sitemapFile = File(p.join(outputDir.path, 'sitemap.xml'));
    sitemapFile.writeAsStringSync(buffer.toString());
  }

  void _generateRobots(String baseUrl) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final content = '''
User-agent: *
Allow: /

Sitemap: $normalizedBase/sitemap.xml
'''.trim();

    final robotsFile = File(p.join(outputDir.path, 'robots.txt'));
    robotsFile.writeAsStringSync(content);
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
