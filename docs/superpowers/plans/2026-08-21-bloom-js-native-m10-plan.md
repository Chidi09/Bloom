# Bloom JS Native M10 — Full-Stack Framework Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `BloomMutation`, `BloomHttpClient`, `BloomEnv` / `BloomEnvironmentSchema`, `BloomContainer`, `BloomFeatureFlags`, and `BloomController` in `packages/bloom_js_native` to achieve complete feature parity with `bloom_framework` without any Flutter SDK dependencies.

**Architecture:** Pure Dart implementation for all 6 subsystems. Reuses the battle-tested architecture and APIs from `packages/bloom_framework` to maintain identical cross-platform semantics.

**Tech Stack:** Dart 3.4+, `package:signals ^5.5.0`, `package:http ^1.2.0`, `package:web ^1.1.0`

**Spec:** `docs/superpowers/specs/2026-08-21-bloom-js-native-m10-design.md`

## Global Constraints
- 0 errors, 0 warnings: `dart analyze packages/bloom_js_native`
- All tests pass: `cd packages/bloom_js_native && dart test`
- Never import `dart:js_interop` or `package:web` in pure Dart files (`mutation.dart`, `http.dart`, `env.dart`, `di.dart`, `features.dart`, `controller.dart`)
- Commit after every task with `feat(bloom_js_native):` prefix

---

### Task 1: Declarative Mutations with Optimistic Updates (`BloomMutation`)

**Files:**
- Create: `packages/bloom_js_native/lib/src/mutation.dart`
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart`
- Create: `packages/bloom_js_native/test/mutation_test.dart`

- [ ] **Step 1: Write failing test for BloomMutation**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `mutation.dart`**
- [ ] **Step 4: Export `src/mutation.dart` in `bloom_js_native.dart`**
- [ ] **Step 5: Verify tests pass**
- [ ] **Step 6: Commit**

---

### Task 2: Isomorphic HTTP Client (`BloomHttpClient`)

**Files:**
- Modify: `packages/bloom_js_native/pubspec.yaml` (add `http: ^1.2.0`)
- Create: `packages/bloom_js_native/lib/src/http.dart`
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart`
- Create: `packages/bloom_js_native/test/http_test.dart`

- [ ] **Step 1: Add `http: ^1.2.0` to `packages/bloom_js_native/pubspec.yaml` & run `dart pub get`**
- [ ] **Step 2: Write failing test for BloomHttpClient**
- [ ] **Step 3: Implement `http.dart`**
- [ ] **Step 4: Export `src/http.dart` in `bloom_js_native.dart`**
- [ ] **Step 5: Verify tests pass**
- [ ] **Step 6: Commit**

---

### Task 3: Environment Parsing & Schema Validation (`BloomEnv` & `BloomEnvironmentSchema`)

**Files:**
- Create: `packages/bloom_js_native/lib/src/env.dart`
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart`
- Create: `packages/bloom_js_native/test/env_test.dart`

- [ ] **Step 1: Write failing test for BloomEnv & BloomEnvironmentSchema**
- [ ] **Step 2: Implement `env.dart`**
- [ ] **Step 3: Export `src/env.dart` in `bloom_js_native.dart`**
- [ ] **Step 4: Verify tests pass**
- [ ] **Step 5: Commit**

---

### Task 4: Dependency Injection Container (`BloomContainer`)

**Files:**
- Create: `packages/bloom_js_native/lib/src/di.dart`
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart`
- Create: `packages/bloom_js_native/test/di_test.dart`

- [ ] **Step 1: Write failing test for BloomContainer**
- [ ] **Step 2: Implement `di.dart`**
- [ ] **Step 3: Export `src/di.dart` in `bloom_js_native.dart`**
- [ ] **Step 4: Verify tests pass**
- [ ] **Step 5: Commit**

---

### Task 5: Dynamic Feature Flags (`BloomFeatureFlags`)

**Files:**
- Create: `packages/bloom_js_native/lib/src/features.dart`
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart`
- Create: `packages/bloom_js_native/test/features_test.dart`

- [ ] **Step 1: Write failing test for BloomFeatureFlags**
- [ ] **Step 2: Implement `features.dart`**
- [ ] **Step 3: Export `src/features.dart` in `bloom_js_native.dart`**
- [ ] **Step 4: Verify tests pass**
- [ ] **Step 5: Commit**

---

### Task 6: State Controllers (`BloomController`)

**Files:**
- Create: `packages/bloom_js_native/lib/src/controller.dart`
- Modify: `packages/bloom_js_native/lib/bloom_js_native.dart`
- Create: `packages/bloom_js_native/test/controller_test.dart`

- [ ] **Step 1: Write failing test for BloomController**
- [ ] **Step 2: Implement `controller.dart`**
- [ ] **Step 3: Export `src/controller.dart` in `bloom_js_native.dart`**
- [ ] **Step 4: Verify tests pass**
- [ ] **Step 5: Commit**

---

### Task 7: Monorepo Quality Gate & Verification

- [ ] **Step 1: Run all Bloom JS Native tests (`dart test --reporter expanded`)**
- [ ] **Step 2: Run all Bloom Framework tests (`flutter test`)**
- [ ] **Step 3: Run analyzer (`dart analyze packages/bloom_js_native`)**
- [ ] **Step 4: Verify JS compilation (`dart compile js -O2 example/main.dart`)**
