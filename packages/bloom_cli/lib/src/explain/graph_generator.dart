// lib/src/explain/graph_generator.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';

class GraphNode {
  final String id;
  final String label;
  final String type; // 'route', 'controller', 'repository', 'service'
  final List<String> dependencies;

  GraphNode({
    required this.id,
    required this.label,
    required this.type,
    this.dependencies = const [],
  });
}

/// Generates architectural relationship graphs across Routes -> Controllers -> Repositories -> Services.
class ArchitectureGraphGenerator {
  final BloomProject project;

  ArchitectureGraphGenerator(this.project);

  List<GraphNode> buildGraph() {
    final nodes = <GraphNode>[];
    final routes = project.scanRoutes();

    for (final route in routes) {
      final deps = <String>[];
      final file = File(p.join(project.rootDir.path, route.relativeFilePath));
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        if (content.contains('Controller') || content.contains('controller')) {
          deps.add('${route.componentClassName}Controller');
        }
        if (content.contains('Repository') || content.contains('BloomData')) {
          deps.add('DataRepository');
        }
      }

      nodes.add(GraphNode(
        id: route.routePath,
        label: '${route.routePath} (${route.componentClassName})',
        type: 'route',
        dependencies: deps,
      ));
    }

    return nodes;
  }

  String toMermaid(List<GraphNode> nodes) {
    final buffer = StringBuffer();
    buffer.writeln('graph TD');
    for (final node in nodes) {
      buffer.writeln('  subgraph Routes');
      buffer.writeln('    ${_sanitize(node.id)}["${node.label}"]');
      buffer.writeln('  end');
      for (final dep in node.dependencies) {
        buffer.writeln('  ${_sanitize(node.id)} --> ${_sanitize(dep)}["$dep"]');
      }
    }
    return buffer.toString();
  }

  /// Renders a Graphviz DOT representation of the dependency graph.
  String toDot(List<GraphNode> nodes) {
    final buffer = StringBuffer();
    buffer.writeln('digraph bloom {');
    buffer.writeln('  rankdir=LR;');
    for (final node in nodes) {
      buffer.writeln('  "${_sanitize(node.id)}" [label="${node.label}", shape=box];');
      for (final dep in node.dependencies) {
        buffer.writeln('  "${_sanitize(node.id)}" -> "${_sanitize(dep)}";');
      }
    }
    buffer.writeln('}');
    return buffer.toString();
  }

  void printConsoleGraph(List<GraphNode> nodes) {
    print(Ansi.boldText('\n📊 Bloom Architecture Dependency Graph\n'));
    print('  Routes ➔ Controllers ➔ Repositories ➔ Services\n');

    if (nodes.isEmpty) {
      print(Ansi.dimText('  (No routes discovered in project)'));
      return;
    }

    for (final node in nodes) {
      print('  • ${Ansi.cyan}${node.label}${Ansi.reset}');
      if (node.dependencies.isNotEmpty) {
        for (final dep in node.dependencies) {
          print('    └── ➔ ${Ansi.green}$dep${Ansi.reset}');
        }
      } else {
        print('    └── ${Ansi.dimText('(Standalone view)')}');
      }
    }
    print('');
  }

  String _sanitize(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }
}
