# Bloom JS Native M9 — Data, Advanced Routing & Transitions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a pure-Dart SWR query data client (`BloomQuery`, `BloomData`), navigation guards (`BloomRouteGuard`), nested shell layouts (`BloomRoute.shell`), and concurrent transitions (`startTransition`, `isTransitionPending`) in `packages/bloom_js_native`.

**Architecture:** Pure Dart implementation for data caching and descriptor-level routing/transitions. The data layer mirrors `BloomData` from the framework without Flutter dependencies, routing adds guard resolution and nested layout chaining, and transitions provide deferred batching.

**Tech Stack:** Dart 3.4+, `package:signals ^5.5.0`, `package:web ^1.1.0`

**Spec:** `docs/superpowers/specs/2026-08-21-bloom-js-native-m9-design.md`

## Global Constraints
- 0 errors, 0 warnings: `dart analyze packages/bloom_js_native`
- All tests pass: `cd packages/bloom_js_native && dart test`
- Never import `dart:js_interop` or `package:web` in pure Dart files (`data.dart`, `transition.dart`, `router.dart`)
- Commit after every task with `feat(bloom_js_native):` prefix

---

### Task 1: Pure-Dart SWR Query Data Client (`BloomData` & `BloomQuery`)

**Files:**
- Create: `packages/bloom_js_native/lib/src/data.dart`
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart`
- Create: `packages/bloom_js_native/test/data_test.dart`

**Interfaces:**
- Produces: `BloomQuery<T>`, `QueryStatus`, `BloomData`, `query<T>()`

- [ ] **Step 1: Write failing tests for BloomData and BloomQuery**

Create `packages/bloom_js_native/test/data_test.dart`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    BloomData.clear();
  });

  group('BloomData & BloomQuery', () {
    test('query fetches and updates signal data', () async {
      final q = query<String>(
        key: ['users', 1],
        fetch: () async => 'Alice',
      );
      expect(q.isLoading, isTrue);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(q.isSuccess, isTrue);
      expect(q.data.value, 'Alice');
      q.dispose();
    });

    test('deduplicates concurrent fetches for same key', () async {
      int fetchCount = 0;
      Future<String> fetcher() async {
        fetchCount++;
        await Future.delayed(const Duration(milliseconds: 20));
        return 'Data';
      }

      final q1 = query<String>(key: ['items'], fetch: fetcher);
      final q2 = query<String>(key: ['items'], fetch: fetcher);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(fetchCount, 1);
      expect(q1.data.value, 'Data');
      expect(q2.data.value, 'Data');
      q1.dispose();
      q2.dispose();
    });

    test('invalidateQueries triggers refetch on active queries', () async {
      int count = 0;
      final q = query<int>(
        key: ['counter'],
        fetch: () async => ++count,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      expect(q.data.value, 1);

      BloomData.invalidateQueries(['counter']);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(q.data.value, 2);
      q.dispose();
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/bloom_js_native && dart test test/data_test.dart
```

- [ ] **Step 3: Implement `data.dart`**

Create `packages/bloom_js_native/lib/src/data.dart` with `BloomData`, `QueryCacheEntry`, `BloomQuery`, and `query()` helper.

- [ ] **Step 4: Export `src/data.dart` from `bloom_js_native.dart`**

Add `export 'src/data.dart';` to `lib/bloom_js_native.dart`.

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/data_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/data.dart packages/bloom_js_native/lib/bloom_js_native.dart packages/bloom_js_native/test/data_test.dart
git commit -m "feat(bloom_js_native): pure-Dart SWR query data caching client"
```

---

### Task 2: Route Guards & Navigation Interception (`BloomRouteGuard`)

**Files:**
- Modify: `packages/bloom_js_native/lib/src/router.dart`
- Modify: `packages/bloom_js_native/lib/src/router_browser.dart`
- Create: `packages/bloom_js_native/test/router_guards_test.dart`

**Interfaces:**
- Produces: `GuardResult`, `BloomRouteGuard`, `BloomRoute.guards`

- [ ] **Step 1: Write failing tests for Route Guards**

Create `packages/bloom_js_native/test/router_guards_test.dart`:

```dart
import 'dart:async';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

class AuthGuard extends BloomRouteGuard {
  final bool isAuthenticated;
  const AuthGuard(this.isAuthenticated);

  @override
  FutureOr<GuardResult> canActivate(String location, Map<String, String> params) {
    if (!isAuthenticated) return GuardResult.redirect('/login');
    return GuardResult.allow();
  }
}

void main() {
  group('BloomRouteGuard', () {
    test('allows navigation when guard permits', () async {
      final router = BloomRouter([
        BloomRoute('/dashboard', (_) => Text('Dashboard'), guards: [const AuthGuard(true)]),
        BloomRoute('/login', (_) => Text('Login')),
      ]);
      final match = router.match('/dashboard');
      expect(match, isNotNull);
      final allowed = await router.evaluateGuards(match!.route, '/dashboard', match.params);
      expect(allowed.isAllowed, isTrue);
    });

    test('redirects navigation when guard denies', () async {
      final router = BloomRouter([
        BloomRoute('/dashboard', (_) => Text('Dashboard'), guards: [const AuthGuard(false)]),
        BloomRoute('/login', (_) => Text('Login')),
      ]);
      final match = router.match('/dashboard');
      expect(match, isNotNull);
      final result = await router.evaluateGuards(match!.route, '/dashboard', match.params);
      expect(result.isAllowed, isFalse);
      expect(result.redirectPath, '/login');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/bloom_js_native && dart test test/router_guards_test.dart
```

- [ ] **Step 3: Update `router.dart` with `GuardResult`, `BloomRouteGuard`, and `evaluateGuards`**

- [ ] **Step 4: Update `router_browser.dart` to execute guards on `navigate()`**

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/router_guards_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/router.dart packages/bloom_js_native/lib/src/router_browser.dart packages/bloom_js_native/test/router_guards_test.dart
git commit -m "feat(bloom_js_native): route guards and redirect interception"
```

---

### Task 3: Nested Route Shells & Layout Persistence (`BloomRoute.shell`)

**Files:**
- Modify: `packages/bloom_js_native/lib/src/router.dart`
- Create: `packages/bloom_js_native/test/router_shell_test.dart`

**Interfaces:**
- Produces: `BloomRoute.shell({required layout, required routes, guards})`

- [ ] **Step 1: Write failing tests for Nested Shell Layouts**

Create `packages/bloom_js_native/test/router_shell_test.dart`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('BloomRoute.shell', () {
    test('matches nested route and wraps with shell layout', () {
      final router = BloomRouter([
        BloomRoute.shell(
          layout: (child, params) => Div(className: 'app-shell', children: [child]),
          routes: [
            BloomRoute('/admin/users', (_) => P(text: 'Users Table')),
            BloomRoute('/admin/settings', (_) => P(text: 'Settings Form')),
          ],
        ),
      ]);

      final match = router.match('/admin/users');
      expect(match, isNotNull);
      final rendered = renderToHtml(match!.build());
      expect(rendered, '<div class="app-shell"><p>Users Table</p></div>');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/bloom_js_native && dart test test/router_shell_test.dart
```

- [ ] **Step 3: Implement `BloomRoute.shell` and nested route matching in `router.dart`**

- [ ] **Step 4: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/router_shell_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add packages/bloom_js_native/lib/src/router.dart packages/bloom_js_native/test/router_shell_test.dart
git commit -m "feat(bloom_js_native): nested persistent shell layouts"
```

---

### Task 4: Concurrent Transitions & Deferred Reactivity (`startTransition`)

**Files:**
- Create: `packages/bloom_js_native/lib/src/transition.dart`
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart`
- Create: `packages/bloom_js_native/test/transition_test.dart`

**Interfaces:**
- Produces: `startTransition(void Function() update)`, `isTransitionPending`

- [ ] **Step 1: Write failing tests for transitions**

Create `packages/bloom_js_native/test/transition_test.dart`:

```dart
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('Concurrent Transitions', () {
    test('isTransitionPending signal tracks transition execution', () async {
      expect(isTransitionPending.value, isFalse);
      startTransition(() {
        // Deferred state update
      });
      expect(isTransitionPending.value, isTrue);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(isTransitionPending.value, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/bloom_js_native && dart test test/transition_test.dart
```

- [ ] **Step 3: Implement `transition.dart`**

Create `packages/bloom_js_native/lib/src/transition.dart` with `_isTransitionPending` signal and `startTransition()`.

- [ ] **Step 4: Export `src/transition.dart` in `bloom_js_native.dart`**

- [ ] **Step 5: Run tests to verify pass**

```bash
cd packages/bloom_js_native && dart test test/transition_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add packages/bloom_js_native/lib/src/transition.dart packages/bloom_js_native/lib/bloom_js_native.dart packages/bloom_js_native/test/transition_test.dart
git commit -m "feat(bloom_js_native): concurrent reactivity and startTransition"
```

---

### Task 5: Monorepo Quality Gate & Verification

- [ ] **Step 1: Run all Bloom JS Native unit & integration tests**

```bash
cd packages/bloom_js_native && dart test --reporter expanded
```

- [ ] **Step 2: Run Bloom Framework test suite**

```bash
cd packages/bloom_framework && flutter test
```

- [ ] **Step 3: Run monorepo analyzer**

```bash
dart analyze packages/bloom_js_native
```

- [ ] **Step 4: Verify JS example compilation**

```bash
cd packages/bloom_js_native/example && dart compile js -O2 -o /tmp/m9_build.js main.dart
```
