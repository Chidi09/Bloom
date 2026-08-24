// packages/bloom_cli/test/og_command_test.dart
import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:bloom_cli/src/assets/og_image_generator.dart';
import 'package:bloom_cli/src/commands/og_command.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('OgCommand CLI', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bloom_og_cmd_test_');
      final bloomYaml = File(p.join(tempDir.path, 'bloom.yaml'));
      bloomYaml.writeAsStringSync('name: test_og_app\nversion: 1.0.0\n');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('returns 1 when --project-dir is not a valid Bloom project', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(OgCommand());

      final exitCode = await runZoned(
        () => runner.run([
          'og',
          'generate',
          '--title',
          'Hello World',
          '--project-dir',
          '/non/existent/path/xyz',
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, equals(1));
      final fullOutput = logs.join('\n');
      expect(fullOutput, contains('Not a valid Bloom project directory'));
    });

    test('generates social card PNG at default location', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(OgCommand());

      final exitCode = await runZoned(
        () => runner.run([
          'og',
          'generate',
          '--title',
          'Bloom Documentation',
          '--subtitle',
          'Fast full-stack Flutter and Dart web applications.',
          '--eyebrow',
          'Guide',
          '--theme',
          'dark',
          '--project-dir',
          tempDir.path,
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, equals(0));
      final fullOutput = logs.join('\n');
      expect(fullOutput, contains('Generated Open Graph image'));
      expect(fullOutput, contains('1200x630'));

      final defaultOut = File(p.join(tempDir.path, 'lib/generated/og/social-card.png'));
      expect(defaultOut.existsSync(), isTrue);

      final bytes = defaultOut.readAsBytesSync();
      expect(bytes, isNotEmpty);

      final decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(kOgImageWidth));
      expect(decoded.height, equals(kOgImageHeight));
    });

    test('generates social card PNG at custom --out path and light theme', () async {
      final logs = <String>[];
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')
        ..addCommand(OgCommand());

      final customRelativeOut = 'static/social/pricing-card.png';
      final exitCode = await runZoned(
        () => runner.run([
          'og',
          'generate',
          '--title',
          'Pricing Plans',
          '--theme',
          'light',
          '--out',
          customRelativeOut,
          '--project-dir',
          tempDir.path,
        ]),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ),
      );

      expect(exitCode, equals(0));
      final customOut = File(p.join(tempDir.path, customRelativeOut));
      expect(customOut.existsSync(), isTrue);

      final decoded = img.decodeImage(customOut.readAsBytesSync());
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(1200));
      expect(decoded.height, equals(630));
    });
  });
}
