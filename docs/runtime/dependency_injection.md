# 13. Dependency Injection (DI) & Scoping

Bloom includes a lightweight, type-safe, hierarchical Dependency Injection container with zero build-runner code generation required.

---

## 📦 Container Registration Methods

Dependencies are registered inside `BloomContainer`:

### 1. `provide<T>(Factory)` — Transient Factory
Instantiates a fresh instance of `T` on every resolution:
```dart
container.provide<UuidGenerator>((c) => UuidGenerator());
```

### 2. `provideSingleton<T>(Factory)` — Lazy Singleton
Instantiates the dependency on first `inject<T>()` call and caches the instance for subsequent resolutions:
```dart
container.provideSingleton<DatabaseService>((c) => DatabaseService());
```

### 3. `provideValue<T>(T instance)` — Eager Value
Registers an already-created instance directly:
```dart
container.provideValue<BloomConfig>(config);
```

---

## 🔍 Resolving Dependencies

Dependencies can be resolved globally or from a specific container instance:

### Global Resolution
```dart
// Throws StateError if T is not registered
final api = inject<ApiService>();

// Returns null if T is not registered
final auth = injectOrNull<BloomAuthBase>();
```

### Container Resolution
```dart
final db = container.inject<DatabaseService>();
```

---

## 🌳 Hierarchical Container Scopes

Containers support parent-child relationships. A child container inherits all registrations from its parent, but local registrations or overrides do not pollute the parent:

```dart
final parentContainer = BloomContainer();
parentContainer.provideValue<String>('parent_value');

final childContainer = BloomContainer(parent: parentContainer);
childContainer.provideValue<int>(42);

print(childContainer.inject<String>()); // 'parent_value' (inherited)
print(childContainer.inject<int>());    // 42
print(parentContainer.injectOrNull<int>()); // null (parent untouched)
```

---

## 🧪 Isolated Test Scoping (`BloomTestScope`)

For unit and widget tests, `Bloom.createTestScope()` creates an isolated container and activates it as the active global container via `setActiveContainer(container)`:

```dart
testWidgets('overrides service during testing', (tester) async {
  final mockService = MockPaymentService();

  await tester.pumpBloomApp(
    overrides: [
      BloomTestOverride<PaymentService>(mockService),
    ],
    home: const CheckoutScreen(),
  );

  // CheckoutScreen calls inject<PaymentService>() and receives mockService!
});
```

When the test completes, `BloomTestScope.dispose()` restores the original container without state leaks.

---

## 🔍 Container Diagnostics (`dumpContainer()`)

To inspect registered bindings at runtime or inside DevTools:

```dart
final bindings = Bloom.container.dumpContainer();
print(bindings);
// {
//   "DatabaseService": "singleton (instantiated: true)",
//   "UuidGenerator": "factory",
//   "BloomConfig": "value"
// }
```
