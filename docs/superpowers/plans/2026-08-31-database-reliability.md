# Database Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make migrations tamper-evident and safe under concurrent deployment, and retain every supported `@BloomField` option in generated model metadata.

**Architecture:** Migration history stores a SHA-256 checksum of each up migration and validates it before apply or rollback. Migration runs acquire a dialect-specific database lock, while SQL parsing uses a lexical scanner that preserves PostgreSQL dollar-quoted bodies. The generator must distinguish absent annotation values from explicitly supplied `false` values so inference is only used when an option is absent.

**Tech Stack:** Dart, `package:bloom_db`, `package:crypto`, `source_gen`, SQLite and PostgreSQL SQL.

**Spec:** User-approved chat design on 2026-08-31.

## Global Constraints

- Keep SQLite and PostgreSQL observable behavior identical.
- Do not split semicolons inside quoted strings, comments, or PostgreSQL dollar-quoted strings.
- A changed applied migration must fail before executing schema SQL.
- Deployment locks must always be released, including failures.

---

### Task 1: Migration integrity and locking

**Files:**
- Modify: `packages/bloom_migrate/lib/src/migration_runner.dart`
- Modify: `packages/bloom_migrate/lib/src/migration_file.dart`
- Modify: `packages/bloom_migrate/test/migration_runner_test.dart`
- Modify: `packages/bloom_migrate/test/migration_file_test.dart`

- [ ] Add a `checksum` column to migration history and a deterministic SHA-256 checksum for `upSql`.
- [ ] Reject an already-applied migration whose stored checksum differs from its current file before any execution.
- [ ] Serialize `migrate` and `rollback` with a PostgreSQL advisory lock and a SQLite lock row transaction, releasing locks in `finally`.
- [ ] Extend the statement scanner for nested block comments and PostgreSQL `$tag$...$tag$` literals.
- [ ] Add SQLite regression tests for checksum mismatch, lock release after failure, and dollar-quoted function bodies.
- [ ] Run `dart test` and `dart analyze` in `packages/bloom_migrate`.

### Task 2: Generator annotation preservation

**Files:**
- Modify: `packages/bloom_db_generator/lib/src/model_generator.dart`
- Modify: `packages/bloom_db_generator/test/model_generator_test.dart`

- [ ] Read each `BloomField` constructor argument as nullable presence-aware data.
- [ ] Preserve explicit `false` for `primaryKey`, `auto`, and `nullable` instead of treating it as absent and applying inferred defaults.
- [ ] Preserve column, kind, unique, and index metadata in generated `FieldMeta` output.
- [ ] Add generator fixtures/assertions for explicit false options and custom field metadata.
- [ ] Run `dart test` and `dart analyze` in `packages/bloom_db_generator`.
