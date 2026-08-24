// lib/src/commands/create_module_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../generator/module_generator.dart';
import '../templates/module_templates.dart';
import '../utils/ansi.dart';

/// Command that scaffolds a new publishable Bloom Native Module.
///
/// Generates cross-platform directory architecture, `@BloomModule` DSL definitions,
/// Android Kotlin bridge, iOS Swift bridge, and unit test scaffold.
///
/// Example:
/// ```
/// bloom create-module sensor_kit --org dev.bloom
/// ```
class CreateModuleCommand extends Command<int> {
  @override
  final String name = 'create-module';
  @override
  final String description = 'Creates a new publishable Bloom Native Module.';

  /// Creates a module scaffolding command with organization, description, and framework-path options.
  CreateModuleCommand() {
    argParser
      ..addOption(
        'org',
        abbr: 'o',
        help: 'The organization responsible for your native module (reverse domain name).',
        defaultsTo: 'dev.bloom',
      )
      ..addOption(
        'description',
        abbr: 'd',
        help: 'The description of the module.',
        defaultsTo: 'A high-performance native module built with Bloom Module DSL',
      )
      ..addOption(
        'framework-path',
        help: 'Local path to bloom_framework package (for local development).',
      );
  }

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a module name.'));
      print('Usage: bloom create module <module_name>');
      return 1;
    }

    final moduleName = rest.first.trim().toLowerCase().replaceAll('-', '_');
    final org = argResults?['org'] as String? ?? 'dev.bloom';
    final description = argResults?['description'] as String? ??
        'A high-performance native module built with Bloom Module DSL';
    final frameworkPath = argResults?['framework-path'] as String?;

    return executeScaffold(
      moduleName: moduleName,
      org: org,
      description: description,
      frameworkPath: frameworkPath,
    );
  }

  /// Scaffolds a complete native module project inside a directory named [moduleName].
  static Future<int> executeScaffold({
    required String moduleName,
    required String org,
    required String description,
    String? frameworkPath,
  }) async {
    // Name validation
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(moduleName)) {
      print(Ansi.error('Invalid module name: "$moduleName". Must be lowercase letters, numbers, and underscores, starting with a letter.'));
      return 1;
    }

    final targetDir = Directory(p.join(Directory.current.path, moduleName));
    if (targetDir.existsSync() && targetDir.listSync().isNotEmpty) {
      print(Ansi.error('Directory "${targetDir.path}" already exists and is not empty.'));
      return 1;
    }

    print(Ansi.boldText('\n📦 Creating Bloom Native Module: ${Ansi.cyan}$moduleName${Ansi.reset}\n'));

    // Determine framework dependency path
    String? resolvedFrameworkPath = frameworkPath;
    if (resolvedFrameworkPath == null) {
      if (Platform.environment['BLOOM_FRAMEWORK_PATH'] != null &&
          Directory(Platform.environment['BLOOM_FRAMEWORK_PATH']!).existsSync()) {
        resolvedFrameworkPath = Platform.environment['BLOOM_FRAMEWORK_PATH'];
      } else {
        try {
          final scriptDir = p.dirname(Platform.script.toFilePath());
          final siblingFramework = p.normalize(p.join(scriptDir, '..', '..', 'bloom_framework'));
          if (Directory(siblingFramework).existsSync()) {
            resolvedFrameworkPath = p.canonicalize(siblingFramework);
          }
        } catch (_) {}
      }
    }

    // 1. Create directory structure
    print(Ansi.step('1/5 Creating module directory architecture...'));
    final dirs = [
      'lib/src',
      'android/src/main/kotlin/${org.replaceAll('.', '/')}/$moduleName',
      'ios/Sources',
      'test',
    ];
    for (final d in dirs) {
      Directory(p.join(targetDir.path, d)).createSync(recursive: true);
    }

    // 2. Generate configuration & manifests
    print(Ansi.step('2/5 Generating bloom.module.yaml and pubspec.yaml...'));
    File(p.join(targetDir.path, 'bloom.module.yaml')).writeAsStringSync(
      BloomModuleTemplates.moduleYaml(name: moduleName, description: description),
    );

    File(p.join(targetDir.path, 'pubspec.yaml')).writeAsStringSync(
      BloomModuleTemplates.pubspecYaml(
        name: moduleName,
        description: description,
        frameworkPath: resolvedFrameworkPath,
      ),
    );

    File(p.join(targetDir.path, 'README.md')).writeAsStringSync(
      BloomModuleTemplates.moduleReadme(name: moduleName, description: description),
    );

    // 3. Generate Dart DSL & Public API
    print(Ansi.step('3/5 Generating Bloom Module DSL and public Dart APIs...'));
    File(p.join(targetDir.path, 'lib', 'src', '$moduleName.module.dart')).writeAsStringSync(
      BloomModuleTemplates.dartModuleDefinition(name: moduleName),
    );

    File(p.join(targetDir.path, 'lib', '$moduleName.dart')).writeAsStringSync(
      BloomModuleTemplates.dartPublicApi(name: moduleName),
    );

    // 4. Generate native Swift & Kotlin bridges
    print(Ansi.step('4/6 Generating native Android Kotlin and iOS Swift bridges...'));
    final kotlinFile = p.join(
      targetDir.path,
      'android/src/main/kotlin/${org.replaceAll('.', '/')}/$moduleName',
      '${BloomModuleTemplates.toPascalCase(moduleName)}Module.kt',
    );
    File(kotlinFile).writeAsStringSync(
      BloomModuleTemplates.kotlinModule(name: moduleName, org: org),
    );

    File(p.join(targetDir.path, 'android', 'build.gradle.kts')).writeAsStringSync(
      BloomModuleTemplates.androidGradleKts(name: moduleName, org: org),
    );

    File(p.join(targetDir.path, 'ios', 'Sources', '${BloomModuleTemplates.toPascalCase(moduleName)}Module.swift')).writeAsStringSync(
      BloomModuleTemplates.swiftModule(name: moduleName),
    );

    File(p.join(targetDir.path, 'ios', '$moduleName.podspec')).writeAsStringSync(
      BloomModuleTemplates.iosPodspec(name: moduleName, description: description),
    );

    // 5. Run Bloom Module Code Generator on DSL
    print(Ansi.step('5/6 Compiling @BloomModule DSL to typed bridge bindings (.g.dart)...'));
    BloomModuleCodeGenerator.generateForModule(targetDir);

    // 6. Generate Unit Tests
    print(Ansi.step('6/6 Generating module unit test suite...'));
    File(p.join(targetDir.path, 'test', '${moduleName}_test.dart')).writeAsStringSync(
      BloomModuleTemplates.moduleTest(name: moduleName),
    );

    print('\n${Ansi.success('Bloom Native Module "$moduleName" created successfully!')}\n');
    print('Next steps:');
    print('  ${Ansi.cyan}cd $moduleName${Ansi.reset}');
    print('  ${Ansi.cyan}flutter test${Ansi.reset}     (Run module test suite)');
    print('  ${Ansi.cyan}bloom prebuild${Ansi.reset}   (Sync native modules)\n');

    return 0;
  }
}
