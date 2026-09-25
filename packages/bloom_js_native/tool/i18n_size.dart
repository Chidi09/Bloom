import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  print(formatNumber(12345678.9, locale: 'hi-IN'));
  print(formatDate(DateTime.now(), locale: 'it-IT'));
  print(formatRelativeTime(DateTime.now().subtract(const Duration(minutes: 5)),
      locale: 'ru-RU'));
}
