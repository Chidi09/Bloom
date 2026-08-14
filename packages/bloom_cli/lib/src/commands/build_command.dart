// lib/src/commands/build_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../templates/templates.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class BuildCommand extends Command<int> {
  @override
  final String name = 'build';
  @override
  final String description = 'Compiles production artifacts with Bloom environment injection and flavor profiles.';

  BuildCommand() {
    argParser
      ..addFlag(
        'release',
        help: 'Build a release version of the application.',
        defaultsTo: true,
      )
      ..addFlag(
        'profile',
        help: 'Build a performance profiling version of the application.',
        defaultsTo: false,
      )
      ..addOption(
        'flavor',
        abbr: 'f',
        help: 'Build flavor to use (defined in bloom.yaml).',
      )
      ..addOption(
        'env-file',
        help: 'Explicit environment file to inject during build.',
      );
  }

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a build target (e.g. "apk", "appbundle", "ipa", "web", "linux", "windows", "macos").'));
      return 1;
    }

    final target = rest.first.toLowerCase();
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    final flavor = argResults?['flavor'] as String?;
    final explicitEnv = argResults?['env-file'] as String?;

    print(Ansi.boldText('\n🏗  Building Bloom target: ${Ansi.cyan}$target${Ansi.reset}${flavor != null ? ' [Flavor: $flavor]' : ''}\n'));

    // 1. Sync routes first
    final routes = project.scanRoutes();
    final routerCode = BloomTemplates.generatedRouter(
      projectName: project.projectName,
      routes: routes,
    );
    final routerFile = File(p.join(project.rootDir.path, 'lib', 'app', 'routes.g.dart'));
    routerFile.createSync(recursive: true);
    routerFile.writeAsStringSync(routerCode);

    // 2. Determine environment file injection
    String? envToInject = explicitEnv;
    if (envToInject == null && flavor != null) {
      final config = project.loadBloomConfig();
      if (config['flavors'] is Map && config['flavors'][flavor] is Map) {
        final flavorConfig = config['flavors'][flavor] as Map;
        envToInject = flavorConfig['env_file']?.toString() ?? flavorConfig['envFile']?.toString();
      }
      envToInject ??= '.env.$flavor';
    }

    // 3. Assemble flutter build arguments
    final buildArgs = ['build', target];

    if (argResults?['profile'] == true) {
      buildArgs.add('--profile');
    } else if (argResults?['release'] == true) {
      buildArgs.add('--release');
    }

    if (flavor != null) {
      buildArgs.addAll(['--flavor', flavor]);
    }

    if (envToInject != null) {
      final envFile = File(p.join(project.rootDir.path, envToInject));
      if (envFile.existsSync()) {
        buildArgs.add('--dart-define-from-file=$envToInject');
        print(Ansi.step('Injecting environment definition: $envToInject'));
      }
    }

    final proc = await Process.start(
      'flutter',
      buildArgs,
      workingDirectory: project.rootDir.path,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await proc.exitCode;
    if (exitCode == 0) {
      print('\n${Ansi.success('Build completed successfully for $target!')}\n');
    } else {
      print('\n${Ansi.error('Build failed with exit code $exitCode')}\n');
    }
    return exitCode;
  }
}
