import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('BloomContainer', () {
    late BloomContainer container;

    setUp(() {
      container = BloomContainer();
    });

    test('provide() creates a new instance each time', () {
      container.provide<_Counter>(() => _Counter());
      final a = container.inject<_Counter>();
      final b = container.inject<_Counter>();
      expect(identical(a, b), isFalse);
    });

    test('provideSingleton() returns the same instance', () {
      container.provideSingleton<_Counter>(() => _Counter());
      final a = container.inject<_Counter>();
      final b = container.inject<_Counter>();
      expect(identical(a, b), isTrue);
    });

    test('provideSingleton(lazy: false) instantiates eagerly', () {
      int count = 0;
      container.provideSingleton<_Counter>(() {
        count++;
        return _Counter();
      }, lazy: false);
      expect(count, 1);
    });

    test('provideValue() returns the provided instance', () {
      final value = _Counter();
      container.provideValue<_Counter>(value);
      expect(identical(container.inject<_Counter>(), value), isTrue);
    });

    test('inject() throws StateError for unregistered type', () {
      expect(() => container.inject<_Counter>(), throwsA(isA<StateError>()));
    });

    test('injectOrNull() returns null for unregistered type', () {
      expect(container.injectOrNull<_Counter>(), isNull);
    });

    test('override() supersedes registered binding', () {
      container.provide<_Counter>(() => _Counter()..value = 1);
      final override = _Counter()..value = 99;
      container.override<_Counter>(override);
      expect(container.inject<_Counter>().value, 99);
    });

    test('removeOverride() restores original binding', () {
      container.provide<_Counter>(() => _Counter()..value = 1);
      final override = _Counter()..value = 99;
      container.override<_Counter>(override);
      container.removeOverride<_Counter>();
      expect(container.inject<_Counter>().value, 1);
    });

    test('has() returns true when registered', () {
      container.provide<_Counter>(() => _Counter());
      expect(container.has<_Counter>(), isTrue);
    });

    test('has() returns false when not registered', () {
      expect(container.has<_Counter>(), isFalse);
    });

    test('child container resolves from parent', () {
      container.provide<_Counter>(() => _Counter()..value = 42);
      final child = BloomContainer(parent: container);
      expect(child.inject<_Counter>().value, 42);
    });

    test('child container overrides parent resolution', () {
      container.provide<_Counter>(() => _Counter()..value = 1);
      final child = BloomContainer(parent: container);
      child.provide<_Counter>(() => _Counter()..value = 2);
      expect(child.inject<_Counter>().value, 2);
    });

    test('reset() clears all bindings', () {
      container.provide<_Counter>(() => _Counter());
      container.reset();
      expect(container.has<_Counter>(), isFalse);
    });

    test('dumpContainer() returns bindings info', () {
      container.provideSingleton<_Counter>(() => _Counter());
      final dump = container.dumpContainer();
      expect(dump['bindingsCount'], 1);
    });
  });

  group('Global DI helpers', () {
    setUp(() => resetActiveContainer());

    test('provide() + inject() work on global container', () {
      provide<_Counter>(() => _Counter()..value = 7);
      expect(inject<_Counter>().value, 7);
    });

    test('provideSingleton() + inject() return same instance', () {
      provideSingleton<_Counter>(() => _Counter());
      expect(identical(inject<_Counter>(), inject<_Counter>()), isTrue);
    });

    test('provideValue() + inject() return same value', () {
      final v = _Counter()..value = 55;
      provideValue<_Counter>(v);
      expect(identical(inject<_Counter>(), v), isTrue);
    });

    test('injectOrNull() returns null when not registered', () {
      expect(injectOrNull<_Counter>(), isNull);
    });
  });
}

class _Counter {
  int value = 0;
}
