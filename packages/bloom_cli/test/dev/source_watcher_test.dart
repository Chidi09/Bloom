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

    test('watches newly-created directories without restarting', () async {
      final watcher = BloomSourceWatcher(
        directories: [tempDir],
        debounceDuration: const Duration(milliseconds: 30),
      );
      final events = <List<FileSystemEvent>>[];
      final sub = watcher.onChange.listen(events.add);

      final nested = Directory('${tempDir.path}/pages');
      await nested.create();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await File('${nested.path}/home.dart').writeAsString('void home() {}');

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
          events
              .expand((batch) => batch)
              .any((e) => e.path.endsWith('home.dart')),
          isTrue);

      await sub.cancel();
      watcher.dispose();
    });

    test('watches multiple roots', () async {
      final webDir = Directory('${tempDir.path}/web');
      await webDir.create();
      final watcher = BloomSourceWatcher(
        directories: [tempDir, webDir],
        debounceDuration: const Duration(milliseconds: 30),
      );
      final events = <List<FileSystemEvent>>[];
      final sub = watcher.onChange.listen(events.add);

      final index = File('${webDir.path}/index.html');
      await index.writeAsString('<title>Bloom</title>');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
          events
              .expand((batch) => batch)
              .any((e) => e.path.endsWith('index.html')),
          isTrue);

      await sub.cancel();
      watcher.dispose();
    });
  });
}
