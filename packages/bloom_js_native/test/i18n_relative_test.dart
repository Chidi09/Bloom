import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 25, 12);

  test('localizes relative phrases across additional language families', () {
    final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
    expect(formatRelativeTime(fiveMinutesAgo, relativeTo: now, locale: 'ru-RU'),
        '5 минут назад');
    expect(formatRelativeTime(fiveMinutesAgo, relativeTo: now, locale: 'it-IT'),
        '5 minuti fa');
    expect(formatRelativeTime(fiveMinutesAgo, relativeTo: now, locale: 'hi-IN'),
        '5 मिनट पहले');
    expect(formatRelativeTime(fiveMinutesAgo, relativeTo: now, locale: 'ko-KR'),
        '5분 전');
    expect(formatRelativeTime(fiveMinutesAgo, relativeTo: now, locale: 'ar-EG'),
        'منذ 5 دقائق');
  });

  test('keeps future and numeric day wording localized', () {
    expect(
      formatRelativeTime(now.add(const Duration(hours: 2)),
          relativeTo: now, locale: 'it-IT'),
      'tra 2 ore',
    );
    expect(
      formatRelativeTime(now.subtract(const Duration(days: 1)),
          relativeTo: now, locale: 'ru-RU', numeric: true),
      '1 день назад',
    );
  });

  test('keeps existing phrases and English fallback', () {
    final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
    expect(formatRelativeTime(fiveMinutesAgo, relativeTo: now, locale: 'fr-FR'),
        'il y a 5 minutes');
    expect(formatRelativeTime(fiveMinutesAgo, relativeTo: now, locale: 'sw-KE'),
        '5 minutes ago');
    expect(supportedRelativeTimeLocales.length, greaterThan(40));
  });
}
