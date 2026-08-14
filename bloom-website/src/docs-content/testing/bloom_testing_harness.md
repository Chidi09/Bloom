# 35. Standardized Testing Harness (`bloom_testing.dart`)

Bloom includes a dedicated testing library (`package:bloom_framework/bloom_testing.dart`) that simplifies widget and unit testing with automated test scopes and dependency overrides.

---

## 📦 Importing the Testing Harness

In your test files inside `test/`, import `bloom_testing.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom_testing.dart';
```

`bloom_testing.dart` exports all core Bloom symbols alongside Flutter's official `flutter_test` library.

---

## 🧪 `tester.pumpBloomApp()` Extension

`pumpBloomApp` mounts a fully configured `BloomApp` widget, isolates the test DI container, applies dependency overrides, and settles animations:

```dart
testWidgets('renders profile screen with mocked user', (tester) async {
  final mockAuth = MockAuthService();

  await tester.pumpBloomApp(
    initialLocation: '/profile',
    overrides: [
      BloomTestOverride<AuthService>(mockAuth),
    ],
    home: const ProfileScreen(),
  );

  expect(find.text('Alice Lovelace'), findsOneWidget);
});
```

### Parameters
* `initialLocation` (`String`): Initial router path (default: `'/'`).
* `routes` (`List<RouteBase>?`): Optional custom route table.
* `overrides` (`List<BloomTestOverride>?`): List of dependency overrides applied to the active test scope.
* `home` (`Widget?`): Single root widget to pump directly.
* `theme` (`ThemeData?`): Custom ThemeData to test styling.
* `settleTimeout` (`Duration`): Duration to wait for widget animations to settle.

---

## 🎭 Creating Test Doubles with `BloomMock`

`BloomMock` is a base mock utility that tracks method invocations, call counts, and argument history without heavy external mock generators:

```dart
class MockPaymentGateway extends BloomMock implements PaymentGateway {
  @override
  Future<bool> processPayment(double amount) async {
    recordCall('processPayment');
    return true;
  }
}

// In your test:
final mock = MockPaymentGateway();
await mock.processPayment(49.99);

expect(mock.wasCalled('processPayment'), isTrue);
expect(mock.getCallCount('processPayment'), equals(1));

// Reset counts between steps
mock.resetMockCalls();
```
