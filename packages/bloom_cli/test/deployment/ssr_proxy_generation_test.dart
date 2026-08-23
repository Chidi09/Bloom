import 'dart:io';
import 'package:bloom_cli/src/utils/project.dart';
import 'package:bloom_cli/src/web/ssr_engine.dart';
import 'package:test/test.dart';

void main() {
  group('generated SSR proxy', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bloom_ssr_proxy_');
      File('${tempDir.path}/bloom.yaml').writeAsStringSync('''
name: proxyprobe
proxy:
  "/gh":
    target: "https://github.com"
    strip_prefix: true
''');
      Directory('${tempDir.path}/lib/app/pages').createSync(recursive: true);
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('streams the upstream body instead of buffering it', () async {
      final project = BloomProject.find(tempDir)!;
      final generated = await BloomSsrEngine(project: project).generate();
      final code = generated.readAsStringSync();

      expect(code, contains('BloomResponse.stream('));
      // The buffering fold is exactly what this task removes.
      expect(code, isNot(contains('fold<List<int>>')));
    });
  });
}
