import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:test/test.dart';

void main() {
  group('Descriptor tree', () {
    test('El creates ElNode with correct tag', () {
      final n = El('div', className: 'foo') as ElNode;
      expect(n.tag, 'div');
      expect(n.className, 'foo');
    });

    test('Text node', () {
      final n = Text('hello') as TextNode;
      expect(n.text, 'hello');
    });

    test('Fragment groups children', () {
      final f = Fragment(children: [Text('a'), Text('b')]) as FragmentNode;
      expect(f.children.length, 2);
    });

    test('Live wraps builder', () {
      final c = signal(0);
      final live = Live(() => P(text: 'Count ${c.value}')) as LiveNode;
      final inner = live.builder() as ElNode;
      expect(inner.tag, 'p');
    });

    test('Show predicate', () {
      final c = signal(5);
      final show = Show(() => c.value > 3, child: Text('yes'), fallback: Text('no')) as ShowNode;
      expect(show.when(), isTrue);
      c.value = 1;
      expect(show.when(), isFalse);
    });

    test('ForEach builder', () {
      final items = signal([1, 2, 3]);
      final node = ForEach(() => items.value, (int x) => Li(text: '$x')) as ForEachNode<int>;
      expect(node.items(), [1, 2, 3]);
      final built = node.builder(42) as ElNode;
      expect(built.text, '42');
    });

    test('ForEachNode keyFn extracts key string correctly', () {
      final items = signal([{'id': 'a', 'text': 'Apple'}, {'id': 'b', 'text': 'Banana'}]);
      final forEach = ForEach<Map<String, String>>(
        () => items.value,
        (m) => Li(text: m['text']!),
        key: (m) => m['id']!,
      );
      expect(forEach.keyFn, isNotNull);
      expect(forEach.keyFn!(items.value[0]), 'a');
      expect(forEach.keyFn!(items.value[1]), 'b');
    });

    test('Element builders produce correct tags', () {
      expect((Div() as ElNode).tag, 'div');
      expect((Span(text: 'x') as ElNode).tag, 'span');
      expect((H1(text: 'h') as ElNode).tag, 'h1');
      expect((Button(text: 'b') as ElNode).tag, 'button');
      expect((Input(placeholder: 'p') as ElNode).tag, 'input');
      expect((A(href: '/') as ElNode).tag, 'a');
      expect((Ul(children: []) as ElNode).tag, 'ul');
      expect((Li(text: 'i') as ElNode).tag, 'li');
    });

    test('onClick sugar merges correctly', () {
      final n = Button(onClick: (_) {}) as ElNode;
      expect(n.on, contains('click'));
    });

    test('Input attrs sugar', () {
      final n = Input(placeholder: 'enter', value: 'hi', type: 'text') as ElNode;
      expect(n.attrs!['placeholder'], 'enter');
      expect(n.attrs!['value'], 'hi');
      expect(n.attrs!['type'], 'text');
    });

    test('onMouseEnter sugar merges into "mouseenter"', () {
      final n = Div(onMouseEnter: (_) {}) as ElNode;
      expect(n.on, contains('mouseenter'));
    });

    test('onFocus sugar merges into "focus"', () {
      final n = Input(onFocus: (_) {}) as ElNode;
      expect(n.on, contains('focus'));
    });

    test('onBlur sugar merges into "blur"', () {
      final n = Input(onBlur: (_) {}) as ElNode;
      expect(n.on, contains('blur'));
    });

    test('onDblClick sugar merges into "dblclick"', () {
      final n = Button(onDblClick: (_) {}) as ElNode;
      expect(n.on, contains('dblclick'));
    });
  });

  group('cx()', () {
    test('joins non-null strings', () {
      expect(cx(['foo', 'bar']), 'foo bar');
    });
    test('filters null and false', () {
      expect(cx(['a', null, false, 'b']), 'a b');
    });
    test('includes conditional string', () {
      bool getActive() => true;
      expect(cx(['base', getActive() ? 'active' : null]), 'base active');
    });
    test('trims extra whitespace', () {
      expect(cx(['  a  ', 'b']), 'a b');
    });
    test('returns empty string for all null', () {
      expect(cx([null, false, null]), '');
    });
  });

  group('Text-semantic and interactive elements', () {
    test('Br produces void br element in SSR', () {
      final html = renderToHtml(Br());
      expect(html, '<br>');
    });

    test('Hr produces void hr element in SSR', () {
      final html = renderToHtml(Hr());
      expect(html, '<hr>');
    });

    test('Details and Summary render', () {
      final html = renderToHtml(
        Details(children: [Summary(text: 'Title'), P(text: 'body')]),
      );
      expect(html, '<details><summary>Title</summary><p>body</p></details>');
    });

    test('TimeEl and Abbr render with attrs', () {
      expect(renderToHtml(TimeEl(text: 'now', dateTime: '2026-08-21')), '<time datetime="2026-08-21">now</time>');
      expect(renderToHtml(Abbr(text: 'HTML', title: 'HyperText Markup Language')), '<abbr title="HyperText Markup Language">HTML</abbr>');
    });
  });

  group('Table and Select elements', () {
    test('Table renders full structure', () {
      final html = renderToHtml(Table(children: [
        Thead(children: [Tr(children: [Th(text: 'Name')])]),
        Tbody(children: [Tr(children: [Td(text: 'Alice')])]),
      ]));
      expect(html, '<table><thead><tr><th>Name</th></tr></thead><tbody><tr><td>Alice</td></tr></tbody></table>');
    });

    test('Select with Options renders', () {
      final html = renderToHtml(Select(children: [
        Option(value: '1', text: 'One'),
        Option(value: '2', text: 'Two'),
      ]));
      expect(html, '<select><option value="1">One</option><option value="2">Two</option></select>');
    });

    test('Th with scope emits attribute', () {
      expect(renderToHtml(Th(text: 'H', scope: 'col')), '<th scope="col">H</th>');
    });
  });
}
