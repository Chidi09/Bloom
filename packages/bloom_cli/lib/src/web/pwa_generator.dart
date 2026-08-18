// lib/src/web/pwa_generator.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'icon_svg.dart';
import 'prerender_engine.dart';

class _IconSpec {
  final String relativePath;
  final String svg;
  final int width;
  final int height;
  final bool omitBackground;

  const _IconSpec({
    required this.relativePath,
    required this.svg,
    required this.width,
    required this.height,
    required this.omitBackground,
  });
}

/// Generates Progressive Web App (PWA) manifest, service worker, and brand mark icons.
class PwaGenerator {
  final BloomProject project;
  final Directory outputDir;

  PwaGenerator({
    required this.project,
    required this.outputDir,
  });

  /// Generates manifest.json, service worker, and branded PNG icon assets.
  Future<void> generate({BloomPrerenderEngine? engine}) async {
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    _generateManifest();
    _generateServiceWorker();

    final ownsEngine = engine == null;
    final renderEngine = engine ?? BloomPrerenderEngine();
    if (ownsEngine) {
      await renderEngine.startBrowserOnly();
    }

    try {
      await _generateIcons(renderEngine);
    } finally {
      if (ownsEngine) {
        await renderEngine.close();
      }
    }
  }

  void _generateManifest() {
    final config = project.loadBloomConfig();
    final pwaConfig = (config['web'] is Map && config['web']['pwa'] is Map)
        ? (config['web']['pwa'] as Map)
        : <dynamic, dynamic>{};

    final appName = pwaConfig['name']?.toString() ?? config['name']?.toString() ?? 'Bloom Application';
    final shortName = pwaConfig['short_name']?.toString() ?? config['name']?.toString() ?? 'BloomApp';
    final themeColor = pwaConfig['theme_color']?.toString() ?? '#6200EE';
    final backgroundColor = pwaConfig['background_color']?.toString() ?? '#FFFFFF';
    final display = pwaConfig['display']?.toString() ?? 'standalone';

    final manifest = {
      'name': appName,
      'short_name': shortName,
      'start_url': '.',
      'display': display,
      'background_color': backgroundColor,
      'theme_color': themeColor,
      'description': config['description']?.toString() ?? '',
      'orientation': 'portrait-primary',
      'prefer_related_applications': false,
      'icons': [
        {
          'src': 'icons/Icon-192.png',
          'sizes': '192x192',
          'type': 'image/png',
          'purpose': 'any',
        },
        {
          'src': 'icons/Icon-512.png',
          'sizes': '512x512',
          'type': 'image/png',
          'purpose': 'any',
        },
        {
          'src': 'icons/Icon-maskable-192.png',
          'sizes': '192x192',
          'type': 'image/png',
          'purpose': 'maskable',
        },
        {
          'src': 'icons/Icon-maskable-512.png',
          'sizes': '512x512',
          'type': 'image/png',
          'purpose': 'maskable',
        },
      ],
    };

    final file = File(p.join(outputDir.path, 'manifest.json'));
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  }

  void _generateServiceWorker() {
    final swContent = '''
// Bloom PWA Service Worker (Cache-First Strategy)
const CACHE_NAME = 'bloom-app-cache-v1';
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
  '/icons/apple-touch-icon.png',
  '/flutter.js',
  '/main.dart.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE).catch(() => {});
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((name) => {
          if (name !== CACHE_NAME) {
            return caches.delete(name);
          }
        })
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  event.respondWith(
    caches.match(event.request).then((response) => {
      return response || fetch(event.request);
    })
  );
});
''';

    final swFile = File(p.join(outputDir.path, 'flutter_service_worker.js'));
    swFile.writeAsStringSync(swContent.trim());
  }

  Future<void> _generateIcons(BloomPrerenderEngine engine) async {
    if (!engine.isBrowserRunning) {
      print(Ansi.warn('  ⚠ Notice: PWA icon generation skipped because headless Chromium prerendering is unavailable.'));
      return;
    }

    final config = project.loadBloomConfig();
    final pwaConfig = (config['web'] is Map && config['web']['pwa'] is Map)
        ? (config['web']['pwa'] as Map)
        : <dynamic, dynamic>{};
    final themeColor = pwaConfig['theme_color']?.toString() ?? '#6200EE';

    final standardSvg = buildBloomLogoSvg();
    final maskableSvg = buildBloomLogoSvg(isMaskable: true, themeColor: themeColor);
    final appleTouchSvg = buildBloomLogoSvg(hasOpaqueBackground: true, themeColor: themeColor);

    final iconSpecs = [
      _IconSpec(
        relativePath: p.join('icons', 'Icon-192.png'),
        svg: standardSvg,
        width: 192,
        height: 192,
        omitBackground: true,
      ),
      _IconSpec(
        relativePath: p.join('icons', 'Icon-512.png'),
        svg: standardSvg,
        width: 512,
        height: 512,
        omitBackground: true,
      ),
      _IconSpec(
        relativePath: p.join('icons', 'Icon-maskable-192.png'),
        svg: maskableSvg,
        width: 192,
        height: 192,
        omitBackground: false,
      ),
      _IconSpec(
        relativePath: p.join('icons', 'Icon-maskable-512.png'),
        svg: maskableSvg,
        width: 512,
        height: 512,
        omitBackground: false,
      ),
      _IconSpec(
        relativePath: 'favicon.png',
        svg: standardSvg,
        width: 32,
        height: 32,
        omitBackground: true,
      ),
      _IconSpec(
        relativePath: p.join('icons', 'apple-touch-icon.png'),
        svg: appleTouchSvg,
        width: 180,
        height: 180,
        omitBackground: false,
      ),
    ];

    for (final spec in iconSpecs) {
      try {
        final bytes = await engine.renderSvgToPng(
          spec.svg,
          width: spec.width,
          height: spec.height,
          omitBackground: spec.omitBackground,
        );

        if (bytes == null || bytes.isEmpty) {
          print(Ansi.warn('  ⚠ Notice: Skipping "${spec.relativePath}" because icon rendering failed.'));
          continue;
        }

        final targetFile = File(p.join(outputDir.path, spec.relativePath));
        final parentDir = targetFile.parent;
        if (!parentDir.existsSync()) {
          parentDir.createSync(recursive: true);
        }
        targetFile.writeAsBytesSync(bytes);
      } catch (e) {
        print(Ansi.warn('  ⚠ Notice: Skipping "${spec.relativePath}" due to error: $e'));
      }
    }
  }
}
