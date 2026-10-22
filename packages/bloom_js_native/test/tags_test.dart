import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/tags.dart' as h;
import 'package:test/test.dart';

void main() {
  group('concise tags', () {
    test('README example renders like core descriptors', () {
      final concise = h.div([
        h.h2(['Title']),
        h.p([
          'Hello ',
          h.strong(['world'])
        ]),
      ], cls: 'card');
      final core = Div(
        className: 'card',
        children: [
          H2(text: 'Title'),
          P(children: [Text('Hello '), Strong(text: 'world')]),
        ],
      );
      expect(renderToHtml(concise), renderToHtml(core));
      expect(renderToHtml(concise),
          '<div class="card"><h2>Title</h2><p>Hello <strong>world</strong></p></div>');
    });

    test('converts and flattens child values safely', () {
      expect(
          renderToHtml(h.div([
            '<b>',
            null,
            false,
            [2]
          ])),
          '<div>&lt;b&gt;<!---->2</div>');
      expect(() => h.nodes([Object()]), throwsArgumentError);
      expect(() => h.nodes([true]), throwsArgumentError);
    });

    test('merges id, data, and explicit attributes', () {
      final node = h.div(
        [],
        id: 'first',
        data: {'kind': 'card', 'state': 'new'},
        attrs: {'id': 'override', 'data-kind': 'explicit'},
      );
      expect(node.attrs, {
        'id': 'override',
        'data-kind': 'explicit',
        'data-state': 'new',
      });
    });

    test('handles specialized attributes and click handlers', () {
      void click(BloomEvent event) {}
      expect(h.a([], href: '/home', target: '_blank').attrs,
          {'href': '/home', 'target': '_blank'});
      expect(
          h.img(src: '/x.png', alt: 'x').attrs, {'src': '/x.png', 'alt': 'x'});
      expect(h.label([], htmlFor: 'email').attrs, {'for': 'email'});
      expect(h.div([], onClick: click).on?['click'], same(click));
    });

    test('forwards reactive class options', () {
      final classIf = {'active': () => true};
      String reactiveClass() => 'ready';
      final node = h.div([], classIf: classIf, reactiveClass: reactiveClass);
      expect(node.classIf, same(classIf));
      expect(node.reactiveClass, same(reactiveClass));
    });
  });
}
