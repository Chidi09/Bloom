// lib/src/native/prebuild_engine.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';
import 'android_prebuild.dart';
import 'autolink_engine.dart';
import 'deep_links_prebuild.dart';
import 'ios_prebuild.dart';

class PrebuildEngine {
  final BloomProject project;

  PrebuildEngine(this.project);

  Future<bool> run() async {
    final config = project.loadBloomConfig();
    final mode = config['mode']?.toString().toLowerCase() ?? 'managed';

    if (mode == 'bare') {
      print(Ansi.info('\nℹ  Bloom Native Mode is set to "bare". Skipping automated manifest synchronization.\n'));
      return true;
    }

    print(Ansi.boldText('\n⚙  Running Bloom Prebuild Engine (mode: $mode) for "${project.projectName}"...\n'));

    final platforms = config['platforms'] is Map ? config['platforms'] as Map : {};
    final plugins = config['plugins'] is List ? config['plugins'] as List : [];
    final deepLinks = config['deep_links'] is Map
        ? config['deep_links'] as Map
        : (config['deepLinks'] is Map ? config['deepLinks'] as Map : null);

    final androidPackage = platforms['android'] is Map ? platforms['android']['package']?.toString() : null;
    final iosBundleId = platforms['ios'] is Map ? platforms['ios']['bundle_identifier']?.toString() : null;

    // 1. Android Prebuild
    final androidDir = Directory(p.join(project.rootDir.path, 'android'));
    final androidSync = AndroidPrebuild(androidDir);
    await androidSync.synchronize(
      platforms: platforms,
      plugins: plugins,
      deepLinks: deepLinks,
    );

    // 2. iOS Prebuild
    final iosDir = Directory(p.join(project.rootDir.path, 'ios'));
    final iosSync = IosPrebuild(iosDir);
    await iosSync.synchronize(
      platforms: platforms,
      plugins: plugins,
      deepLinks: deepLinks,
    );

    // 3. Deep Links Domain Verification files (.well-known)
    final deepLinksSync = DeepLinksPrebuild(project.rootDir);
    await deepLinksSync.synchronize(
      deepLinks: deepLinks,
      packageName: androidPackage,
      iosBundleId: iosBundleId,
    );

    // 4. Zero-Config Autolinking & bloom.lock generation
    final autolink = AutolinkEngine(project);
    await autolink.runAutolink();

    print('\n${Ansi.success('Native platform synchronization completed successfully!')}\n');
    return true;
  }
}
