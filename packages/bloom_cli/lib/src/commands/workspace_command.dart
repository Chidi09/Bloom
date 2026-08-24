// lib/src/commands/workspace_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import '../native/dependency_graph.dart';
import '../native/workspace_manager.dart';
import '../utils/ansi.dart';
import '../utils/project.dart';

/// Parent command for monorepo and workspace coordination across multiple apps and modules.
///
/// Provides subcommands: `status`, `deps`, `prebuild`, and `test`.
///
/// Example:
/// ```
/// bloom workspace status
/// bloom workspace deps
/// bloom workspace prebuild
/// bloom workspace test
/// ```
class WorkspaceCommand extends Command<int> {
  @override
  final String name = 'workspace';
  @override
  final String description = 'Monorepo & workspace coordinator (status, deps, prebuild, test).';

  WorkspaceCommand() {
    addSubcommand(_WorkspaceStatusCommand());
    addSubcommand(_WorkspaceDepsCommand());
    addSubcommand(_WorkspacePrebuildCommand());
    addSubcommand(_WorkspaceTestCommand());
  }
}

class _WorkspaceStatusCommand extends Command<int> {
  @override
  final String name = 'status';
  @override
  final String description = 'Discovers all apps, packages, and native modules in the monorepo workspace.';

  _WorkspaceStatusCommand() {
    argParser.addOption(
      'workspace-dir',
      help: 'Explicit path to the workspace root directory.',
    );
  }

  @override
  Future<int> run() async {
    final explicitDir = argResults?['workspace-dir'] != null
        ? Directory(argResults!['workspace-dir'] as String)
        : null;

    final workspace = BloomWorkspaceManager.find(explicitDir);
    if (workspace == null) {
      print(Ansi.error('No Bloom workspace found in current or parent directory.'));
      return 1;
    }

    workspace.printStatus();
    return 0;
  }
}

class _WorkspaceDepsCommand extends Command<int> {
  @override
  final String name = 'deps';
  @override
  final String description = 'Visualizes dependencies across all workspace packages and apps.';

  _WorkspaceDepsCommand() {
    argParser.addOption(
      'workspace-dir',
      help: 'Explicit path to the workspace root directory.',
    );
  }

  @override
  Future<int> run() async {
    final explicitDir = argResults?['workspace-dir'] != null
        ? Directory(argResults!['workspace-dir'] as String)
        : null;

    final workspace = BloomWorkspaceManager.find(explicitDir);
    if (workspace == null) {
      print(Ansi.error('No Bloom workspace found.'));
      return 1;
    }

    final projects = workspace.discoverProjects();
    print(Ansi.boldText('\n🏢 Bloom Workspace Dependencies (${projects.length} projects):\n'));

    for (final p in projects) {
      final bloomProj = BloomProject(
        rootDir: p.dir,
        bloomYamlFile: File('${p.dir.path}/bloom.yaml'),
        pubspecFile: File('${p.dir.path}/pubspec.yaml'),
      );
      final resolver = DependencyGraphResolver(bloomProj);
      print(resolver.renderTree());
      print('');
    }

    return 0;
  }
}

class _WorkspacePrebuildCommand extends Command<int> {
  @override
  final String name = 'prebuild';
  @override
  final String description = 'Prebuilds all application targets in the workspace in parallel.';

  _WorkspacePrebuildCommand() {
    argParser.addOption(
      'workspace-dir',
      help: 'Explicit path to the workspace root directory.',
    );
  }

  @override
  Future<int> run() async {
    final explicitDir = argResults?['workspace-dir'] != null
        ? Directory(argResults!['workspace-dir'] as String)
        : null;

    final workspace = BloomWorkspaceManager.find(explicitDir);
    if (workspace == null) {
      print(Ansi.error('No Bloom workspace found.'));
      return 1;
    }

    return workspace.prebuildAll();
  }
}

class _WorkspaceTestCommand extends Command<int> {
  @override
  final String name = 'test';
  @override
  final String description = 'Executes test suites across all workspace packages in topological dependency order.';

  _WorkspaceTestCommand() {
    argParser.addOption(
      'workspace-dir',
      help: 'Explicit path to the workspace root directory.',
    );
  }

  @override
  Future<int> run() async {
    final explicitDir = argResults?['workspace-dir'] != null
        ? Directory(argResults!['workspace-dir'] as String)
        : null;

    final workspace = BloomWorkspaceManager.find(explicitDir);
    if (workspace == null) {
      print(Ansi.error('No Bloom workspace found.'));
      return 1;
    }

    return workspace.testAll();
  }
}
