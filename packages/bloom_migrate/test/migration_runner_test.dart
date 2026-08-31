import 'dart:io';

import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_migrate/bloom_migrate.dart';
import 'package:test/test.dart';

void main() {
  late Directory migrations;
  late SqliteDbExecutor db;
  late MigrationRunner runner;

  setUp(() {
    migrations = Directory.systemTemp.createTempSync('bloom_migrate_test_');
    db = SqliteDbExecutor.inMemory();
    runner = MigrationRunner(db: db, migrationsDirectory: migrations.path);
  });

  tearDown(() async {
    await db.close();
    migrations.deleteSync(recursive: true);
  });

  test('rejects a changed applied migration before executing its SQL',
      () async {
    final file = File('${migrations.path}/0001_initial.sql')
      ..writeAsStringSync(
          '-- up\nCREATE TABLE original_table (id INTEGER);\n-- down\nDROP TABLE original_table;');
    await runner.migrate();
    file.writeAsStringSync(
        '-- up\nCREATE TABLE changed_table (id INTEGER);\n-- down\nDROP TABLE changed_table;');

    await expectLater(runner.migrate(), throwsA(isA<StateError>()));
    final changed = await db.fetchAll(
        "SELECT name FROM sqlite_master WHERE name = 'changed_table'");
    expect(changed, isEmpty);
  });

  test('releases the SQLite deployment lock after a migration failure',
      () async {
    final file = File('${migrations.path}/0001_initial.sql')
      ..writeAsStringSync(
          '-- up\nCREATE TABLE broken (\n-- down\nDROP TABLE broken;');

    await expectLater(
        runner.migrate(), throwsA(isA<MigrationExecutionException>()));
    file.writeAsStringSync(
        '-- up\nCREATE TABLE recovered (id INTEGER);\n-- down\nDROP TABLE recovered;');

    await runner.migrate();
    final recovered = await db
        .fetchAll("SELECT name FROM sqlite_master WHERE name = 'recovered'");
    expect(recovered, hasLength(1));
  });
}
