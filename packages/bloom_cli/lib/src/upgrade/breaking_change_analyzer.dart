// lib/src/upgrade/breaking_change_analyzer.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';
import '../utils/project.dart';

class BreakingChangeFinding {
  final String filePath;
  final int lineNumber;
  final String category;
  final String deprecatedSymbol;
  final String remediation;
  final String snippet;

  BreakingChangeFinding({
    required this.filePath,
    required this.lineNumber,
    required this.category,
    required this.deprecatedSymbol,
    required this.remediation,
    required this.snippet,
  });
}

class BreakingChangeReport {
  final List<BreakingChangeFinding> findings;
  final String currentVersion;
  final String targetVersion;

  BreakingChangeReport({
    required this.findings,
    required this.currentVersion,
    required this.targetVersion,
  });

  bool get isCompatible => findings.isEmpty;
  int get findingCount => findings.length;
}

/// Static analyzer to detect breaking API changes, deprecated symbols, and legacy patterns.
class BreakingChangeAnalyzer {
  final BloomProject project;

  BreakingChangeAnalyzer(this.project);

  /// Performs full breaking change analysis across the project.
  BreakingChangeReport analyze({String targetVersion = '2.0.0'}) {
    final findings = <BreakingChangeFinding>[];
    final bloomConfig = project.loadBloomConfig();
    final currentVersion = bloomConfig['version']?.toString() ?? '1.0.0';

    final libDir = Directory(p.join(project.rootDir.path, 'lib'));
    if (libDir.existsSync()) {
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)); // Deterministic order

      for (final file in dartFiles) {
        final relPath = p.relative(file.path, from: project.rootDir.path).replaceAll('\\', '/');
        final lines = file.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final lineNum = i + 1;

          // 1. Check legacy RouteGuard inheritance
          if (line.contains('extends RouteGuard')) {
            findings.add(BreakingChangeFinding(
              filePath: relPath,
              lineNumber: lineNum,
              category: 'Routing',
              deprecatedSymbol: 'RouteGuard',
              remediation: 'CustomGuard must implement BloomGuard interface',
              snippet: line.trim(),
            ));
          }

          // 2. Check deprecated BloomAuth.currentUser
          if (line.contains('BloomAuth.currentUser')) {
            findings.add(BreakingChangeFinding(
              filePath: relPath,
              lineNumber: lineNum,
              category: 'Auth / Security',
              deprecatedSymbol: 'BloomAuth.currentUser',
              remediation: 'Use Bloom.auth.currentUser or BloomAuth.instance.currentUser',
              snippet: line.trim(),
            ));
          }

          // 3. Check deprecated BloomRouter.pushNamed
          if (line.contains('BloomRouter.pushNamed')) {
            findings.add(BreakingChangeFinding(
              filePath: relPath,
              lineNumber: lineNum,
              category: 'Routing',
              deprecatedSymbol: 'BloomRouter.pushNamed',
              remediation: 'Use BloomRouter.go() with path-based routing',
              snippet: line.trim(),
            ));
          }
        }
      }
    }

    final report = BreakingChangeReport(
      findings: findings,
      currentVersion: currentVersion,
      targetVersion: targetVersion,
    );

    print(Ansi.boldText('\n🔍 Bloom Upgrade Compatibility Analysis (v$currentVersion ➔ v$targetVersion)\n'));

    if (report.isCompatible) {
      print(Ansi.success('✔ Routing / Auth:      100% compatible (no deprecated BloomAuth.currentUser, BloomRouter.pushNamed, or RouteGuard inheritance found)'));
      print(Ansi.dimText('  Note: State/data/native-module compatibility is not scanned by this analyzer; it only checks the above routing/auth patterns.\n'));
    } else {
      final routingFindings = findings.where((f) => f.category == 'Routing').toList();
      final otherFindings = findings.where((f) => f.category != 'Routing').toList();

      if (routingFindings.isNotEmpty) {
        print(Ansi.warn('⚠ Routing:             ${routingFindings.length} legacy Route item(s) require refactoring:'));
        for (final f in routingFindings) {
          print('  • ${f.filePath}:${f.lineNumber} ➔ ${f.remediation}');
        }
      }

      if (otherFindings.isNotEmpty) {
        print(Ansi.warn('⚠ APIs / Deprecations: ${otherFindings.length} deprecated symbol(s) detected:'));
        for (final f in otherFindings) {
          print('  • ${f.filePath}:${f.lineNumber} ➔ ${f.remediation}');
        }
      }
      print('');
    }

    return report;
  }
}
