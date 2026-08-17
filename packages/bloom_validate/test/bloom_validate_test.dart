import 'package:bloom_validate/bloom_validate.dart';
import 'package:test/test.dart';

class _SignupSchema extends BloomRequestSchema {
  _SignupSchema(super.data);

  late final String name = requireStringLength('name', min: 2, max: 100);
  late final String email = requireEmail('email');
  late final int age = requireInt('age');
  late final bool subscribed = optionalBool('subscribed', defaultValue: false);

  @override
  void validate() {
    name;
    email;
    age;
    subscribed;
  }
}

void main() {
  group('BloomRequestSchema', () {
    test('validates a fully correct payload', () {
      final schema = BloomRequestSchema.validateSchema(_SignupSchema({
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'age': 30,
        'subscribed': true,
      }));

      expect(schema.name, 'Ada Lovelace');
      expect(schema.email, 'ada@example.com');
      expect(schema.age, 30);
      expect(schema.subscribed, isTrue);
    });

    test('applies default for a missing optional field', () {
      final schema = BloomRequestSchema.validateSchema(_SignupSchema({
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'age': 30,
      }));
      expect(schema.subscribed, isFalse);
    });

    test('throws BloomValidationException for a missing required field', () {
      expect(
        () => BloomRequestSchema.validateSchema(_SignupSchema({
          'email': 'ada@example.com',
          'age': 30,
        })),
        throwsA(isA<BloomValidationException>()),
      );
    });

    test('throws for an invalid email address', () {
      expect(
        () => BloomRequestSchema.validateSchema(_SignupSchema({
          'name': 'Ada',
          'email': 'not-an-email',
          'age': 30,
        })),
        throwsA(isA<BloomValidationException>()),
      );
    });

    test('throws for a string field failing length constraints', () {
      expect(
        () => BloomRequestSchema.validateSchema(_SignupSchema({
          'name': 'A',
          'email': 'ada@example.com',
          'age': 30,
        })),
        throwsA(isA<BloomValidationException>()),
      );
    });

    test('throws for an unparseable integer field', () {
      expect(
        () => BloomRequestSchema.validateSchema(_SignupSchema({
          'name': 'Ada Lovelace',
          'email': 'ada@example.com',
          'age': 'not-a-number',
        })),
        throwsA(isA<BloomValidationException>()),
      );
    });

    test('accepts a numeric-string integer field', () {
      final schema = BloomRequestSchema.validateSchema(_SignupSchema({
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'age': '42',
      }));
      expect(schema.age, 42);
    });
  });
}
