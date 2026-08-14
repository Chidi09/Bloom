import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom_testing.dart';

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

    test('BloomSupabaseAuthAdapter manages session lifecycle', () async {
      final auth = BloomSupabaseAuthAdapter(
        supabaseUrl: 'https://demo.supabase.co',
        supabaseAnonKey: 'anon-key-123',
      );

      expect(auth.isAuthenticated.value, false);

      final user = BloomSupabaseUser(
        id: 'user_999',
        email: 'test@bloom.dev',
        accessToken: 'access_jwt',
      );

      await auth.setSession(user: user, token: 'access_jwt');
      expect(auth.isAuthenticated.value, true);
      expect(auth.currentUser.value?.id, 'user_999');

      await auth.logout();
      expect(auth.isAuthenticated.value, false);
      expect(auth.currentUser.value, isNull);
    });
  });

  group('Phase 8: Serverpod Adapter', () {
    test('BloomServerpodClient generates reactive signal from stream', () async {
      final client = BloomServerpodClient(
        serverUrl: 'https://api.bloom.dev',
        initialAuthKey: 'auth_key_123',
      );

      expect(client.authKey, 'auth_key_123');

      final controller = StreamController<int>.broadcast();
      final countSignal = client.signalFromStream<int>(
        stream: controller.stream,
        initialValue: 0,
      );

      expect(countSignal.value, 0);

      controller.add(10);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(countSignal.value, 10);

      controller.add(42);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(countSignal.value, 42);

      await controller.close();
    });

    test('BloomServerpodRepository forwards CRUD operations to delegates', () async {
      final items = <Map<String, dynamic>>[];

      final repo = BloomServerpodRepository<Map<String, dynamic>>(
        getAllDelegate: () async => List.unmodifiable(items),
        getByIdDelegate: (id) async => items.firstWhere((e) => e['id'] == id),
        insertDelegate: (item) async {
          items.add(item);
          return item;
        },
        updateDelegate: (item) async {
          final idx = items.indexWhere((e) => e['id'] == item['id']);
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
      expect((await repo.findById(1))?['name'], 'Updated Item');

      final deleted = await repo.delete(1);
      expect(deleted, true);
      expect((await repo.findAll()).isEmpty, true);
    });
  });

  group('Phase 8: Bloom Testing Harness', () {
    testWidgets('pumpBloomApp helper mounts widgets with isolated overrides', (tester) async {
      await tester.pumpBloomApp(
        home: const Scaffold(
          body: Center(
            child: Text('Hello Bloom 1.0!'),
          ),
        ),
      );

      expect(find.text('Hello Bloom 1.0!'), findsOneWidget);
    });
  });
}
