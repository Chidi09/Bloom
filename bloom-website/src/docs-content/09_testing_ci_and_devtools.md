# 09. Testing, CI/CD & DevTools

## 1. Testing Conventions

Bloom standardizes test organization and provides ergonomic utilities for unit, widget, and integration testing without reinventing Flutter's core test framework.

```bash
# Run all tests
bloom test

# Run targeted test suites
bloom test unit
bloom test widget
bloom test integration
bloom test golden
```

---

## 2. Test Harness & Container Overrides

Bloom provides clean test isolation through scoped dependency containers:

```dart
// test/features/auth/auth_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom.dart';
import 'package:my_app/features/auth/controllers/auth_controller.dart';
import 'package:my_app/features/auth/services/auth_service.dart';

class MockAuthService extends BloomMock implements AuthService {
  @override
  Future<bool> login(String user, String pass) async => user == 'valid';
}

void main() {
  late BloomTestScope scope;
  late AuthController controller;

  setUp(() {
    scope = Bloom.createTestScope(overrides: [
      provideSingleton<AuthService>(() => MockAuthService()),
    ]);
    controller = scope.inject<AuthController>();
  });

  tearDown(() => scope.dispose());

  test('successful login sets isAuthenticated to true', () async {
    expect(controller.isAuthenticated.value, isFalse);
    await controller.login('valid', 'pass');
    expect(controller.isAuthenticated.value, isTrue);
  });
}
```

---

## 3. Widget & Route Testing

```dart
// test/routes/dashboard_route_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_framework/bloom_testing.dart';
import 'package:my_app/routes/dashboard.dart';

void main() {
  testWidgets('Dashboard renders user greeting', (tester) async {
    await tester.pumpBloomApp(
      initialLocation: '/dashboard',
      overrides: [
        provideValue<UserSession>(UserSession(name: 'Alice')),
      ],
    );

    expect(find.text('Welcome, Alice!'), findsOneWidget);
  });
}
```

---

## 4. Continuous Integration (CI/CD)

Bloom's predictable CLI commands streamline automated CI pipelines:

### GitHub Actions Workflow Example

```yaml
# .github/workflows/ci.yml
name: Bloom CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Install Bloom CLI
        run: dart pub global activate bloom_cli

      - name: Check Environment
        run: bloom doctor

      - name: Verify Code Generation
        run: |
          bloom generate
          git diff --exit-code

      - name: Static Analysis
        run: bloom analyze

      - name: Run Test Suite
        run: bloom test
```

---

## 5. DevTools & Diagnostics Roadmap

### 5.1 CLI Diagnostics (`bloom doctor` & `bloom inspect`)
* `bloom doctor`: Validates SDK installations, native requirements, and `bloom.yaml` integrity.
* `bloom inspect`: Dumps live dependency trees, active signal graphs, and query cache states to the terminal.

### 5.2 Future Visual DevTools Extension (v0.6+)
Bloom integrates with Dart VM Service extensions to provide a dedicated tab within Flutter DevTools:

```text
┌─────────────────────────────────────────────────────────────┐
│ Bloom DevTools Extension                                    │
├─────────────┬─────────────┬─────────────┬───────────────────┤
│ State Graph │ Query Cache │ Route Tree  │ Dependency Graph  │
├─────────────┴─────────────┴─────────────┴───────────────────┤
│ Active Queries:                                             │
│  • ['users', '102']    [SUCCESS]  Cache: 4m remaining       │
│  • ['posts', 'feed']   [FETCHING] In Flight                 │
│                                                             │
│ Reactive Signals:                                           │
│  • AuthController.isAuthenticated -> false                  │
│  • CartController.totalCount     -> 4                       │
└─────────────────────────────────────────────────────────────┘
```
