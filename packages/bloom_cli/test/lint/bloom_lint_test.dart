// test/lint/bloom_lint_test.dart
import 'package:bloom_cli/src/lint/bloom_lint.dart';
import 'package:test/test.dart';

void main() {
  group('BloomLinter Rules', () {
    group('Rule 1: nullable_event_force_unwrap', () {
      test('TRUE POSITIVE: flags untyped event parameter force unwrap e.value!', () {
        const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode buildInput() {
  return Input(
    onInput: (e) => print(e.value!),
  );
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings.length, equals(1));
        expect(findings.first.ruleName, equals('nullable_event_force_unwrap'));
        expect(findings.first.snippet, contains('e.value!'));
      });

      test('TRUE POSITIVE: flags typed BloomEvent parameter force unwrap ev.checked!', () {
        const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

void handleCheck(BloomEvent ev) {
  final isChecked = ev.checked!;
  print(isChecked);
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings.length, equals(1));
        expect(findings.first.ruleName, equals('nullable_event_force_unwrap'));
        expect(findings.first.snippet, contains('ev.checked!'));
      });

      test('TRUE NEGATIVE: passes null-coalesced e.value ?? ""', () {
        const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode buildInput() {
  return Input(
    onInput: (e) => print(e.value ?? ''),
  );
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings, isEmpty);
      });

      test('TRUE NEGATIVE: ignores force-unwrap on unrelated object with value property', () {
        const source = '''
class NonEventWrapper {
  String? value;
}

void process(NonEventWrapper wrapper) {
  print(wrapper.value!);
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings, isEmpty);
      });
    });

    group('Rule 2: foreach_missing_key', () {
      test('TRUE POSITIVE: flags ForEach without key: argument', () {
        const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode buildList(Signal<List<String>> items) {
  return Ul(
    children: [
      ForEach<String>(
        () => items.value,
        (item) => Li(text: item),
      ),
    ],
  );
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings.length, equals(1));
        expect(findings.first.ruleName, equals('foreach_missing_key'));
        expect(findings.first.snippet, contains('ForEach<String>('));
      });

      test('TRUE NEGATIVE: passes ForEach with key: argument', () {
        const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode buildList(Signal<List<String>> items) {
  return Ul(
    children: [
      ForEach<String>(
        () => items.value,
        (item) => Li(text: item),
        key: (item) => item,
      ),
    ],
  );
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings, isEmpty);
      });
    });

    group('Rule 3: browser_import_in_test', () {
      test('TRUE POSITIVE: flags browser.dart import in test/ file', () {
        const source = '''
import 'package:test/test.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  test('example', () {});
}
''';
        final findings = BloomLinter.lintDartSource(source, filePath: 'test/component_test.dart');
        expect(findings.length, equals(1));
        expect(findings.first.ruleName, equals('browser_import_in_test'));
      });

      test('TRUE NEGATIVE: passes bloom_js_native.dart import in test/ file', () {
        const source = '''
import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  test('example', () {});
}
''';
        final findings = BloomLinter.lintDartSource(source, filePath: 'test/component_test.dart');
        expect(findings, isEmpty);
      });

      test('TRUE NEGATIVE: allows browser.dart import in lib/ entrypoint file', () {
        const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  mount(Div(), '#app');
}
''';
        final findings = BloomLinter.lintDartSource(source, filePath: 'lib/main.dart');
        expect(findings, isEmpty);
      });
    });

    group('Rule 4: live_never_reads_signal', () {
      test('TRUE POSITIVE: flags Live builder that never reads .value', () {
        const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode buildStatic() {
  return Live(() => Span(text: 'Static constant text without signals'));
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings.length, equals(1));
        expect(findings.first.ruleName, equals('live_never_reads_signal'));
      });

      test('TRUE NEGATIVE: passes Live builder accessing count.value', () {
        const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

final count = signal(0);

BloomNode buildDynamic() {
  return Live(() => Span(text: 'Count: \${count.value}'));
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings, isEmpty);
      });
    });

    group('Rule 5: inplace_signal_collection_mutation', () {
      test('TRUE POSITIVE: flags todos.value.add(...)', () {
        const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

void addTodo(Signal<List<String>> todos, String item) {
  todos.value.add(item);
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings.length, equals(1));
        expect(findings.first.ruleName, equals('inplace_signal_collection_mutation'));
        expect(findings.first.snippet, contains('todos.value.add(item)'));
      });

      test('TRUE POSITIVE: flags map.value.clear()', () {
        const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

void clearState(Signal<Map<String, dynamic>> state) {
  state.value.clear();
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings.length, equals(1));
        expect(findings.first.ruleName, equals('inplace_signal_collection_mutation'));
        expect(findings.first.snippet, contains('state.value.clear()'));
      });

      test('TRUE NEGATIVE: passes reassignment todos.value = [...todos.value, item]', () {
        const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

void addTodo(Signal<List<String>> todos, String item) {
  todos.value = [...todos.value, item];
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings, isEmpty);
      });

      test('TRUE NEGATIVE: passes regular list mutation without .value target', () {
        const source = '''
void helper() {
  final list = <String>[];
  list.add('test');
}
''';
        final findings = BloomLinter.lintDartSource(source);
        expect(findings, isEmpty);
      });
    });

    group('Rule 6: hand_authored_style_in_index_html', () {
      test('TRUE POSITIVE: flags <style> tag in web/index.html', () {
        const html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { background-color: #000; }
  </style>
</head>
<body>
  <div id="app"></div>
</body>
</html>
''';
        final findings = BloomLinter.lintHtmlSource(html);
        expect(findings.length, equals(1));
        expect(findings.first.ruleName, equals('hand_authored_style_in_index_html'));
      });

      test('TRUE POSITIVE: flags stylesheet <link> tag in web/index.html', () {
        const html = '''
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <div id="app"></div>
</body>
</html>
''';
        final findings = BloomLinter.lintHtmlSource(html);
        expect(findings.length, equals(1));
        expect(findings.first.ruleName, equals('hand_authored_style_in_index_html'));
      });

      test('TRUE NEGATIVE: passes clean index.html with meta tags and main.js script', () {
        const html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Bloom App</title>
</head>
<body>
  <div id="app"></div>
  <script defer src="main.dart.js"></script>
</body>
</html>
''';
        final findings = BloomLinter.lintHtmlSource(html);
        expect(findings, isEmpty);
      });

      test('TRUE NEGATIVE: skips lines marked AUTO-GENERATED by bloom_cli', () {
        const html = '''
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="tailwind.css"> <!-- AUTO-GENERATED by bloom_cli -->
</head>
<body>
  <div id="app"></div>
</body>
</html>
''';
        final findings = BloomLinter.lintHtmlSource(html);
        expect(findings, isEmpty);
      });
    });
  });
}
