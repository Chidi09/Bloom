# 36. Testing Recipes & Best Practices

Comprehensive end-to-end testing recipes covering state controllers, asynchronous queries, optimistic mutations, and dependency injection overrides.

---

## 🍳 Recipe 1: Testing a `BloomController`

Controllers can be tested in isolation as pure Dart unit tests:

```dart
// test/features/counter_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';
import 'package:quickstart_app/features/counter/counter_controller.dart';

void main() {
  setUp(() => Bloom.reset());

  test('CounterController increments, decrements, and resets', () {
    final controller = CounterController();

    expect(controller.count.value, 0);

    controller.increment();
    expect(controller.count.value, 1);

    controller.decrement();
    expect(controller.count.value, 0);

    // Negative values are guarded
    controller.decrement();
    expect(controller.count.value, 0);
  });
}
```

---

## 🍳 Recipe 2: Testing a Query with Mock Data

```dart
// test/data/user_query_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';

void main() {
  setUp(() {
    Bloom.reset();
    BloomData.clearCache();
  });

  test('BloomQuery fetches data, updates signals, and caches payload', () async {
    final query = BloomData.query<String>(
      queryKey: ['greeting'],
      queryFn: () async => 'Hello from Test Server',
    );

    // Initial loading state
    expect(query.isLoading.value, true);

    // Await query completion
    await query.refetch();

    expect(query.isLoading.value, false);
    expect(query.isSuccess.value, true);
    expect(query.data.value, 'Hello from Test Server');
  });
}
```

---

## 🍳 Recipe 3: Testing an Optimistic Mutation with Rollback

```dart
// test/data/mutation_rollback_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';

void main() {
  setUp(() {
    Bloom.reset();
    BloomData.clearCache();
  });

  test('BloomMutation rolls back state on server exception', () async {
    final listQuery = BloomData.query<List<String>>(
      queryKey: ['items'],
      queryFn: () async => ['Item 1', 'Item 2'],
    );
    await listQuery.refetch();

    final deleteMutation = BloomData.mutation<bool, String>(
      mutationFn: (id) async => throw Exception('Server 500 Error'),
      onMutate: (id) {
        final prev = listQuery.data.value ?? [];
        listQuery.setData(prev.where((item) => item != id).toList());
        return {'previous': prev};
      },
      onError: (err, id, context) {
        if (context != null && context['previous'] != null) {
          listQuery.setData(context['previous'] as List<String>);
        }
      },
    );

    // Trigger failing mutation
    await deleteMutation.mutate('Item 1');

    // Verified: data rolled back to original 2 items
    expect(listQuery.data.value?.length, 2);
    expect(deleteMutation.isError.value, true);
  });
}
```

---

## 🍳 Recipe 4: Overriding Dependencies in Widget Tests

```dart
// test/widgets/profile_route_test.dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom_testing.dart';

class FakeAnalyticsService extends BloomMock implements AnalyticsService {
  @override
  void trackEvent(String name) => recordCall(name);
}

void main() {
  testWidgets('ProfileRoute triggers screen view analytics on mount', (tester) async {
    final mockAnalytics = FakeAnalyticsService();

    await tester.pumpBloomApp(
      overrides: [
        BloomTestOverride<AnalyticsService>(mockAnalytics),
      ],
      home: const ProfileRoute(),
    );

    expect(mockAnalytics.wasCalled('profile_viewed'), isTrue);
  });
}
```
