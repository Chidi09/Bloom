// lib/src/commands/explain_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../explain/explain_engine.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Parent command that explains architectural decisions, routing resolutions, and dependency chains.
///
/// Provides subcommands: `route` and `config`.
///
/// Example:
/// ```
/// bloom explain route /users/[id]
/// bloom explain config
/// ```
class ExplainCommand extends Command<int> {
  @override
  final String name = 'explain';

  @override
  final String description = 'Explains architectural decisions, routing resolutions, and dependency chains.';

  ExplainCommand() {
    addSubcommand(_ExplainRouteCommand());
    addSubcommand(_ExplainConfigCommand());
  }
}

class _ExplainRouteCommand extends Command<int> {
  @override
  final String name = 'route';

  @override
  final String description =
      'Explains how a specific URL route path resolves to files, parameters, layouts, and guards.';

  _ExplainRouteCommand() {
    argParser.addOption(
      'project-dir',
      help: 'Explicit path to the Bloom project directory.',
    );
  }

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('✖ Please provide a route path to explain (e.g. `bloom explain route /users/42`)'));
      return 1;
    }

    final routePath = rest.first;
    final projectDir = argResults?['project-dir'] != null
        ? Directory(argResults!['project-dir'] as String)
        : Directory.current;

    final project = BloomProject.find(projectDir);
    if (project == null) {
      print(Ansi.error('✖ Not a valid Bloom project directory: ${projectDir.path}'));
      return 1;
    }

    final engine = ExplainEngine(project);
    final explanation = engine.explainRoute(routePath);
    engine.printRouteExplanation(explanation);

    return explanation.isFound ? 0 : 1;
  }
}

class _ExplainConfigCommand extends Command<int> {
  @override
  final String name = 'config';

  @override
  final String description = 'Explains active project configuration and platform targets.';

  _ExplainConfigCommand() {
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

    final config = project.loadBloomConfig();
    print(Ansi.boldText('\n⚙ Project Configuration: ${project.projectName}\n'));
    print('  • Mode:        ${config['mode'] ?? 'managed'}');
    print('  • Version:     ${config['version'] ?? '0.1.0'}');
    print('  • Platforms:   ${config['platforms'] ?? {}}');
    print('  • Plugins:     ${config['plugins'] ?? {}}\n');
    return 0;
  }
}
