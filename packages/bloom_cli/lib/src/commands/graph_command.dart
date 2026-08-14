// lib/src/commands/graph_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../explain/graph_generator.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

class GraphCommand extends Command<int> {
  @override
  final String name = 'graph';

  @override
  final String description =
      'Renders the architectural dependency graph (Routes ➔ Controllers ➔ Repositories ➔ Services).';

  GraphCommand() {
    argParser.addOption(
      'format',
      help: 'Output format: text, mermaid, or dot.',
      allowed: ['text', 'mermaid', 'dot'],
      defaultsTo: 'text',
    );
    argParser.addOption(
      'project-dir',
      help: 'Explicit path to the Bloom project directory.',
    );
  }

  @override
  Future<int> run() async {
    final projectDir = argResults?['project-dir'] != null
        ? Directory(argResults!['project-dir'] as String)
        : Directory.current;

    final project = BloomProject.find(projectDir);
    if (project == null) {
      print(Ansi.error('✖ Not a valid Bloom project directory: ${projectDir.path}'));
      return 1;
    }

    final generator = ArchitectureGraphGenerator(project);
    final nodes = generator.buildGraph();
    final format = argResults?['format'] as String? ?? 'text';

    if (format == 'mermaid') {
      print(generator.toMermaid(nodes));
    } else if (format == 'dot') {
      print(generator.toDot(nodes));
    } else {
      generator.printConsoleGraph(nodes);
    }

    return 0;
  }
}
