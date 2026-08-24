// lib/src/commands/module_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../utils/ansi.dart';

/// Parent command for native module authoring, isolated sandbox dev runner, and multi-platform testing.
///
/// Provides subcommands: `dev` and `test`.
///
/// Example:
/// ```
/// bloom module dev --dry-run
/// bloom module test --module-dir ./packages/my_module
/// ```
class ModuleCommand extends Command<int> {
  @override
  final String name = 'module';

  @override
  final String description = 'Native module authoring, isolated sandbox dev runner, and multi-platform testing.';

  ModuleCommand() {
    addSubcommand(_ModuleDevCommand());
    addSubcommand(_ModuleTestCommand());
  }
}

class _ModuleDevCommand extends Command<int> {
  @override
  final String name = 'dev';

  @override
  final String description = 'Boots a minimal, isolated host Flutter sandbox containing only this native module.';

  _ModuleDevCommand() {
    argParser.addOption(
      'module-dir',
      help: 'Path to the module directory (defaults to current directory).',
    );
    argParser.addFlag(
      'dry-run',
      help: 'Generate the sandbox host app without starting flutter run process.',
      defaultsTo: false,
    );
  }

  @override
  Future<int> run() async {
    final moduleDir = argResults?['module-dir'] != null
        ? Directory(argResults!['module-dir'] as String)
        : Directory.current;

    final pubspecFile = File(p.join(moduleDir.path, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      print(Ansi.error('✖ Not a valid Dart/Flutter package directory (missing pubspec.yaml): ${moduleDir.path}'));
      return 1;
    }

    final moduleName = _getModuleName(pubspecFile);
    print(Ansi.boldText('\n🧪 Launching Bloom Module Sandbox for "$moduleName"...'));

    // 1. Generate sandbox host application
    final sandboxDir = Directory(p.join(moduleDir.path, '.bloom', 'sandbox'));
    if (!sandboxDir.existsSync()) {
      sandboxDir.createSync(recursive: true);
    }

    final hostPubspec = File(p.join(sandboxDir.path, 'pubspec.yaml'));
    hostPubspec.writeAsStringSync('''
name: ${moduleName}_sandbox
description: Bloom Developer Sandbox Host for $moduleName
version: 0.0.1
publish_to: 'none'

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.27.0'

dependencies:
  flutter:
    sdk: flutter
  bloom_framework:
    path: ../../../packages/bloom_framework
  $moduleName:
    path: ../..

dev_dependencies:
  flutter_test:
    sdk: flutter
''');

    final libDir = Directory(p.join(sandboxDir.path, 'lib'))..createSync(recursive: true);
    final mainDart = File(p.join(libDir.path, 'main.dart'));
    mainDart.writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:$moduleName/$moduleName.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ModuleSandboxScreen(),
  ));
}

class ModuleSandboxScreen extends StatefulWidget {
  const ModuleSandboxScreen({super.key});

  @override
  State<ModuleSandboxScreen> createState() => _ModuleSandboxScreenState();
}

class _ModuleSandboxScreenState extends State<ModuleSandboxScreen> {
  String _status = 'Module Sandbox Ready';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bloom Module Sandbox: $moduleName'),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.developer_mode, size: 64, color: Colors.indigo),
              const SizedBox(height: 16),
              Text(
                'Testing Module: $moduleName',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
''');

    print(Ansi.success('✔ Generated minimal sandbox host in: ${sandboxDir.path}'));

    if (argResults?['dry-run'] == true) {
      print(Ansi.step('Dry-run specified. Skipping flutter run execution.'));
      return 0;
    }

    // 2. Launch flutter run in sandbox
    print(Ansi.step('Starting sandbox process with hot reload...'));
    final proc = await Process.start(
      'flutter',
      ['run'],
      workingDirectory: sandboxDir.path,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await proc.exitCode;
    return exitCode;
  }

  String _getModuleName(File pubspec) {
    try {
      final yaml = loadYaml(pubspec.readAsStringSync());
      if (yaml is Map && yaml['name'] != null) {
        return yaml['name'].toString();
      }
    } catch (_) {}
    return 'module';
  }
}

class _ModuleTestCommand extends Command<int> {
  @override
  final String name = 'test';

  @override
  final String description =
      'Executes Dart unit tests, Android JUnit tests, and iOS XCTests for this native module.';

  _ModuleTestCommand() {
    argParser.addOption(
      'module-dir',
      help: 'Path to the module directory (defaults to current directory).',
    );
  }

  @override
  Future<int> run() async {
    final moduleDir = argResults?['module-dir'] != null
        ? Directory(argResults!['module-dir'] as String)
        : Directory.current;

    final pubspecFile = File(p.join(moduleDir.path, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      print(Ansi.error('✖ Not a valid Dart/Flutter package directory: ${moduleDir.path}'));
      return 1;
    }

    final moduleName = _getModuleName(pubspecFile);
    print(Ansi.boldText('\n🧪 Executing Bloom Module Test Matrix ($moduleName)\n'));

    var totalSuitesFailed = 0;
    var suitesRun = 0;

    // 1. Dart API Unit Tests
    final dartTestDir = Directory(p.join(moduleDir.path, 'test'));
    if (dartTestDir.existsSync() && dartTestDir.listSync().whereType<File>().any((f) => f.path.endsWith('_test.dart'))) {
      print(Ansi.step('Running Dart API Unit Tests...'));
      suitesRun++;
      final dartResult = Process.runSync(
        'dart',
        ['test'],
        workingDirectory: moduleDir.path,
      );

      if (dartResult.exitCode == 0) {
        print('  • ${Ansi.green}Dart API Unit Tests:     passed (exit 0)${Ansi.reset}');
      } else {
        totalSuitesFailed++;
        print('  • ${Ansi.red}Dart API Unit Tests:     FAILED${Ansi.reset}');
        print(dartResult.stdout);
        print(dartResult.stderr);
      }
    } else {
      print('  • Dart API Unit Tests:     0 tests found');
    }

    // 2. Android JUnit Tests
    final androidDir = Directory(p.join(moduleDir.path, 'android'));
    if (androidDir.existsSync()) {
      final gradlew = File(p.join(androidDir.path, 'gradlew'));
      if (gradlew.existsSync()) {
        print(Ansi.step('Running Android JUnit Tests...'));
        suitesRun++;
        final androidResult = Process.runSync(
          './gradlew',
          ['test'],
          workingDirectory: androidDir.path,
        );
        if (androidResult.exitCode == 0) {
          print('  • ${Ansi.green}Android JUnit Tests:     passed (exit 0)${Ansi.reset}');
        } else {
          totalSuitesFailed++;
          print('  • ${Ansi.red}Android JUnit Tests:     FAILED${Ansi.reset}');
          print(androidResult.stdout);
          print(androidResult.stderr);
        }
      } else {
        // No gradle wrapper: do NOT claim a pass. Report that tests were not run.
        print('  • ${Ansi.yellow}Android JUnit Tests:     NOT RUN (no gradle wrapper found)${Ansi.reset}');
      }
    }

    // 3. iOS XCTest Suite
    final iosDir = Directory(p.join(moduleDir.path, 'ios'));
    if (iosDir.existsSync()) {
      final workspace = File(p.join(iosDir.path, 'Runner.xcworkspace'));
      final project = File(p.join(iosDir.path, 'Runner.xcodeproj'));
      if (workspace.existsSync() || project.existsSync()) {
        print(Ansi.step('Running iOS XCTest Suite (xcodebuild)...'));
        suitesRun++;
        final iosTarget = workspace.existsSync() ? workspace.path : project.path;
        final iosResult = Process.runSync('xcodebuild', [
          'test',
          if (workspace.existsSync()) '-workspace' else '-project',
          iosTarget,
          '-scheme',
          'Runner',
          '-destination',
          "platform=iOS Simulator,name=iPhone 16,OS=latest",
        ], workingDirectory: moduleDir.path);
        if (iosResult.exitCode == 0) {
          print('  • ${Ansi.green}iOS XCTest Suite:        passed (exit 0)${Ansi.reset}');
        } else {
          totalSuitesFailed++;
          print('  • ${Ansi.red}iOS XCTest Suite:        FAILED${Ansi.reset}');
          print(iosResult.stdout.toString().split('\n').take(20).join('\n'));
          print(iosResult.stderr);
        }
      } else {
        // No Xcode project: do NOT claim a pass.
        print('  • ${Ansi.yellow}iOS XCTest Suite:        NOT RUN (no Xcode project found)${Ansi.reset}');
      }
    }

    if (totalSuitesFailed > 0) {
      print(Ansi.error('\n✖ Module test suites failed! Total suite failures: $totalSuitesFailed\n'));
      return 1;
    }

    if (suitesRun == 0) {
      print(Ansi.warn('\n⚠ No test suites were run (no Dart/Android/iOS tests found).\n'));
      return 2;
    }

    print(Ansi.success('\n✔ All native module test suites passed successfully!\n'));
    return 0;
  }

  String _getModuleName(File pubspec) {
    try {
      final yaml = loadYaml(pubspec.readAsStringSync());
      if (yaml is Map && yaml['name'] != null) {
        return yaml['name'].toString();
      }
    } catch (_) {}
    return 'module';
  }
}
