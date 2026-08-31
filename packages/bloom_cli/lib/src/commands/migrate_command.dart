// lib/src/commands/migrate_command.dart
import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../utils/ansi.dart';

typedef ProcessExecutor = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment,
  bool runInShell,
});

/// Top-level command `bloom migrate` that orchestrates database migrations.
///
/// Delegates execution to the target project's `bloom_migrate` package via subprocess.
/// Subcommands: `make`, `apply`, `status`, `rollback`.
class MigrateCommand extends Command<int> {
  @override
  final String name = 'migrate';

  @override
  final String description =
      'Manage and execute database migrations for Bloom applications.';

  MigrateCommand({
    ProcessExecutor? processExecutor,
    Directory? targetDir,
    StringSink? customStdout,
    StringSink? customStderr,
  }) {
    addSubcommand(_MigrateMakeCommand(
      processExecutor: processExecutor,
      targetDir: targetDir,
      customStdout: customStdout,
      customStderr: customStderr,
    ));
    addSubcommand(_MigrateApplyCommand(
      processExecutor: processExecutor,
      targetDir: targetDir,
      customStdout: customStdout,
      customStderr: customStderr,
    ));
    addSubcommand(_MigrateStatusCommand(
      processExecutor: processExecutor,
      targetDir: targetDir,
      customStdout: customStdout,
      customStderr: customStderr,
    ));
    addSubcommand(_MigrateRollbackCommand(
      processExecutor: processExecutor,
      targetDir: targetDir,
      customStdout: customStdout,
      customStderr: customStderr,
    ));
  }

  @override
  Future<int> run() async {
    printUsage();
    return 0;
  }
}

abstract class _BaseMigrateSubcommand extends Command<int> {
  final ProcessExecutor? _processExecutor;
  final Directory? _targetDir;
  final StringSink? _customStdout;
  final StringSink? _customStderr;

  _BaseMigrateSubcommand({
    ProcessExecutor? processExecutor,
    Directory? targetDir,
    StringSink? customStdout,
    StringSink? customStderr,
  })  : _processExecutor = processExecutor,
        _targetDir = targetDir,
        _customStdout = customStdout,
        _customStderr = customStderr;

  String get mappedCommand;

  List<String> buildForwardedArgs();

  Directory get resolvedTargetDir => _targetDir ?? Directory.current;

  StringSink get resolvedStdout => _customStdout ?? stdout;
  StringSink get resolvedStderr => _customStderr ?? stderr;

  @override
  Future<int> run() async {
    final targetDir = resolvedTargetDir;
    final pubspecFile = File(p.join(targetDir.path, 'pubspec.yaml'));

    if (!pubspecFile.existsSync()) {
      resolvedStderr.writeln(
        Ansi.error(
            'Cannot run migrations: pubspec.yaml not found in ${targetDir.path}.'),
      );
      return 1;
    }

    if (!_isBloomMigrateResolvable(targetDir)) {
      resolvedStderr.writeln(
        Ansi.error(
          'Package "bloom_migrate" is not resolvable in ${targetDir.path}. '
          'Please add bloom_migrate to your pubspec.yaml and run "dart pub get".',
        ),
      );
      return 1;
    }

    final forwarded = buildForwardedArgs();
    final processArgs = ['run', 'bloom_migrate', mappedCommand, ...forwarded];

    final executor = _processExecutor ?? Process.run;

    try {
      final result = await executor(
        'dart',
        processArgs,
        workingDirectory: targetDir.path,
      );

      final stdoutStr = result.stdout.toString();
      if (stdoutStr.isNotEmpty) {
        resolvedStdout.write(stdoutStr);
      }

      final stderrStr = result.stderr.toString();
      if (stderrStr.isNotEmpty) {
        resolvedStderr.write(stderrStr);
      }

      return result.exitCode;
    } catch (e) {
      resolvedStderr.writeln(Ansi.error('Failed to run bloom_migrate: $e'));
      return 1;
    }
  }

  bool _isBloomMigrateResolvable(Directory dir) {
    final pubspecFile = File(p.join(dir.path, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return false;

    try {
      final content = pubspecFile.readAsStringSync();
      final doc = loadYaml(content);
      if (doc is Map) {
        final deps = doc['dependencies'];
        final devDeps = doc['dev_dependencies'];
        final overrides = doc['dependency_overrides'];
        if ((deps is Map && deps.containsKey('bloom_migrate')) ||
            (devDeps is Map && devDeps.containsKey('bloom_migrate')) ||
            (overrides is Map && overrides.containsKey('bloom_migrate'))) {
          return true;
        }
      }
    } catch (_) {}

    final packageConfigFile =
        File(p.join(dir.path, '.dart_tool', 'package_config.json'));
    if (packageConfigFile.existsSync()) {
      try {
        final content = packageConfigFile.readAsStringSync();
        if (content.contains('"name": "bloom_migrate"') ||
            content.contains('"name":"bloom_migrate"')) {
          return true;
        }
      } catch (_) {}
    }

    return false;
  }
}

class _MigrateMakeCommand extends _BaseMigrateSubcommand {
  @override
  final String name = 'make';

  @override
  final String description =
      'Generates a new numbered .sql migration file for an app.';

  @override
  String get mappedCommand => 'makemigrations';

  _MigrateMakeCommand({
    super.processExecutor,
    super.targetDir,
    super.customStdout,
    super.customStderr,
  }) {
    argParser
      ..addOption(
        'name',
        abbr: 'n',
        help:
            'Custom name suffix for the migration (e.g. "initial", "add_tokens").',
      )
      ..addOption(
        'dir',
        abbr: 'd',
        help: 'Base migrations directory path.',
      )
      ..addOption(
        'dialect',
        help: 'Target SQL dialect (postgres or sqlite).',
        allowed: ['postgres', 'sqlite'],
      );
  }

  @override
  List<String> buildForwardedArgs() {
    final args = <String>[];
    final rest = argResults?.rest ?? [];
    if (rest.isNotEmpty) {
      args.addAll(rest);
    }
    if (argResults?.wasParsed('name') ?? false) {
      args.addAll(['--name', argResults!['name'] as String]);
    }
    if (argResults?.wasParsed('dialect') ?? false) {
      args.addAll(['--dialect', argResults!['dialect'] as String]);
    }
    if (argResults?.wasParsed('dir') ?? false) {
      args.addAll(['--dir', argResults!['dir'] as String]);
    }
    return args;
  }
}

class _MigrateApplyCommand extends _BaseMigrateSubcommand {
  @override
  final String name = 'apply';

  @override
  final String description =
      'Applies all pending database migrations in sequence.';

  @override
  String get mappedCommand => 'migrate';

  _MigrateApplyCommand({
    super.processExecutor,
    super.targetDir,
    super.customStdout,
    super.customStderr,
  }) {
    argParser
      ..addOption(
        'url',
        abbr: 'u',
        help: 'Database connection URL (e.g. postgres://... or sqlite:app.db).',
      )
      ..addOption(
        'dir',
        abbr: 'd',
        help: 'Migrations directory path.',
      )
      ..addOption(
        'app',
        abbr: 'a',
        help: 'Filter operations to a specific app namespace.',
      )
      ..addOption(
        'step',
        abbr: 's',
        help: 'Limit number of migrations to apply.',
      );
  }

  @override
  List<String> buildForwardedArgs() {
    final args = <String>[];
    final rest = argResults?.rest ?? [];
    if (rest.isNotEmpty) {
      args.addAll(rest);
    }
    if (argResults?.wasParsed('url') ?? false) {
      args.addAll(['--url', argResults!['url'] as String]);
    }
    if (argResults?.wasParsed('dir') ?? false) {
      args.addAll(['--dir', argResults!['dir'] as String]);
    }
    if (argResults?.wasParsed('app') ?? false) {
      args.addAll(['--app', argResults!['app'] as String]);
    }
    if (argResults?.wasParsed('step') ?? false) {
      args.addAll(['--step', argResults!['step'] as String]);
    }
    return args;
  }
}

class _MigrateStatusCommand extends _BaseMigrateSubcommand {
  @override
  final String name = 'status';

  @override
  final String description = 'Shows applied and pending database migrations.';

  @override
  String get mappedCommand => 'status';

  _MigrateStatusCommand({
    super.processExecutor,
    super.targetDir,
    super.customStdout,
    super.customStderr,
  }) {
    argParser
      ..addOption(
        'url',
        abbr: 'u',
        help: 'Database connection URL (e.g. postgres://... or sqlite:app.db).',
      )
      ..addOption(
        'dir',
        abbr: 'd',
        help: 'Migrations directory path.',
      )
      ..addOption(
        'app',
        abbr: 'a',
        help: 'Filter operations to a specific app namespace.',
      );
  }

  @override
  List<String> buildForwardedArgs() {
    final args = <String>[];
    final rest = argResults?.rest ?? [];
    if (rest.isNotEmpty) {
      args.addAll(rest);
    }
    if (argResults?.wasParsed('url') ?? false) {
      args.addAll(['--url', argResults!['url'] as String]);
    }
    if (argResults?.wasParsed('dir') ?? false) {
      args.addAll(['--dir', argResults!['dir'] as String]);
    }
    if (argResults?.wasParsed('app') ?? false) {
      args.addAll(['--app', argResults!['app'] as String]);
    }
    return args;
  }
}

class _MigrateRollbackCommand extends _BaseMigrateSubcommand {
  @override
  final String name = 'rollback';

  @override
  final String description =
      'Rolls back the most recently applied migration(s).';

  @override
  String get mappedCommand => 'rollback';

  _MigrateRollbackCommand({
    super.processExecutor,
    super.targetDir,
    super.customStdout,
    super.customStderr,
  }) {
    argParser
      ..addOption(
        'url',
        abbr: 'u',
        help: 'Database connection URL (e.g. postgres://... or sqlite:app.db).',
      )
      ..addOption(
        'dir',
        abbr: 'd',
        help: 'Migrations directory path.',
      )
      ..addOption(
        'app',
        abbr: 'a',
        help: 'Filter operations to a specific app namespace.',
      )
      ..addOption(
        'count',
        abbr: 'c',
        help: 'Number of migrations to roll back.',
      );
  }

  @override
  List<String> buildForwardedArgs() {
    final args = <String>[];
    final rest = argResults?.rest ?? [];
    if (rest.isNotEmpty) {
      args.addAll(rest);
    }
    if (argResults?.wasParsed('url') ?? false) {
      args.addAll(['--url', argResults!['url'] as String]);
    }
    if (argResults?.wasParsed('dir') ?? false) {
      args.addAll(['--dir', argResults!['dir'] as String]);
    }
    if (argResults?.wasParsed('app') ?? false) {
      args.addAll(['--app', argResults!['app'] as String]);
    }
    if (argResults?.wasParsed('count') ?? false) {
      args.addAll(['--count', argResults!['count'] as String]);
    }
    return args;
  }
}
