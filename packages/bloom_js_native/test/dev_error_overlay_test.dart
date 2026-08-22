import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('renderDevErrorOverlay', () {
    test('includes the error message', () {
      final html = renderDevErrorOverlay(
        StateError('boom'),
        StackTrace.current,
      );
      expect(html, contains('boom'));
    });

    test('includes a data attribute marking it as the overlay root', () {
      final html = renderDevErrorOverlay(
        Exception('failure'),
        StackTrace.current,
      );
      expect(html, contains('data-bloom-dev-error-overlay="true"'));
    });

    test('includes componentName when provided', () {
      final html = renderDevErrorOverlay(
        Exception('failure'),
        StackTrace.current,
        componentName: 'UserProfile',
      );
      expect(html, contains('UserProfile'));
    });

    test('includes sourceHint when provided', () {
      final html = renderDevErrorOverlay(
        Exception('failure'),
        StackTrace.current,
        sourceHint: 'lib/pages/home.dart:42',
      );
      expect(html, contains('lib/pages/home.dart:42'));
    });

    test('omits the subtitle line when neither componentName nor sourceHint is given', () {
      final html = renderDevErrorOverlay(
        Exception('failure'),
        StackTrace.current,
      );
      expect(html.contains('color:#e0b3b3'), isFalse);
    });

    test('escapes HTML special characters in the error message', () {
      final html = renderDevErrorOverlay(
        Exception('<script>alert(1)</script>'),
        StackTrace.current,
      );
      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script&gt;'));
    });

    test('includes the stack trace text', () {
      StackTrace? captured;
      try {
        throw StateError('x');
      } catch (_, st) {
        captured = st;
      }
      final html = renderDevErrorOverlay(StateError('x'), captured);
      expect(html, contains('main.<anonymous closure>'.replaceAll('<', '&lt;').replaceAll('>', '&gt;')));
    });
  });

  group('renderDevErrorOverlayJson', () {
    test('produces valid JSON with message and stack fields', () {
      final json = renderDevErrorOverlayJson(
        StateError('boom'),
        StackTrace.current,
      );
      expect(json, contains('"type":"bloom-dev-error"'));
      expect(json, contains('boom'));
    });

    test('includes componentName and sourceHint fields when provided', () {
      final json = renderDevErrorOverlayJson(
        Exception('failure'),
        StackTrace.current,
        componentName: 'Widget',
        sourceHint: 'foo.dart:1',
      );
      expect(json, contains('Widget'));
      expect(json, contains('foo.dart:1'));
    });

    test('omits componentName/sourceHint fields when not provided', () {
      final json = renderDevErrorOverlayJson(
        Exception('failure'),
        StackTrace.current,
      );
      expect(json, isNot(contains('componentName')));
      expect(json, isNot(contains('sourceHint')));
    });
  });
}
