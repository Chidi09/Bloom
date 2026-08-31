import 'package:bloom_migrate/bloom_migrate.dart';
import 'package:test/test.dart';

void main() {
  test('does not split PostgreSQL dollar-quoted function bodies or comments',
      () {
    final statements = splitSqlStatements(r'''
/* outer ; /* nested ; */ still outer ; */
CREATE FUNCTION notify() RETURNS void AS $body$
BEGIN
  PERFORM 1;
  -- a semicolon ; in a comment
END;
$body$ LANGUAGE plpgsql;
CREATE TABLE events (id INTEGER);
''');

    expect(statements, hasLength(2));
    expect(statements.first, contains('PERFORM 1;'));
    expect(statements.first, contains(r'$body$'));
    expect(statements.last, 'CREATE TABLE events (id INTEGER);');
  });
}
