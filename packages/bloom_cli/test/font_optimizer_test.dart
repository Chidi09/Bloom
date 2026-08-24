// test/font_optimizer_test.dart
import 'dart:io';
import 'package:bloom_cli/src/assets/font_optimizer.dart';
import 'package:bloom_cli/src/utils/project.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('BloomFontOptimizer', () {
    late Directory tempDir;
    late BloomProject project;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bloom_font_optimizer_test_');
      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('name: test_font_app\nversion: 1.0.0\n');
      project = BloomProject.fromDirectory(tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('toKebabCase normalizes font family names correctly', () {
      expect(BloomFontOptimizer.toKebabCase('Inter'), 'inter');
      expect(BloomFontOptimizer.toKebabCase('JetBrains Mono'), 'jetbrains-mono');
      expect(BloomFontOptimizer.toKebabCase('Open Sans Condensed'), 'open-sans-condensed');
      expect(BloomFontOptimizer.toKebabCase('  Roboto_Flex  '), 'roboto-flex');
    });

    test('throws ArgumentError if families list is empty', () async {
      final optimizer = BloomFontOptimizer(project: project);
      expect(
        () => optimizer.optimize(families: []),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError if an invalid weight is passed', () async {
      final optimizer = BloomFontOptimizer(project: project);
      expect(
        () => optimizer.optimize(families: ['Inter'], weights: ['450']),
        throwsArgumentError,
      );
    });

    test('downloads woff2 font files and generates fonts.g.css with CLS fallback', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'fonts.googleapis.com') {
          // Assert User-Agent is set
          expect(request.headers['User-Agent'], equals(kModernBrowserUserAgent));

          // Return mock Google Fonts CSS
          const mockCss = '''
/* latin */
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/inter/v18/inter-400.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
/* latin */
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 700;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/inter/v18/inter-700.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
''';
          return http.Response(mockCss, 200, headers: {'content-type': 'text/css'});
        } else if (request.url.host == 'fonts.gstatic.com') {
          // Return mock woff2 binary payload
          final dummyBytes = [0x77, 0x4F, 0x46, 0x32, 0x00, 0x01, 0x00, 0x00];
          return http.Response.bytes(dummyBytes, 200);
        }
        return http.Response('Not Found', 404);
      });

      final optimizer = BloomFontOptimizer(project: project, httpClient: mockClient);
      final result = await optimizer.optimize(
        families: ['Inter'],
        weights: ['400', '700'],
      );

      expect(result.families, equals(['Inter']));
      expect(result.warnings, isEmpty);
      expect(result.filesWritten.length, equals(3)); // 2 woff2 files + 1 fonts.g.css

      final font400 = File(p.join(tempDir.path, 'lib', 'generated', 'fonts', 'inter-400.woff2'));
      final font700 = File(p.join(tempDir.path, 'lib', 'generated', 'fonts', 'inter-700.woff2'));
      final cssFile = File(p.join(tempDir.path, 'lib', 'generated', 'fonts', 'fonts.g.css'));

      expect(font400.existsSync(), isTrue);
      expect(font700.existsSync(), isTrue);
      expect(cssFile.existsSync(), isTrue);

      final cssContent = cssFile.readAsStringSync();
      expect(cssContent, contains("font-family: 'Inter';"));
      expect(cssContent, contains('font-weight: 400;'));
      expect(cssContent, contains("src: url('/generated/fonts/inter-400.woff2') format('woff2');"));
      expect(cssContent, contains('font-weight: 700;'));
      expect(cssContent, contains("src: url('/generated/fonts/inter-700.woff2') format('woff2');"));
      expect(cssContent, contains("font-family: 'Inter Fallback';"));
      expect(cssContent, contains('size-adjust: 100%;'));
    });

    test('supports custom sizeAdjustOverrides for CLS fallback metric', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'fonts.googleapis.com') {
          const mockCss = '''
@font-face {
  font-family: 'Roboto';
  font-style: normal;
  font-weight: 400;
  src: url(https://fonts.gstatic.com/s/roboto/v30/roboto-400.woff2) format('woff2');
}
''';
          return http.Response(mockCss, 200);
        } else if (request.url.host == 'fonts.gstatic.com') {
          return http.Response.bytes([0x77, 0x4F, 0x46, 0x32], 200);
        }
        return http.Response('Not Found', 404);
      });

      final optimizer = BloomFontOptimizer(project: project, httpClient: mockClient);
      final result = await optimizer.optimize(
        families: ['Roboto'],
        weights: ['400'],
        sizeAdjustOverrides: {'Roboto': 107.5},
      );

      expect(result.warnings, isEmpty);
      final cssFile = File(result.cssPath);
      expect(cssFile.existsSync(), isTrue);
      final cssContent = cssFile.readAsStringSync();
      expect(cssContent, contains("font-family: 'Roboto Fallback';"));
      expect(cssContent, contains('size-adjust: 107.50%;'));
    });

    test('handles Google Fonts 404 or network failure gracefully with warnings', () async {
      final mockClient = MockClient((request) async {
        if (request.url.query.contains('family=NonExistentFont')) {
          return http.Response('Font family not found', 404);
        }
        // Successful font
        if (request.url.host == 'fonts.googleapis.com') {
          return http.Response(
            "@font-face { font-family: 'Fira Code'; font-weight: 400; src: url(https://fonts.gstatic.com/s/fira/fira-400.woff2) format('woff2'); }",
            200,
          );
        }
        return http.Response.bytes([0x77, 0x4F], 200);
      });

      final optimizer = BloomFontOptimizer(project: project, httpClient: mockClient);
      final result = await optimizer.optimize(
        families: ['NonExistentFont', 'Fira Code'],
        weights: ['400'],
      );

      expect(result.families, equals(['NonExistentFont', 'Fira Code']));
      expect(result.warnings.length, equals(1));
      expect(result.warnings.first, contains('HTTP 404'));
      expect(result.filesWritten, isNotEmpty);
      expect(File(p.join(tempDir.path, 'lib', 'generated', 'fonts', 'fira-code-400.woff2')).existsSync(), isTrue);
    });

    test('default client handles offline/unreachable network gracefully without throwing', () async {
      final optimizer = BloomFontOptimizer(project: project);
      // optimize against real network or offline sandbox
      final result = await optimizer.optimize(
        families: ['Inter'],
        weights: ['400'],
      );

      // In any environment (online or offline), optimize must return a BloomFontOptimizeResult
      expect(result, isA<BloomFontOptimizeResult>());
      expect(result.families, contains('Inter'));
    });
  });
}
