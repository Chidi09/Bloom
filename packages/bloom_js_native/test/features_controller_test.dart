import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('BloomFeatureFlags', () {
    late BloomFeatureFlags flags;

    setUp(() {
      flags = BloomFeatureFlags();
    });

    test('isEnabled returns false for unknown flag', () {
      expect(flags.isEnabled('unknown'), isFalse);
    });

    test('isEnabled returns registered default value', () {
      flags.register('dark_mode', defaultValue: true);
      expect(flags.isEnabled('dark_mode'), isTrue);
    });

    test('register with defaultValue=false', () {
      flags.register('beta', defaultValue: false);
      expect(flags.isEnabled('beta'), isFalse);
    });

    test('setOverride changes the flag value', () {
      flags.register('feature', defaultValue: false);
      flags.setOverride('feature', true);
      expect(flags.isEnabled('feature'), isTrue);
    });

    test('watch returns ReadonlySignal that updates on setOverride', () {
      flags.register('live_flag', defaultValue: false);
      final sig = flags.watch('live_flag');
      expect(sig.value, isFalse);
      flags.setOverride('live_flag', true);
      expect(sig.value, isTrue);
    });

    test('registerAll registers multiple flags from map', () {
      flags.registerAll({'a': true, 'b': false, 'c': 'true'});
      expect(flags.isEnabled('a'), isTrue);
      expect(flags.isEnabled('b'), isFalse);
      expect(flags.isEnabled('c'), isTrue);
    });

    test('registerAll updates existing flag values', () {
      flags.register('x', defaultValue: false);
      flags.registerAll({'x': true});
      expect(flags.isEnabled('x'), isTrue);
    });

    test('clearOverrides restores defaults', () {
      flags.register('toggle', defaultValue: false);
      flags.setOverride('toggle', true);
      flags.clearOverrides();
      expect(flags.isEnabled('toggle'), isFalse);
    });

    test('reset clears all flags', () {
      flags.register('a');
      flags.register('b');
      flags.reset();
      expect(flags.getAll(), isEmpty);
    });

    test('getAll returns snapshot of all flags', () {
      flags.registerAll({'x': true, 'y': false});
      final all = flags.getAll();
      expect(all['x'], isTrue);
      expect(all['y'], isFalse);
    });

    test('getAll returns unmodifiable map', () {
      flags.register('f');
      final all = flags.getAll();
      expect(() => (all as dynamic)['new'] = true, throwsA(anything));
    });
  });

  group('BloomController', () {
    test('onInit is called on construction', () {
      _TestController.initCalled = false;
      _TestController();
      expect(_TestController.initCalled, isTrue);
    });

    test('addEffect registers a running effect', () {
      final ctrl = _EffectController();
      expect(ctrl.effectRan, isTrue);
      ctrl.onDispose();
    });

    test('autoDispose cleanup is called on onDispose', () {
      bool cleaned = false;
      final ctrl = _CleanupController(() => cleaned = true);
      ctrl.onDispose();
      expect(cleaned, isTrue);
    });

    test('onDispose sets isDisposed to true', () {
      final ctrl = _SimpleController();
      expect(ctrl.isDisposed, isFalse);
      ctrl.onDispose();
      expect(ctrl.isDisposed, isTrue);
    });

    test('double dispose is idempotent', () {
      final ctrl = _SimpleController();
      ctrl.onDispose();
      expect(() => ctrl.onDispose(), returnsNormally);
      expect(ctrl.isDisposed, isTrue);
    });

    test('addEffect after dispose is a no-op', () {
      final ctrl = _SimpleController();
      ctrl.onDispose();
      expect(() => ctrl.addEffect(() {}), returnsNormally);
    });
  });
}

class _TestController extends BloomController {
  static bool initCalled = false;

  _TestController() {
    initCalled = true;
  }
}

class _EffectController extends BloomController {
  bool effectRan = false;

  _EffectController() {
    addEffect(() {
      effectRan = true;
    });
  }
}

class _CleanupController extends BloomController {
  final void Function() _cleanup;
  _CleanupController(this._cleanup) {
    autoDispose(_cleanup);
  }
}

class _SimpleController extends BloomController {}
