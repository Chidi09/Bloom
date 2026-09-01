// test/bloom_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';
import 'package:flutter/widgets.dart';

class User {
  final String id;
  final String name;
  User(this.id, this.name);
}

void main() {
  setUp(() {
    Bloom.reset();
    BloomData.clear();
  });

  group('Phase 2: BloomData & Query Cache', () {
    test('normalizes keys and matches prefixes correctly', () {
      expect(BloomData.normalizeKey(['users', 42, 'posts']), 'users:42:posts');
      expect(BloomData.matchesKey(['users', '42', 'posts'], ['users']), true);
      expect(BloomData.matchesKey(['users', '42'], ['users', '42']), true);
      expect(BloomData.matchesKey(['products', '1'], ['users']), false);
    });

    test('deduplicates in-flight simultaneous requests for the same key', () async {
      int serverCalls = 0;
      Future<String> fetcher() async {
        serverCalls++;
        await Future.delayed(const Duration(milliseconds: 20));
        return 'data';
      }

      final future1 = BloomData.deduplicate(['test_key'], fetcher);
      final future2 = BloomData.deduplicate(['test_key'], fetcher);

      final results = await Future.wait([future1, future2]);
      expect(results[0], 'data');
      expect(results[1], 'data');
      expect(serverCalls, 1); // Deduplicated to a single call
    });

    test('invalidates matching cached queries', () async {
      BloomData.putEntry(
        QueryCacheEntry<String>(
          key: ['users', '1'],
          data: 'Alice',
          updatedAt: DateTime.now(),
        ),
      );

      expect(BloomData.getQueryData<String>(['users', '1']), 'Alice');
      expect(BloomData.getEntry<String>(['users', '1'])!.isStale, false);

      BloomData.invalidateQueries(['users']);

      expect(BloomData.getEntry<String>(['users', '1'])!.isStale, true);
    });
  });

  group('Phase 2: BloomQuery Async Lifecycle', () {
    test('fetches data, caches in memory, and updates signals', () async {
      int fetchCalls = 0;
      final q = query<String>(
        key: ['greeting'],
        fetch: () async {
          fetchCalls++;
          return 'Hello Bloom';
        },
      );

      // Wait for initial fetch
      await Future.delayed(const Duration(milliseconds: 50));

      expect(q.isSuccess, true);
      expect(q.data.value, 'Hello Bloom');
      expect(fetchCalls, 1);

      // Second query with same key should read from memory cache
      final q2 = query<String>(
        key: ['greeting'],
        fetch: () async {
          fetchCalls++;
          return 'Hello Again';
        },
      );

      expect(q2.data.value, 'Hello Bloom'); // Instant cache hit
      q.dispose();
      q2.dispose();
    });

    test('automatically refetches when cache is invalidated', () async {
      int counter = 1;
      final q = query<int>(
        key: ['counter'],
        fetch: () async => counter++,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(q.data.value, 1);

      // Invalidate key
      BloomData.invalidateQueries(['counter']);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(q.data.value, 2);
      q.dispose();
    });
  });

  group('Phase 2: BloomMutation & Optimistic Updates', () {
    test('handles successful mutation and updates signals', () async {
      final m = mutation<String, String>(
        mutate: (name) async => 'Updated $name',
      );

      expect(m.isIdle, true);
      final res = await m.mutate('Alice');

      expect(res, 'Updated Alice');
      expect(m.isSuccess, true);
      expect(m.data.value, 'Updated Alice');
    });

    test('executes optimistic update with rollback on error', () async {
      BloomData.setQueryData<String>(['item'], (_) => 'Original');

      final m = mutation<String, String>(
        mutate: (name) async {
          throw Exception('Server Error');
        },
        onMutate: (newName) {
          final previous = BloomData.getQueryData<String>(['item']);
          BloomData.setQueryData<String>(['item'], (_) => newName);
          return {'previous': previous};
        },
        onError: (err, newName, context) {
          final prev = context['previous'] as String?;
          BloomData.setQueryData<String>(['item'], (_) => prev!);
        },
      );

      expect(BloomData.getQueryData<String>(['item']), 'Original');

      try {
        await m.mutate('OptimisticValue');
      } catch (_) {}

      expect(m.isError, true);
      // Data was rolled back to original
      expect(BloomData.getQueryData<String>(['item']), 'Original');
    });
  });

  group('Phase 2: Storage & TTL Expiration', () {
    test('stores and reads JSON with TTL expiration', () async {
      final storage = BloomJsonStorage();

      await storage.writeJson('profile', {'name': 'Bob'}, expiresIn: const Duration(seconds: 1));
      var read = await storage.readJson('profile');
      expect(read?['name'], 'Bob');

      // Test already expired
      await storage.writeJson('expired', {'key': 'val'}, expiresIn: const Duration(milliseconds: -100));
      var expiredRead = await storage.readJson('expired');
      expect(expiredRead, null);
    });
  });

  group('Phase 2: OfflineMutationQueue', () {
    test('enqueues mutations and replays sequentially', () async {
      final queue = OfflineMutationQueue();

      queue.enqueue(tag: 'create_task', payload: {'title': 'Task 1'});
      queue.enqueue(tag: 'create_task', payload: {'title': 'Task 2'});

      expect(queue.length, 2);

      final replayedTitles = <String>[];
      final successCount = await queue.processQueue((mutation) async {
        replayedTitles.add(mutation.payload['title'] as String);
        return true;
      });

      expect(successCount, 2);
      expect(queue.isEmpty, true);
      expect(replayedTitles, ['Task 1', 'Task 2']);
    });
  });

  group('Phase 2: BloomAuth & Guard', () {
    test('authenticates user, computes signals, and restores session', () async {
      final storage = InMemoryStorageAdapter();
      final auth = BloomAuth<User>(
        storage: storage,
        userSerializer: (u) => {'id': u.id, 'name': u.name},
        userDeserializer: (json) => User(json['id'] as String, json['name'] as String),
      );

      expect(auth.isAuthenticated.value, false);
      expect(auth.currentUser.value, null);

      await auth.login('test_token_123', User('42', 'Alice'));

      expect(auth.isAuthenticated.value, true);
      expect(auth.token.value, 'test_token_123');
      expect(auth.currentUser.value?.name, 'Alice');

      // Create new instance with same storage to test restoration
      final newAuth = BloomAuth<User>(
        storage: storage,
        userSerializer: (u) => {'id': u.id, 'name': u.name},
        userDeserializer: (json) => User(json['id'] as String, json['name'] as String),
      );

      final restored = await newAuth.restoreSession();
      expect(restored, true);
      expect(newAuth.isAuthenticated.value, true);
      expect(newAuth.currentUser.value?.name, 'Alice');

      await newAuth.logout();
      expect(newAuth.isAuthenticated.value, false);
    });

    test('BloomAuthGuard redirects unauthenticated match', () {
      final guard = const BloomAuthGuard(loginPath: '/login');
      const match = BloomRouteMatch(location: '/dashboard', path: '/dashboard');

      final result = guard.canActivate(FakeBuildContext(), match) as GuardResult;
      expect(result.isAllowed, false);
      expect(result.redirectPath, '/login?from=%2Fdashboard');
    });
  });
}

class FakeBuildContext extends Fake implements BuildContext {}
