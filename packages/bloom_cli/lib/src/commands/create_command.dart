// lib/src/commands/create_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../templates/templates.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

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
            depSpec = '  bloom_framework: ^0.1.0';
          }
        } catch (_) {
          depSpec = '  bloom_framework: ^0.1.0';
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
}
