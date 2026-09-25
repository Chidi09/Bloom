import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  test('uses locale-specific Indian digit grouping', () {
    expect(formatNumber(12345678.9, locale: 'hi-IN'), '1,23,45,678.9');
  });

  test('uses localized month names beyond the original four languages', () {
    expect(
      formatDate(DateTime(2026, 8, 23),
          locale: 'it-IT', style: DateFormatStyle.long),
      '23 agosto 2026',
    );
  });

  test('preserves ratio and whole-number percent inputs', () {
    expect(formatPercent(0.42, locale: 'en-US'), '42%');
    expect(formatPercent(42, locale: 'en-US'), '42%');
  });
}
