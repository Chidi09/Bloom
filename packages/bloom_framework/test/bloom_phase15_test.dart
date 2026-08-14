// test/bloom_phase15_test.dart
import 'package:bloom_framework/bloom.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Bloom.reset();
    BloomDev.reset();
    BloomPermissions.resetSimulation();
    BloomNetworkInspector.clear();
    BloomSignalsInspector.clear();
    BloomQueryCacheInspector.purgeAll();
  });

  tearDown(() async {
    await Bloom.reset();
    BloomDev.reset();
    BloomPermissions.resetSimulation();
    BloomNetworkInspector.clear();
    BloomSignalsInspector.clear();
    BloomQueryCacheInspector.purgeAll();
  });

  group('Phase 15: Network & Permission Simulation Harness (C5)', () {
    test('BloomDev.setOffline(true) fails all requests with BloomOfflineException (C5)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"ok": true}', 200);
      });

      final client = BloomHttpClient(
        baseUrl: 'https://api.bloom.dev',
        innerClient: mockClient,
      );

      BloomDev.setOffline(true);

      expect(
        () => client.get('/products'),
        throwsA(isA<BloomOfflineException>()),
      );

      // Verify trace was recorded in inspector
      expect(BloomNetworkInspector.traces.length, 1);
      expect(BloomNetworkInspector.traces.first.error, contains('offline'));
    });

    test('BloomDev.simulateNetwork(failureRate: 1.0) deterministically fails 100% of requests (C5)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"ok": true}', 200);
      });

      final client = BloomHttpClient(
        baseUrl: 'https://api.bloom.dev',
        innerClient: mockClient,
      );

      BloomDev.simulateNetwork(failureRate: 1.0, failureStatusCode: 503);

      expect(
        () => client.get('/feed'),
        throwsA(isA<http.ClientException>().having(
          (e) => e.message,
          'message',
          contains('503'),
        )),
      );

      expect(BloomNetworkInspector.traces.length, 1);
      expect(BloomNetworkInspector.traces.first.statusCode, 503);
    });

    test('BloomPermissions.simulate provides deterministic permission statuses without native channel', () async {
      BloomPermissions.simulate(
        permission: BloomPermission.camera,
        status: BloomPermissionStatus.permanentlyDenied,
      );
      BloomPermissions.simulate(
        permission: BloomPermission.notifications,
        status: BloomPermissionStatus.granted,
      );

      final cameraStatus = await BloomPermissions.check(BloomPermission.camera);
      final cameraRequest = await BloomPermissions.request(BloomPermission.camera);
      final notifStatus = await BloomPermissions.check(BloomPermission.notifications);

      expect(cameraStatus, BloomPermissionStatus.permanentlyDenied);
      expect(cameraRequest, BloomPermissionStatus.permanentlyDenied);
      expect(notifStatus, BloomPermissionStatus.granted);
    });
  });

  group('Phase 15: In-App Visual DevTools & Request Replay (C2)', () {
    test('Records network requests and allows real re-execution via replayRequest (C2)', () async {
      var callCount = 0;
      Map<String, String>? lastHeaders;

      final mockClient = MockClient((request) async {
        callCount++;
        lastHeaders = request.headers;
        if (request.headers['X-Custom-Replay'] == 'true') {
          return http.Response('{"status": "replayed", "count": $callCount}', 200);
        }
        return http.Response('{"status": "initial", "count": $callCount}', 200);
      });

      final client = BloomHttpClient(
        baseUrl: 'https://api.bloom.dev',
        innerClient: mockClient,
      );

      // 1. Initial request
      final initialResult = await client.get<Map<String, dynamic>>('/items');
      expect(initialResult['status'], 'initial');
      expect(callCount, 1);

      // Verify trace was recorded
      expect(BloomNetworkInspector.traces.length, 1);
      final initialTraceId = BloomNetworkInspector.traces.first.id;

      // 2. Replay request with modified headers
      final replayedResult = await BloomNetworkInspector.replayRequest(
        initialTraceId,
        modifiedHeaders: {'X-Custom-Replay': 'true'},
        client: client,
      );

      expect(replayedResult['status'], 'replayed');
      expect(callCount, 2);
      expect(lastHeaders?['x-custom-replay'], 'true');

      // Verify second trace recorded as replay
      expect(BloomNetworkInspector.traces.length, 2);
      final replayedTrace = BloomNetworkInspector.traces.last;
      expect(replayedTrace.isReplay, isTrue);
      expect(replayedTrace.originalTraceId, initialTraceId);
      expect(replayedTrace.statusCode, 200);
    });

    test('BloomSignalsInspector tracks, inspects, and modifies signal state remotely', () {
      final counterSignal = signal<int>(10);
      BloomSignalsInspector.trackSignal('app_counter', counterSignal);

      final descriptors = BloomSignalsInspector.inspectAll();
      expect(descriptors.length, 1);
      expect(descriptors.first.name, 'app_counter');
      expect(descriptors.first.currentValue, 10);

      BloomSignalsInspector.setSignalValue('app_counter', 42);
      expect(counterSignal.value, 42);

      final updated = BloomSignalsInspector.inspectAll();
      expect(updated.first.currentValue, 42);
      expect(updated.first.updateCount, 1);
    });

    test('BloomQueryCacheInspector inspects active queries and purges keys', () {
      BloomData.setQueryData(['users', 1], (_) => {'name': 'Alice'});
      BloomData.setQueryData(['users', 2], (_) => {'name': 'Bob'});

      final descriptors = BloomQueryCacheInspector.inspectAll();
      expect(descriptors.length, 2);
      expect(descriptors.any((d) => d.key == 'users:1'), isTrue);

      BloomQueryCacheInspector.purgeKey(['users', 1]);
      expect(BloomData.getQueryData<Map>(['users', 1]), isNull);
      expect(BloomData.getQueryData<Map>(['users', 2]), isNotNull);

      BloomQueryCacheInspector.purgeAll();
      expect(BloomQueryCacheInspector.inspectAll(), isEmpty);
    });
  });

  group('Phase 15: Dev Server Discovery (C1)', () {
    test('Discovers and ingests active dev server broadcast metadata (C1)', () async {
      final discovery = BloomDevServerDiscovery();
      final stream = discovery.discover();

      final server = BloomDiscoveredServer(
        name: "Chidi's MacBook Pro",
        host: '192.168.1.150',
        port: 4040,
        version: '0.1.0',
        projectId: 'bloom_shop',
        appName: 'Bloom Shop',
        lastSeen: DateTime.now(),
      );

      final expectation = expectLater(
        stream,
        emits(predicate<List<BloomDiscoveredServer>>((list) =>
            list.isNotEmpty &&
            list.first.name == "Chidi's MacBook Pro" &&
            list.first.endpoint == 'http://192.168.1.150:4040')),
      );

      discovery.ingestServer(server);
      await expectation;

      discovery.stop();
    });
  });
}
