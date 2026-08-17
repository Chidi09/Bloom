import 'package:bloom_i18n/bloom_i18n.dart';
import 'package:test/test.dart';

void main() {
  group('BloomLocales translation & fallback', () {
    late BloomLocales locales;

    setUp(() {
      locales = BloomLocales(defaultLocale: 'en-US');
      locales.addLocale('en-US', {
        'welcome': 'Welcome!',
        'greeting': 'Hello, {name}!',
      });
      locales.addLocale('es-ES', {
        'welcome': '¡Bienvenido!',
      });
    });

    test('translates an exact locale match', () {
      expect(locales.translate('es-ES', 'welcome'), '¡Bienvenido!');
    });

    test('falls back to defaultLocale when key missing in requested locale', () {
      expect(locales.translate('es-ES', 'greeting', args: {'name': 'Ada'}), 'Hello, Ada!');
    });

    test('falls back to language subtag when exact regional tag has no catalog', () {
      locales.addLocale('en', {'onlyInBase': 'base value'});
      expect(locales.translate('en-GB', 'onlyInBase'), 'base value');
    });

    test('returns the raw messageId when no catalog has a translation', () {
      expect(locales.translate('fr-FR', 'nonexistent_key'), 'nonexistent_key');
    });

    test('interpolates named arguments', () {
      expect(locales.translate('en-US', 'greeting', args: {'name': 'World'}), 'Hello, World!');
    });

    test('hasLocale reflects registered catalogs', () {
      expect(locales.hasLocale('es-ES'), isTrue);
      expect(locales.hasLocale('de-DE'), isFalse);
    });
  });

  group('Plural formatting (ICU-style)', () {
    test('selects the correct plural branch for zero/one/other', () {
      final locales = BloomLocales(defaultLocale: 'en-US');
      locales.addLocale('en-US', {
        'items': '{count, plural, =0 {No items} =1 {One item} other {# items}}',
      });

      expect(locales.translate('en-US', 'items', args: {'count': 0}), 'No items');
      expect(locales.translate('en-US', 'items', args: {'count': 1}), 'One item');
      expect(locales.translate('en-US', 'items', args: {'count': 5}), '5 items');
    });
  });
}
