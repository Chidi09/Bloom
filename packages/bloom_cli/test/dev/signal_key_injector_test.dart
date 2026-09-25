import 'package:bloom_cli/src/dev/signal_key_injector.dart';
import 'package:test/test.dart';

void main() {
  group('SignalKeyInjector AST Pass', () {
    test('injects stable key into top-level variable signal declaration', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

final count = signal(0);
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');
      expect(output,
          contains("final count = signal(0, key: 'lib/main.dart#count#0');"));
    });

    test('injects typed signal declaration with generic argument', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

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
import 'package:bloom_js_native/bloom_js_native.dart';

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
import 'package:bloom_js_native/bloom_js_native.dart';

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

    test('scopes stateful instances created from main by stable call site', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

class CounterStore {
  final count = signal(0);
}

void main() {
  final first = CounterStore();
  final second = CounterStore();
}
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');

      expect(
        output,
        contains("signal(0, key: 'lib/main.dart#CounterStore.count#0')"),
      );
      expect(
        output,
        contains(
          "bloomHmrScope('lib/main.dart#main#first#CounterStore', () => (CounterStore()))",
        ),
      );
      expect(
        output,
        contains(
          "bloomHmrScope('lib/main.dart#main#second#CounterStore', () => (CounterStore()))",
        ),
      );
    });

    test('scopes constructor initializers but not arbitrary factory functions',
        () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

class CounterStore {
  final count = signal(0);
}
class PlainValue {}

CounterStore createStore() => CounterStore();
void main() {
  final plain = PlainValue();
}
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');

      expect(output, contains('CounterStore createStore() => CounterStore();'));
      expect(
        output,
        contains(
            "final plain = bloomHmrScope('lib/main.dart#main#plain#PlainValue', () => (PlainValue()));"),
      );
      expect(output, isNot(contains('createStore() => bloomHmrScope(')));
    });

    test('scopes imported constructor call sites without resolving their body',
        () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'stores/cart_store.dart';

void main() {
  final left = CartStore();
  final right = CartStore();
  final loaded = loadStore();
}
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');
      expect(
        output,
        contains(
            "bloomHmrScope('lib/main.dart#main#left#CartStore', () => (CartStore()))"),
      );
      expect(
        output,
        contains(
            "bloomHmrScope('lib/main.dart#main#right#CartStore', () => (CartStore()))"),
      );
      expect(output, contains('final loaded = loadStore();'));
    });

    test('inserting another instance does not shift an existing variable scope',
        () {
      const before = '''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'stores/cart_store.dart';

void main() {
  final cart = CartStore();
}
''';
      const after = '''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'stores/cart_store.dart';

void main() {
  final scratch = CartStore();
  final cart = CartStore();
}
''';

      final first = SignalKeyInjector.injectKeys(
        before,
        relativePath: 'lib/main.dart',
      );
      final second = SignalKeyInjector.injectKeys(
        after,
        relativePath: 'lib/main.dart',
      );
      const cartScope =
          "bloomHmrScope('lib/main.dart#main#cart#CartStore', () => (CartStore()))";
      expect(first, contains(cartScope));
      expect(second, contains(cartScope));
    });

    test('scopes prefixed imported constructor variable initializers', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'stores/cart_store.dart' as stores;

void main() {
  final cart = stores.CartStore();
}
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');
      expect(
        output,
        contains(
            "bloomHmrScope('lib/main.dart#main#cart#CartStore', () => (stores.CartStore()))"),
      );
    });

    test('scopes named imported constructors assigned to variables', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'stores/cart_store.dart' as stores;

void main() {
  final cart = stores.CartStore.fromId('active');
}
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');
      expect(
        output,
        contains(
            "bloomHmrScope('lib/main.dart#main#cart#CartStore', () => (stores.CartStore.fromId('active')))"),
      );
    });

    test('does not scope constructor initializers inside ordinary loops', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  for (var index = 0; index < 2; index++) {
    final store = Store();
  }
}
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');
      expect(output, contains('final store = Store();'));
      expect(output, isNot(contains('bloomHmrScope(')));
    });

    test('scopes subclasses that inherit signal-bearing fields', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

class BaseStore {
  final count = signal(0);
}
class CartStore extends BaseStore {}

void main() {
  final cart = CartStore();
}
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');
      expect(
        output,
        contains(
            "bloomHmrScope('lib/main.dart#main#cart#CartStore', () => (CartStore()))"),
      );
    });

    test('stateful constructor scope respects prefixed Bloom imports', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart' as bloom;

class Store {
  final count = bloom.signal(0);
}
void main() {
  final store = Store();
}
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');
      expect(
        output,
        contains(
            "bloom.bloomHmrScope('lib/main.dart#main#store#Store', () => (Store()))"),
      );
    });

    test('does not inject a scope helper hidden by import show', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart' show signal;

class Store {
  final count = signal(0);
}
void main() {
  final store = Store();
}
''';

      final output =
          SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart');
      expect(output, contains("signal(0, key: 'lib/main.dart#Store.count#0')"));
      expect(output, contains('final store = Store();'));
      expect(output, isNot(contains('bloomHmrScope(')));
    });

    test(
        'adding unrelated signal in another declaration does not shift existing keys',
        () {
      const sourceBefore = '''
import 'package:bloom_js_native/bloom_js_native.dart';

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
import 'package:bloom_js_native/bloom_js_native.dart';

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

    test('does not auto-key signals inside anonymous Live builders', () {
      const source = '''
BloomNode counter() => Live(() => Div(children: [
  Text('count: \${signal(0).value}'),
]));
''';

      final output = SignalKeyInjector.injectKeys(source,
          relativePath: 'lib/component.dart');
      expect(output, equals(source));
    });

    test('scopes and keys signals in an imported Live builder', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode counter() => Live(() => Div(
  text: 'count: ${signal(0).value}',
));
''';

      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/counter.dart',
      );

      expect(output, contains("signal(0, key: 'lib/counter.dart#counter#0')"));
      expect(
        output,
        contains("hotReloadScopeId: 'lib/counter.dart#counter#Live#0'"),
      );

      const editedSource = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode counter() => Live(() => Div(
  text: 'updated text: ${signal(0).value}',
));
''';
      final editedOutput = SignalKeyInjector.injectKeys(
        editedSource,
        relativePath: 'lib/counter.dart',
      );
      expect(
        editedOutput,
        contains("hotReloadScopeId: 'lib/counter.dart#counter#Live#0'"),
        reason: 'editing Live builder contents must not change its scope ID',
      );
    });

    test('scopes signals created inside a Show predicate', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode panel() => Show(
  () => signal(false).value,
  child: P(text: 'Visible'),
  fallback: P(text: 'Hidden'),
);
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/panel.dart',
      );
      expect(
        output,
        contains("hotReloadScopeId: 'lib/panel.dart#panel#Show#0'"),
      );
      expect(
        output,
        contains("signal(false, key: 'lib/panel.dart#panel#0')"),
      );
    });

    test('auto-keys signals created inside event handler callbacks', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

BloomNode counter() => Div(children: [
  Button(
    on: {'click': (_) { signal(0); }},
    onClick: (_) => signal(1),
  ),
  customElement('chart-view', events: {
    'chart-select': (_) => signal(2),
  }),
]);
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/counter.dart',
      );
      expect(output, contains("signal(0, key: 'lib/counter.dart#counter#0')"));
      expect(output, contains("signal(1, key: 'lib/counter.dart#counter#1')"));
      expect(output, contains("signal(2, key: 'lib/counter.dart#counter#2')"));
    });

    test('scopes Memo builder signals with a stable declaration ordinal', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode counter() => Memo<int>(
  () => 1,
  (value) => P(text: 'Count: ${signal(0).value}'),
);
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/counter.dart',
      );
      expect(output,
          contains("hotReloadScopeId: 'lib/counter.dart#counter#Memo#0'"));
      expect(output, contains("signal(0, key: 'lib/counter.dart#counter#0')"));

      const editedSource = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode counter() => Memo<int>(
  () => 1,
  (value) => P(text: 'Updated count: ${signal(0).value}'),
);
''';
      final editedOutput = SignalKeyInjector.injectKeys(
        editedSource,
        relativePath: 'lib/counter.dart',
      );
      expect(
        editedOutput,
        contains("hotReloadScopeId: 'lib/counter.dart#counter#Memo#0'"),
        reason: 'editing Memo builder contents must not change its scope ID',
      );
    });

    test('scopes signals created in a Memo dependency callback', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode counter() => Memo<int>(
  () => signal(0).value,
  (value) => P(text: '$value'),
);
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/counter.dart',
      );
      expect(
        output,
        contains("hotReloadScopeId: 'lib/counter.dart#counter#Memo#0'"),
      );
      expect(
        output,
        contains("signal(0, key: 'lib/counter.dart#counter#0')"),
      );
    });

    test('scopes Suspense resolved and error builders at the call site', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode profile() => Suspense<String>(
  resource: loadName,
  fallback: P(text: 'Loading'),
  builder: (name) => P(text: '${name} ${signal(0).value}'),
  errorBuilder: (error, stack) => P(text: '$error ${signal(1).value}'),
);
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/profile.dart',
      );
      expect(
        output,
        contains("hotReloadScopeId: 'lib/profile.dart#profile#Suspense#0'"),
      );
      expect(output, contains("signal(0, key: 'lib/profile.dart#profile#0')"));
      expect(output, contains("signal(1, key: 'lib/profile.dart#profile#1')"));
    });

    test('auto-keys signals created in a Suspense resource callback', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode profile() => Suspense<int>(
  resource: () async => signal(0).value,
  fallback: P(text: 'Loading'),
  builder: (value) => P(text: '$value'),
);
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/profile.dart',
      );
      expect(
        output,
        contains("hotReloadScopeId: 'lib/profile.dart#profile#Suspense#0'"),
      );
      expect(
        output,
        contains("signal(0, key: 'lib/profile.dart#profile#0')"),
      );
    });

    test('scopes ErrorBoundary builder and fallback callbacks', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode safe() => ErrorBoundary(
  builder: () => P(text: 'Ready ${signal(0).value}'),
  fallback: (error, stack) => P(text: '$error ${signal(1).value}'),
);
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/safe.dart',
      );
      expect(
        output,
        contains("hotReloadScopeId: 'lib/safe.dart#safe#ErrorBoundary#0'"),
      );
      expect(output, contains("signal(0, key: 'lib/safe.dart#safe#0')"));
      expect(output, contains("signal(1, key: 'lib/safe.dart#safe#1')"));
    });

    test('scopes Mount lifecycle callbacks', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode panel() => Mount(
  P(text: 'Panel'),
  onMount: () => signal(0),
  onUnmount: () => signal(1),
);
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/panel.dart',
      );
      expect(
        output,
        contains("hotReloadScopeId: 'lib/panel.dart#panel#Mount#0'"),
      );
      expect(output, contains("signal(0, key: 'lib/panel.dart#panel#0')"));
      expect(output, contains("signal(1, key: 'lib/panel.dart#panel#1')"));
    });

    test('scopes signals created inside effect callbacks', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

void track() {
  effect(() {
    final local = signal(0);
    local.value;
  });
}
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/effect.dart',
      );
      expect(
        output,
        contains("hotReloadScopeId: 'lib/effect.dart#track#effect#0'"),
      );
      expect(output, contains("signal(0, key: 'lib/effect.dart#track#0')"));
    });

    test('does not share one auto-key across repeated list items', () {
      const source = '''
BloomNode list() => ForEach<int>(
  () => [1, 2],
  (item) {
    final selected = signal(false);
    return Button(text: '\${selected.value}');
  },
  key: (item) => item,
);
''';
      final output = SignalKeyInjector.injectKeys(source,
          relativePath: 'lib/component.dart');
      expect(output, equals(source));
    });

    test('scopes keyed ForEach builder signals to their item identity', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode list() => ForEach<int>(
  () => [1, 2],
  (item) => Live(() => P(text: 'Value: ${signal(0).value}')),
  key: (item) => item.toString(),
);
''';

      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/list.dart',
      );

      expect(
        output,
        contains("signal(0, key: 'lib/list.dart#list#0')"),
      );
      expect(
        output,
        matches(RegExp(
            r"hotReloadScopeId: 'lib/list.dart#list#ForEach#[0-9a-f]{64}#0'")),
      );
    });

    test('scopes signals created in a keyed ForEach items callback', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode list() => ForEach<int>(
  () => [signal(0).value],
  (item) => P(text: '$item'),
  key: (item) => item.toString(),
);
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/list.dart',
      );
      expect(
        output,
        matches(RegExp(
            r"hotReloadScopeId: 'lib/list.dart#list#ForEach#[0-9a-f]{64}#0'")),
      );
      expect(output, contains("signal(0, key: 'lib/list.dart#list#0')"));
    });

    test('does not scope unkeyed ForEach builder signals', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode list() => ForEach<int>(
  () => [1, 2],
  (item) => Live(() => P(text: 'Value: ${signal(0).value}')),
);
''';

      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/list.dart',
      );
      expect(output, equals(source));
    });

    test('adding a different keyed list keeps existing list scope identity',
        () {
      const before = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode list() => ForEach<int>(
  () => [1],
  (item) => P(text: '$item'),
  key: (item) => item.toString(),
);
''';
      const after = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode list() => Div(children: [
  ForEach<String>(
    () => ['other'],
    (item) => P(text: item),
    key: (item) => item,
  ),
  ForEach<int>(
    () => [1],
    (item) => P(text: '$item'),
    key: (item) => item.toString(),
  ),
]);
''';
      final beforeOutput = SignalKeyInjector.injectKeys(
        before,
        relativePath: 'lib/list.dart',
      );
      final afterOutput = SignalKeyInjector.injectKeys(
        after,
        relativePath: 'lib/list.dart',
      );
      final scopePattern = RegExp(r"hotReloadScopeId: '([^']+)'");
      final beforeScope = scopePattern.firstMatch(beforeOutput)?.group(1);
      final afterScopes = scopePattern
          .allMatches(afterOutput)
          .map((match) => match.group(1))
          .toList();

      expect(beforeScope, isNotNull);
      expect(afterScopes, contains(beforeScope));
    });

    test('recognizes unprefixed ForEach with a qualified generic type', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:models/models.dart' as models;

BloomNode list() => ForEach<models.Item>(
  () => <models.Item>[],
  (item) => P(text: item.name),
  key: (item) => item.id,
);
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/list.dart',
      );
      expect(output, contains('hotReloadScopeId:'));
    });

    test('handles trailing commas cleanly', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

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

    test('does not rewrite unrelated signal functions', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';
int signal(int value) => value;
final count = signal(0);
''';

      expect(SignalKeyInjector.injectKeys(source), equals(source));
    });

    test('does not rewrite a local variable that shadows an import prefix', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart' as bloom;
final count = bloom.signal(0);
void helper() {
  final bloom = Object();
  bloom.signal(0);
}
''';

      expect(SignalKeyInjector.injectKeys(source), equals(source));
    });

    test('supports a prefixed Bloom import', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart' as bloom;
final count = bloom.signal(0);
''';

      expect(
        SignalKeyInjector.injectKeys(source, relativePath: 'lib/main.dart'),
        contains("bloom.signal(0, key: 'lib/main.dart#count#0')"),
      );
    });

    test('wraps class BloomNode build methods in stable component boundaries',
        () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

class ProductCardComponent {
  BloomNode build() {
    final label = 'Product';
    return Div(text: label);
  }
}
''';

      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/components/product_card.dart',
      );
      expect(
        output,
        contains(
          "return bloomHmrComponent('lib/components/product_card.dart#ProductCardComponent.build', () {",
        ),
      );
      expect(output, contains('final label = \'Product\';'));
      expect(output, contains('return Div(text: label);'));
    });

    test('wraps expression-bodied BloomNode component methods', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart';

class BadgeComponent {
  BloomNode build() => Span(text: 'Ready');
}
''';

      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/components/badge.dart',
      );
      expect(
        output,
        contains(
          "=> bloomHmrComponent('lib/components/badge.dart#BadgeComponent.build', () => (Span(text: 'Ready')))",
        ),
      );
    });

    test('respects prefixed imports and show/hide combinators for boundaries',
        () {
      const prefixed = '''
import 'package:bloom_js_native/bloom_js_native.dart' as bloom;
class BadgeComponent {
  bloom.BloomNode build() => bloom.Span(text: 'Ready');
}
''';
      final prefixedOutput = SignalKeyInjector.injectKeys(
        prefixed,
        relativePath: 'lib/badge.dart',
      );
      expect(prefixedOutput, contains('bloom.bloomHmrComponent('));

      const hidden = '''
import 'package:bloom_js_native/bloom_js_native.dart' hide bloomHmrComponent;
class BadgeComponent {
  BloomNode build() => Span(text: 'Ready');
}
''';
      expect(SignalKeyInjector.injectKeys(hidden), equals(hidden));
    });

    test('does not rewrite signal when hidden by an import combinator', () {
      const source = '''
import 'package:bloom_js_native/bloom_js_native.dart' hide signal;
final count = signal(0);
''';

      expect(SignalKeyInjector.injectKeys(source), equals(source));
    });

    test('scopes signals and loader identity inside lazy callbacks', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

BloomNode settings() => lazy(() async {
  final count = signal(0);
  return Button(text: 'Count: ${count.value}');
}, fallback: const P(text: 'Loading'));
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/settings.dart',
      );
      expect(
        output,
        contains("hotReloadScopeId: 'lib/settings.dart#settings#lazy#0'"),
      );
      expect(
        output,
        contains("signal(0, key: 'lib/settings.dart#settings#0')"),
      );
    });

    test('scopes custom element definition builders', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

void main() {
  defineCustomElement('counter-panel', (context) {
    final count = signal(0);
    return Button(text: 'Count: ${count.value}');
  });
}
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/main.dart',
      );
      expect(
        output,
        contains("hotReloadScopeId: 'lib/main.dart#main#customElement#0'"),
      );
      expect(output, contains("signal(0, key: 'lib/main.dart#main#0')"));
    });

    test('auto-keys signals inside imported batch and untracked callbacks', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  batch(() {
    final batched = signal(0);
    batched.value++;
  });
  untracked(() => signal(1));
}
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/batch.dart',
      );
      expect(output, contains("signal(0, key: 'lib/batch.dart#main#0')"));
      expect(output, contains("signal(1, key: 'lib/batch.dart#main#1')"));
    });

    test('recognizes prefixed batch and untracked callback imports', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart' as bloom;

void main() {
  bloom.batch(() => bloom.signal(0));
  bloom.untracked(() => bloom.signal(1));
}
''';
      final output = SignalKeyInjector.injectKeys(
        source,
        relativePath: 'lib/prefixed_batch.dart',
      );
      expect(
        output,
        contains("bloom.signal(0, key: 'lib/prefixed_batch.dart#main#0')"),
      );
      expect(
        output,
        contains("bloom.signal(1, key: 'lib/prefixed_batch.dart#main#1')"),
      );
    });

    test('does not infer hidden batch or untracked callbacks', () {
      const source = r'''
import 'package:bloom_js_native/bloom_js_native.dart' hide batch, untracked;

void main() {
  batch(() => signal(0));
  untracked(() => signal(1));
}
''';
      expect(SignalKeyInjector.injectKeys(source), equals(source));
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
