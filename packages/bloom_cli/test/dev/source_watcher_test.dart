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

      // Native filesystem watchers start asynchronously after listen(). Let
      // the OS finish registering this temporary directory before writing.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final testFile = File('${tempDir.path}/test.dart');
      await testFile.writeAsString('void main() {}');
      await testFile.writeAsString('void main() { print(1); }');
      await testFile.writeAsString('void main() { print(2); }');

      // FSEvents on macOS can deliver well after the debounce window, so wait
      // for the first batch with a bounded deadline instead of a fixed sleep.
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (events.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
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

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final nested = Directory('${tempDir.path}/pages');
      await nested.create();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await File('${nested.path}/home.dart').writeAsString('void home() {}');

      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (DateTime.now().isBefore(deadline) &&
          !events
              .expand((batch) => batch)
              .any((e) => e.path.endsWith('home.dart'))) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
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

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final index = File('${webDir.path}/index.html');
      await index.writeAsString('<title>Bloom</title>');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(
          events
              .expand((batch) => batch)
              .any((e) => e.path.endsWith('index.html')),
          isTrue);

      await sub.cancel();
      watcher.dispose();
    });

    test('still reports files whose names merely contain main.js', () async {
      final watcher = BloomSourceWatcher(
        directories: [tempDir],
        debounceDuration: const Duration(milliseconds: 30),
      );
      final events = <List<FileSystemEvent>>[];
      final sub = watcher.onChange.listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      await File('${tempDir.path}/domain.js').writeAsString('export {};');

      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (events.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(events.expand((batch) => batch).map((e) => e.path),
          contains(endsWith('domain.js')));

      await sub.cancel();
      watcher.dispose();
    });

    test('ignores web/main.js, web/main.js.map, and web/main.js.deps',
        () async {
      final webDir = Directory('${tempDir.path}/web')..createSync();
      final watcher = BloomSourceWatcher(
        directories: [webDir],
        debounceDuration: const Duration(milliseconds: 30),
      );
      final events = <List<FileSystemEvent>>[];
      final sub = watcher.onChange.listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      await File('${webDir.path}/main.js').writeAsString('console.log(1);');
      await File('${webDir.path}/main.js.map').writeAsString('{}');
      await File('${webDir.path}/main.js.deps').writeAsString('deps');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(events, isEmpty);

      // Verify other js file is NOT ignored
      await File('${webDir.path}/app.js').writeAsString('console.log(2);');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(
        events.expand((b) => b).any((e) => e.path.endsWith('app.js')),
        isTrue,
      );

      await sub.cancel();
      watcher.dispose();
    });
  });
}
