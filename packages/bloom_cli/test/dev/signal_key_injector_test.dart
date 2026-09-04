import 'package:bloom_cli/src/dev/signal_key_injector.dart';
import 'package:test/test.dart';

void main() {
  group('SignalKeyInjector AST Pass', () {
    test('injects stable key into top-level variable signal declaration', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

final count = signal(0);
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');
      expect(output,
          contains("final count = signal(0, key: 'lib/main.dart#count#0');"));
    });

    test('injects typed signal declaration with generic argument', () {
      const source = '''
final activeUser = signal<String?>('alice');
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/user.dart');
      expect(
          output,
          contains(
              "final activeUser = signal<String?>('alice', key: 'lib/user.dart#activeUser#0');"));
    });

    test('injects ordinal scoped to enclosing function declaration', () {
      const source = '''
void main() {
  final a = signal(1);
  final b = signal(2);
}
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');
      expect(output,
          contains("final a = signal(1, key: 'lib/main.dart#main#0');"));
      expect(output,
          contains("final b = signal(2, key: 'lib/main.dart#main#1');"));
    });

    test(
        'injects class fields and methods with class-qualified enclosing names',
        () {
      const source = '''
class Store {
  final cart = signal<Map<int, int>>({});
  final total = signal(0);

  void reset() {
    final flag = signal(false);
  }
}
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/store.dart');
      expect(
          output,
          contains(
              "final cart = signal<Map<int, int>>({}, key: 'lib/store.dart#Store.cart#0');"));
      expect(
          output,
          contains(
              "final total = signal(0, key: 'lib/store.dart#Store.total#0');"));
      expect(
          output,
          contains(
              "final flag = signal(false, key: 'lib/store.dart#Store.reset#0');"));
    });

    test(
        'adding unrelated signal in another declaration does not shift existing keys',
        () {
      const sourceBefore = '''
final first = signal(10);
void run() {
  final tracked = signal('tracked');
}
''';
      final outBefore = SignalKeyInjector.injectKeys(sourceBefore,
          relativePath: 'lib/main.dart');
      expect(
          outBefore,
          contains(
              "final tracked = signal('tracked', key: 'lib/main.dart#run#0');"));

      // Add unrelated signal above tracked
      const sourceAfter = '''
final newUnrelated = signal(999);
final first = signal(10);
void run() {
  final tracked = signal('tracked');
}
''';
      final outAfter = SignalKeyInjector.injectKeys(sourceAfter,
          relativePath: 'lib/main.dart');
      // tracked's key MUST be identical
      expect(
          outAfter,
          contains(
              "final tracked = signal('tracked', key: 'lib/main.dart#run#0');"));
      // first's key MUST also be identical
      expect(outAfter,
          contains("final first = signal(10, key: 'lib/main.dart#first#0');"));
      expect(
          outAfter,
          contains(
              "final newUnrelated = signal(999, key: 'lib/main.dart#newUnrelated#0');"));
    });

    test('preserves explicit developer-provided key argument', () {
      const source = '''
final count = signal(0, key: 'my-custom-stable-key');
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');
      expect(output, equals(source),
          reason: 'Explicit developer keys must not be overridden');
    });

    test(
        'injects stable keys for signals inside anonymous closures / Live builders',
        () {
      const source = '''
BloomNode counter() => Live(() => Div(children: [
  Text('count: \${signal(0).value}'),
]));
''';

      final output = SignalKeyInjector.injectKeys(source,
          relativePath: 'lib/component.dart');
      expect(
          output, contains("signal(0, key: 'lib/component.dart#counter#0')"));
    });

    test('handles trailing commas cleanly', () {
      const source = '''
final list = signal(
  [1, 2, 3],
);
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/data.dart');
      expect(
          output,
          contains(
              "final list = signal(\n  [1, 2, 3], key: 'lib/data.dart#list#0',\n);"));
    });

    test('returns original source on syntax errors without crashing', () {
      const badSource = '''
void main() {
  this is invalid syntax !!!
}
''';

      final output =
          SignalKeyInjector.injectKeys(badSource, relativePath: 'lib/bad.dart');
      expect(output, equals(badSource));
    });
  });
}
