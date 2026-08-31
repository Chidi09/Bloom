import 'dart:io';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_seo/bloom_seo.dart';
import 'package:bloom_website_native/pages/blocks_page.dart';
import 'package:bloom_website_native/pages/bloom_page.dart';
import 'package:bloom_website_native/pages/build_page.dart';
import 'package:bloom_website_native/pages/home_page.dart';
import 'package:bloom_website_native/pages/server_page.dart';
import 'package:bloom_website_native/pages/ship_page.dart';

void main() async {
  final stopwatch = Stopwatch()..start();
  print('🌱 Starting Bloom JS Native Static Site Generator (SSG)...\n');

  final distDir = Directory('dist');
  if (distDir.existsSync()) {
    distDir.deleteSync(recursive: true);
  }
  distDir.createSync(recursive: true);

  // 1. Define Routes
  final routes = <String,
      ({String title, String description, BloomNode Function() builder})>{
    '/': (
      title: 'Bloom — BUILD • SHIP • BLOOM | The Application Platform '
          'for Dart & Flutter',
      description: 'Bloom is the opinionated application platform for Dart & '
          'Flutter. Architecture, CLI, Signals state, GoRouter '
          'generation, Shorebird OTA, and Bloom UI.',
      builder: homePage,
    ),
    '/bloom': (
      title: 'BLOOM — UI Studio & Interactive Mobile Component System',
      description: 'shadcn-inspired composable primitives built natively for '
          'Flutter Mobile & Tablet with live interactive design '
          'token controls.',
      builder: bloomPage,
    ),
    '/build': (
      title: 'BUILD — Bloom Framework & Developer Experience',
      description: 'Next.js-style file-system routing, fine-grained reactive '
          'signals, thin DI abstraction, and automated CLI '
          'generators for Flutter.',
      builder: buildPage,
    ),
    '/ship': (
      title: 'SHIP — Bloom Cloud OTA & Deploy Pipeline',
      description: 'Integrated Shorebird over-the-air (OTA) updates, remote '
          'build farm, preview channels, and cryptographic patch '
          'signing for Flutter.',
      builder: shipPage,
    ),
    '/server': (
      title: 'Bloom Server — Pure Dart Backend Platform & Ecosystem',
      description: 'Full-stack Django-style backend platform for pure Dart. '
          'Typed ORM, migrations, REST ViewSets, automatic HTML '
          'admin panel, and 78k msgs/s multi-isolate realtime '
          'clusters.',
      builder: serverPage,
    ),
    '/blocks': (
      title: 'Application Blocks — Bloom UI Primitives',
      description: 'Pre-built, copy-pasteable application screens and sections '
          'built with Bloom UI primitives.',
      builder: blocksPage,
    ),
  };

  // 2. Render each route to HTML
  final sitemap = SitemapBuilder();

  for (final entry in routes.entries) {
    final path = entry.key;
    final meta = entry.value;

    final node = meta.builder();
    final bodyHtml = renderToHtml(node);

    final fullHtml = '''<!DOCTYPE html>
<html lang="en" class="dark scroll-smooth">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#000000">
  <title>${meta.title}</title>
  <meta name="description" content="${meta.description}">
  <link rel="icon" type="image/svg+xml" href="/favicon.svg">
  <link rel="stylesheet" href="/generated/fonts/fonts.g.css">
  <meta property="og:title" content="${meta.title}">
  <meta property="og:description" content="${meta.description}">
  <meta name="twitter:card" content="summary_large_image">
  <script type="importmap">
{
  "imports": {
    "@tailwindcss/browser": "/vendor/tailwindcss-browser.min.js",
    "clsx": "/vendor/clsx.min.js",
    "tailwind-merge": "/vendor/tailwind-merge.min.js",
    "class-variance-authority": "/vendor/class-variance-authority.min.js"
  }
}
</script>
  <script type="module">
import '@tailwindcss/browser';
</script>
  <script type="module">
import * as __bloom_ns_clsx from 'clsx';
window.clsx = __bloom_ns_clsx;
import * as __bloom_ns_tailwind_merge from 'tailwind-merge';
window.tailwind_merge = __bloom_ns_tailwind_merge;
import * as __bloom_ns_class_variance_authority from 'class-variance-authority';
window.class_variance_authority = __bloom_ns_class_variance_authority;
</script>
  <style type="text/tailwindcss">
    @theme {
      --font-sans: 'Plus Jakarta Sans', system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      --font-mono: 'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    }
    @custom-variant dark (&:where(.dark, .dark *));
  </style>
</head>
<body class="min-h-screen relative overflow-x-clip antialiased selection:bg-purple-500/30 bg-slate-50 dark:bg-black text-slate-900 dark:text-white font-sans">
  <div id="app">$bodyHtml</div>
  <script defer src="/main.js"></script>
</body>
</html>
''';

    final targetFile =
        path == '/' ? File('dist/index.html') : File('dist${path}/index.html');

    targetFile.parent.createSync(recursive: true);
    targetFile.writeAsStringSync(fullHtml);

    sitemap.add(
      'https://bloom.dev$path',
      priority: path == '/' ? 1.0 : 0.8,
      changefreq: 'daily',
    );
    print('  ✓ Pre-rendered: $path -> ${targetFile.path}');
  }

  // 3. Generate sitemap.xml
  final sitemapXml = sitemap.buildXml();
  File('dist/sitemap.xml').writeAsStringSync(sitemapXml);
  print('  ✓ Generated: dist/sitemap.xml');

  // 4. Generate llms.txt
  final llmsContent =
      '''# Bloom Framework — The Application Platform for Dart & Flutter
> An all-in-one platform for high-performance cross-platform apps, edge SSR, and reactive web.

- [Overview](https://bloom.dev/): Platform overview & benchmark telemetry
- [Runtime](https://bloom.dev/bloom): Signals reactivity model & direct DOM leaf patching
- [Build](https://bloom.dev/build): CLI tooling, incremental compilation & hot reload
- [Ship](https://bloom.dev/ship): Over-the-air patches & multi-channel release pipeline
- [Server](https://bloom.dev/server): Multi-isolate server runtime & OpenAPI 3.1 docs
''';
  File('dist/llms.txt').writeAsStringSync(llmsContent);
  print('  ✓ Generated: dist/llms.txt');

  // 5. Copy static assets from web/
  for (final dirName in [
    'vendor',
    'generated',
    'images',
    'videos',
    'gifs',
    'og',
  ]) {
    final src = Directory('web/$dirName');
    if (src.existsSync()) {
      final dest = Directory('dist/$dirName');
      dest.createSync(recursive: true);
      _copyDirectory(src, dest);
      print('  ✓ Copied: web/$dirName -> dist/$dirName');
    }
  }

  // `bloom fonts optimize` writes self-hosted assets to lib/generated/fonts.
  // Copy them after web/ assets so the generated stylesheet and font weights
  // used by the app are the same ones served by the static output.
  final generatedFonts = Directory('lib/generated/fonts');
  if (generatedFonts.existsSync()) {
    final fontDestination = Directory('dist/generated/fonts');
    fontDestination.createSync(recursive: true);
    _copyDirectory(generatedFonts, fontDestination);
    print('  ✓ Copied: lib/generated/fonts -> dist/generated/fonts');
  }

  final favicon = File('web/favicon.svg');
  if (favicon.existsSync()) {
    favicon.copySync('dist/favicon.svg');
  }

  // `bloom js build` writes the client hydration bundle to web/main.js.
  // Every generated document references /main.js, so an SSG output without
  // this copy is visually static and all event handlers are unavailable.
  final clientBundle = File('web/main.js');
  if (!clientBundle.existsSync()) {
    throw StateError(
      'Missing web/main.js. Run "bloom js build" before "dart run bin/ssg.dart".',
    );
  }
  clientBundle.copySync('dist/main.js');
  print('  ✓ Copied: web/main.js -> dist/main.js');

  stopwatch.stop();
  print(
    '\n✨ SSG build finished in ${stopwatch.elapsedMilliseconds}ms across ${routes.length} pages.\n',
  );
}

void _copyDirectory(Directory source, Directory destination) {
  for (final entity in source.listSync(recursive: false)) {
    final destPath =
        '${destination.path}/${entity.uri.pathSegments.where((s) => s.isNotEmpty).last}';
    if (entity is Directory) {
      final newDir = Directory(destPath)..createSync(recursive: true);
      _copyDirectory(entity, newDir);
    } else if (entity is File) {
      entity.copySync(destPath);
    }
  }
}
