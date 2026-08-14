# 44. Contributing to Bloom & Monorepo Architecture

Welcome! This guide outlines how to contribute to the Bloom Framework, run the monorepo test suite, and follow standard commit conventions.

---

## 📦 Monorepo Layout

```text
Bloom/
├── packages/
│   ├── bloom_framework/   # Core Dart/Flutter framework runtime
│   └── bloom_cli/         # Dart command-line interface
├── apps/
│   └── bloom_go/          # Universal native mobile development shell
├── examples/
│   └── bloom_counter/     # End-to-end reference application
└── docs/                  # Technical documentation and guides
```

---

## 🧪 Running the 4-Package Validation Matrix

Before submitting a Pull Request, you must run tests and static analysis across all four packages:

```bash
# 1. Framework
cd /root/dev/Bloom/packages/bloom_framework
flutter test
flutter analyze

# 2. CLI
cd /root/dev/Bloom/packages/bloom_cli
dart test
dart analyze

# 3. Example Reference App
cd /root/dev/Bloom/examples/bloom_counter
flutter test
flutter analyze

# 4. Bloom Go Mobile Shell
cd /root/dev/Bloom/apps/bloom_go
flutter test
flutter analyze
```

---

## 📜 Git Commit Conventions

Bloom uses semantic commit conventions:

### Commit Types
* `feat(<scope>)`: A new framework or CLI feature (e.g. `feat(data,cache): implement TTL garbage collection`).
* `fix(<scope>)`: A bug fix or correctness resolution (e.g. `fix(testing,di): ensure active container scoping in tests`).
* `docs(<scope>)`: Documentation additions and improvements (e.g. `docs(cli): add deploy command guide`).
* `test(<scope>)`: Adding or refactoring test suites (e.g. `test(adapters): add supabase auth test`).

### Example Commit Format
```text
feat(adapters,v1.0): implement Phase 8 full-stack adapters and bloom_testing harness

- Implement official SupabaseAdapter with session persistence and token refresh
- Implement official ServerpodAdapter with signalFromStream
- Create bloom_testing library with pumpBloomApp extension
- 71 total tests passed across 4 packages, 0 analyzer issues
```
