// lib/src/commands/prebuild_command.dart
import 'package:args/command_runner.dart';
import '../native/prebuild_engine.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Command that generates and validates native platform configurations from `bloom.yaml`.
///
/// Synchronizes native Android Gradle and Manifest configurations and iOS Podfile
/// and Info.plist configurations without requiring manual project edits.
///
/// Example:
/// ```
/// bloom prebuild
/// ```
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

    final engine = PrebuildEngine(project);
    final ok = await engine.run();
    return ok ? 0 : 1;
  }
}
