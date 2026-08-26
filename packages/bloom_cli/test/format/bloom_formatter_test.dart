// test/format/bloom_formatter_test.dart
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:bloom_cli/src/format/bloom_formatter.dart';
import 'package:bloom_cli/src/format/css_formatter.dart';
import 'package:test/test.dart';

void main() {
  group('BloomFormatter', () {
    late BloomFormatter formatter;

    setUp(() {
      formatter = BloomFormatter(pageWidth: 80);
    });

    test('wraps long named argument string literal and preserves exact concatenated value', () {
      const originalValue =
          'flex items-center justify-between rounded-lg border border-slate-200 px-4 py-2 text-sm font-medium';
      final source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode buildCard() {
  return Div(
    className: '$originalValue',
    children: [
      Span(text: 'Hello'),
    ],
  );
}
''';

      final result = formatter.format(source);
      expect(result.hasError, isFalse);
      expect(result.changed, isTrue);

      // Re-parse formatted output and programmatically extract the concatenated string
      final parseResult = parseString(content: result.formatted, throwIfDiagnostics: true);
      String? extractedConcatenatedValue;

      for (final declaration in parseResult.unit.declarations) {
        if (declaration is FunctionDeclaration) {
          declaration.functionExpression.body.accept(_StringExtractor((val) {
            extractedConcatenatedValue = val;
          }));
        }
      }

      expect(extractedConcatenatedValue, isNotNull);
      expect(extractedConcatenatedValue, equals(originalValue));

      // Verify that lines in formatted output do not exceed page width
      for (final line in result.formatted.split('\n')) {
        expect(line.length, lessThanOrEqualTo(80), reason: 'Line exceeds 80 columns: "$line"');
      }
    });

    test('leaves short string literals untouched', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode buildButton() {
  return Button(
    className: 'btn primary',
    children: [Text('Click')],
  );
}
''';

      final result = formatter.format(source);
      expect(result.hasError, isFalse);
      expect(result.formatted, contains("className: 'btn primary'"));
    });

    test('leaves raw strings untouched', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode buildCode() {
  return Code(
    className: r'long raw string with \d+ regex and spaces that exceeds normal lengths by a lot',
  );
}
''';

      final result = formatter.format(source);
      expect(result.hasError, isFalse);
      // dart_style may still break the line after `className:` — assert the
      // raw string content itself stayed intact as a single literal (was
      // never split into adjacent-string concatenation).
      expect(
        result.formatted,
        contains(r"r'long raw string with \d+ regex and spaces that exceeds normal lengths by a lot'"),
      );
    });

    test('leaves interpolated strings untouched', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode buildDynamic(String activeClass) {
  return Div(
    className: 'base-class $activeClass and some more text that makes it quite long on one line',
  );
}
''';

      final result = formatter.format(source);
      expect(result.hasError, isFalse);
      expect(result.formatted, contains(r'className:'));
      expect(result.formatted, contains(r'$activeClass'));
    });

    test('formats embedded CSS in top-level const <name>Css declaration', () {
      // Built via concatenation: Dart cannot nest a raw triple-quoted string
      // literally inside another triple-quoted literal in source.
      final source = "const tokensCss = r'''\n"
          ':root { --brand-500: #14B8A6; --brand-600: #0D9488; }\n'
          "@media (prefers-color-scheme: dark) { :root { --bg: #000000; } }\n"
          "''';\n";

      final result = formatter.format(source);
      expect(result.hasError, isFalse);
      expect(result.changed, isTrue);
      expect(result.formatted, contains(':root {'));
      expect(result.formatted, contains('  --brand-500: #14B8A6;'));
      expect(result.formatted, contains('  --brand-600: #0D9488;'));
      expect(result.formatted, contains('}'));
      expect(result.formatted, contains('@media (prefers-color-scheme: dark) {'));
    });

    test('formats embedded CSS in Style(...) call', () {
      // Built via concatenation: Dart cannot nest a raw triple-quoted string
      // literally inside another triple-quoted literal in source.
      final source = "import 'package:bloom_js_native/bloom_js_native.dart';\n\n"
          'BloomNode buildStyle() {\n'
          "  return Style(r'''\n"
          '.card { padding: 16px; margin: 8px; }\n'
          "''');\n"
          '}\n';

      final result = formatter.format(source);
      expect(result.hasError, isFalse);
      expect(result.changed, isTrue);
      expect(result.formatted, contains('.card {'));
      expect(result.formatted, contains('  padding: 16px;'));
      expect(result.formatted, contains('  margin: 8px;'));
    });

    test('handles syntax errors gracefully without throwing', () {
      const invalidSource = 'void main() { Div(className: ';
      final result = formatter.format(invalidSource);
      expect(result.hasError, isTrue);
      expect(result.errorMessage, isNotNull);
      expect(result.formatted, equals(invalidSource));
    });
  });

  group('formatCss', () {
    test('normalizes indentation and braces without changing property/value token content', () {
      const rawCss = '''
:root {
  --brand-50: #F0FDFA;
  --brand-500: #14B8A6;
  font-family: 'Plus Jakarta Sans', sans-serif;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0C0A09;
  }
}
* { box-sizing: border-box; }
''';

      final formatted = formatCss(rawCss);

      // Verify structure
      expect(formatted, contains(':root {'));
      expect(formatted, contains('  --brand-50: #F0FDFA;'));
      expect(formatted, contains('  --brand-500: #14B8A6;'));
      expect(formatted, contains("  font-family: 'Plus Jakarta Sans', sans-serif;"));
      expect(formatted, contains('@media (prefers-color-scheme: dark) {'));
      expect(formatted, contains('    --bg: #0C0A09;'));
      expect(formatted, contains('* {'));
      expect(formatted, contains('  box-sizing: border-box;'));

      // Assert all property: value pairs from input are present verbatim in output
      final expectedPairs = [
        '--brand-50: #F0FDFA',
        '--brand-500: #14B8A6',
        "font-family: 'Plus Jakarta Sans', sans-serif",
        '--bg: #0C0A09',
        'box-sizing: border-box',
      ];

      for (final pair in expectedPairs) {
        expect(formatted, contains(pair));
      }

      // Assert token content without whitespace matches
      final strippedInput = rawCss.replaceAll(RegExp(r'\s+'), '');
      final strippedOutput = formatted.replaceAll(RegExp(r'\s+'), '');
      expect(strippedOutput, equals(strippedInput));
    });

    test('does not insert space between CSS function names and opening parenthesis', () {
      const rawCss = '''
.card {
  background: rgba(0, 0, 0, .5);
  filter: blur(4px);
  color: var(--x);
  transform: translateY(4px);
}
''';

      final formatted = formatCss(rawCss);

      expect(formatted, contains('background: rgba(0, 0, 0, .5);'));
      expect(formatted, contains('filter: blur(4px);'));
      expect(formatted, contains('color: var(--x);'));
      expect(formatted, contains('transform: translateY(4px);'));
      expect(formatted, isNot(contains('rgba (')));
      expect(formatted, isNot(contains('blur (')));
      expect(formatted, isNot(contains('var (')));
      expect(formatted, isNot(contains('translateY (')));
    });

    test('does not insert space before parentheses in selectors like :not() and :nth-child()', () {
      const rawCss = '''
.list li:nth-child(2n):not(.foo) {
  color: red;
}
''';

      final formatted = formatCss(rawCss);

      expect(formatted, contains('.list li:nth-child(2n):not(.foo) {'));
      expect(formatted, isNot(contains(':nth-child (')));
      expect(formatted, isNot(contains(':not (')));
    });
  });
}

class _StringExtractor extends RecursiveAstVisitor<void> {
  final void Function(String) onFound;

  _StringExtractor(this.onFound);

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == 'className') {
      final expr = node.expression;
      if (expr is SimpleStringLiteral) {
        onFound(expr.value);
      } else if (expr is AdjacentStrings) {
        final combined = expr.strings
            .whereType<SimpleStringLiteral>()
            .map((s) => s.value)
            .join();
        onFound(combined);
      }
    }
    super.visitNamedExpression(node);
  }
}
