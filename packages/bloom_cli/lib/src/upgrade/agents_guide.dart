import 'dart:io';
import 'package:path/path.dart' as p;
import '../templates/templates.dart';

const String agentsGuideStart =
    '<!-- bloom:agents-guide:start — managed by bloom; `bloom upgrade` refreshes this block -->';
const String agentsGuideEnd = '<!-- bloom:agents-guide:end -->';

enum AgentsGuideStatus {
  unchanged,
  updated,
  replacedLegacy,
  skippedUserFile,
  missing,
}

/// Result of refreshing the managed portion of a project's agent guide.
class AgentsGuideRefresh {
  final AgentsGuideStatus status;
  final String? backupPath;
  final String? message;

  const AgentsGuideRefresh(
    this.status, {
    this.backupPath,
    this.message,
  });
}

/// Refreshes only Bloom-managed guide text and preserves user-authored notes.
AgentsGuideRefresh refreshAgentsGuide(
  Directory root, {
  required String projectName,
  required bool dryRun,
}) {
  final file = File(p.join(root.path, 'AGENTS.md'));
  final template = BloomTemplates.jsNativeAgentsMd(projectName: projectName);
  final freshBlock = _managedBlock(template);
  if (!file.existsSync()) {
    if (!dryRun) file.writeAsStringSync(template);
    return const AgentsGuideRefresh(AgentsGuideStatus.missing);
  }
  final existing = file.readAsStringSync();
  final start = existing.indexOf(agentsGuideStart);
  final end = existing.indexOf(agentsGuideEnd);
  if (start >= 0 && end >= start) {
    final endExclusive = end + agentsGuideEnd.length;
    final updated = existing.substring(0, start) +
        freshBlock +
        existing.substring(endExclusive);
    if (updated == existing) {
      return const AgentsGuideRefresh(AgentsGuideStatus.unchanged);
    }
    if (!dryRun) file.writeAsStringSync(updated);
    return const AgentsGuideRefresh(AgentsGuideStatus.updated);
  }

  if (!existing.contains(agentsGuideStart) &&
      !existing.contains(agentsGuideEnd) &&
      existing.contains(
        'This is a **Bloom JS Native** project: pure Dart, compiles to native',
      )) {
    final backup = File('${file.path}.bak');
    if (!dryRun) {
      backup.writeAsStringSync(existing);
      file.writeAsStringSync(template);
    }
    return AgentsGuideRefresh(
      AgentsGuideStatus.replacedLegacy,
      backupPath: backup.path,
    );
  }
  return const AgentsGuideRefresh(
    AgentsGuideStatus.skippedUserFile,
    message:
        'Bloom guide blocks are refreshed only in files with managed markers. '
        'Use `bloom create` for a new guide.',
  );
}

String _managedBlock(String template) {
  final start = template.indexOf(agentsGuideStart);
  final end = template.indexOf(agentsGuideEnd, start);
  if (start < 0 || end < 0) return template;
  return template.substring(start, end + agentsGuideEnd.length);
}
