import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/widgets.dart';
import 'package:test/test.dart';

void main() {
  group('layout widgets', () {
    test('Row and Column emit flex styles', () {
      final row = renderToHtml(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: 8,
        children: [StyledText('a')],
      ));
      expect(row, contains('display: flex'));
      expect(row, contains('flex-direction: row'));
      expect(row, contains('justify-content: space-between'));
      expect(row, contains('align-items: stretch'));
      expect(row, contains('gap: 8px'));
      expect(renderToHtml(Column()), contains('flex-direction: column'));
    });

    test('flex main-axis sizing avoids forced maximum dimensions', () {
      final maxRow = renderToHtml(Row());
      final minRow = renderToHtml(Row(mainAxisSize: MainAxisSize.min));
      final maxColumn = renderToHtml(Column());
      final minColumn = renderToHtml(Column(mainAxisSize: MainAxisSize.min));

      expect(maxRow, isNot(contains('width: 100%')));
      expect(minRow, contains('width: fit-content'));
      expect(maxColumn, isNot(contains('height: 100%')));
      expect(minColumn, contains('height: fit-content'));
    });

    test('padding, container and decoration emit CSS', () {
      final html = renderToHtml(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(4),
          color: Colors.white,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey),
          ),
          child: StyledText('box'),
        ),
      ));
      expect(const EdgeInsets.symmetric(vertical: 8, horizontal: 16).css,
          '8px 16px 8px 16px');
      expect(html, contains('padding: 8px 16px 8px 16px'));
      expect(html, contains('background-color: #ffffff'));
      expect(html, contains('border-radius: 6px'));
      expect(html, contains('border: 1px solid #9e9e9e'));
    });

    test('flex, Stack and Positioned emit expected styles', () {
      final html = renderToHtml(Row(children: [
        Expanded(flex: 2, child: StyledText('fill')),
        Flexible(child: StyledText('fit')),
        Spacer(),
      ]));
      expect(html, contains('flex: 2'));
      expect(html, contains('flex: 1 1 0%'));
      expect(html, contains('flex: 1'));
      final stack = renderToHtml(Stack(children: [
        Positioned(left: 3, top: 4, child: StyledText('badge')),
      ]));
      expect(stack, contains('position: relative'));
      expect(stack, contains('position: absolute'));
      expect(stack, contains('left: 3px'));
    });

    test('alignment, sizing, wrapping and scrolling emit CSS', () {
      expect(renderToHtml(Center(child: StyledText('center'))),
          contains('place-items: center center'));
      expect(renderToHtml(SizedBox(width: 80, height: 20)),
          contains('width: 80px; height: 20px'));
      expect(renderToHtml(SizedBox.expand()), contains('width: 100%'));
      expect(renderToHtml(SizedBox.shrink()), contains('width: 0; height: 0'));
      final container = renderToHtml(Container(
        minWidth: 10,
        maxWidth: 90,
        minHeight: 20,
        maxHeight: 100,
        alignment: Alignment.bottomRight,
      ));
      expect(container, contains('min-width: 10px'));
      expect(container, contains('max-width: 90px'));
      expect(container, contains('min-height: 20px'));
      expect(container, contains('max-height: 100px'));
      expect(container, contains('place-items: end end'));
      expect(renderToHtml(Wrap(spacing: 4, runSpacing: 6)),
          contains('column-gap: 4px; row-gap: 6px'));
      expect(renderToHtml(ListView(scrollDirection: Axis.horizontal)),
          contains('flex-direction: row'));
    });
  });

  test('StyledText maps text style and line clamp to CSS', () {
    final html = renderToHtml(StyledText(
      'styled',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      textAlign: TextAlign.center,
      maxLines: 2,
    ));
    expect(html, contains('font-size: 18px'));
    expect(html, contains('font-weight: 600'));
    expect(html, contains('text-align: center'));
    expect(html, contains('-webkit-line-clamp: 2'));
  });

  test('Theme emits custom properties and themed styles', () {
    final html = renderToHtml(Theme(
      data: const ThemeData(),
      child: StyledText('themed'),
    ));
    expect(html, contains('--bloom-primary: #2196f3'));
    expect(html, contains('--bloom-background: #ffffff'));
    expect(html, contains('--bloom-surface: #ffffff'));
    expect(html, contains('--bloom-text: #000000'));
    expect(html, contains('--bloom-muted: #9e9e9e'));
    expect(html, contains('--bloom-radius: 8px'));
    expect(html, contains('--bloom-font: sans-serif'));
    expect(html, contains('color: var(--bloom-text)'));
  });

  test('AnimatedOpacity evaluates its getter for SSR style', () {
    final html = renderToHtml(AnimatedOpacity(
      opacity: () => 0.4,
      child: StyledText('fade'),
    ));
    expect(html, contains('transition: opacity 200ms ease-in-out'));
    expect(html, contains('opacity: 0.4'));
  });

  test('AnimatedContainer evaluates its style getters for SSR', () {
    final html = renderToHtml(AnimatedContainer(
      width: () => 64,
      height: () => 32,
      color: () => Colors.red,
      padding: () => const EdgeInsets.all(5),
      decoration: () => const BoxDecoration(borderRadius: BorderRadius.all(4)),
      child: StyledText('animate'),
    ));
    expect(html, contains('transition: all 200ms ease-in-out'));
    expect(html, contains('width: 64px'));
    expect(html, contains('height: 32px'));
    expect(html, contains('background-color: #f44336'));
    expect(html, contains('padding: 5px 5px 5px 5px'));
    expect(html, contains('border-radius: 4px'));
  });

  test('GestureDetector has accessible button semantics and click handler', () {
    var tapped = false;
    final node = GestureDetector(
      onTap: () => tapped = true,
      child: StyledText('tap'),
    ) as ElNode;
    expect(node.attrs, {'role': 'button', 'tabindex': '0'});
    expect(node.on?.containsKey('click'), isTrue);
    node.on!['click']!(BloomEvent.fakeClick());
    expect(tapped, isTrue);
    node.on!['keydown']!(BloomEvent.fakeKeyDown(' '));
    expect(tapped, isTrue);
  });

  test('Color CSS supports opaque and translucent values', () {
    expect(const Color(0xffff0000).css, '#ff0000');
    expect(const Color.fromARGB(128, 255, 0, 0).css, 'rgba(255, 0, 0, 0.502)');
    expect(Color.fromRGBO(0, 0, 255, 0.5).css, 'rgba(0, 0, 255, 0.502)');
  });
}
