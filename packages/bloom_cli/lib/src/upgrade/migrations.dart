import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:pub_semver/pub_semver.dart';
import 'analyzer_issues.dart';
import 'ui_symbols.dart';

/// A safe, analyzer-gated source migration for a Bloom package release.
class BloomMigration {
  final String id;
  final String package;
  final Version version;
  final String summary;
  final String? Function(String source, List<AnalyzerIssue> fileIssues) apply;

  const BloomMigration({
    required this.id,
    required this.package,
    required this.version,
    required this.summary,
    required this.apply,
  });
}

/// Every known migration, applied in list order. Analyzer line numbers refer
/// to the unmodified file, so migrations that rewrite flagged lines in place
/// come before migrations that insert lines (such as new imports).
final List<BloomMigration> bloomMigrations = [
  BloomMigration(
    id: 'svg-stroke-width-num',
    package: 'bloom_js_native',
    version: Version(0, 4, 0),
    summary: 'strokeWidth takes a number',
    apply: _fixSvgStrokeWidth,
  ),
  BloomMigration(
    id: 'ui-import',
    package: 'bloom_js_native',
    version: Version(0, 4, 0),
    summary: 'Import UI primitives from package:bloom_js_native/ui.dart',
    apply: _addUiImport,
  ),
];

String? _addUiImport(String source, List<AnalyzerIssue> issues) {
  const codes = {
    'UNDEFINED_FUNCTION',
    'UNDEFINED_IDENTIFIER',
    'UNDEFINED_CLASS',
    'UNDEFINED_PREFIXED_NAME',
    'UNDEFINED_METHOD',
  };
  final shouldAdd = issues.any((issue) {
    final symbol = RegExp("'([^']+)'").firstMatch(issue.message)?.group(1);
    return codes.contains(issue.code) &&
        symbol != null &&
        bloomUiSymbols.contains(symbol);
  });
  if (!shouldAdd) return null;

  final parsed = parseString(content: source, throwIfDiagnostics: false);
  final directives =
      parsed.unit.directives.whereType<ImportDirective>().toList();
  if (directives.any((directive) =>
      directive.uri.stringValue == 'package:bloom_js_native/ui.dart')) {
    return null;
  }

  final coreImports = directives
      .where((directive) =>
          directive.uri.stringValue ==
          'package:bloom_js_native/bloom_js_native.dart')
      .toList();
  final core = coreImports.isEmpty ? null : coreImports.first;
  final newline = source.contains('\r\n') ? '\r\n' : '\n';
  final prefix = core?.prefix?.name;
  final import = prefix == null
      ? "import 'package:bloom_js_native/ui.dart';"
      : "import 'package:bloom_js_native/ui.dart' as $prefix;";
  final offset = core != null
      ? _lineEndOffset(source, core.end)
      : directives.isNotEmpty
          ? _lineEndOffset(source, directives.last.end)
          : _leadingCommentEnd(source);
  final before = source.substring(0, offset);
  final separator =
      before.isNotEmpty && !before.endsWith('\n') && !before.endsWith('\r')
          ? newline
          : '';
  final result =
      before + separator + import + newline + source.substring(offset);
  return result == source ? null : result;
}

int _lineEndOffset(String source, int offset) {
  final nextNewline = source.indexOf('\n', offset);
  if (nextNewline < 0) return source.length;
  return nextNewline + 1;
}

int _leadingCommentEnd(String source) {
  var offset = 0;
  while (offset < source.length) {
    if (source[offset].trim().isEmpty) {
      offset++;
      continue;
    }
    if (source.startsWith('//', offset)) {
      final end = source.indexOf('\n', offset);
      offset = end < 0 ? source.length : end + 1;
      continue;
    }
    if (source.startsWith('/*', offset)) {
      final end = source.indexOf('*/', offset + 2);
      offset = end < 0 ? source.length : end + 2;
      continue;
    }
    break;
  }
  return offset;
}

String? _fixSvgStrokeWidth(String source, List<AnalyzerIssue> issues) {
  final lines = source.split('\n');
  var changed = false;
  final expression = RegExp(
    r'''(strokeWidth\s*:\s*)(['"])(-?\d+(?:\.\d+)?)\2''',
  );
  for (final issue in issues.where(
    (issue) => issue.code == 'ARGUMENT_TYPE_NOT_ASSIGNABLE',
  )) {
    final index = issue.line - 1;
    if (index < 0 || index >= lines.length) continue;
    final old = lines[index];
    lines[index] = old.replaceAllMapped(
      expression,
      (match) => '${match.group(1)}${match.group(3)}',
    );
    changed = changed || lines[index] != old;
  }
  if (!changed) return null;
  return lines.join('\n');
}
