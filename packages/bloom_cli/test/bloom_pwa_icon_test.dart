import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../lib/src/utils/project.dart';
import '../lib/src/web/icon_svg.dart';
import '../lib/src/web/prerender_engine.dart';
import '../lib/src/web/pwa_generator.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_pwa_icon_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('PWA Brand Icon SVG Generation', () {
    test('buildBloomLogoSvg generates canonical 5-petal flower with linear gradients and sparkle', () {
      final svg = buildBloomLogoSvg();

      expect(svg, contains('viewBox="0 0 200 200"'));
      expect(svg, contains('linearGradient id="petal1"'));
      expect(svg, contains('linearGradient id="petal2"'));
      expect(svg, contains('linearGradient id="petal3"'));
      expect(svg, contains('linearGradient id="petal4"'));
      expect(svg, contains('linearGradient id="petal5"'));

      // Verify exact petal gradient coordinates & colors matching bloom_logo.dart
      expect(svg, contains('x1="100" y1="20" x2="100" y2="100"'));
      expect(svg, contains('stop-color="#FF4B8B"'));
      expect(svg, contains('stop-color="#FF8BA7"'));

      expect(svg, contains('x1="180" y1="80" x2="110" y2="110"'));
      expect(svg, contains('stop-color="#FF884D"'));
      expect(svg, contains('stop-color="#FFA066"'));

      expect(svg, contains('x1="140" y1="175" x2="100" y2="115"'));
      expect(svg, contains('stop-color="#20C9B0"'));
      expect(svg, contains('stop-color="#48E5C8"'));

      expect(svg, contains('x1="60" y1="175" x2="100" y2="115"'));
      expect(svg, contains('stop-color="#2563EB"'));
      expect(svg, contains('stop-color="#60A5FA"'));

      expect(svg, contains('x1="20" y1="80" x2="90" y2="110"'));
      expect(svg, contains('stop-color="#8B5CF6"'));
      expect(svg, contains('stop-color="#A855F7"'));

      // Verify petal paths and 0.95 fill opacity
      expect(svg, contains('fill-opacity="0.95"'));
      expect(svg, contains('M100 20 C130 20 145 60 125 90 C110 100 90 100 75 90 C55 60 70 20 100 20 Z'));
      expect(svg, contains('M180 80 C190 110 155 135 125 115 C115 100 105 85 115 70 C145 50 170 50 180 80 Z'));
      expect(svg, contains('M140 175 C115 185 85 155 100 125 C110 110 125 105 135 115 C165 135 165 165 140 175 Z'));
      expect(svg, contains('M60 175 C35 165 35 135 65 115 C75 105 90 110 100 125 C115 155 85 185 60 175 Z'));
      expect(svg, contains('M20 80 C30 50 55 50 85 70 C95 85 85 100 75 115 C45 135 10 110 20 80 Z'));

      // Verify sparkle accent
      expect(svg, contains('M100 82 L104 96 L118 100 L104 104 L100 118 L96 104 L82 100 L96 96 Z'));
      expect(svg, contains('fill="#FFFFFF"'));
    });

    test('buildBloomLogoSvg supports maskable and opaque background variants', () {
      final maskableSvg = buildBloomLogoSvg(isMaskable: true, themeColor: '#10B981');
      expect(maskableSvg, contains('<rect width="200" height="200" fill="#10B981" />'));
      expect(maskableSvg, contains('<g transform="translate(20, 20) scale(0.8)">'));

      final appleTouchSvg = buildBloomLogoSvg(hasOpaqueBackground: true, themeColor: '#6366F1');
      expect(appleTouchSvg, contains('<rect width="200" height="200" fill="#6366F1" />'));
      expect(appleTouchSvg, isNot(contains('<g transform="translate(20, 20) scale(0.8)">')));
    });
  });

  group('Headless Chromium SVG to PNG Rendering', () {
    test('BloomPrerenderEngine returns null safely when browser is uninitialized', () async {
      final engine = BloomPrerenderEngine();
      expect(engine.isBrowserRunning, isFalse);

      final bytes = await engine.renderSvgToPng(buildBloomLogoSvg(), width: 192, height: 192);
      expect(bytes, isNull);
      await engine.close();
    });

    test('BloomPrerenderEngine rasterizes SVG to valid PNG bytes when started with startBrowserOnly()', () async {
      final engine = BloomPrerenderEngine();
      await engine.startBrowserOnly();

      if (engine.isBrowserRunning) {
        final bytes = await engine.renderSvgToPng(buildBloomLogoSvg(), width: 192, height: 192);
        expect(bytes, isNotNull);
        expect(bytes!.isNotEmpty, isTrue);

        // Standard PNG 8-byte magic header
        final pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        expect(bytes.sublist(0, 8), pngMagic);
      }

      await engine.close();
    });
  });

  group('PwaGenerator Brand Icon Generation and Fallback', () {
    test('PwaGenerator creates all required branded icons, manifest, and service worker', () async {
      final appDir = Directory(p.join(tempDir.path, 'pwa_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('''
name: pwa_app
web:
  pwa:
    name: "Bloom Test PWA"
    short_name: "TestPWA"
    theme_color: "#6200EE"
''');

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final outputDir = Directory(p.join(appDir.path, 'build', 'web'));
      final pwaGen = PwaGenerator(project: project, outputDir: outputDir);
      await pwaGen.generate();

      // Manifest & Service Worker
      final manifestFile = File(p.join(outputDir.path, 'manifest.json'));
      final swFile = File(p.join(outputDir.path, 'flutter_service_worker.js'));
      expect(manifestFile.existsSync(), isTrue);
      expect(swFile.existsSync(), isTrue);

      final manifestContent = manifestFile.readAsStringSync();
      expect(manifestContent, contains('Bloom Test PWA'));
      expect(manifestContent, contains('icons/Icon-192.png'));
      expect(manifestContent, contains('icons/Icon-512.png'));
      expect(manifestContent, contains('icons/Icon-maskable-192.png'));
      expect(manifestContent, contains('icons/Icon-maskable-512.png'));

      // If Chromium ran in this environment, verify all icon files and their PNG headers
      final icon192 = File(p.join(outputDir.path, 'icons', 'Icon-192.png'));
      final icon512 = File(p.join(outputDir.path, 'icons', 'Icon-512.png'));
      final iconMaskable192 = File(p.join(outputDir.path, 'icons', 'Icon-maskable-192.png'));
      final iconMaskable512 = File(p.join(outputDir.path, 'icons', 'Icon-maskable-512.png'));
      final favicon = File(p.join(outputDir.path, 'favicon.png'));
      final appleTouch = File(p.join(outputDir.path, 'icons', 'apple-touch-icon.png'));

      if (icon192.existsSync()) {
        final pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

        expect(icon512.existsSync(), isTrue);
        expect(iconMaskable192.existsSync(), isTrue);
        expect(iconMaskable512.existsSync(), isTrue);
        expect(favicon.existsSync(), isTrue);
        expect(appleTouch.existsSync(), isTrue);

        expect(icon192.readAsBytesSync().sublist(0, 8), pngMagic);
        expect(icon512.readAsBytesSync().sublist(0, 8), pngMagic);
        expect(iconMaskable192.readAsBytesSync().sublist(0, 8), pngMagic);
        expect(iconMaskable512.readAsBytesSync().sublist(0, 8), pngMagic);
        expect(favicon.readAsBytesSync().sublist(0, 8), pngMagic);
        expect(appleTouch.readAsBytesSync().sublist(0, 8), pngMagic);
      }
    });

    test('PwaGenerator degrades gracefully without throwing when browser is unavailable and preserves existing icons', () async {
      final appDir = Directory(p.join(tempDir.path, 'fallback_pwa_app'))..createSync(recursive: true);
      File(p.join(appDir.path, 'bloom.yaml')).writeAsStringSync('name: fallback_pwa_app\n');

      final project = BloomProject(
        rootDir: appDir,
        bloomYamlFile: File(p.join(appDir.path, 'bloom.yaml')),
        pubspecFile: File(p.join(appDir.path, 'pubspec.yaml')),
      );

      final outputDir = Directory(p.join(appDir.path, 'build', 'web'));
      final iconsDir = Directory(p.join(outputDir.path, 'icons'))..createSync(recursive: true);

      // Pre-existing icon from flutter build web
      final existingIcon = File(p.join(iconsDir.path, 'Icon-192.png'));
      existingIcon.writeAsStringSync('flutter-default-icon-placeholder');

      // Uninitialized engine simulates browser unavailability
      final uninitializedEngine = BloomPrerenderEngine();
      final pwaGen = PwaGenerator(project: project, outputDir: outputDir);

      // Must complete without error
      await pwaGen.generate(engine: uninitializedEngine);

      // Manifest & Service worker still generated
      expect(File(p.join(outputDir.path, 'manifest.json')).existsSync(), isTrue);
      expect(File(p.join(outputDir.path, 'flutter_service_worker.js')).existsSync(), isTrue);

      // Pre-existing icon preserved and not overwritten with empty or corrupted file
      expect(existingIcon.readAsStringSync(), 'flutter-default-icon-placeholder');

      await uninitializedEngine.close();
    });
  });
}
