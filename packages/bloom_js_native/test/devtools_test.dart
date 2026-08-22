import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

void main() {
  setUp(() {
    BloomJsDevTools.clearEventLog();
  });

  group('BloomJsDevTools.notify / eventLog', () {
    test('notify() appends an event to eventLog', () {
      BloomJsDevTools.notify('mount', {'id': 'a'});
      expect(BloomJsDevTools.eventLog, hasLength(1));
      expect(BloomJsDevTools.eventLog.first.type, 'mount');
      expect(BloomJsDevTools.eventLog.first.data, {'id': 'a'});
    });

    test('notify() calls registered listeners', () {
      final received = <String>[];
      final unregister = BloomJsDevTools.addListener((event, data) {
        received.add(event);
      });
      BloomJsDevTools.notify('unmount', {});
      unregister();
      BloomJsDevTools.notify('mount', {});
      expect(received, ['unmount']);
    });

    test('eventLog is capped at maxEventLogSize', () {
      for (var i = 0; i < BloomJsDevTools.maxEventLogSize + 10; i++) {
        BloomJsDevTools.notify('event$i', {});
      }
      expect(BloomJsDevTools.eventLog.length, BloomJsDevTools.maxEventLogSize);
      expect(BloomJsDevTools.eventLog.first.type, 'event10');
    });

    test('clearEventLog() empties the log', () {
      BloomJsDevTools.notify('mount', {});
      BloomJsDevTools.clearEventLog();
      expect(BloomJsDevTools.eventLog, isEmpty);
    });

    test('a throwing listener does not prevent other listeners from running', () {
      var secondCalled = false;
      BloomJsDevTools.addListener((event, data) => throw StateError('boom'));
      BloomJsDevTools.addListener((event, data) => secondCalled = true);
      BloomJsDevTools.notify('mount', {});
      expect(secondCalled, isTrue);
    });
  });

  group('BloomJsDevTools.snapshotTree', () {
    test('serializes an ElNode with tag, text, and children', () {
      final tree = Div(
        className: 'wrapper',
        children: [
          Span(text: 'hello'),
        ],
      );
      final snapshot = BloomJsDevTools.snapshotTree(tree);
      expect(snapshot['kind'], 'element');
      expect(snapshot['tag'], 'div');
      expect(snapshot['className'], 'wrapper');
      final children = snapshot['children'] as List;
      expect(children, hasLength(1));
      expect(children.first['tag'], 'span');
    });

    test('serializes a TextNode', () {
      final snapshot = BloomJsDevTools.snapshotTree(Text('plain text'));
      expect(snapshot['kind'], 'text');
      expect(snapshot['text'], 'plain text');
    });

    test('serializes attrs when present', () {
      final tree = El('button', attrs: {'data-testid': 'submit'});
      final snapshot = BloomJsDevTools.snapshotTree(tree);
      expect(snapshot['attrs'], {'data-testid': 'submit'});
    });
  });
}
