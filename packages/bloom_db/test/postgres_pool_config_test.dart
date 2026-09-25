import 'package:bloom_db/bloom_db.dart';
import 'package:test/test.dart';

void main() {
  group('PostgreSQL pooled executor configuration', () {
    test('rejects a zero or negative connection limit', () {
      expect(
        () => PostgresDbExecutor.pooled(
          host: 'localhost',
          database: 'unused',
          username: 'unused',
          maxConnections: 0,
        ),
        throwsArgumentError,
      );
    });

    test(
      'creates and closes an unused pool without connecting eagerly',
      () async {
        final db = PostgresDbExecutor.pooled(
          host: '127.0.0.1',
          database: 'unused',
          username: 'unused',
          maxConnections: 2,
        );

        expect(db.dialect, Dialect.postgres);
        await expectLater(db.close(), completes);
      },
    );
  });
}
