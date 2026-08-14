// test/bloom_adapters_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom_testing.dart';

abstract class GreetingService {
  String getGreeting();
}

class DefaultGreetingService implements GreetingService {
  @override
  String getGreeting() => 'Hello from Default Service';
}

class MockGreetingService extends BloomMock implements GreetingService {
  @override
  String getGreeting() {
    recordCall('getGreeting');
    return 'Hello from Mock Service';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Bloom.reset();
  });

  group('Phase 8: Supabase Adapter', () {
    test('serializes and deserializes BloomSupabaseUser model', () {
      final user = BloomSupabaseUser(
        id: 'user_1234',
        email: 'alice@bloom.dev',
        accessToken: 'jwt_token_abc',
        refreshToken: 'refresh_token_xyz',
        userMetadata: {'full_name': 'Alice Bloom'},
      );

      final json = user.toJson();
      expect(json['id'], 'user_1234');
      expect(json['email'], 'alice@bloom.dev');
      expect(json['user_metadata']['full_name'], 'Alice Bloom');

      final deserialized = BloomSupabaseUser.fromJson(json);
      expect(deserialized.id, 'user_1234');
      expect(deserialized.email, 'alice@bloom.dev');
      expect(deserialized.userMetadata['full_name'], 'Alice Bloom');
    });

    test('BloomSupabaseAuthAdapter manages session lifecycle and token refresh', () async {
      final auth = BloomSupabaseAuthAdapter(
        supabaseUrl: 'https://demo.supabase.co',
        supabaseAnonKey: 'anon-key-123',
      );

      expect(auth.isAuthenticated.value, false);

      final user = BloomSupabaseUser(
        id: 'user_999',
        email: 'test@bloom.dev',
        accessToken: 'access_jwt_1',
        refreshToken: 'refresh_token_abc',
      );

      await auth.setSession(user: user, token: 'access_jwt_1');
      expect(auth.isAuthenticated.value, true);
      expect(auth.currentUser.value?.id, 'user_999');
      expect(auth.token.value, 'access_jwt_1');

      await auth.logout();
      expect(auth.isAuthenticated.value, false);
      expect(auth.currentUser.value, isNull);
    });
  });

  group('Phase 8: Serverpod Adapter', () {
    test('BloomServerpodClient generates reactive signal from stream with disposal', () async {
      final client = BloomServerpodClient(
        serverUrl: 'https://api.bloom.dev',
        initialAuthKey: 'auth_key_123',
      );

      expect(client.authKey, 'auth_key_123');

      final controller = StreamController<int>.broadcast();
      final streamSignal = client.signalFromStream<int>(
        stream: controller.stream,
        initialValue: 0,
      );

      expect(streamSignal.value, 0);

      controller.add(10);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(streamSignal.value, 10);

      controller.add(42);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(streamSignal.value, 42);

      await streamSignal.dispose();
      await controller.close();
    });

    test('BloomServerpodRepository forwards CRUD operations including id parameter', () async {
      final items = <Map<String, dynamic>>[];
      int? lastUpdatedId;

      final repo = BloomServerpodRepository<Map<String, dynamic>>(
        getAllDelegate: () async => List.unmodifiable(items),
        getByIdDelegate: (id) async => items.firstWhere((e) => e['id'] == id),
        insertDelegate: (item) async {
          items.add(item);
          return item;
        },
        updateDelegate: (id, item) async {
          lastUpdatedId = id;
          final idx = items.indexWhere((e) => e['id'] == id);
          items[idx] = item;
          return item;
        },
        deleteDelegate: (id) async {
          items.removeWhere((e) => e['id'] == id);
          return true;
        },
      );

      await repo.create({'id': 1, 'name': 'First Item'});
      expect((await repo.findAll()).length, 1);

      final fetched = await repo.findById(1);
      expect(fetched?['name'], 'First Item');

      await repo.update(1, {'id': 1, 'name': 'Updated Item'});
      expect(lastUpdatedId, 1);
      expect((await repo.findById(1))?['name'], 'Updated Item');

      final deleted = await repo.delete(1);
      expect(deleted, true);
      expect((await repo.findAll()).isEmpty, true);
    });
  });

  group('Phase 8: Bloom Testing Harness & Mocking', () {
    testWidgets('pumpBloomApp overrides resolve correctly inside widget tree via inject<T>()', (tester) async {
      final mockService = MockGreetingService();

      await tester.pumpBloomApp(
        overrides: [
          BloomTestOverride<GreetingService>(mockService),
        ],
        home: Builder(
          builder: (context) {
            final service = inject<GreetingService>();
            return Scaffold(
              body: Center(
                child: Text(service.getGreeting()),
              ),
            );
          },
        ),
      );

      expect(find.text('Hello from Mock Service'), findsOneWidget);
      expect(mockService.wasCalled('getGreeting'), true);
      expect(mockService.getCallCount('getGreeting'), 1);
    });

    test('BloomHttpClient throws StateError when relative path called without baseUrl', () {
      final client = BloomHttpClient();
      expect(
        () => client.get('/api/v1/users'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
