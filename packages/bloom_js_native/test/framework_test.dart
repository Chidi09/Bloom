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
  });
}
