// test/bloom_db_test.dart
import 'dart:io';

import 'package:bloom_db/bloom_db.dart';
import 'package:test/test.dart';

import 'shared_orm_tests.dart';

void main() {
  // =========================================================================
  // 1. SQLite In-Memory Test Suite Execution
  // =========================================================================
  runOrmTestSuite(
    suiteName: 'SQLite :memory:',
    openExecutor: () async {
      return SqliteDbExecutor.inMemory();
    },
    supportsNestedTransactions: true,
    setupSchema: (executor) async {
      await executor.execute('DROP TABLE IF EXISTS "auth_users";');
      await executor.execute('''
        CREATE TABLE "auth_users" (
          "id" INTEGER PRIMARY KEY AUTOINCREMENT,
          "name" TEXT NOT NULL,
          "email" TEXT NOT NULL,
          "age" INTEGER NOT NULL DEFAULT 0,
          "is_active" INTEGER NOT NULL DEFAULT 1
        );
      ''');
    },
  );

  // PostgreSQL integration tests require an explicitly prepared test database.
  // Keep plain `dart test` useful on machines without a local PostgreSQL service;
  // CI opts in after provisioning its PostgreSQL container.
  if (Platform.environment['BLOOM_TEST_POSTGRES'] == '1') {
    final postgresPort = int.tryParse(
          Platform.environment['BLOOM_TEST_POSTGRES_PORT'] ?? '',
        ) ??
        5432;

    // =======================================================================
    // 2. Real PostgreSQL Test Suite Execution
    // =======================================================================
    runOrmTestSuite(
      suiteName: 'PostgreSQL Localhost',
      openExecutor: () async {
        return await PostgresDbExecutor.connect(
          host: 'localhost',
          database: 'bloom_db_test',
          username: 'postgres',
          password: 'postgres',
          port: postgresPort,
        );
      },
      supportsNestedTransactions: false,
      setupSchema: (executor) async {
        await executor.execute('DROP TABLE IF EXISTS "auth_users" CASCADE;');
        await executor.execute('''
        CREATE TABLE "auth_users" (
          "id" BIGSERIAL PRIMARY KEY,
          "name" TEXT NOT NULL,
          "email" TEXT NOT NULL,
          "age" BIGINT NOT NULL DEFAULT 0,
          "is_active" BOOLEAN NOT NULL DEFAULT TRUE
        );
      ''');
      },
    );

    // =======================================================================
    // 3. PostgreSQL Pooled Executor Contract
    // =======================================================================
    runOrmTestSuite(
      suiteName: 'PostgreSQL Pool Localhost',
      openExecutor: () async {
        return PostgresDbExecutor.pooled(
          host: 'localhost',
          database: 'bloom_db_test',
          username: 'postgres',
          password: 'postgres',
          port: postgresPort,
          maxConnections: 4,
        );
      },
      supportsNestedTransactions: false,
      setupSchema: (executor) async {
        await executor.execute('DROP TABLE IF EXISTS "auth_users" CASCADE;');
        await executor.execute('''
        CREATE TABLE "auth_users" (
          "id" BIGSERIAL PRIMARY KEY,
          "name" TEXT NOT NULL,
          "email" TEXT NOT NULL,
          "age" BIGINT NOT NULL DEFAULT 0,
          "is_active" BOOLEAN NOT NULL DEFAULT TRUE
        );
      ''');
      },
    );

    group('PostgreSQL pooled concurrency', () {
      late PostgresDbExecutor db;

      setUp(() {
        db = PostgresDbExecutor.pooled(
          host: 'localhost',
          database: 'bloom_db_test',
          username: 'postgres',
          password: 'postgres',
          port: postgresPort,
          maxConnections: 4,
        );
      });

      tearDown(() => db.close());

      test('runs concurrent queries on multiple backend sessions', () async {
        final rows = await Future.wait(
          List.generate(
            4,
            (_) => db
                .fetchOne('SELECT pg_backend_pid() AS pid FROM pg_sleep(0.1)'),
          ),
        );
        final backendPids = rows.map((row) => row.tryIntByName('pid')).toSet();

        expect(backendPids.whereType<int>().length, greaterThan(1));
      });
    });
  } else {
    test(
      'PostgreSQL integration suite requires BLOOM_TEST_POSTGRES=1',
      () {},
      skip: 'Set BLOOM_TEST_POSTGRES=1 when bloom_db_test is available.',
    );
  }
}
