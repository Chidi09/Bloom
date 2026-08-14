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
  final String description = 'Compiles production artifacts with Bloom environment injection.';

  BuildCommand() {
    argParser
      ..addFlag(
        'release',
        help: 'Build a release version of the application.',
        defaultsTo: true,
      )
      ..addOption(
        'flavor',
        help: 'Build flavor to use.',
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

    print(Ansi.boldText('\n🏗  Building Bloom target: ${Ansi.cyan}$target${Ansi.reset}\n'));

    // 1. Sync routes first
    final routes = project.scanRoutes();
    final routerCode = BloomTemplates.generatedRouter(
      projectName: project.projectName,
      routes: routes,
    );
    final routerFile = File(p.join(project.rootDir.path, 'lib', 'app', 'routes.g.dart'));
    routerFile.createSync(recursive: true);
    routerFile.writeAsStringSync(routerCode);

    // 2. Run flutter build
    final buildArgs = ['build', target];
    if (argResults?['release'] == true) {
      buildArgs.add('--release');
    }
    if (argResults?['flavor'] != null) {
      buildArgs.addAll(['--flavor', argResults!['flavor'] as String]);
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
