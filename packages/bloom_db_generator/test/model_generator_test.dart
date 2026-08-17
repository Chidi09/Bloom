// test/model_generator_test.dart
import 'package:bloom_db_generator/src/model_generator.dart';
import 'package:test/test.dart';

void main() {
  group('ModelGenerator', () {
    test('instantiates generator correctly', () {
      final generator = ModelGenerator();
      expect(generator, isNotNull);
    });
  });
}
