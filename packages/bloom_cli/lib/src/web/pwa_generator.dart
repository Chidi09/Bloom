// lib/src/web/pwa_generator.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/project.dart';

/// Generates Progressive Web App (PWA) manifest and service worker configuration.
class PwaGenerator {
  final BloomProject project;
  final Directory outputDir;

  PwaGenerator({
    required this.project,
    required this.outputDir,
  });

  /// Generates manifest.json and service worker.
  void generate() {
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    _generateManifest();
    _generateServiceWorker();
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
          'purpose': 'maskable any',
        },
        {
          'src': 'icons/Icon-512.png',
          'sizes': '512x512',
          'type': 'image/png',
          'purpose': 'maskable any',
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
}
