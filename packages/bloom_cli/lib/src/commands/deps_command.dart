// lib/src/commands/deps_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../native/dependency_graph.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class DepsCommand extends Command<int> {
  @override
  final String name = 'deps';
  @override
  final List<String> aliases = ['dependencies'];
  @override
  final String description = 'Inspects and visualizes the resolved Dart and native module dependency tree.';

  DepsCommand() {
    argParser.addOption(
      'project-dir',
      help: 'Explicit path to the Bloom project directory.',
    );
  }

  @override
  Future<int> run() async {
    final explicitDir = argResults?['project-dir'] != null
        ? Directory(argResults!['project-dir'] as String)
        : null;

    final project = BloomProject.find(explicitDir);
    if (project == null) {
      print(Ansi.error('No Bloom project found.'));
      return 1;
    }

    final resolver = DependencyGraphResolver(project);
    final output = resolver.renderTree();
    print(output);
    return 0;
  }
}
