// lib/src/native/prebuild_engine.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'android_prebuild.dart';
import 'ios_prebuild.dart';

class PrebuildEngine {
  final BloomProject project;

  PrebuildEngine(this.project);

  Future<bool> run() async {
    print(Ansi.boldText('\n⚙  Running Bloom Prebuild Engine for "${project.projectName}"...\n'));

    final config = project.loadBloomConfig();
    final platforms = config['platforms'] is Map ? config['platforms'] as Map : {};
    final plugins = config['plugins'] is List ? config['plugins'] as List : [];

    // 1. Android Prebuild
    final androidDir = Directory(p.join(project.rootDir.path, 'android'));
    final androidSync = AndroidPrebuild(androidDir);
    await androidSync.synchronize(platforms: platforms, plugins: plugins);

    // 2. iOS Prebuild
    final iosDir = Directory(p.join(project.rootDir.path, 'ios'));
    final iosSync = IosPrebuild(iosDir);
    await iosSync.synchronize(platforms: platforms, plugins: plugins);

    print('\n${Ansi.success('Native platform synchronization completed successfully!')}\n');
    return true;
  }
}
