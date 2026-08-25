// lib/src/format/bloom_formatter.dart
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:dart_style/dart_style.dart';
import 'css_formatter.dart';

/// Result of formatting a single file.
class BloomFormatResult {
  final String formatted;
  final bool changed;
  final String? errorMessage;

  const BloomFormatResult({
    required this.formatted,
    required this.changed,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
}

/// Formats Bloom `bloom_js_native` source:
/// 1. Run official `dart_style` (tall style) on source.
/// 2. AST pass via `package:analyzer` (`parseString` parse-only):
///    - Wraps long named-arg string literals (e.g. `className: '...'`) into
///      adjacent string literals split at word boundaries.
///    - Formats embedded raw CSS strings (`const fooCss = r'''...''';` and `Style(r'''...''')`).
/// 3. Run `dart_style` once more on the rewritten source to produce consistent indentation.
class BloomFormatter {
  final int pageWidth;

  BloomFormatter({this.pageWidth = 80});

  BloomFormatResult format(String source) {
    final String base;
    try {
      base = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
        pageWidth: pageWidth,
      ).format(source);
    } on FormatterException catch (e) {
      return BloomFormatResult(
        formatted: source,
        changed: false,
        errorMessage: e.message(color: false),
      );
    }

    final parseResult = parseString(content: base, throwIfDiagnostics: false);
    if (parseResult.errors.isNotEmpty) {
      // If base formatted code had parse errors, return base without AST transformations
      return BloomFormatResult(
        formatted: base,
        changed: base != source,
      );
    }

    final collector = _BloomFormatVisitor(
      source: base,
      lineInfo: parseResult.lineInfo,
      pageWidth: pageWidth,
    );
    parseResult.unit.accept(collector);

    if (collector.replacements.isEmpty) {
      return BloomFormatResult(
        formatted: base,
        changed: base != source,
      );
    }

    // Apply replacements in reverse offset order so earlier offsets remain valid
    collector.replacements.sort((a, b) => b.offset.compareTo(a.offset));
    var rewritten = base;
    for (final r in collector.replacements) {
      rewritten = rewritten.substring(0, r.offset) + r.text + rewritten.substring(r.end);
    }

    final String finalFormatted;
    try {
      finalFormatted = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
        pageWidth: pageWidth,
      ).format(rewritten);
    } on FormatterException catch (e) {
      return BloomFormatResult(
        formatted: source,
        changed: false,
        errorMessage: e.message(color: false),
      );
    }

    return BloomFormatResult(
      formatted: finalFormatted,
      changed: finalFormatted != source,
    );
  }
}

class _SourceReplacement {
  final int offset;
  final int end;
  final String text;

  const _SourceReplacement({
    required this.offset,
    required this.end,
    required this.text,
  });
}

class _BloomFormatVisitor extends RecursiveAstVisitor<void> {
  final String source;
  final LineInfo lineInfo;
  final int pageWidth;
  final List<_SourceReplacement> replacements = [];

  _BloomFormatVisitor({
    required this.source,
    required this.lineInfo,
    required this.pageWidth,
  });

  @override
  void visitNamedExpression(NamedExpression node) {
    super.visitNamedExpression(node);

    final expr = node.expression;
    if (expr is! SimpleStringLiteral) return;
    if (expr.isRaw || expr.isMultiline) return;

    final content = expr.value;
    if (!content.contains(' ')) return;

    final lineNumber = lineInfo.getLocation(expr.offset).lineNumber;
    final lineStarts = lineInfo.lineStarts;
    final lineStart = lineStarts[lineNumber - 1];
    final lineEnd = lineNumber < lineStarts.length ? lineStarts[lineNumber] - 1 : source.length;
    final lineLength = lineEnd - lineStart;

    if (lineLength <= pageWidth) return;

    // Split into adjacent string literals
    final budget = (pageWidth - 24).clamp(24, 60);
    final words = content.split(' ');
    final chunks = <String>[];
    var current = StringBuffer();

    for (final word in words) {
      final candidateLen = current.isEmpty ? word.length : current.length + 1 + word.length;
      if (candidateLen > budget && current.isNotEmpty) {
        chunks.add('${current.toString()} ');
        current = StringBuffer(word);
      } else {
        if (current.isNotEmpty) current.write(' ');
        current.write(word);
      }
    }
    if (current.isNotEmpty) {
      chunks.add(current.toString());
    }

    if (chunks.length <= 1) return;

    final quote = expr.isSingleQuoted ? "'" : '"';
    final replacement = chunks.map((c) => '$quote$c$quote').join('\n');
    replacements.add(_SourceReplacement(
      offset: expr.offset,
      end: expr.end,
      text: replacement,
    ));
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    super.visitTopLevelVariableDeclaration(node);

    if (!node.variables.isConst) return;

    for (final v in node.variables.variables) {
      if (!v.name.lexeme.endsWith('Css')) continue;
      final init = v.initializer;
      if (init is! SimpleStringLiteral) continue;
      if (!init.isRaw || !init.isMultiline) continue;

      final formattedCss = formatCss(init.value);
      if (formattedCss != init.value) {
        final quote = init.isSingleQuoted ? "'''" : '"""';
        replacements.add(_SourceReplacement(
          offset: init.offset,
          end: init.end,
          text: 'r$quote$formattedCss$quote',
        ));
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);

    final typeName = node.constructorName.type.name2.lexeme;
    if (typeName == 'Style') {
      _checkStyleCall(node.argumentList);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    if (node.methodName.name == 'Style') {
      _checkStyleCall(node.argumentList);
    }
  }

  void _checkStyleCall(ArgumentList argumentList) {
    if (argumentList.arguments.length != 1) return;
    final arg = argumentList.arguments.first;
    if (arg is NamedExpression) return;
    if (arg is! SimpleStringLiteral) return;
    if (!arg.isRaw || !arg.isMultiline) return;

    final formattedCss = formatCss(arg.value);
    if (formattedCss != arg.value) {
      final quote = arg.isSingleQuoted ? "'''" : '"""';
      replacements.add(_SourceReplacement(
        offset: arg.offset,
        end: arg.end,
        text: 'r$quote$formattedCss$quote',
      ));
    }
  }
}
