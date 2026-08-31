// test/font_optimizer_test.dart
import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:bloom_cli/src/assets/font_optimizer.dart';
import 'package:bloom_cli/src/commands/font_command.dart';
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
      tempDir =
          Directory.systemTemp.createTempSync('bloom_font_optimizer_test_');
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
      expect(
          BloomFontOptimizer.toKebabCase('JetBrains Mono'), 'jetbrains-mono');
      expect(BloomFontOptimizer.toKebabCase('Open Sans Condensed'),
          'open-sans-condensed');
      expect(BloomFontOptimizer.toKebabCase('  Roboto_Flex  '), 'roboto-flex');
    });

    test('throws ArgumentError if families list is empty', () async {
      final optimizer = BloomFontOptimizer(project: project);
      expect(
        () => optimizer.optimize(families: []),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError if styles list is empty', () async {
      final optimizer = BloomFontOptimizer(project: project);
      expect(
        () => optimizer.optimize(families: ['Inter'], styles: []),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError if an invalid style is passed', () async {
      final optimizer = BloomFontOptimizer(project: project);
      expect(
        () => optimizer.optimize(families: ['Inter'], styles: ['oblique']),
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

    test(
        'downloads woff2 font files and generates fonts.g.css with CLS fallback',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'fonts.googleapis.com') {
          // Assert User-Agent is set
          expect(
              request.headers['User-Agent'], equals(kModernBrowserUserAgent));

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
          return http.Response(mockCss, 200,
              headers: {'content-type': 'text/css'});
        } else if (request.url.host == 'fonts.gstatic.com') {
          // Return mock woff2 binary payload
          final dummyBytes = [0x77, 0x4F, 0x46, 0x32, 0x00, 0x01, 0x00, 0x00];
          return http.Response.bytes(dummyBytes, 200);
        }
        return http.Response('Not Found', 404);
      });

      final optimizer =
          BloomFontOptimizer(project: project, httpClient: mockClient);
      final result = await optimizer.optimize(
        families: ['Inter'],
        weights: ['400', '700'],
      );

      expect(result.families, equals(['Inter']));
      expect(result.warnings, isEmpty);
      expect(result.filesWritten.length,
          equals(3)); // 2 woff2 files + 1 fonts.g.css

      final font400 = File(
          p.join(tempDir.path, 'lib', 'generated', 'fonts', 'inter-400.woff2'));
      final font700 = File(
          p.join(tempDir.path, 'lib', 'generated', 'fonts', 'inter-700.woff2'));
      final cssFile = File(
          p.join(tempDir.path, 'lib', 'generated', 'fonts', 'fonts.g.css'));

      expect(font400.existsSync(), isTrue);
      expect(font700.existsSync(), isTrue);
      expect(cssFile.existsSync(), isTrue);

      final cssContent = cssFile.readAsStringSync();
      expect(cssContent, contains("font-family: 'Inter';"));
      expect(cssContent, contains('font-weight: 400;'));
      expect(
          cssContent,
          contains(
              "src: url('/generated/fonts/inter-400.woff2') format('woff2');"));
      expect(cssContent, contains('font-weight: 700;'));
      expect(
          cssContent,
          contains(
              "src: url('/generated/fonts/inter-700.woff2') format('woff2');"));
      expect(cssContent, contains("font-family: 'Inter Fallback';"));
      expect(cssContent, contains('size-adjust: 100%;'));
    });

    test(
        'prefers the Latin unicode subset when Google Fonts returns multiple blocks per weight',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'fonts.googleapis.com') {
          const mockCss = '''
@font-face {
  font-family: 'Plus Jakarta Sans';
  font-style: normal;
  font-weight: 800;
  src: url(https://fonts.gstatic.com/non-latin-800.woff2) format('woff2');
  unicode-range: U+0460-052F;
}
@font-face {
  font-family: 'Plus Jakarta Sans';
  font-style: normal;
  font-weight: 800;
  src: url(https://fonts.gstatic.com/latin-800.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
''';
          return http.Response(mockCss, 200);
        }
        if (request.url.path.endsWith('/latin-800.woff2')) {
          return http.Response.bytes([0x4c, 0x41, 0x54, 0x49, 0x4e], 200);
        }
        return http.Response.bytes(
            [0x4e, 0x4f, 0x4e, 0x4c, 0x41, 0x54, 0x49, 0x4e], 200);
      });

      final optimizer =
          BloomFontOptimizer(project: project, httpClient: mockClient);
      await optimizer.optimize(
        families: ['Plus Jakarta Sans'],
        weights: ['800'],
      );

      final font = File(p.join(
        tempDir.path,
        'lib',
        'generated',
        'fonts',
        'plus-jakarta-sans-800.woff2',
      ));
      expect(font.readAsBytesSync(), equals([0x4c, 0x41, 0x54, 0x49, 0x4e]));
    });

    test('supports custom sizeAdjustOverrides for CLS fallback metric',
        () async {
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

      final optimizer =
          BloomFontOptimizer(project: project, httpClient: mockClient);
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

    test('handles Google Fonts 404 or network failure gracefully with warnings',
        () async {
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

      final optimizer =
          BloomFontOptimizer(project: project, httpClient: mockClient);
      final result = await optimizer.optimize(
        families: ['NonExistentFont', 'Fira Code'],
        weights: ['400'],
      );

      expect(result.families, equals(['NonExistentFont', 'Fira Code']));
      expect(result.warnings.length, equals(1));
      expect(result.warnings.first, contains('HTTP 404'));
      expect(result.filesWritten, isNotEmpty);
      expect(
          File(p.join(tempDir.path, 'lib', 'generated', 'fonts',
                  'fira-code-400.woff2'))
              .existsSync(),
          isTrue);
    });

    test(
        'default client handles offline/unreachable network gracefully without throwing',
        () async {
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

    test(
        'downloads italic woff2 font files and generates CSS with font-style: italic',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'fonts.googleapis.com') {
          expect(request.url.query, contains(':ital,wght@1,400;1,700'));

          const mockCss = '''
@font-face {
  font-family: 'Inter';
  font-style: italic;
  font-weight: 400;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/inter/v18/inter-400-italic.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
@font-face {
  font-family: 'Inter';
  font-style: italic;
  font-weight: 700;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/inter/v18/inter-700-italic.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
''';
          return http.Response(mockCss, 200,
              headers: {'content-type': 'text/css'});
        } else if (request.url.host == 'fonts.gstatic.com') {
          return http.Response.bytes([0x77, 0x4F, 0x46, 0x32], 200);
        }
        return http.Response('Not Found', 404);
      });

      final optimizer =
          BloomFontOptimizer(project: project, httpClient: mockClient);
      final result = await optimizer.optimize(
        families: ['Inter'],
        weights: ['400', '700'],
        styles: ['italic'],
      );

      expect(result.warnings, isEmpty);
      expect(result.filesWritten.length, equals(3));

      final font400Italic = File(p.join(
          tempDir.path, 'lib', 'generated', 'fonts', 'inter-400-italic.woff2'));
      final font700Italic = File(p.join(
          tempDir.path, 'lib', 'generated', 'fonts', 'inter-700-italic.woff2'));
      final cssFile = File(
          p.join(tempDir.path, 'lib', 'generated', 'fonts', 'fonts.g.css'));

      expect(font400Italic.existsSync(), isTrue);
      expect(font700Italic.existsSync(), isTrue);
      expect(cssFile.existsSync(), isTrue);

      final cssContent = cssFile.readAsStringSync();
      expect(cssContent, contains("font-family: 'Inter';"));
      expect(cssContent, contains('font-style: italic;'));
      expect(cssContent, contains('font-weight: 400;'));
      expect(
          cssContent,
          contains(
              "src: url('/generated/fonts/inter-400-italic.woff2') format('woff2');"));
      expect(cssContent, contains('font-weight: 700;'));
      expect(
          cssContent,
          contains(
              "src: url('/generated/fonts/inter-700-italic.woff2') format('woff2');"));
    });

    test(
        'supports normal and italic together, generating distinct filenames and CSS rules',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'fonts.googleapis.com') {
          expect(request.url.query, contains(':ital,wght@0,400;1,400'));

          const mockCss = '''
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/inter/v18/inter-400.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
@font-face {
  font-family: 'Inter';
  font-style: italic;
  font-weight: 400;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/inter/v18/inter-400-italic.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
''';
          return http.Response(mockCss, 200,
              headers: {'content-type': 'text/css'});
        } else if (request.url.host == 'fonts.gstatic.com') {
          return http.Response.bytes([0x77, 0x4F, 0x46, 0x32], 200);
        }
        return http.Response('Not Found', 404);
      });

      final optimizer =
          BloomFontOptimizer(project: project, httpClient: mockClient);
      final result = await optimizer.optimize(
        families: ['Inter'],
        weights: ['400'],
        styles: ['normal', 'italic'],
      );

      expect(result.warnings, isEmpty);
      expect(result.filesWritten.length, equals(3)); // 2 woff2 + 1 css

      final fontNormal = File(
          p.join(tempDir.path, 'lib', 'generated', 'fonts', 'inter-400.woff2'));
      final fontItalic = File(p.join(
          tempDir.path, 'lib', 'generated', 'fonts', 'inter-400-italic.woff2'));
      expect(fontNormal.existsSync(), isTrue);
      expect(fontItalic.existsSync(), isTrue);

      final cssContent = File(result.cssPath).readAsStringSync();
      expect(cssContent, contains('font-style: normal;'));
      expect(cssContent, contains('font-style: italic;'));
      expect(
          cssContent,
          contains(
              "src: url('/generated/fonts/inter-400.woff2') format('woff2');"));
      expect(
          cssContent,
          contains(
              "src: url('/generated/fonts/inter-400-italic.woff2') format('woff2');"));
    });

    test('generates 900 weight font face when supplied', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'fonts.googleapis.com') {
          expect(request.url.query, contains(':wght@900'));
          const mockCss = '''
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 900;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/inter/v18/inter-900.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
''';
          return http.Response(mockCss, 200);
        } else if (request.url.host == 'fonts.gstatic.com') {
          return http.Response.bytes([0x77, 0x4F, 0x46, 0x32], 200);
        }
        return http.Response('Not Found', 404);
      });

      final optimizer =
          BloomFontOptimizer(project: project, httpClient: mockClient);
      final result = await optimizer.optimize(
        families: ['Inter'],
        weights: ['900'],
      );

      expect(result.warnings, isEmpty);
      final font900 = File(
          p.join(tempDir.path, 'lib', 'generated', 'fonts', 'inter-900.woff2'));
      expect(font900.existsSync(), isTrue);

      final cssContent = File(result.cssPath).readAsStringSync();
      expect(cssContent, contains('font-weight: 900;'));
      expect(
          cssContent,
          contains(
              "src: url('/generated/fonts/inter-900.woff2') format('woff2');"));
    });

    test(
        'strict mode (requireAllRequestedFaces) fails and emits warning when a face is missing',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'fonts.googleapis.com') {
          // Google Fonts only returns 400 face, missing 900
          const mockCss = '''
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/inter/v18/inter-400.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
''';
          return http.Response(mockCss, 200);
        } else if (request.url.host == 'fonts.gstatic.com') {
          return http.Response.bytes([0x77, 0x4F, 0x46, 0x32], 200);
        }
        return http.Response('Not Found', 404);
      });

      final optimizer =
          BloomFontOptimizer(project: project, httpClient: mockClient);
      final result = await optimizer.optimize(
        families: ['Inter'],
        weights: ['400', '900'],
        requireAllRequestedFaces: true,
      );

      // CSS path must be empty (no successful CSS bundle generated)
      expect(result.cssPath, isEmpty);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) =>
            w.contains('Missing requested font face') && w.contains('900')),
        isTrue,
      );
      final cssFile = File(
          p.join(tempDir.path, 'lib', 'generated', 'fonts', 'fonts.g.css'));
      expect(cssFile.existsSync(), isFalse);
    });

    test(
        'non-strict retains partial-result behavior when some requested faces are unavailable',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'fonts.googleapis.com') {
          // Returns 400, but 900 is absent
          const mockCss = '''
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url(https://fonts.gstatic.com/s/inter/v18/inter-400.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
''';
          return http.Response(mockCss, 200);
        } else if (request.url.host == 'fonts.gstatic.com') {
          return http.Response.bytes([0x77, 0x4F, 0x46, 0x32], 200);
        }
        return http.Response('Not Found', 404);
      });

      final optimizer =
          BloomFontOptimizer(project: project, httpClient: mockClient);
      final result = await optimizer.optimize(
        families: ['Inter'],
        weights: ['400', '900'],
        requireAllRequestedFaces: false,
      );

      // In non-strict mode, available face 400 produces a valid CSS bundle
      expect(result.cssPath, isNotEmpty);
      final cssFile = File(result.cssPath);
      expect(cssFile.existsSync(), isTrue);
      final cssContent = cssFile.readAsStringSync();
      expect(cssContent, contains('font-weight: 400;'));
      expect(cssContent, isNot(contains('font-weight: 900;')));
    });

    test('optimizeManifest throws ArgumentError if requests list is empty',
        () async {
      final optimizer = BloomFontOptimizer(project: project);
      expect(
        () => optimizer.optimizeManifest([]),
        throwsArgumentError,
      );
    });

    test(
        'optimizeManifest downloads requests and generates one combined fonts.g.css for Plus Jakarta 300..800 normal and JetBrains 400/700 normal+italic',
        () async {
      final req1 = FontFaceRequest.parse(
          'Plus Jakarta Sans:300,400,500,600,700,800:normal');
      final req2 =
          FontFaceRequest.parse('JetBrains Mono:400,700:normal,italic');

      final mockClient = MockClient((request) async {
        if (request.url.host == 'fonts.googleapis.com') {
          final query = request.url.query;
          if (query.contains('Plus+Jakarta+Sans') ||
              query.contains('Plus%20Jakarta%20Sans')) {
            const pjsCss = '''
@font-face {
  font-family: 'Plus Jakarta Sans';
  font-style: normal;
  font-weight: 300;
  src: url(https://fonts.gstatic.com/s/pjs/pjs-300.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
@font-face {
  font-family: 'Plus Jakarta Sans';
  font-style: normal;
  font-weight: 400;
  src: url(https://fonts.gstatic.com/s/pjs/pjs-400.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
@font-face {
  font-family: 'Plus Jakarta Sans';
  font-style: normal;
  font-weight: 500;
  src: url(https://fonts.gstatic.com/s/pjs/pjs-500.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
@font-face {
  font-family: 'Plus Jakarta Sans';
  font-style: normal;
  font-weight: 600;
  src: url(https://fonts.gstatic.com/s/pjs/pjs-600.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
@font-face {
  font-family: 'Plus Jakarta Sans';
  font-style: normal;
  font-weight: 700;
  src: url(https://fonts.gstatic.com/s/pjs/pjs-700.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
@font-face {
  font-family: 'Plus Jakarta Sans';
  font-style: normal;
  font-weight: 800;
  src: url(https://fonts.gstatic.com/s/pjs/pjs-800.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
''';
            return http.Response(pjsCss, 200,
                headers: {'content-type': 'text/css'});
          } else if (query.contains('JetBrains+Mono') ||
              query.contains('JetBrains%20Mono')) {
            const jbmCss = '''
@font-face {
  font-family: 'JetBrains Mono';
  font-style: normal;
  font-weight: 400;
  src: url(https://fonts.gstatic.com/s/jbm/jbm-400.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
@font-face {
  font-family: 'JetBrains Mono';
  font-style: normal;
  font-weight: 700;
  src: url(https://fonts.gstatic.com/s/jbm/jbm-700.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
@font-face {
  font-family: 'JetBrains Mono';
  font-style: italic;
  font-weight: 400;
  src: url(https://fonts.gstatic.com/s/jbm/jbm-400-italic.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
@font-face {
  font-family: 'JetBrains Mono';
  font-style: italic;
  font-weight: 700;
  src: url(https://fonts.gstatic.com/s/jbm/jbm-700-italic.woff2) format('woff2');
  unicode-range: U+0000-00FF;
}
''';
            return http.Response(jbmCss, 200,
                headers: {'content-type': 'text/css'});
          }
        } else if (request.url.host == 'fonts.gstatic.com') {
          return http.Response.bytes([0x77, 0x4F, 0x46, 0x32], 200);
        }
        return http.Response('Not Found', 404);
      });

      final optimizer =
          BloomFontOptimizer(project: project, httpClient: mockClient);
      final result = await optimizer.optimizeManifest([req1, req2]);

      expect(result.warnings, isEmpty);
      expect(result.families, equals(['Plus Jakarta Sans', 'JetBrains Mono']));
      // 6 woff2 for Plus Jakarta + 4 woff2 for JetBrains Mono + 1 fonts.g.css = 11 files
      expect(result.filesWritten.length, equals(11));

      final cssFile = File(result.cssPath);
      expect(cssFile.existsSync(), isTrue);
      final cssContent = cssFile.readAsStringSync();

      // Check Plus Jakarta Sans rules
      expect(cssContent, contains("font-family: 'Plus Jakarta Sans';"));
      for (final w in ['300', '400', '500', '600', '700', '800']) {
        expect(cssContent, contains('font-weight: $w;'));
        expect(
            cssContent,
            contains(
                "src: url('/generated/fonts/plus-jakarta-sans-$w.woff2') format('woff2');"));
      }
      expect(
          cssContent, contains("font-family: 'Plus Jakarta Sans Fallback';"));

      // Check JetBrains Mono rules
      expect(cssContent, contains("font-family: 'JetBrains Mono';"));
      expect(cssContent, contains('font-style: normal;'));
      expect(cssContent, contains('font-style: italic;'));
      expect(
          cssContent,
          contains(
              "src: url('/generated/fonts/jetbrains-mono-400.woff2') format('woff2');"));
      expect(
          cssContent,
          contains(
              "src: url('/generated/fonts/jetbrains-mono-700.woff2') format('woff2');"));
      expect(
          cssContent,
          contains(
              "src: url('/generated/fonts/jetbrains-mono-400-italic.woff2') format('woff2');"));
      expect(
          cssContent,
          contains(
              "src: url('/generated/fonts/jetbrains-mono-700-italic.woff2') format('woff2');"));
      expect(cssContent, contains("font-family: 'JetBrains Mono Fallback';"));
    });
  });

  group('FontFaceRequest', () {
    test('parses standard Family:weights:styles manifest spec', () {
      final req = FontFaceRequest.parse(
          'Plus Jakarta Sans:300,400,500,600,700,800:normal');
      expect(req.family, equals('Plus Jakarta Sans'));
      expect(
        req.weights,
        equals(['300', '400', '500', '600', '700', '800']),
      );
      expect(req.styles, equals(['normal']));
    });

    test('parses comma-separated values with whitespace and multiple styles',
        () {
      final req = FontFaceRequest.parse(
          '  JetBrains Mono : 400 , 700 : normal , italic  ');
      expect(req.family, equals('JetBrains Mono'));
      expect(req.weights, equals(['400', '700']));
      expect(req.styles, equals(['normal', 'italic']));
    });

    test('implements value equality and hashCode', () {
      final req1 = FontFaceRequest(
        family: 'Inter',
        weights: ['400', '700'],
        styles: ['normal', 'italic'],
      );
      final req2 = FontFaceRequest(
        family: 'Inter',
        weights: ['400', '700'],
        styles: ['normal', 'italic'],
      );
      final req3 = FontFaceRequest(
        family: 'Inter',
        weights: ['400'],
        styles: ['normal'],
      );

      expect(req1, equals(req2));
      expect(req1.hashCode, equals(req2.hashCode));
      expect(req1, isNot(equals(req3)));
    });

    test('throws ArgumentError on malformed format', () {
      expect(() => FontFaceRequest.parse(''), throwsArgumentError);
      expect(() => FontFaceRequest.parse('Inter'), throwsArgumentError);
      expect(() => FontFaceRequest.parse('Inter:400'), throwsArgumentError);
      expect(() => FontFaceRequest.parse('Inter:400:normal:extra'),
          throwsArgumentError);
    });

    test('throws ArgumentError on empty family', () {
      expect(() => FontFaceRequest.parse(':400:normal'), throwsArgumentError);
      expect(
          () => FontFaceRequest.parse('   :400:normal'), throwsArgumentError);
    });

    test('throws ArgumentError on empty weights', () {
      expect(() => FontFaceRequest.parse('Inter::normal'), throwsArgumentError);
      expect(
          () => FontFaceRequest.parse('Inter:  :normal'), throwsArgumentError);
    });

    test('throws ArgumentError on empty styles', () {
      expect(() => FontFaceRequest.parse('Inter:400:'), throwsArgumentError);
      expect(() => FontFaceRequest.parse('Inter:400:   '), throwsArgumentError);
    });

    test('throws ArgumentError on invalid weight', () {
      expect(
          () => FontFaceRequest.parse('Inter:450:normal'), throwsArgumentError);
      expect(() => FontFaceRequest.parse('Inter:bold:normal'),
          throwsArgumentError);
    });

    test('throws ArgumentError on invalid style', () {
      expect(() => FontFaceRequest.parse('Inter:400:oblique'),
          throwsArgumentError);
      expect(
          () => FontFaceRequest.parse('Inter:400:bold'), throwsArgumentError);
    });
  });

  group('FontCommand CLI with --face option', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('bloom_font_cmd_face_test_');
      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('name: test_font_cmd_app\nversion: 1.0.0\n');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('returns 1 when neither --family nor --face is provided', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(FontCommand());

      final exitCode = await runZoned(
        () => runner.run(['fonts', 'optimize', '--project-dir', tempDir.path]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, equals(1));
      final fullOutput = logs.join('\n');
      expect(fullOutput, contains('At least one --family must be specified'));
    });

    test('returns 1 when --face is mixed with --family', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(FontCommand());

      final exitCode = await runZoned(
        () => runner.run([
          'fonts',
          'optimize',
          '--face',
          'Inter:400:normal',
          '--family',
          'Roboto',
          '--project-dir',
          tempDir.path,
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, equals(1));
      final fullOutput = logs.join('\n');
      expect(
        fullOutput,
        contains(
            'Cannot mix --face with explicit --family, --weight, or --style options.'),
      );
    });

    test('returns 1 when --face is mixed with explicit --weight', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(FontCommand());

      final exitCode = await runZoned(
        () => runner.run([
          'fonts',
          'optimize',
          '--face',
          'Inter:400:normal',
          '--weight',
          '700',
          '--project-dir',
          tempDir.path,
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, equals(1));
      final fullOutput = logs.join('\n');
      expect(
        fullOutput,
        contains(
            'Cannot mix --face with explicit --family, --weight, or --style options.'),
      );
    });

    test('returns 1 when --face is mixed with explicit --style', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(FontCommand());

      final exitCode = await runZoned(
        () => runner.run([
          'fonts',
          'optimize',
          '--face',
          'Inter:400:normal',
          '--style',
          'italic',
          '--project-dir',
          tempDir.path,
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, equals(1));
      final fullOutput = logs.join('\n');
      expect(
        fullOutput,
        contains(
            'Cannot mix --face with explicit --family, --weight, or --style options.'),
      );
    });

    test('returns 1 when malformed --face is provided', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(FontCommand());

      final exitCode = await runZoned(
        () => runner.run([
          'fonts',
          'optimize',
          '--face',
          'Inter:invalid_weight:normal',
          '--project-dir',
          tempDir.path,
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, equals(1));
      final fullOutput = logs.join('\n');
      expect(fullOutput, contains('is not an allowed font weight'));
    });
  });
}
