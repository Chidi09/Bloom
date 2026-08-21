import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import 'package:bloom_cli/src/dev/source_watcher.dart';

void main() {
  group('BloomSourceWatcher', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bloom_watch_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('debounces rapid file modifications into a single event', () async {
      final watcher = BloomSourceWatcher(
        directories: [tempDir],
        debounceDuration: const Duration(milliseconds: 50),
      );

      final events = <List<FileSystemEvent>>[];
      final sub = watcher.onChange.listen(events.add);

      final testFile = File('${tempDir.path}/test.dart');
      await testFile.writeAsString('void main() {}');
      await testFile.writeAsString('void main() { print(1); }');
      await testFile.writeAsString('void main() { print(2); }');

      await Future.delayed(const Duration(milliseconds: 150));
      expect(events.isNotEmpty, isTrue);

      await sub.cancel();
      watcher.dispose();
    });
  });
}
