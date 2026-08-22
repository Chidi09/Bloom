import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('Validators', () {
    test('required() returns null for non-empty value', () {
      expect(required()('hello'), isNull);
    });

    test('required() returns error for empty value', () {
      expect(required()(''), isNotNull);
    });

    test('required() uses custom message', () {
      expect(required('Name is required')(''), 'Name is required');
    });

    test('minLength(3) passes for 3-char string', () {
      expect(minLength(3)('abc'), isNull);
    });

    test('minLength(3) fails for 2-char string', () {
      expect(minLength(3)('ab'), isNotNull);
    });

    test('maxLength(5) passes for 5-char string', () {
      expect(maxLength(5)('hello'), isNull);
    });

    test('maxLength(5) fails for 6-char string', () {
      expect(maxLength(5)('toolong'), isNotNull);
    });

    test('email() passes valid email', () {
      expect(email()('user@example.com'), isNull);
    });

    test('email() fails invalid email', () {
      expect(email()('not-an-email'), isNotNull);
    });

    test('pattern() passes matching string', () {
      expect(pattern(RegExp(r'^\d+$'))('123'), isNull);
    });

    test('pattern() fails non-matching string', () {
      expect(pattern(RegExp(r'^\d+$'))('abc'), isNotNull);
    });
  });

  group('BloomFormField', () {
    test('starts clean with initial value', () {
      final field = BloomFormField(initialValue: 'hello');
      expect(field.value.value, 'hello');
      expect(field.isDirty.value, isFalse);
      expect(field.isTouched.value, isFalse);
      expect(field.isValid.value, isTrue);
    });

    test('setValue marks dirty and updates value', () {
      final field = BloomFormField(initialValue: '');
      field.setValue('new value');
      expect(field.value.value, 'new value');
      expect(field.isDirty.value, isTrue);
    });

    test('touch marks isTouched', () {
      final field = BloomFormField(initialValue: '');
      field.touch();
      expect(field.isTouched.value, isTrue);
    });

    test('validate() populates errors for failing validators', () {
      final field = BloomFormField(
        initialValue: '',
        validators: [required('Required'), minLength(3, 'Too short')],
      );
      field.validate();
      expect(field.errors.value, contains('Required'));
    });

    test('validate() clears errors after fixing value', () {
      final field = BloomFormField(
          initialValue: '', validators: [required()]);
      field.validate();
      expect(field.isValid.value, isFalse);
      field.setValue('hello');
      field.validate();
      expect(field.isValid.value, isTrue);
      expect(field.errors.value, isEmpty);
    });

    test('reset() restores initial value and clears state', () {
      final field = BloomFormField(initialValue: 'init');
      field.setValue('changed');
      field.touch();
      field.validate();
      field.reset();
      expect(field.value.value, 'init');
      expect(field.isDirty.value, isFalse);
      expect(field.isTouched.value, isFalse);
      expect(field.errors.value, isEmpty);
    });
  });

  group('BloomForm', () {
    late BloomForm form;

    setUp(() {
      form = BloomForm({
        'username': BloomFormField(
          initialValue: '',
          validators: [required(), minLength(3)],
        ),
        'email': BloomFormField(
          initialValue: '',
          validators: [required(), email()],
        ),
      });
    });

    test('isValid is false when required fields are empty', () {
      form.validate();
      expect(form.isValid.value, isFalse);
    });

    test('isValid is true when all fields pass', () {
      form.getField('username').setValue('alice');
      form.getField('email').setValue('alice@example.com');
      form.validate();
      expect(form.isValid.value, isTrue);
    });

    test('getValue returns current field value', () {
      form.getField('username').setValue('bob');
      expect(form.getValue('username'), 'bob');
    });

    test('values returns map of all fields', () {
      form.getField('username').setValue('charlie');
      form.getField('email').setValue('charlie@example.com');
      final vals = form.values;
      expect(vals['username'], 'charlie');
      expect(vals['email'], 'charlie@example.com');
    });

    test('submit calls onSubmit with values when valid', () async {
      form.getField('username').setValue('dave');
      form.getField('email').setValue('dave@example.com');
      Map<String, String>? submitted;
      await form.submit((vals) async => submitted = vals);
      expect(submitted, isNotNull);
      expect(submitted!['username'], 'dave');
    });

    test('submit does not call onSubmit when invalid', () async {
      bool called = false;
      await form.submit((_) async => called = true);
      expect(called, isFalse);
    });

    test('isSubmitting is true during submit', () async {
      form.getField('username').setValue('eve');
      form.getField('email').setValue('eve@example.com');
      final statuses = <bool>[];
      effect(() => statuses.add(form.isSubmitting.value));
      await form.submit((_) async =>
          await Future.delayed(const Duration(milliseconds: 10)));
      expect(statuses, containsAllInOrder([true, false]));
    });

    test('reset() restores all fields', () {
      form.getField('username').setValue('frank');
      form.reset();
      expect(form.getValue('username'), '');
    });

    test('getField throws StateError for unknown name', () {
      expect(() => form.getField('nonexistent'), throwsA(isA<StateError>()));
    });
  });
}
