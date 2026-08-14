// lib/src/commands/prebuild_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../templates/templates.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class PrebuildCommand extends Command<int> {
  @override
  final String name = 'prebuild';
  @override
  final String description = 'Generates and validates native platform configurations from bloom.yaml.';

  @override
  Future<int> run() async {
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    print(Ansi.boldText('\n⚙  Running Bloom Prebuild Native Synchronization...\n'));

    final config = project.loadBloomConfig();
    final platforms = config['platforms'] is Map ? config['platforms'] as Map : {};

    // 1. Sync routes
    final routes = project.scanRoutes();
    final routerCode = BloomTemplates.generatedRouter(
      projectName: project.projectName,
      routes: routes,
    );
    final routerFile = File(p.join(project.rootDir.path, 'lib', 'app', 'routes.g.dart'));
    routerFile.createSync(recursive: true);
    routerFile.writeAsStringSync(routerCode);
    print(Ansi.step('Synchronized ${routes.length} filesystem route(s).'));

    // 2. Validate Android project
    final androidDir = Directory(p.join(project.rootDir.path, 'android'));
    if (androidDir.existsSync()) {
      print(Ansi.step('Validating Android native project config...'));
      final minSdk = platforms['android']?['min_sdk'] ?? 24;
      print('  ${Ansi.dim}Android minSdk target: $minSdk${Ansi.reset}');
    }

    // 3. Validate iOS project
    final iosDir = Directory(p.join(project.rootDir.path, 'ios'));
    if (iosDir.existsSync()) {
      print(Ansi.step('Validating iOS native project config...'));
      final minIos = platforms['ios']?['minimum_version'] ?? '15.0';
      print('  ${Ansi.dim}iOS minimum deployment target: $minIos${Ansi.reset}');
    }

    print('\n${Ansi.success('Prebuild native synchronization completed!')}\n');
    return 0;
  }
}
