// test/bloom_db_test.dart
import 'package:bloom_db/bloom_db.dart';
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

  // =========================================================================
  // 2. Real PostgreSQL 16 Test Suite Execution
  // =========================================================================
  runOrmTestSuite(
    suiteName: 'PostgreSQL Localhost',
    openExecutor: () async {
      return await PostgresDbExecutor.connect(
        host: 'localhost',
        database: 'bloom_db_test',
        username: 'postgres',
        password: 'postgres',
        port: 5432,
      );
    },
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
}
