import 'dart:async';
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

  test('warns when a migration parses with an empty up section (#15)', () {
    final printed = <String>[];
    // Marker typo: '-- UP' (uppercase) is not recognized, so upSql is empty
    // and the migration would apply nothing yet record as applied.
    final content = '-- UP\nCREATE TABLE typo_table (id INTEGER);';
    runZoned(
      () {
        BloomMigration.parse(
          app: 'test',
          name: '0001_typo',
          filePath: 'migrations/test/0001_typo.sql',
          content: content,
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) =>
            printed.add(line),
      ),
    );

    expect(
      printed.join('\n'),
      contains('0001_typo'),
      reason: 'an empty `-- up` section must emit a loud warning',
    );
    expect(printed.join('\n'), contains('empty'));
  });

  test('does not warn when the up section is present (#15)', () {
    final printed = <String>[];
    runZoned(
      () {
        BloomMigration.parse(
          app: 'test',
          name: '0001_ok',
          filePath: 'migrations/test/0001_ok.sql',
          content: '-- up\nCREATE TABLE ok_table (id INTEGER);',
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) =>
            printed.add(line),
      ),
    );

    expect(printed.where((l) => l.contains('WARNING')), isEmpty);
  });

  test('stores checksums matching SHA-256 golden vectors', () async {
    File('${migrations.path}/0001_empty_up.sql')
        .writeAsStringSync('-- up\n-- down\nDROP TABLE nothing;');
    File('${migrations.path}/0002_ascii_up.sql').writeAsStringSync(
        '-- up\nCREATE TABLE original_table (id INTEGER);\n-- down\nDROP TABLE original_table;');
    File('${migrations.path}/0003_utf8_up.sql').writeAsStringSync(
        "-- up\nCREATE TABLE greetings (msg TEXT);\nINSERT INTO greetings VALUES ('héllo wörld 🌸');\n-- down\nDROP TABLE greetings;");

    await runner.migrate();

    final applied = await runner.getAppliedMigrations();
    final checksums = {for (final m in applied) m.name: m.checksum};
    // sha256('') — the empty-string golden vector.
    expect(checksums['0001_empty_up'],
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    // sha256('CREATE TABLE original_table (id INTEGER);').
    expect(checksums['0002_ascii_up'],
        '4f93b3042499e9b8fd8044d93a147f75d776716bf0ff433b33df53e2a4e10891');
    // sha256 of a UTF-8 multibyte up section.
    expect(checksums['0003_utf8_up'],
        '0e40580c023cc538a547c3e49664ab733ec70f3c4ba708f43488117936d6691c');
  });

}
