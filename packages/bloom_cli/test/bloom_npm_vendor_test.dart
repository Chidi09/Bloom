import 'dart:io';
import 'package:bloom_cli/src/npm/npm_vendor_assembler.dart';
import 'package:bloom_cli/src/utils/project.dart';
import 'package:test/test.dart';

void main() {
  group('NpmVendorAssembler', () {
    test('detects local vendor dependencies and builds import map', () async {
      final tempDir = Directory.systemTemp.createTempSync('bloom_vendor_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

File('${tempDir.path}/bloom.yaml').writeAsStringSync('''
name: test_app
target: web_dom
npm_packages:
  canvas-confetti:
    npm_name: canvas-confetti
    version: 1.9.3
    vendor_file: web/vendor/canvas-confetti.min.js
    dart_binding: lib/src/plugins/canvas_confetti.dart
  lucide:
    npm_name: lucide
    version: 0.460.0
    vendor_file: web/vendor/lucide.min.js
    dart_binding: lib/src/plugins/lucide.dart
''');

      Directory('${tempDir.path}/web').createSync(recursive: true);
      File('${tempDir.path}/web/index.html').writeAsStringSync('<html><head></head><body></body></html>');

      final project = BloomProject.fromDirectory(tempDir);
      final assembler = NpmVendorAssembler(project);
      expect(assembler, isNotNull);
      expect(assembler.manifest.count, 2);
    });

    test('hasBun getter returns boolean without throwing', () {
      expect(NpmVendorAssembler.hasBun, isA<bool>());
    });
  });
}
