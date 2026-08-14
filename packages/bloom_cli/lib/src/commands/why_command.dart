// lib/src/commands/why_command.dart
import 'package:args/command_runner.dart';
import '../native/dependency_graph.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class WhyCommand extends Command<int> {
  @override
  final String name = 'why';
  @override
  final String description = 'Explains why a native module or Dart package is included in the project.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a package or module name to explain (e.g. `bloom why bloom_camera`).'));
      return 1;
    }

    final target = rest.first.trim();
    final project = BloomProject.find();
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    final resolver = DependencyGraphResolver(project);
    final explanation = resolver.explain(target);
    print('\n$explanation\n');
    return 0;
  }
}
