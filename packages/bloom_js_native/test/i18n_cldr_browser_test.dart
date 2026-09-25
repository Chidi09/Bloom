@TestOn('browser')
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  test('CLDR number and date results match the server', () {
    expect(formatNumber(12345678.9, locale: 'hi-IN'), '1,23,45,678.9');
    expect(
      formatDate(DateTime(2026, 8, 23),
          locale: 'it-IT', style: DateFormatStyle.long),
      '23 agosto 2026',
    );
  });
}
