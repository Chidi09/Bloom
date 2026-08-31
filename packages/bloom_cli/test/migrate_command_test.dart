// test/migrate_command_test.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:bloom_cli/src/commands/migrate_command.dart';

void main() {
  late Directory tempDir;
  late StringBuffer stdoutBuf;
  late StringBuffer stderrBuf;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_migrate_test_');
    stdoutBuf = StringBuffer();
    stderrBuf = StringBuffer();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  void _setupMockProject(
    Directory dir, {
    bool includePubspec = true,
    bool includeBloomMigrateDep = true,
    bool inDevDeps = false,
    bool inOverrides = false,
    bool inPackageConfigOnly = false,
  }) {
    if (!includePubspec) return;

    if (inPackageConfigOnly) {
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_project
version: 1.0.0
environment:
  sdk: '>=3.3.0 <4.0.0'
''');
      final dartToolDir = Directory(p.join(dir.path, '.dart_tool'))
        ..createSync(recursive: true);
      File(p.join(dartToolDir.path, 'package_config.json'))
          .writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "bloom_migrate",
      "rootUri": "../packages/bloom_migrate"
    }
  ]
}
''');
      return;
    }

    final pubspecLines = [
      'name: test_project',
      'version: 1.0.0',
      'environment:',
      "  sdk: '>=3.3.0 <4.0.0'",
    ];

    if (includeBloomMigrateDep) {
      if (inDevDeps) {
        pubspecLines.addAll([
          'dev_dependencies:',
          '  bloom_migrate: ^0.1.0',
        ]);
      } else if (inOverrides) {
        pubspecLines.addAll([
          'dependency_overrides:',
          '  bloom_migrate: ^0.1.0',
        ]);
      } else {
        pubspecLines.addAll([
          'dependencies:',
          '  bloom_migrate: ^0.1.0',
        ]);
      }
    }

    File(p.join(dir.path, 'pubspec.yaml'))
        .writeAsStringSync(pubspecLines.join('\n') + '\n');
  }

  group('MigrateCommand Top-Level', () {
    test('throws UsageException when invoked without subcommands', () async {
      final cmd = MigrateCommand(targetDir: tempDir);
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);

      expect(() => runner.run(['migrate']), throwsA(isA<UsageException>()));
    });

    test('registers all subcommands: make, apply, status, rollback', () {
      final cmd = MigrateCommand(targetDir: tempDir);
      expect(cmd.subcommands.keys,
          containsAll(['make', 'apply', 'status', 'rollback']));
    });

    test('rejects invalid option values like disallowed dialect', () async {
      _setupMockProject(tempDir);
      final cmd = MigrateCommand(targetDir: tempDir);
      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);

      expect(
        () => runner.run(['migrate', 'make', '--dialect', 'oracle']),
        throwsA(isA<UsageException>()),
      );
    });
  });

  group('Precondition validation & error handling', () {
    test('fails with clear error and exit code 1 when pubspec.yaml is absent',
        () async {
      var processCalled = false;
      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          processCalled = true;
          return ProcessResult(0, 0, '', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run(['migrate', 'apply']);

      expect(exitCode, 1);
      expect(processCalled, isFalse);
      expect(stderrBuf.toString(),
          contains('Cannot run migrations: pubspec.yaml not found'));
    });

    test(
        'fails with clear error and exit code 1 when bloom_migrate is not resolvable',
        () async {
      _setupMockProject(tempDir, includeBloomMigrateDep: false);

      var processCalled = false;
      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          processCalled = true;
          return ProcessResult(0, 0, '', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run(['migrate', 'status']);

      expect(exitCode, 1);
      expect(processCalled, isFalse);
      expect(stderrBuf.toString(),
          contains('Package "bloom_migrate" is not resolvable'));
    });

    test('resolves bloom_migrate when declared in dev_dependencies', () async {
      _setupMockProject(tempDir, inDevDeps: true);

      var processCalled = false;
      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          processCalled = true;
          return ProcessResult(0, 0, 'OK\n', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run(['migrate', 'status']);

      expect(exitCode, 0);
      expect(processCalled, isTrue);
    });

    test('resolves bloom_migrate when declared in dependency_overrides',
        () async {
      _setupMockProject(tempDir, inOverrides: true);

      var processCalled = false;
      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          processCalled = true;
          return ProcessResult(0, 0, 'OK\n', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run(['migrate', 'status']);

      expect(exitCode, 0);
      expect(processCalled, isTrue);
    });

    test('resolves bloom_migrate when found in .dart_tool/package_config.json',
        () async {
      _setupMockProject(tempDir, inPackageConfigOnly: true);

      var processCalled = false;
      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          processCalled = true;
          return ProcessResult(0, 0, 'OK\n', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run(['migrate', 'status']);

      expect(exitCode, 0);
      expect(processCalled, isTrue);
    });
  });

  group('Argument Mapping & Subcommand Forwarding', () {
    test('make -> bloom_migrate makemigrations with positional app and options',
        () async {
      _setupMockProject(tempDir);

      String? capturedExe;
      List<String>? capturedArgs;
      String? capturedWorkingDir;

      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          capturedExe = exe;
          capturedArgs = args;
          capturedWorkingDir = workingDirectory;
          return ProcessResult(1234, 0, 'Created migration\n', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run([
        'migrate',
        'make',
        'accounts',
        '--name',
        'add_users_table',
        '--dialect',
        'sqlite',
        '--dir',
        'custom_migrations',
      ]);

      expect(exitCode, 0);
      expect(capturedExe, 'dart');
      expect(capturedWorkingDir, tempDir.path);
      expect(capturedArgs, [
        'run',
        'bloom_migrate',
        'makemigrations',
        'accounts',
        '--name',
        'add_users_table',
        '--dialect',
        'sqlite',
        '--dir',
        'custom_migrations',
      ]);
    });

    test('make supports short abbreviations -n and -d', () async {
      _setupMockProject(tempDir);

      List<String>? capturedArgs;

      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          capturedArgs = args;
          return ProcessResult(1234, 0, '', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run([
        'migrate',
        'make',
        'notes',
        '-n',
        'initial',
        '-d',
        'db/migrations',
      ]);

      expect(exitCode, 0);
      expect(capturedArgs, [
        'run',
        'bloom_migrate',
        'makemigrations',
        'notes',
        '--name',
        'initial',
        '--dir',
        'db/migrations',
      ]);
    });

    test('apply -> bloom_migrate migrate with options', () async {
      _setupMockProject(tempDir);

      String? capturedExe;
      List<String>? capturedArgs;
      String? capturedWorkingDir;

      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          capturedExe = exe;
          capturedArgs = args;
          capturedWorkingDir = workingDirectory;
          return ProcessResult(1234, 0, 'Applied 2 migrations\n', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run([
        'migrate',
        'apply',
        '--url',
        'postgres://user:pass@localhost:5432/mydb',
        '--dir',
        'db/migrations',
        '--app',
        'notes',
        '--step',
        '1',
      ]);

      expect(exitCode, 0);
      expect(capturedExe, 'dart');
      expect(capturedWorkingDir, tempDir.path);
      expect(capturedArgs, [
        'run',
        'bloom_migrate',
        'migrate',
        '--url',
        'postgres://user:pass@localhost:5432/mydb',
        '--dir',
        'db/migrations',
        '--app',
        'notes',
        '--step',
        '1',
      ]);
    });

    test('apply supports short abbreviations -u, -d, -a, -s', () async {
      _setupMockProject(tempDir);

      List<String>? capturedArgs;

      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          capturedArgs = args;
          return ProcessResult(1234, 0, '', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run([
        'migrate',
        'apply',
        '-u',
        'sqlite:dev.db',
        '-d',
        'migrations',
        '-a',
        'accounts',
        '-s',
        '3',
      ]);

      expect(exitCode, 0);
      expect(capturedArgs, [
        'run',
        'bloom_migrate',
        'migrate',
        '--url',
        'sqlite:dev.db',
        '--dir',
        'migrations',
        '--app',
        'accounts',
        '--step',
        '3',
      ]);
    });

    test('status -> bloom_migrate status with options', () async {
      _setupMockProject(tempDir);

      String? capturedExe;
      List<String>? capturedArgs;
      String? capturedWorkingDir;

      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          capturedExe = exe;
          capturedArgs = args;
          capturedWorkingDir = workingDirectory;
          return ProcessResult(1234, 0, 'Migration Status\n', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run([
        'migrate',
        'status',
        '--url',
        'sqlite:dev.db',
        '--dir',
        'migrations',
        '--app',
        'accounts',
      ]);

      expect(exitCode, 0);
      expect(capturedExe, 'dart');
      expect(capturedWorkingDir, tempDir.path);
      expect(capturedArgs, [
        'run',
        'bloom_migrate',
        'status',
        '--url',
        'sqlite:dev.db',
        '--dir',
        'migrations',
        '--app',
        'accounts',
      ]);
    });

    test('rollback -> bloom_migrate rollback with options', () async {
      _setupMockProject(tempDir);

      String? capturedExe;
      List<String>? capturedArgs;
      String? capturedWorkingDir;

      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          capturedExe = exe;
          capturedArgs = args;
          capturedWorkingDir = workingDirectory;
          return ProcessResult(1234, 0, 'Rolled back 1 migration\n', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run([
        'migrate',
        'rollback',
        '--url',
        'postgres://user:pass@localhost:5432/mydb',
        '--dir',
        'migrations',
        '--app',
        'accounts',
        '--count',
        '2',
      ]);

      expect(exitCode, 0);
      expect(capturedExe, 'dart');
      expect(capturedWorkingDir, tempDir.path);
      expect(capturedArgs, [
        'run',
        'bloom_migrate',
        'rollback',
        '--url',
        'postgres://user:pass@localhost:5432/mydb',
        '--dir',
        'migrations',
        '--app',
        'accounts',
        '--count',
        '2',
      ]);
    });

    test('rollback supports short abbreviations -u, -d, -a, -c', () async {
      _setupMockProject(tempDir);

      List<String>? capturedArgs;

      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          capturedArgs = args;
          return ProcessResult(1234, 0, '', '');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run([
        'migrate',
        'rollback',
        '-u',
        'sqlite:dev.db',
        '-d',
        'migrations',
        '-a',
        'accounts',
        '-c',
        '4',
      ]);

      expect(exitCode, 0);
      expect(capturedArgs, [
        'run',
        'bloom_migrate',
        'rollback',
        '--url',
        'sqlite:dev.db',
        '--dir',
        'migrations',
        '--app',
        'accounts',
        '--count',
        '4',
      ]);
    });
  });

  group('Output forwarding & Exit code propagation', () {
    test('forwards child process stdout and stderr', () async {
      _setupMockProject(tempDir);

      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          return ProcessResult(
              1234, 0, 'Stdout line 1\nStdout line 2\n', 'Stderr warning\n');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run(['migrate', 'apply']);

      expect(exitCode, 0);
      expect(stdoutBuf.toString(), 'Stdout line 1\nStdout line 2\n');
      expect(stderrBuf.toString(), 'Stderr warning\n');
    });

    test('propagates non-zero exit code from child process', () async {
      _setupMockProject(tempDir);

      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          return ProcessResult(
              1234, 42, 'Some output\n', 'Database connection failed\n');
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run(['migrate', 'apply']);

      expect(exitCode, 42);
      expect(stdoutBuf.toString(), 'Some output\n');
      expect(stderrBuf.toString(), 'Database connection failed\n');
    });

    test('handles process executor exception gracefully', () async {
      _setupMockProject(tempDir);

      final cmd = MigrateCommand(
        targetDir: tempDir,
        customStdout: stdoutBuf,
        customStderr: stderrBuf,
        processExecutor: (exe, args,
            {environment,
            includeParentEnvironment = true,
            runInShell = false,
            workingDirectory}) async {
          throw const ProcessException(
              'dart', ['run'], 'Executable not found', 2);
        },
      );

      final runner = CommandRunner<int>('bloom', 'Bloom CLI')..addCommand(cmd);
      final exitCode = await runner.run(['migrate', 'apply']);

      expect(exitCode, 1);
      expect(stderrBuf.toString(), contains('Failed to run bloom_migrate:'));
    });
  });
}
