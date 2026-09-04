import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_rest/bloom_rest.dart';
import 'package:test/test.dart';

class TestUser extends Model {
  final int id;
  final String username;
  final String email;
  final String password;
  final String passwordHash;
  final String token;
  final String apiKey;
  final String secret;
  final bool isActive;
  final DateTime createdAt;

  TestUser({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    required this.passwordHash,
    required this.token,
    required this.apiKey,
    required this.secret,
    required this.isActive,
    required this.createdAt,
  });

  static const meta = ModelMeta(
    structName: 'TestUser',
    appLabel: 'auth',
    tableName: 'test_users',
    fields: [
      FieldMeta(
          name: 'id',
          columnName: 'id',
          kind: FieldKind.bigInt,
          primaryKey: true,
          auto: true),
      FieldMeta(
          name: 'username',
          columnName: 'username',
          kind: FieldKind.char,
          maxLength: 100),
      FieldMeta(
          name: 'email',
          columnName: 'email',
          kind: FieldKind.char,
          maxLength: 255),
      FieldMeta(
          name: 'password',
          columnName: 'password',
          kind: FieldKind.char,
          maxLength: 255),
      FieldMeta(
          name: 'password_hash',
          columnName: 'password_hash',
          kind: FieldKind.char,
          maxLength: 255),
      FieldMeta(
          name: 'token',
          columnName: 'token',
          kind: FieldKind.char,
          maxLength: 255),
      FieldMeta(
          name: 'api_key',
          columnName: 'api_key',
          kind: FieldKind.char,
          maxLength: 255),
      FieldMeta(
          name: 'secret',
          columnName: 'secret',
          kind: FieldKind.char,
          maxLength: 255),
      FieldMeta(
          name: 'is_active', columnName: 'is_active', kind: FieldKind.boolean),
      FieldMeta(
          name: 'created_at',
          columnName: 'created_at',
          kind: FieldKind.dateTime),
    ],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('username', BloomValue.text(username)),
        ('email', BloomValue.text(email)),
        ('password', BloomValue.text(password)),
        ('password_hash', BloomValue.text(passwordHash)),
        ('token', BloomValue.text(token)),
        ('api_key', BloomValue.text(apiKey)),
        ('secret', BloomValue.text(secret)),
        ('is_active', BloomValue.boolVal(isActive)),
        ('created_at', BloomValue.dateTime(createdAt)),
      ];

  static TestUser fromRow(DbRow row) {
    return TestUser(
      id: row.tryIntByName('id') ?? 0,
      username: row.tryStringByName('username') ?? '',
      email: row.tryStringByName('email') ?? '',
      password: row.tryStringByName('password') ?? '',
      passwordHash: row.tryStringByName('password_hash') ?? '',
      token: row.tryStringByName('token') ?? '',
      apiKey: row.tryStringByName('api_key') ?? '',
      secret: row.tryStringByName('secret') ?? '',
      isActive: row.tryBoolByName('is_active') ?? true,
      createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now(),
    );
  }
}

void main() {
  final sampleUser = TestUser(
    id: 1,
    username: 'alice',
    email: 'alice@example.com',
    password: 'plaintext_password_123',
    passwordHash: 'argon2_hashed_secret',
    token: 'jwt_access_token_xyz',
    apiKey: 'bk_live_key_999',
    secret: 'totp_shared_secret',
    isActive: true,
    createdAt: DateTime.utc(2026, 8, 25, 12, 0, 0),
  );

  group('Sensitive Field Hardening (Secure by Default)', () {
    test('excludes all sensitive fields from toRepresentation by default', () {
      final serializer = BloomModelSerializer<TestUser>(meta: TestUser.meta);
      final repr = serializer.toRepresentation(sampleUser);

      expect(repr['id'], 1);
      expect(repr['username'], 'alice');
      expect(repr['email'], 'alice@example.com');
      expect(repr['is_active'], true);
      expect(repr['created_at'], '2026-08-25T12:00:00.000Z');

      // Sensitive fields must NOT be emitted in output
      expect(repr.containsKey('password'), isFalse);
      expect(repr.containsKey('password_hash'), isFalse);
      expect(repr.containsKey('token'), isFalse);
      expect(repr.containsKey('api_key'), isFalse);
      expect(repr.containsKey('secret'), isFalse);
    });

    test('rejects sensitive fields on write by default', () {
      final serializer = BloomModelSerializer<TestUser>(meta: TestUser.meta);
      final (values, errors) = serializer.parse({
        'username': 'bob',
        'email': 'bob@example.com',
        'is_active': true,
        'created_at': '2026-08-25T12:00:00Z',
        'password': 'bad_password',
        'token': 'injected_token',
      });

      expect(values, isNull);
      expect(errors, isNotNull);
      expect(errors!.toMap().containsKey('password'), isTrue);
      expect(errors.toMap().containsKey('token'), isTrue);
    });

    test(
        'allows sensitive fields when includeSensitiveFields is explicitly true',
        () {
      final serializer = BloomModelSerializer<TestUser>(
        meta: TestUser.meta,
        includeSensitiveFields: true,
      );
      final repr = serializer.toRepresentation(sampleUser);

      expect(repr['password'], 'plaintext_password_123');
      expect(repr['password_hash'], 'argon2_hashed_secret');
      expect(repr['token'], 'jwt_access_token_xyz');
      expect(repr['api_key'], 'bk_live_key_999');
      expect(repr['secret'], 'totp_shared_secret');

      final (values, errors) = serializer.parse({
        'username': 'bob',
        'email': 'bob@example.com',
        'password': 'bob_password',
        'password_hash': 'hash_123',
        'token': 'token_abc',
        'api_key': 'key_xyz',
        'secret': 'sec_456',
        'is_active': true,
        'created_at': '2026-08-25T12:00:00Z',
      });

      expect(errors, isNull);
      expect(values?['password'], 'bob_password');
      expect(values?['secret'], 'sec_456');
    });

    test('can configure writeOnly sensitive fields when opted in', () {
      final serializer = BloomModelSerializer<TestUser>(
        meta: TestUser.meta,
        includeSensitiveFields: true,
        fields: BloomFieldSet.all().withWriteOnly(
            ['password', 'password_hash']).withReadOnly(['id', 'created_at']),
      );

      final repr = serializer.toRepresentation(sampleUser);
      expect(repr.containsKey('password'), isFalse);
      expect(repr.containsKey('password_hash'), isFalse);
      expect(repr['username'], 'alice');

      final (values, errors) = serializer.parse({
        'username': 'charlie',
        'email': 'charlie@example.com',
        'password': 'new_password',
        'password_hash': 'new_hash',
        'token': 'tok',
        'api_key': 'key',
        'secret': 'sec',
        'is_active': true,
      }, partial: true);

      expect(errors, isNull);
      expect(values?['password'], 'new_password');
    });
  });

  group('BloomFieldSet & Validation', () {
    test('onlyFields limits both read and write', () {
      final serializer = BloomModelSerializer<TestUser>(
        meta: TestUser.meta,
        fields: BloomFieldSet.onlyFields(['id', 'username']),
      );

      final repr = serializer.toRepresentation(sampleUser);
      expect(repr.keys, ['id', 'username']);

      final (values, errors) = serializer.parse({
        'username': 'dan',
        'email': 'dan@example.com',
      }, partial: true);

      expect(values, isNull);
      expect(errors?.toMap().containsKey('email'), isTrue);
    });

    test('readOnly fields cannot be written', () {
      final serializer = BloomModelSerializer<TestUser>(
        meta: TestUser.meta,
        fields: BloomFieldSet.all().withReadOnly(['id', 'created_at']),
      );

      final (values, errors) = serializer.parse({
        'id': 99,
        'username': 'eve',
      }, partial: true);

      expect(values, isNull);
      expect(errors?.toMap()['id']?.first, 'field is read-only');
    });

    test('withValidator executes custom validation logic', () {
      final serializer = BloomModelSerializer<TestUser>(
        meta: TestUser.meta,
      ).withValidator((values, errors) {
        if (values['username'] == 'admin') {
          errors.add('username', 'The username "admin" is reserved.');
        }
      });

      final (values, errors) = serializer.parse({
        'username': 'admin',
        'email': 'admin@example.com',
        'is_active': true,
        'created_at': '2026-08-25T12:00:00Z',
      });

      expect(values, isNull);
      expect(errors?.toMap()['username']?.first,
          'The username "admin" is reserved.');
    });

    test('rejects fractional numeric booleans', () {
      final serializer = BloomModelSerializer<TestUser>(meta: TestUser.meta);
      final (values, errors) = serializer.parse({
        'username': 'fractional',
        'email': 'fractional@example.com',
        'is_active': 0.5,
        'created_at': '2026-08-25T12:00:00Z',
      });

      expect(values, isNull);
      expect(errors?.toMap().containsKey('is_active'), isTrue);
    });

    test('rejects garbage date values and relation-name typos', () {
      final dateMeta = ModelMeta(
        structName: 'DateInput',
        appLabel: 'test',
        tableName: 'date_inputs',
        fields: [
          FieldMeta(
            name: 'birth_date',
            columnName: 'birth_date',
            kind: FieldKind.date,
          ),
        ],
      );
      final dateSerializer = BloomModelSerializer<TestUser>(meta: dateMeta);
      final (_, dateErrors) = dateSerializer.parse(
        {'birth_date': 'not-a-date'},
        partial: true,
      );
      expect(dateErrors?.toMap().containsKey('birth_date'), isTrue);

      final serializer = BloomModelSerializer<TestUser>(meta: TestUser.meta);
      expect(
        () => serializer.toRepresentationNested(sampleUser, {
          'misspelled_relation': {'id': 1},
        }),
        throwsArgumentError,
      );
    });
  });

  group('BloomValidationErrors', () {
    test(
        'flattens single errors and preserves list for multiple errors in toJson',
        () {
      final errors = BloomValidationErrors();
      errors.add('email', 'Email required');
      errors.add('tags', 'Tag 1 invalid');
      errors.add('tags', 'Tag 2 invalid');

      final json = errors.toJson();
      expect(json['email'], 'Email required');
      expect(json['tags'], ['Tag 1 invalid', 'Tag 2 invalid']);
    });
  });
}
