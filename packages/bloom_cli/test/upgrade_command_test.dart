import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:bloom_cli/src/commands/upgrade_command.dart';
import 'package:bloom_cli/src/upgrade/analyzer_issues.dart';
import 'package:bloom_cli/src/upgrade/agents_guide.dart';
import 'package:bloom_cli/src/upgrade/migrations.dart';
import 'package:bloom_cli/src/upgrade/upgrade_engine.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bloom_upgrade_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('machine analyzer parser handles escaped pipes', () {
    final issues = parseMachineAnalyzerOutput(
      r'ERROR|COMPILE_TIME_ERROR|CODE|/tmp/a\|b.dart|2|3|4|message \| detail',
    );
    expect(issues, hasLength(1));
    expect(issues.single.file, '/tmp/a|b.dart');
    expect(issues.single.message, 'message | detail');
  });

  test('ui-import mirrors as prefix and is idempotent', () {
    const source =
        "import 'package:bloom_js_native/bloom_js_native.dart' as b;\n"
        'void main() => b.button();\n';
    const issue = AnalyzerIssue(
      severity: 'ERROR',
      type: 'COMPILE_TIME_ERROR',
      code: 'UNDEFINED_FUNCTION',
      file: 'app.dart',
      line: 2,
      column: 19,
      length: 6,
      message: "The function 'button' isn't defined.",
    );
    final migration =
        bloomMigrations.firstWhere((item) => item.id == 'ui-import');
    final result = migration.apply(source, [issue])!;
    expect(result, contains("import 'package:bloom_js_native/ui.dart' as b;"));
    expect(migration.apply(result, [issue]), isNull);
    expect(
        migration.apply(
          source,
          [issue.copyWith(message: "Undefined name 'unlistedThing'.")],
        ),
        isNull);
  });

  test('ui-import does nothing when ui.dart already exists', () {
    const source = "import 'package:bloom_js_native/ui.dart';\n";
    const issue = AnalyzerIssue(
      severity: 'ERROR',
      type: 'COMPILE_TIME_ERROR',
      code: 'UNDEFINED_FUNCTION',
      file: 'app.dart',
      line: 1,
      column: 1,
      length: 6,
      message: "The function 'button' isn't defined.",
    );
    expect(
      bloomMigrations.first.apply(source, [issue]),
      isNull,
    );
  });

  test('svg strokeWidth migration only changes flagged lines', () {
    const source = "SvgPath(strokeWidth: '2');\nSvgPath(strokeWidth: '3');\n";
    const issue = AnalyzerIssue(
      severity: 'ERROR',
      type: 'COMPILE_TIME_ERROR',
      code: 'ARGUMENT_TYPE_NOT_ASSIGNABLE',
      file: 'app.dart',
      line: 1,
      column: 1,
      length: 1,
      message: 'type mismatch',
    );
    final migration = bloomMigrations.firstWhere(
      (item) => item.id == 'svg-stroke-width-num',
    );
    expect(migration.apply(source, [issue]),
        "SvgPath(strokeWidth: 2);\nSvgPath(strokeWidth: '3');\n");
  });

  test('dry run lists outdated packages and does not write files', () async {
    final project = _project(tempDir);
    final app = File(p.join(project.path, 'lib', 'app.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
          "import 'package:bloom_js_native/bloom_js_native.dart';\nbutton();\n");
    final lock = File(p.join(project.path, 'pubspec.lock'))
      ..writeAsStringSync(_lock('0.3.8'));
    final before = app.readAsStringSync();
    final pubspecBefore =
        File(p.join(project.path, 'pubspec.yaml')).readAsStringSync();
    final bloomBefore =
        File(p.join(project.path, 'bloom.yaml')).readAsStringSync();
    final out = StringBuffer();
    final calls = <String>[];
    final env = _environment(
      out,
      calls,
      (executable, arguments, {workingDirectory}) async => ProcessResult(
        0,
        0,
        '{"packages":[{"package":"bloom_js_native","current":{"version":"0.3.8"},"resolvable":{"version":"0.4.0"},"latest":{"version":"0.4.0"}}]}',
        '',
      ),
    );
    final command = UpgradeCommand(environment: env);
    final runner = CommandRunner<int>('bloom', 'test')..addCommand(command);
    expect(
        await runner.run([
          'upgrade',
          '--skip-cli',
          '--dry-run',
          '--project-dir',
          project.path
        ]),
        0);
    expect(out.toString(), contains('bloom_js_native  0.3.8 → 0.4.0'));
    expect(out.toString(), contains('ui-import'));
    expect(out.toString(), contains('svg-stroke-width-num'));
    expect(app.readAsStringSync(), before);
    expect(File(p.join(project.path, 'pubspec.yaml')).readAsStringSync(),
        pubspecBefore);
    expect(File(p.join(project.path, 'bloom.yaml')).readAsStringSync(),
        bloomBefore);
    expect(calls, ['dart pub outdated --json']);
    expect(lock.readAsStringSync(), _lock('0.3.8'));
  });

  test('real upgrade applies analyzer gated fixes and preserves app versions',
      () async {
    final project = _project(tempDir);
    final app = File(p.join(project.path, 'lib', 'app.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
          "import 'package:bloom_js_native/bloom_js_native.dart';\nvoid main() { button(); SvgPath(strokeWidth: '2'); }\n");
    final pubspec = File(p.join(project.path, 'pubspec.yaml'));
    final bloom = File(p.join(project.path, 'bloom.yaml'));
    final originalVersion =
        '${pubspec.readAsStringSync().split('version:').last}\n';
    final issueOutput = [
      "ERROR|COMPILE_TIME_ERROR|UNDEFINED_FUNCTION|${app.path}|2|14|6|The function 'button' isn't defined.",
      "ERROR|COMPILE_TIME_ERROR|ARGUMENT_TYPE_NOT_ASSIGNABLE|${app.path}|2|35|1|String is not assignable",
    ].join('\n');
    final calls = <String>[];
    final out = StringBuffer();
    var analyzeRuns = 0;
    final env = _environment(out, calls, (executable, arguments,
        {workingDirectory}) async {
      if (arguments.join(' ') ==
          'pub upgrade --major-versions bloom_js_native') {
        File(p.join(project.path, 'pubspec.lock'))
            .writeAsStringSync(_lock('0.4.0'));
      }
      if (arguments.join(' ') == 'analyze --format=machine') {
        analyzeRuns++;
        return ProcessResult(0, 1, analyzeRuns == 1 ? issueOutput : '', '');
      }
      return ProcessResult(0, 0, '', '');
    });
    final runner = CommandRunner<int>('bloom', 'test')
      ..addCommand(UpgradeCommand(environment: env));
    expect(
        await runner
            .run(['upgrade', '--skip-cli', '--project-dir', project.path]),
        0);
    final migrated = app.readAsStringSync();
    expect(migrated, contains("import 'package:bloom_js_native/ui.dart';"));
    expect(migrated, contains('strokeWidth: 2'));
    expect(pubspec.readAsStringSync(), contains('version: 7.4.2'));
    expect(bloom.readAsStringSync(), contains('version: 8.1.0'));
    expect(originalVersion, contains('7.4.2'));
    expect(calls, [
      'dart pub upgrade --major-versions bloom_js_native',
      'dart analyze --format=machine',
      'dart analyze --format=machine',
    ]);
  });

  test('pub upgrade failure returns one and leaves source unchanged', () async {
    final project = _project(tempDir);
    final app = File(p.join(project.path, 'lib', 'app.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}\n');
    final before = app.readAsStringSync();
    final env = _environment(
        StringBuffer(),
        [],
        (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 1, '', 'failed'));
    final runner = CommandRunner<int>('bloom', 'test')
      ..addCommand(UpgradeCommand(environment: env));
    expect(
        await runner
            .run(['upgrade', '--skip-cli', '--project-dir', project.path]),
        1);
    expect(app.readAsStringSync(), before);
  });

  test('path and git dependencies are skipped and flutter is selected',
      () async {
    final project = _project(tempDir);
    final pubspec = File(p.join(project.path, 'pubspec.yaml'));
    pubspec.writeAsStringSync('''
name: test_app
dependencies:
  flutter:
    sdk: flutter
  bloom_local:
    path: ../bloom_local
  bloom_git:
    git:
      url: https://example.invalid/bloom_git.git
  bloom_js_native: ^0.3.0
''');
    final calls = <String>[];
    final out = StringBuffer();
    final env = _environment(
        out,
        calls,
        (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 0, '', ''));
    final result = await ProjectUpgrader(project, env).run(dryRun: false);
    expect(result.success, isTrue);
    expect(calls, ['flutter pub upgrade --major-versions bloom_js_native']);
    expect(out.toString(), contains('skipped (path/git dependency)'));
    expect(calls.single, isNot(contains('bloom_local')));
    expect(calls.single, isNot(contains('bloom_git')));
  });

  test('AGENTS managed block refresh preserves notes and backs up legacy guide',
      () async {
    final project = _project(tempDir);
    final guide = File(p.join(project.path, 'AGENTS.md'));
    guide.writeAsStringSync('''
before
<!-- bloom:agents-guide:start — managed by bloom; `bloom upgrade` refreshes this block -->
old managed text
<!-- bloom:agents-guide:end -->

my note stays
''');
    final env = _environment(
        StringBuffer(),
        [],
        (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 0, '', ''));
    await ProjectUpgrader(project, env).run(dryRun: false);
    expect(guide.readAsStringSync(), contains('before\n'));
    expect(guide.readAsStringSync(), contains('my note stays'));
    expect(guide.readAsStringSync(), contains('## Upgrading'));

    guide.writeAsStringSync(
        'This is a **Bloom JS Native** project: pure Dart, compiles to native\nlegacy\n');
    await ProjectUpgrader(project, env).run(dryRun: false);
    expect(File('${guide.path}.bak').readAsStringSync(), contains('legacy'));
    expect(guide.readAsStringSync(), contains('<!-- bloom:agents-guide:start'));
  });

  test('user-authored AGENTS.md is left unchanged', () {
    final project = _project(tempDir);
    final guide = File(p.join(project.path, 'AGENTS.md'))
      ..writeAsStringSync('# My own guide\nkeep this exactly\n');
    final before = guide.readAsStringSync();
    final result = refreshAgentsGuide(
      project,
      projectName: 'test_app',
      dryRun: false,
    );
    expect(result.status, AgentsGuideStatus.skippedUserFile);
    expect(guide.readAsStringSync(), before);
  });

  test('hosted CLI upgrade hands off project work to the new CLI', () async {
    final project = _project(tempDir);
    final calls = <String>[];
    final out = StringBuffer();
    final env = UpgradeEnvironment(
      runProcess: (executable, arguments, {workingDirectory}) async {
        calls.add('$executable ${arguments.join(' ')}');
        if (arguments.join(' ') == 'pub global list') {
          return ProcessResult(0, 0, 'bloom_cli 0.7.0\n', '');
        }
        return ProcessResult(0, 0, '', '');
      },
      runInteractive: (executable, arguments, {workingDirectory}) async {
        calls.add('$executable ${arguments.join(' ')}');
        return 23;
      },
      latestVersion: (_) async => '0.9.0',
      out: out,
    );
    final runner = CommandRunner<int>('bloom', 'test')
      ..addCommand(UpgradeCommand(environment: env));
    expect(await runner.run(['upgrade', '--project-dir', project.path]), 23);
    expect(calls, contains('dart pub global activate bloom_cli'));
    expect(calls.last, contains('upgrade --skip-cli --project-dir'));
  });

  test('path CLI install is skipped while project continues', () async {
    final project = _project(tempDir);
    final calls = <String>[];
    final out = StringBuffer();
    final env = UpgradeEnvironment(
      runProcess: (executable, arguments, {workingDirectory}) async {
        calls.add('$executable ${arguments.join(' ')}');
        if (arguments.join(' ') == 'pub global list') {
          return ProcessResult(
              0, 0, 'bloom_cli 0.8.0 at path "/src/bloom"\n', '');
        }
        return ProcessResult(0, 0, '', '');
      },
      runInteractive: (executable, arguments, {workingDirectory}) async => 0,
      latestVersion: (_) async => '1.0.0',
      out: out,
    );
    final runner = CommandRunner<int>('bloom', 'test')
      ..addCommand(UpgradeCommand(environment: env));
    expect(await runner.run(['upgrade', '--project-dir', project.path]), 0);
    expect(out.toString(), contains('source checkout (/src/bloom)'));
    expect(
        calls, contains('dart pub upgrade --major-versions bloom_js_native'));
    expect(
      File(p.join(project.path, 'AGENTS.md')).readAsStringSync(),
      contains('<!-- bloom:agents-guide:start'),
    );
  });

  test('up-to-date CLI, unreachable pub.dev, and dry run never activate',
      () async {
    for (final scenario in ['current', 'offline', 'dry']) {
      final project = _project(tempDir);
      final calls = <String>[];
      final out = StringBuffer();
      final env = UpgradeEnvironment(
        runProcess: (executable, arguments, {workingDirectory}) async {
          calls.add('$executable ${arguments.join(' ')}');
          if (arguments.join(' ') == 'pub global list') {
            return ProcessResult(0, 0, 'bloom_cli 0.8.0\n', '');
          }
          if (arguments.join(' ') == 'pub outdated --json') {
            return ProcessResult(
                0,
                0,
                '{"packages":[{"package":"bloom_js_native","current":{"version":"0.3.8"},"latest":{"version":"0.3.8"}}]}',
                '');
          }
          return ProcessResult(0, 0, '', '');
        },
        runInteractive: (executable, arguments, {workingDirectory}) async => 0,
        latestVersion: (_) async => scenario == 'offline'
            ? null
            : scenario == 'current'
                ? '0.8.0'
                : '0.9.0',
        out: out,
      );
      final runner = CommandRunner<int>('bloom', 'test')
        ..addCommand(UpgradeCommand(environment: env));
      final args = ['upgrade', '--project-dir', project.path];
      if (scenario == 'dry') args.add('--dry-run');
      expect(await runner.run(args), 0);
      expect(calls.where((call) => call.contains('global activate')), isEmpty);
      if (scenario == 'current') {
        expect(out.toString(), contains('is up to date'));
      } else if (scenario == 'offline') {
        expect(out.toString(), contains("Couldn't reach pub.dev"));
      } else {
        expect(out.toString(), contains('Would upgrade bloom CLI'));
      }
    }
  });

  test('no project with skip-cli fails; ordinary no-project checks CLI only',
      () async {
    final env = _environment(
        StringBuffer(),
        [],
        (executable, arguments, {workingDirectory}) async =>
            ProcessResult(0, 0, 'bloom_cli 0.8.0\n', ''));
    final runner = CommandRunner<int>('bloom', 'test')
      ..addCommand(UpgradeCommand(environment: env));
    expect(
        await runner
            .run(['upgrade', '--skip-cli', '--project-dir', tempDir.path]),
        1);
    expect(await runner.run(['upgrade', '--project-dir', tempDir.path]), 0);
  });
}

Directory _project(Directory parent) {
  final directory = Directory(p.join(parent.path, 'app'))
    ..createSync(recursive: true);
  File(p.join(directory.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_app
version: 7.4.2
dependencies:
  bloom_js_native: ^0.3.0
''');
  File(p.join(directory.path, 'bloom.yaml')).writeAsStringSync('''
name: test_app
version: 8.1.0
type: js_native
''');
  File(p.join(directory.path, 'pubspec.lock'))
      .writeAsStringSync(_lock('0.3.8'));
  return directory;
}

String _lock(String version) => '''
packages:
  bloom_js_native:
    dependency: "direct main"
    source: hosted
    version: "$version"
''';

UpgradeEnvironment _environment(
  StringBuffer out,
  List<String> calls,
  Future<ProcessResult> Function(String, List<String>,
          {String? workingDirectory})
      run,
) =>
    UpgradeEnvironment(
      runProcess: (executable, arguments, {workingDirectory}) async {
        calls.add('$executable ${arguments.join(' ')}');
        return run(executable, arguments, workingDirectory: workingDirectory);
      },
      runInteractive: (executable, arguments, {workingDirectory}) async => 0,
      latestVersion: (_) async => '99.0.0',
      out: out,
    );

extension on AnalyzerIssue {
  AnalyzerIssue copyWith({String? message}) => AnalyzerIssue(
        severity: severity,
        type: type,
        code: code,
        file: file,
        message: message ?? this.message,
        line: line,
        column: column,
        length: length,
      );
}
