@TestOn('browser')
library;

import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLDivElement container;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body?.appendChild(container);
  });

  tearDown(() {
    container.remove();
  });

  group('SVG namespace browser tests', () {
    test('mounting Svg with children yields SVG namespace elements', () {
      final node = Svg(
        viewBox: '0 0 100 100',
        className: 'svg-icon',
        children: [
          SvgPath(d: 'M0 0L1 1'),
          El('g', children: [
            El('circle', attrs: {'cx': '50', 'cy': '50', 'r': '10'}),
          ]),
        ],
      );

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      final svgEl = container.firstElementChild as web.Element;
      expect(svgEl.namespaceURI, 'http://www.w3.org/2000/svg');
      expect(svgEl.getAttribute('class'), 'svg-icon');

      final pathEl = svgEl.querySelector('path')!;
      expect(pathEl.namespaceURI, 'http://www.w3.org/2000/svg');

      final gEl = svgEl.querySelector('g')!;
      expect(gEl.namespaceURI, 'http://www.w3.org/2000/svg');

      final circleEl = svgEl.querySelector('circle')!;
      expect(circleEl.namespaceURI, 'http://www.w3.org/2000/svg');
    });

    test('SVG elements inside Live whose signal changes keep SVG namespace',
        () {
      final color = signal('red');
      final node = Svg(
        viewBox: '0 0 20 20',
        children: [
          Live(() => SvgPath(
                d: 'M0 0L10 10',
                className: 'path-${color.value}',
                fill: color.value,
              )),
        ],
      );

      final handle = mountToElement(node, container);
      addTearDown(handle.dispose);

      final pathEl1 = container.querySelector('path')!;
      expect(pathEl1.namespaceURI, 'http://www.w3.org/2000/svg');
      expect(pathEl1.getAttribute('class'), 'path-red');

      color.value = 'blue';

      final pathEl2 = container.querySelector('path')!;
      expect(pathEl2.namespaceURI, 'http://www.w3.org/2000/svg');
      expect(pathEl2.getAttribute('class'), 'path-blue');
    });
  });
}
