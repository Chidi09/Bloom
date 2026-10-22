import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

String avatar() => 'local avatar';

void main() {
  test('core import leaves UI primitive names available to callers', () {
    expect(avatar(), 'local avatar');
    expect(renderToHtml(Div(text: 'core')), contains('core'));
  });
}
