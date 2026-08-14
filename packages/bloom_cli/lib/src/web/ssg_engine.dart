// lib/src/web/ssg_engine.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'pwa_generator.dart';

class DiscoveredRoute {
  final String path;
  final String relativeFilePath;
  final bool isDynamic;

  DiscoveredRoute({
    required this.path,
    required this.relativeFilePath,
    required this.isDynamic,
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
      routes.add(DiscoveredRoute(
        path: routePath.isEmpty ? '/' : routePath,
        relativeFilePath: relPath,
        isDynamic: isDynamic,
      ));
    }

    // Sort routes for deterministic output
    routes.sort((a, b) => a.path.compareTo(b.path));
    return routes;
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

    // 1. Generate HTML for each static route
    for (final route in routes) {
      if (route.isDynamic) {
        // Parameterized routes get a template shell
        _generateHtmlPage(route.path.replaceAll(RegExp(r'\[.*?\]'), 'sample'), appTitle);
      } else {
        _generateHtmlPage(route.path, appTitle);
      }
    }

    // Ensure root index.html exists
    _generateHtmlPage('/', appTitle);

    // 2. Generate XML Sitemap
    _generateSitemap(routes, baseUrl);

    // 3. Generate Robots.txt
    _generateRobots(baseUrl);

    // 4. Generate PWA Assets
    PwaGenerator(project: project, outputDir: outputDir).generate();

    print(Ansi.success('✔ Static site generation complete! Output written to ${outputDir.path}\n'));
  }

  void _generateHtmlPage(String routePath, String appTitle) {
    final cleanPath = routePath == '/' ? '' : (routePath.startsWith('/') ? routePath.substring(1) : routePath);
    final targetDir = cleanPath.isEmpty ? outputDir : Directory(p.join(outputDir.path, cleanPath));
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final targetFile = File(p.join(targetDir.path, 'index.html'));
    final html = _buildHtmlTemplate(
      title: '$appTitle - ${cleanPath.isEmpty ? "Home" : cleanPath}',
      routePath: routePath,
    );

    targetFile.writeAsStringSync(html);
  }

  String _buildHtmlTemplate({required String title, required String routePath}) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <base href="/" />
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>$title</title>
  <meta name="description" content="Bloom universal fullstack application prerendered page for $routePath" />
  <meta property="og:title" content="$title" />
  <meta property="og:type" content="website" />
  <link rel="manifest" href="/manifest.json" />
  <link rel="apple-touch-icon" href="/icons/Icon-192.png" />
  <meta name="theme-color" content="#6200EE" />
  <style>
    body { margin: 0; padding: 0; background-color: #FAFAFA; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    #bloom-loading { display: flex; height: 100vh; align-items: center; justify-content: center; color: #666; }
  </style>
</head>
<body>
  <div id="bloom-loading">Loading application...</div>
  <script src="flutter.js" defer></script>
  <script>
    window.addEventListener('load', function(ev) {
      if (typeof _flutter !== 'undefined') {
        _flutter.loader.loadEntrypoint({
          serviceWorker: { serviceWorkerVersion: 'bloom-v1' },
          onEntrypointLoaded: function(engineInitializer) {
            engineInitializer.initializeEngine().then(function(appRunner) {
              const loader = document.getElementById('bloom-loading');
              if (loader) loader.remove();
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

  void _generateSitemap(List<DiscoveredRoute> routes, String baseUrl) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');

    final now = DateTime.now().toUtc().toIso8601String().split('T').first;
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

    for (final route in routes) {
      if (route.isDynamic) continue;
      final fullUrl = '$normalizedBase${route.path}';
      buffer.writeln('  <url>');
      buffer.writeln('    <loc>$fullUrl</loc>');
      buffer.writeln('    <lastmod>$now</lastmod>');
      buffer.writeln('    <changefreq>daily</changefreq>');
      buffer.writeln('    <priority>${route.path == "/" ? "1.0" : "0.8"}</priority>');
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
}
