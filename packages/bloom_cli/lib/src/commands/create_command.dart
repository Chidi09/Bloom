// lib/src/commands/create_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../templates/templates.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'create_module_command.dart';

/// Command that creates a new standardized Bloom application or native module.
///
/// Scaffolds directory hierarchy, core files (`bloom.yaml`, `.env`, `routes.g.dart`),
/// injects framework dependencies, and initializes git and pub configuration.
///
/// Example:
/// ```
/// bloom create my_app --org com.mycompany --description "My Bloom app"
/// bloom create module my_sensor --org dev.bloom
/// ```
class CreateCommand extends Command<int> {
  @override
  final String name = 'create';
  @override
  final String description = 'Creates a new standardized Bloom application.';

  CreateCommand() {
    argParser
      ..addOption(
        'org',
        abbr: 'o',
        help: 'The organization responsible for your project (reverse domain name).',
        defaultsTo: 'com.example',
      )
      ..addOption(
        'description',
        abbr: 'd',
        help: 'The description of the project.',
        defaultsTo: 'A modern application built with Bloom',
      )
      ..addOption(
        'framework-path',
        help: 'Local path to bloom_framework package (for local development).',
      )
      ..addFlag(
        'js-native',
        help: 'Scaffold a Flutter-free Bloom JS Native web project instead of a Flutter app.',
        negatable: false,
      );
  }

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a project name.'));
      print('Usage: bloom create <app_name>');
      return 1;
    }

    if (rest.first == 'module') {
      if (rest.length < 2) {
        print(Ansi.error('Please specify a module name.'));
        print('Usage: bloom create module <module_name>');
        return 1;
      }
      final moduleName = rest[1].trim().toLowerCase().replaceAll('-', '_');
      return CreateModuleCommand.executeScaffold(
        moduleName: moduleName,
        org: argResults?['org'] as String? ?? 'dev.bloom',
        description: argResults?['description'] as String? ??
            'A high-performance native module built with Bloom Module DSL',
        frameworkPath: argResults?['framework-path'] as String?,
      );
    }

    final appName = rest.first.trim().toLowerCase().replaceAll('-', '_');
    final org = argResults?['org'] as String? ?? 'com.example';
    final description = argResults?['description'] as String? ?? 'A modern application built with Bloom';
    final frameworkPath = argResults?['framework-path'] as String?;

    // Name validation
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(appName)) {
      print(Ansi.error('Invalid project name: "$appName". Must be lowercase letters, numbers, and underscores, starting with a letter.'));
      return 1;
    }

    final targetDir = Directory(p.join(Directory.current.path, appName));
    if (targetDir.existsSync() && targetDir.listSync().isNotEmpty) {
      print(Ansi.error('Directory "${targetDir.path}" already exists and is not empty.'));
      return 1;
    }

    if (argResults?['js-native'] as bool? ?? false) {
      return _createJsNativeProject(
        appName: appName,
        description: description,
        targetDir: targetDir,
      );
    }

    print(Ansi.boldText('\n🌱 Creating Bloom application: ${Ansi.cyan}$appName${Ansi.reset}\n'));

    // 1. Run flutter create
    print(Ansi.step('1/6 Initializing Flutter base project...'));
    final flutterResult = await Process.run('flutter', [
      'create',
      '--org',
      org,
      '--project-name',
      appName,
      '--description',
      description,
      targetDir.path,
    ]);

    if (flutterResult.exitCode != 0) {
      print(Ansi.error('Failed to run flutter create:'));
      print(flutterResult.stderr);
      return flutterResult.exitCode;
    }

    // 2. Inject bloom_framework in pubspec.yaml
    print(Ansi.step('2/6 Injecting Bloom runtime dependency...'));
    final pubspecFile = File(p.join(targetDir.path, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      var pubspecContent = pubspecFile.readAsStringSync();
      
      // Determine framework dependency specification dynamically
      String depSpec;
      if (frameworkPath != null && Directory(frameworkPath).existsSync()) {
        depSpec = '  bloom_framework:\n    path: ${p.canonicalize(frameworkPath)}';
      } else if (Platform.environment['BLOOM_FRAMEWORK_PATH'] != null &&
          Directory(Platform.environment['BLOOM_FRAMEWORK_PATH']!).existsSync()) {
        depSpec = '  bloom_framework:\n    path: ${Platform.environment['BLOOM_FRAMEWORK_PATH']}';
      } else {
        // Check relative monorepo path from executing script
        try {
          final scriptDir = p.dirname(Platform.script.toFilePath());
          final siblingFramework = p.normalize(p.join(scriptDir, '..', '..', 'bloom_framework'));
          if (Directory(siblingFramework).existsSync()) {
            depSpec = '  bloom_framework:\n    path: ${p.canonicalize(siblingFramework)}';
          } else {
            depSpec = '  bloom_framework: ^0.2.1';
          }
        } catch (_) {
          depSpec = '  bloom_framework: ^0.2.1';
        }
      }

      pubspecContent = pubspecContent.replaceFirst(
        'dependencies:\n  flutter:\n    sdk: flutter\n',
        'dependencies:\n  flutter:\n    sdk: flutter\n$depSpec\n',
      );
      pubspecFile.writeAsStringSync(pubspecContent);
    }

    // 3. Create Bloom directory hierarchy
    print(Ansi.step('3/6 Creating Bloom directory architecture...'));
    final dirs = [
      'lib/app',
      'lib/config',
      'lib/routes',
      'lib/features',
    ];
    for (final d in dirs) {
      Directory(p.join(targetDir.path, d)).createSync(recursive: true);
    }

    // 4. Generate core files
    print(Ansi.step('4/6 Generating application manifests and initial routes...'));
    
    // bloom.yaml
    File(p.join(targetDir.path, 'bloom.yaml')).writeAsStringSync(
      BloomTemplates.bloomYaml(name: appName, description: description),
    );

    // .env and .env.example
    File(p.join(targetDir.path, '.env')).writeAsStringSync(
      BloomTemplates.dotEnv(name: appName),
    );
    File(p.join(targetDir.path, '.env.example')).writeAsStringSync(
      BloomTemplates.dotEnvExample(),
    );

    // analysis_options.yaml
    File(p.join(targetDir.path, 'analysis_options.yaml')).writeAsStringSync(
      BloomTemplates.analysisOptions(),
    );

    // lib/main.dart
    File(p.join(targetDir.path, 'lib', 'main.dart')).writeAsStringSync(
      BloomTemplates.mainDart(projectName: appName),
    );

    // lib/app/boot.dart
    File(p.join(targetDir.path, 'lib', 'app', 'boot.dart')).writeAsStringSync(
      BloomTemplates.bootDart(),
    );

    // lib/routes/index.dart
    File(p.join(targetDir.path, 'lib', 'routes', 'index.dart')).writeAsStringSync(
      BloomTemplates.indexRoute(projectName: appName),
    );

    // test/widget_test.dart
    File(p.join(targetDir.path, 'test', 'widget_test.dart')).writeAsStringSync(
      BloomTemplates.widgetTest(projectName: appName),
    );

    // 5. Generate initial routes.g.dart
    print(Ansi.step('5/6 Generating filesystem routing table...'));
    final bloomProj = BloomProject(
      rootDir: targetDir,
      bloomYamlFile: File(p.join(targetDir.path, 'bloom.yaml')),
      pubspecFile: pubspecFile,
    );
    final routes = bloomProj.scanRoutes();
    final routerCode = BloomTemplates.generatedRouter(
      projectName: appName,
      routes: routes,
    );
    File(p.join(targetDir.path, 'lib', 'app', 'routes.g.dart')).writeAsStringSync(
      routerCode,
    );

    // 6. Run flutter pub get
    print(Ansi.step('6/6 Resolving project dependencies...'));
    final pubGet = await Process.run('flutter', ['pub', 'get'], workingDirectory: targetDir.path);
    if (pubGet.exitCode != 0) {
      print(Ansi.warn('Warning: flutter pub get completed with warnings:'));
      print(pubGet.stderr);
    }

    print('\n${Ansi.success('Bloom application "$appName" created successfully!')}\n');
    print('Next steps:');
    print('  ${Ansi.cyan}cd $appName${Ansi.reset}');
    print('  ${Ansi.cyan}bloom dev${Ansi.reset}      (Launch development server)');
    print('  ${Ansi.cyan}bloom doctor${Ansi.reset}   (Check environment health)\n');

    return 0;
  }

  /// Scaffolds a Flutter-free Bloom JS Native project: no `flutter create`,
  /// no `bloom_framework` dependency, no Flutter-shaped directories. Just a
  /// correct, working `pubspec.yaml` + `bloom.yaml` (`type: js_native`) +
  /// `web/index.html` + `lib/main.dart` that compiles and runs via
  /// `bloom js dev` / `bloom js build` out of the box.
  Future<int> _createJsNativeProject({
    required String appName,
    required String description,
    required Directory targetDir,
  }) async {
    print(Ansi.boldText('\n🌱 Creating Bloom JS Native application: ${Ansi.cyan}$appName${Ansi.reset}\n'));

    print(Ansi.step('1/4 Creating project directories...'));
    targetDir.createSync(recursive: true);
    Directory(p.join(targetDir.path, 'lib')).createSync(recursive: true);
    Directory(p.join(targetDir.path, 'web')).createSync(recursive: true);
    Directory(p.join(targetDir.path, 'test')).createSync(recursive: true);

    print(Ansi.step('2/4 Generating manifests and entry point...'));
    File(p.join(targetDir.path, 'bloom.yaml')).writeAsStringSync(
      BloomTemplates.jsNativeBloomYaml(name: appName, description: description),
    );
    File(p.join(targetDir.path, 'pubspec.yaml')).writeAsStringSync(
      BloomTemplates.jsNativePubspec(
        name: appName,
        description: description,
        bloomJsNativeVersion: '0.3.0',
      ),
    );
    File(p.join(targetDir.path, 'web', 'index.html')).writeAsStringSync(
      BloomTemplates.jsNativeIndexHtml(name: appName),
    );
    File(p.join(targetDir.path, 'lib', 'main.dart')).writeAsStringSync(
      BloomTemplates.jsNativeMainDart(projectName: appName),
    );
    File(p.join(targetDir.path, 'test', 'smoke_test.dart')).writeAsStringSync(
      BloomTemplates.jsNativeSmokeTest(projectName: appName),
    );
    File(p.join(targetDir.path, '.gitignore')).writeAsStringSync(
      BloomTemplates.jsNativeGitignore(),
    );

    print(Ansi.step('3/4 Resolving project dependencies...'));
    final pubGet = await Process.run('dart', ['pub', 'get'], workingDirectory: targetDir.path);
    if (pubGet.exitCode != 0) {
      print(Ansi.warn('Warning: dart pub get completed with warnings:'));
      print(pubGet.stderr);
    }

    print(Ansi.step('4/4 Done.'));
    print('\n${Ansi.success('Bloom JS Native application "$appName" created successfully!')}\n');
    print('Next steps:');
    print('  ${Ansi.cyan}cd $appName${Ansi.reset}');
    print('  ${Ansi.cyan}bloom js dev${Ansi.reset}     (Launch dev server with live reload)');
    print('  ${Ansi.cyan}bloom js build${Ansi.reset}   (Compile a production bundle)\n');

    return 0;
  }
}
