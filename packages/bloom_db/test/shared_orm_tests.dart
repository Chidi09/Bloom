// test/shared_orm_tests.dart
import 'package:bloom_db/bloom_db.dart';
import 'package:test/test.dart';
import 'models/user.dart';

/// Parameterized test suite executed symmetrically against both SQLite and Postgres.
void runOrmTestSuite({
  required String suiteName,
  required Future<DbExecutor> Function() openExecutor,
  required Future<void> Function(DbExecutor executor) setupSchema,
}) {
  group('[$suiteName] Bloom ORM Contract Test Suite', () {
    late DbExecutor db;

    setUp(() async {
      db = await openExecutor();
      await setupSchema(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. save() - INSERT-only with auto-PK exclusion and RETURNING *', () async {
      final user = User(
        name: 'Alice',
        email: 'alice@example.com',
        age: 25,
        isActive: true,
      );

      final saved = await user.save(db);
      expect(saved.id, greaterThan(0));
      expect(saved.name, 'Alice');
      expect(saved.email, 'alice@example.com');
      expect(saved.age, 25);
      expect(saved.isActive, isTrue);

      // Verify it's a new instance (immutability)
      expect(identical(saved, user), isFalse);
      expect(user.id, 0); // Original remains unchanged
    });

    test('2. get() & first() - Single record lookup and error semantics', () async {
      final u1 = await User(name: 'Bob', email: 'bob@example.com', age: 30).save(db);
      final u2 = await User(name: 'Charlie', email: 'charlie@example.com', age: 35).save(db);

      // get() success
      final fetched = await UserOrmExtension.objects().filter({'id': u1.id}).get(db);
      expect(fetched.name, 'Bob');
      expect(fetched.email, 'bob@example.com');

      // first() success
      final first = await UserOrmExtension.objects().filter({'id': u2.id}).first(db);
      expect(first, isNotNull);
      expect(first!.name, 'Charlie');

      // first() not found returns null
      final notFoundFirst = await UserOrmExtension.objects().filter({'id': 99999}).first(db);
      expect(notFoundFirst, isNull);

      // get() NotFound error
      expect(
        () => UserOrmExtension.objects().filter({'id': 99999}).get(db),
        throwsA(isA<BloomOrmNotFoundError>()),
      );

      // get() MultipleObjectsReturned error
      expect(
        () => UserOrmExtension.objects().filter(Q('age__gte', 20)).get(db),
        throwsA(isA<BloomOrmMultipleObjectsReturnedError>()),
      );
    });

    test('3. filter() & exclude() expression tree & operators', () async {
      await User(name: 'Alice', email: 'alice@example.com', age: 20).save(db);
      await User(name: 'Bob', email: 'bob@example.com', age: 30).save(db);
      await User(name: 'Charlie', email: 'charlie@example.com', age: 40).save(db);

      // Comparison lookups
      final gte25 = await UserOrmExtension.objects().filter(Q('age__gte', 25)).all(db);
      expect(gte25.length, 2);

      final lt35 = await UserOrmExtension.objects().filter(Q('age__lt', 35)).all(db);
      expect(lt35.length, 2);

      final startsWithAli = await UserOrmExtension.objects().filter(Q('name__startswith', 'Ali')).all(db);
      expect(startsWithAli.length, 1);
      expect(startsWithAli.first.name, 'Alice');

      final endsWithLie = await UserOrmExtension.objects().filter(Q('name__endswith', 'lie')).all(db);
      expect(endsWithLie.length, 1);
      expect(endsWithLie.first.name, 'Charlie');

      final icontains = await UserOrmExtension.objects().filter(Q('name__icontains', 'OB')).all(db);
      expect(icontains.length, 1);
      expect(icontains.first.name, 'Bob');

      final inList = await UserOrmExtension.objects().filter(Q('age__in', [20, 40])).all(db);
      expect(inList.length, 2);

      // exclude
      final notBob = await UserOrmExtension.objects().exclude(Q('name', 'Bob')).all(db);
      expect(notBob.length, 2);
      expect(notBob.any((u) => u.name == 'Bob'), isFalse);

      // Composite expressions: (age < 25 OR age > 35) & isActive
      final composite = await UserOrmExtension.objects()
          .filter((Q('age__lt', 25) | Q('age__gt', 35)) & Q('isActive', true))
          .all(db);
      expect(composite.length, 2);
      expect(composite.map((u) => u.name).toSet(), {'Alice', 'Charlie'});
    });

    test('4. SQL Injection safety - filter values with quotes & semicolons', () async {
      const maliciousName = "O'Brien'); DROP TABLE auth_users; --";
      const dangerousEmail = "hack' OR '1'='1";

      final saved = await User(
        name: maliciousName,
        email: dangerousEmail,
        age: 99,
        isActive: true,
      ).save(db);

      // Filter by the exact special character value
      final fetched = await UserOrmExtension.objects().filter(Q('name', maliciousName)).get(db);
      expect(fetched.id, saved.id);
      expect(fetched.name, maliciousName);
      expect(fetched.email, dangerousEmail);

      // Verify table was not dropped and data is intact
      final count = await UserOrmExtension.objects().count(db);
      expect(count, 1);

      // Inspect debug_sql and ensure parameter was bound, not inlined
      final (sql, params) = UserOrmExtension.objects()
          .filter(Q('name', maliciousName))
          .debugSql(db.dialect);

      expect(sql.contains(maliciousName), isFalse);
      expect(params.contains(maliciousName), isTrue);
    });

    test('5. order_by(), limit(), and offset()', () async {
      await User(name: 'User1', email: 'u1@example.com', age: 10).save(db);
      await User(name: 'User2', email: 'u2@example.com', age: 30).save(db);
      await User(name: 'User3', email: 'u3@example.com', age: 20).save(db);
      await User(name: 'User4', email: 'u4@example.com', age: 40).save(db);

      // Ascending order
      final asc = await UserOrmExtension.objects().orderBy('age').all(db);
      expect(asc.map((u) => u.age).toList(), [10, 20, 30, 40]);

      // Descending order
      final desc = await UserOrmExtension.objects().orderBy('-age').all(db);
      expect(desc.map((u) => u.age).toList(), [40, 30, 20, 10]);

      // Limit and offset
      final page = await UserOrmExtension.objects()
          .orderBy('age')
          .limit(2)
          .offset(1)
          .all(db);
      expect(page.map((u) => u.age).toList(), [20, 30]);
    });

    test('6. exists() and count()', () async {
      expect(await UserOrmExtension.objects().exists(db), isFalse);
      expect(await UserOrmExtension.objects().count(db), 0);

      await User(name: 'David', email: 'david@example.com', age: 28).save(db);

      expect(await UserOrmExtension.objects().exists(db), isTrue);
      expect(await UserOrmExtension.objects().count(db), 1);
      expect(
        await UserOrmExtension.objects().filter(Q('name', 'David')).exists(db),
        isTrue,
      );
      expect(
        await UserOrmExtension.objects().filter(Q('name', 'NonExistent')).exists(db),
        isFalse,
      );
    });

    test('6b. count() ignores limit/offset instead of throwing (#10)',
        () async {
      await User(name: 'A', email: 'a@example.com', age: 1).save(db);
      await User(name: 'B', email: 'b@example.com', age: 2).save(db);
      await User(name: 'C', email: 'c@example.com', age: 3).save(db);

      // OFFSET beyond the row count must return the total, not throw
      // BloomOrmNotFoundError (SELECT COUNT(*) … OFFSET n yields zero rows).
      expect(
        await UserOrmExtension.objects().offset(10).count(db),
        3,
      );
      expect(
        await UserOrmExtension.objects().limit(1).offset(10).count(db),
        3,
      );
      expect(
        await UserOrmExtension.objects().limit(2).count(db),
        3,
      );
    });

    test('6c. LIKE lookups escape wildcards in user input (#12)', () async {
      await User(name: 'plain', email: 'p@example.com', age: 1).save(db);
      await User(name: 'a%b', email: 'pct@example.com', age: 2).save(db);
      await User(name: 'a_b', email: 'us@example.com', age: 3).save(db);

      // `%` in input must match a literal percent, not act as a wildcard.
      final pct = await UserOrmExtension.objects()
          .filter(Q('name__contains', 'a%b'))
          .all(db);
      expect(pct.map((u) => u.name).toList(), ['a%b']);

      // `_` in input must match a literal underscore, not any character.
      final under = await UserOrmExtension.objects()
          .filter(Q('name__contains', 'a_b'))
          .all(db);
      expect(under.map((u) => u.name).toList(), ['a_b']);

      // startsWith / endsWith with wildcards behave literally too.
      final starts = await UserOrmExtension.objects()
          .filter(Q('name__startswith', 'a_'))
          .all(db);
      expect(starts.map((u) => u.name).toList(), ['a_b']);
      final ends = await UserOrmExtension.objects()
          .filter(Q('name__endswith', '%b'))
          .all(db);
      expect(ends.map((u) => u.name).toList(), ['a%b']);
    });

    test('7. Model instance update() and delete() with NotFound error semantics', () async {
      final user = await User(name: 'Eva', email: 'eva@example.com', age: 22).save(db);

      // Update instance
      final updatedUser = User(
        id: user.id,
        name: 'Eva Green',
        email: 'evagreen@example.com',
        age: 23,
        isActive: false,
      );
      await updatedUser.update(db);

      final reloaded = await UserOrmExtension.objects().filter({'id': user.id}).get(db);
      expect(reloaded.name, 'Eva Green');
      expect(reloaded.email, 'evagreen@example.com');
      expect(reloaded.age, 23);
      expect(reloaded.isActive, isFalse);

      // Update NotFound on 0 rows affected
      final nonExistent = User(id: 99999, name: 'Ghost', email: 'ghost@example.com');
      expect(
        () => nonExistent.update(db),
        throwsA(isA<BloomOrmNotFoundError>()),
      );

      // Delete instance
      await updatedUser.delete(db);
      expect(await UserOrmExtension.objects().filter({'id': user.id}).exists(db), isFalse);

      // Delete NotFound on 0 rows affected
      expect(
        () => nonExistent.delete(db),
        throwsA(isA<BloomOrmNotFoundError>()),
      );
    });

    test('8. QuerySet update() with literals and F() expressions', () async {
      await User(name: 'Player1', email: 'p1@example.com', age: 10).save(db);
      await User(name: 'Player2', email: 'p2@example.com', age: 20).save(db);

      // Literal bulk update
      final affected = await UserOrmExtension.objects()
          .filter(Q('name', 'Player1'))
          .update(db, {'email': 'player1_updated@example.com'});
      expect(affected, 1);

      final p1 = await UserOrmExtension.objects().filter(Q('name', 'Player1')).get(db);
      expect(p1.email, 'player1_updated@example.com');

      // Atomic F() arithmetic update: age = age + 5
      final fAffected = await UserOrmExtension.objects()
          .filter(Q('age__gte', 10))
          .update(db, {'age': F('age') + 5});
      expect(fAffected, 2);

      final players = await UserOrmExtension.objects().orderBy('name').all(db);
      expect(players[0].age, 15); // 10 + 5
      expect(players[1].age, 25); // 20 + 5
    });

    test('9. QuerySet delete()', () async {
      await User(name: 'Del1', email: 'd1@example.com', age: 10).save(db);
      await User(name: 'Del2', email: 'd2@example.com', age: 20).save(db);
      await User(name: 'Keep', email: 'k@example.com', age: 30).save(db);

      final deleted = await UserOrmExtension.objects()
          .filter(Q('age__lt', 25))
          .delete(db);
      expect(deleted, 2);

      final remaining = await UserOrmExtension.objects().all(db);
      expect(remaining.length, 1);
      expect(remaining.first.name, 'Keep');
    });

    test('10. bulk_create() - multi-row insert returning primary keys', () async {
      final usersToCreate = [
        User(name: 'Bulk1', email: 'b1@example.com', age: 21),
        User(name: 'Bulk2', email: 'b2@example.com', age: 22),
        User(name: 'Bulk3', email: 'b3@example.com', age: 23),
      ];

      final pks = await QuerySet.bulkCreate(db, UserOrmExtension.meta(), usersToCreate);
      expect(pks.length, 3);
      expect(pks.every((pk) => pk > 0), isTrue);

      final allUsers = await UserOrmExtension.objects().orderBy('id').all(db);
      expect(allUsers.length, 3);
      expect(allUsers.map((u) => u.name).toList(), ['Bulk1', 'Bulk2', 'Bulk3']);
    });

    test('11. get_or_create() & update_or_create()', () async {
      // 1. get_or_create on new record -> creates
      final (u1, created1) = await UserOrmExtension.objects()
          .filter(Q('name', 'GOC_User'))
          .getOrCreate(db, defaults: {
        'name': 'GOC_User',
        'email': 'goc@example.com',
        'age': 33,
        'is_active': true,
      });
      expect(created1, isTrue);
      expect(u1.name, 'GOC_User');
      expect(u1.id, greaterThan(0));

      // 2. get_or_create on existing record -> returns existing
      final (u2, created2) = await UserOrmExtension.objects()
          .filter(Q('name', 'GOC_User'))
          .getOrCreate(db, defaults: {
        'name': 'GOC_User',
        'email': 'different@example.com',
        'age': 99,
        'is_active': true,
      });
      expect(created2, isFalse);
      expect(u2.id, u1.id);
      expect(u2.email, 'goc@example.com');

      // 3. update_or_create on existing record -> updates and returns existing
      final (u3, created3) = await UserOrmExtension.objects()
          .filter(Q('name', 'GOC_User'))
          .updateOrCreate(
            db,
            defaults: {
              'name': 'GOC_User',
              'email': 'should_not_use@example.com',
              'age': 1,
              'is_active': true,
            },
            updates: {
              'email': 'updated_goc@example.com',
              'age': 34,
            },
          );
      expect(created3, isFalse);
      expect(u3.id, u1.id);

      final reloaded = await UserOrmExtension.objects().filter({'id': u1.id}).get(db);
      expect(reloaded.email, 'updated_goc@example.com');
      expect(reloaded.age, 34);

      // 4. update_or_create on new record -> creates
      final (u4, created4) = await UserOrmExtension.objects()
          .filter(Q('name', 'BrandNew'))
          .updateOrCreate(
            db,
            defaults: {
              'name': 'BrandNew',
              'email': 'new@example.com',
              'age': 18,
              'is_active': true,
            },
            updates: {},
          );
      expect(created4, isTrue);
      expect(u4.name, 'BrandNew');
      expect(u4.id, greaterThan(0));
    });

    test('12. values() and values_list() projection', () async {
      await User(name: 'John', email: 'john@example.com', age: 40).save(db);
      await User(name: 'Jane', email: 'jane@example.com', age: 42).save(db);

      // values()
      final valList = await UserOrmExtension.objects()
          .orderBy('name')
          .values(db, ['name', 'age']);
      expect(valList.length, 2);
      expect(valList[0]['name'], 'Jane');
      expect(valList[0]['age'], 42);
      expect(valList[1]['name'], 'John');
      expect(valList[1]['age'], 40);

      // values_list()
      final names = await UserOrmExtension.objects()
          .orderBy('name')
          .valuesList(db, 'name');
      expect(names, ['Jane', 'John']);
    });

    test('13. transaction() - commits all writes on success', () async {
      await db.transaction((tx) async {
        await User(name: 'Tx1', email: 'tx1@example.com', age: 20).save(tx);
        await User(name: 'Tx2', email: 'tx2@example.com', age: 21).save(tx);
      });

      final rows = await db.fetchAll('SELECT name FROM "auth_users"');
      expect(rows.map((r) => r['name']), containsAll(['Tx1', 'Tx2']));
    });

    test('14. transaction() - rolls back all writes when the callback throws',
        () async {
      await User(name: 'Pristine', email: 'pristine@example.com', age: 50)
          .save(db);

      Object? caught;
      try {
        await db.transaction((tx) async {
          await User(
                  name: 'ShouldRollback',
                  email: 'rollback@example.com',
                  age: 22)
              .save(tx);
          throw StateError('deliberate failure inside transaction');
        });
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<StateError>());

      final rows = await db.fetchAll('SELECT name FROM "auth_users"');
      expect(rows.map((r) => r['name']), isNot(contains('ShouldRollback')));
      expect(rows.map((r) => r['name']), contains('Pristine'));
    });

    test('15. transaction() - returns the callback\'s value', () async {
      final result = await db.transaction((tx) async {
        final u = await User(
                name: 'Returned', email: 'returned@example.com', age: 33)
            .save(tx);
        return u.id;
      });

      expect(result, greaterThan(0));
      final fetched =
          await UserOrmExtension.objects().filter(Q('name', 'Returned')).get(db);
      expect(fetched.id, result);
    });
  });
}
