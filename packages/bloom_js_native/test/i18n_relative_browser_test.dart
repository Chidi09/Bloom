@TestOn('browser')
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  test('relative-time wording matches the VM output', () {
    final now = DateTime.utc(2026, 9, 25, 12);
    final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
    expect(formatRelativeTime(fiveMinutesAgo, relativeTo: now, locale: 'ru-RU'),
        '5 минут назад');
    expect(formatRelativeTime(fiveMinutesAgo, relativeTo: now, locale: 'ar-EG'),
        'منذ 5 دقائق');
  });
}
