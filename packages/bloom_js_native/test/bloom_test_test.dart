import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  group('BloomTestRenderer queries', () {
    test('getByTestId finds element by data-testid attribute', () {
      final tree = Div(children: [
        El('button', attrs: {'data-testid': 'submit-btn'}, text: 'Submit'),
      ]);
      final renderer = renderForTest(tree);
      final btn = renderer.getByTestId('submit-btn');
      expect(btn.tag, 'button');
    });

    test('queryByTestId returns null when not found', () {
      final tree = Div(children: [Text('hello')]);
      final renderer = renderForTest(tree);
      expect(renderer.queryByTestId('nope'), isNull);
    });

    test('getByTestId throws StateError when not found', () {
      final tree = Div(children: [Text('hello')]);
      final renderer = renderForTest(tree);
      expect(() => renderer.getByTestId('nope'), throwsA(isA<StateError>()));
    });

    test('getByText finds a TextNode by exact text', () {
      final tree = Div(children: [Span(text: 'Hello world')]);
      final renderer = renderForTest(tree);
      final found = renderer.getByText('Hello world');
      expect(found, isNotNull);
    });

    test('queryByText returns null for non-matching text', () {
      final tree = Div(children: [Text('Hello world')]);
      final renderer = renderForTest(tree);
      expect(renderer.queryByText('Goodbye'), isNull);
    });

    test('getByTag finds first matching element tag', () {
      final tree = Div(children: [
        Span(text: 'a'),
        El('button', text: 'Click me'),
      ]);
      final renderer = renderForTest(tree);
      final btn = renderer.getByTag('button');
      expect(btn.text, 'Click me');
    });

    test('toHtml renders the tree via SSR', () {
      final tree = Div(children: [Text('rendered')]);
      final renderer = renderForTest(tree);
      expect(renderer.toHtml(), contains('rendered'));
    });

    test('queries traverse nested Fragment and Show', () {
      final tree = Fragment(children: [
        Show(
          () => true,
          child: El('button', attrs: {'data-testid': 'nested-btn'}),
        ),
      ]);
      final renderer = renderForTest(tree);
      expect(renderer.getByTestId('nested-btn').tag, 'button');
    });
  });

  group('fireEvent', () {
    test('click invokes the onClick-registered handler', () {
      var clicked = false;
      final btn = El('button', on: {
        'click': (event) => clicked = true,
      });
      fireEvent.click(btn);
      expect(clicked, isTrue);
    });

    test('input invokes handler with the given value', () {
      String? received;
      final input = El('input', on: {
        'input': (event) => received = event.value,
      });
      fireEvent.input(input, value: 'hello');
      expect(received, 'hello');
    });

    test('change invokes handler with value and checked', () {
      String? receivedValue;
      bool? receivedChecked;
      final checkbox = El('input', on: {
        'change': (event) {
          receivedValue = event.value;
          receivedChecked = event.checked;
        },
      });
      fireEvent.change(checkbox, value: 'x', checked: true);
      expect(receivedValue, 'x');
      expect(receivedChecked, isTrue);
    });

    test('submit invokes the registered handler', () {
      var submitted = false;
      final form = El('form', on: {
        'submit': (event) => submitted = true,
      });
      fireEvent.submit(form);
      expect(submitted, isTrue);
    });

    test('throws StateError when no handler is registered for the event type', () {
      final btn = El('button');
      expect(() => fireEvent.click(btn), throwsA(isA<StateError>()));
    });
  });
}
