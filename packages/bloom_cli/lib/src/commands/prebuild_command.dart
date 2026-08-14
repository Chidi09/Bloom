// lib/src/commands/prebuild_command.dart
import 'package:args/command_runner.dart';
import '../native/prebuild_engine.dart';
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

    final engine = PrebuildEngine(project);
    final ok = await engine.run();
    return ok ? 0 : 1;
  }
}
