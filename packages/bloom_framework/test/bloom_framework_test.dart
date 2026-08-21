// test/bloom_framework_test.dart
import 'package:bloom_framework/bloom_testing.dart';
import 'package:flutter/material.dart';

class CounterService {
  int value = 42;
}

class SampleController extends BloomController {
  final count = signal(0);
  late final isEven = computed(() => count.value.isEven);

  void increment() => count.value++;
}

class TestAuthGuard extends BloomGuard {
  final bool allow;
  const TestAuthGuard({required this.allow});

  @override
  GuardResult canActivate(BuildContext context, BloomRouteMatch match) {
    if (allow) return GuardResult.allow();
    return GuardResult.redirect('/login');
  }
}

void main() {
  setUp(() {
    Bloom.reset();
  });

  group('Core: BloomEnv', () {
    test('parses environment string correctly', () {
      const sampleEnv = '''
        # Comments should be ignored
        APP_NAME=BloomShop
        PORT=8080
        IS_PRODUCTION=false
        API_RATE=3.14
        QUOTED_VAL="hello world"
      ''';

      BloomEnv.loadContent(sampleEnv);

      expect(BloomEnv.get('APP_NAME'), 'BloomShop');
      expect(BloomEnv.getInt('PORT'), 8080);
      expect(BloomEnv.getBool('IS_PRODUCTION'), false);
      expect(BloomEnv.getDouble('API_RATE'), 3.14);
      expect(BloomEnv.get('QUOTED_VAL'), 'hello world');
      expect(BloomEnv.has('APP_NAME'), true);
      expect(BloomEnv.has('NON_EXISTENT'), false);
    });
  });

  group('Core: BloomConfig', () {
    test('parses yaml configuration into strongly-typed model', () {
      const sampleYaml = '''
        schema: 1
        name: test_app
        version: 1.2.3
        platforms:
          android:
            min_sdk: 26
            package: com.bloom.test
          ios:
            minimum_version: "16.0"
        features:
          routing: true
          state: true
        plugins:
          - secure_storage
          - camera:
              permission: "Allow camera"
      ''';

      final config = BloomConfig.fromYaml(sampleYaml);

      expect(config.schema, 1);
      expect(config.name, 'test_app');
      expect(config.version, '1.2.3');
      expect(config.platforms.androidMinSdk, 26);
      expect(config.platforms.androidPackage, 'com.bloom.test');
      expect(config.platforms.iosMinVersion, '16.0');
      expect(config.features.routing, true);
      expect(config.plugins.containsKey('secure_storage'), true);
      expect(config.plugins.containsKey('camera'), true);
    });
  });

  group('DI: BloomContainer', () {
    test('registers and resolves transient dependencies', () {
      int creations = 0;
      provide<CounterService>(() {
        creations++;
        return CounterService();
      });

      final instance1 = inject<CounterService>();
      final instance2 = inject<CounterService>();

      expect(instance1.value, 42);
      expect(identical(instance1, instance2), false);
      expect(creations, 2);
    });

    test('registers and resolves singletons', () {
      int creations = 0;
      provideSingleton<CounterService>(() {
        creations++;
        return CounterService();
      });

      final instance1 = inject<CounterService>();
      final instance2 = inject<CounterService>();

      expect(identical(instance1, instance2), true);
      expect(creations, 1);
    });

    test('supports test mock overrides', () {
      final defaultService = CounterService()..value = 10;
      final mockService = CounterService()..value = 999;

      provideSingleton<CounterService>(() => defaultService);
      expect(inject<CounterService>().value, 10);

      Bloom.container.override<CounterService>(mockService);
      expect(inject<CounterService>().value, 999);

      Bloom.container.removeOverride<CounterService>();
      expect(inject<CounterService>().value, 10);
    });
  });

  group('State: Signals & Controller', () {
    test('signal and computed values update synchronously', () {
      final controller = SampleController();

      expect(controller.count.value, 0);
      expect(controller.isEven.value, true);

      controller.increment();

      expect(controller.count.value, 1);
      expect(controller.isEven.value, false);

      controller.onDispose();
      expect(controller.isDisposed, true);
    });

    test('effect executes on signal mutation and cleans up', () {
      final s = signal(10);
      int runCount = 0;
      int observedValue = 0;

      final cleanup = effect(() {
        runCount++;
        observedValue = s.value;
      });

      expect(runCount, 1);
      expect(observedValue, 10);

      s.value = 20;
      expect(runCount, 2);
      expect(observedValue, 20);

      cleanup();

      s.value = 30;
      expect(runCount, 2); // No longer triggers after cleanup
    });
  });

  group('Router: Guards & Match', () {
    test('guard allows or redirects based on criteria', () {
      final allowedGuard = const TestAuthGuard(allow: true);
      final deniedGuard = const TestAuthGuard(allow: false);
      const match = BloomRouteMatch(location: '/secret', path: '/secret');

      final allowedResult = allowedGuard.canActivate(
        FakeBuildContext(),
        match,
      );
      expect(allowedResult.isAllowed, true);

      final deniedResult = deniedGuard.canActivate(
        FakeBuildContext(),
        match,
      );
      expect(deniedResult.isAllowed, false);
      expect(deniedResult.redirectPath, '/login');
    });
  });

  group('Widgets: Watch & BloomApp', () {
    testWidgets('Watch widget rebuilds on signal change', (tester) async {
      final count = signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Watch((context) {
              return Text('Count: ${count.value}');
            }),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      count.value++;
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });
  });

  group('Core: Bloom.reset() Lifecycle & Test Isolation', () {
    test('clears BloomData query cache and resets simulated permissions', () async {
      // 1. Populate query cache
      BloomData.setQueryData(['test', 'key'], (old) => {'hello': 'world'});
      expect(BloomData.entryCount, 1);
      expect(BloomData.getQueryData<Map<String, dynamic>>(['test', 'key']), {'hello': 'world'});

      // 2. Simulate permission override
      BloomPermissions.simulate(
        permission: BloomPermission.camera,
        status: BloomPermissionStatus.granted,
      );
      final permStatusBefore = await BloomPermissions.check(BloomPermission.camera);
      expect(permStatusBefore, BloomPermissionStatus.granted);

      // 3. Invoke Bloom.reset()
      await Bloom.reset();

      // 4. Verify BloomData query cache is completely emptied
      expect(BloomData.entryCount, 0);
      expect(BloomData.getQueryData<Map<String, dynamic>>(['test', 'key']), isNull);

      // 5. Verify BloomPermissions simulation is cleared
      BloomPermissions.simulate(
        permission: BloomPermission.camera,
        status: BloomPermissionStatus.denied,
      );
      expect(await BloomPermissions.check(BloomPermission.camera), BloomPermissionStatus.denied);
      BloomPermissions.resetSimulation();
    });
  });
}

class FakeBuildContext extends Fake implements BuildContext {}
