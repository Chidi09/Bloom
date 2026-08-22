import 'dart:io';
import 'package:test/test.dart';
import 'package:bloom_cli/src/dev/server_supervisor.dart';

void main() {
  group('BloomServerSupervisor', () {
    late File entryFile;

    setUp(() async {
      entryFile = File('${Directory.systemTemp.path}/bloom_test_entry_${DateTime.now().millisecondsSinceEpoch}.dart');
      await entryFile.writeAsString('void main() { print("server running"); }');
    });

    tearDown(() async {
      if (await entryFile.exists()) await entryFile.delete();
    });

    test('isRunning is false before start()', () {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      expect(supervisor.isRunning, isFalse);
    });

    test('currentPid is null before start()', () {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      expect(supervisor.currentPid, isNull);
    });

    test('start() sets isRunning to true', () async {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      await supervisor.start();
      expect(supervisor.isRunning, isTrue);
      await supervisor.stop();
    });

    test('stop() sets isRunning to false', () async {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      await supervisor.start();
      await supervisor.stop();
      expect(supervisor.isRunning, isFalse);
    });

    test('restart() changes the process PID', () async {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      await supervisor.start();
      final pid1 = supervisor.currentPid;
      await supervisor.restart(reason: 'file.dart');
      final pid2 = supervisor.currentPid;
      expect(pid1, isNotNull);
      expect(pid2, isNotNull);
      expect(pid1 == pid2, isFalse);
      await supervisor.stop();
    });

    test('onOutput stream receives stdout', () async {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      final output = <String>[];
      supervisor.onOutput.listen(output.add);
      await supervisor.start();
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!output.any((l) => l.contains('server running')) &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await supervisor.stop();
      expect(output.any((l) => l.contains('server running')), isTrue);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('double stop() is idempotent', () async {
      final supervisor = BloomServerSupervisor(entryFile: entryFile);
      await supervisor.start();
      await supervisor.stop();
      expect(() => supervisor.stop(), returnsNormally);
    });
  });
}
